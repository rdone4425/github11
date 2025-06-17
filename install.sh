#!/bin/bash

# GitHub文件同步工具一键安装脚本
# 适用于OpenWrt/Kwrt系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目信息
REPO_URL="https://github.com/rdone4425/github11"
RAW_URL="https://raw.githubusercontent.com/rdone4425/github11/main"
# GitHub加速域名（国内用户）
MIRROR_PREFIX="https://git.910626.xyz/"
INSTALL_DIR="/root/github-sync"
SCRIPT_NAME="github-sync.sh"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检测最佳下载源
detect_best_source() {
    log_info "检测最佳下载源..."

    # 测试GitHub原站连接速度
    local github_speed=999
    if curl -s --connect-timeout 3 --max-time 5 "https://raw.githubusercontent.com" >/dev/null 2>&1; then
        local start_time=$(date +%s%N)
        if curl -s --connect-timeout 5 --max-time 10 "https://raw.githubusercontent.com/rdone4425/github11/main/README.md" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            github_speed=$(( (end_time - start_time) / 1000000 ))
        fi
    fi

    # 测试加速镜像连接速度
    local mirror_speed=999
    if curl -s --connect-timeout 3 --max-time 5 "https://git.910626.xyz" >/dev/null 2>&1; then
        local start_time=$(date +%s%N)
        if curl -s --connect-timeout 5 --max-time 10 "https://git.910626.xyz/rdone4425/github11/raw/branch/main/README.md" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            mirror_speed=$(( (end_time - start_time) / 1000000 ))
        fi
    fi

    # 选择最快的源
    if [ "$mirror_speed" -lt "$github_speed" ]; then
        log_info "使用加速镜像源 (响应时间: ${mirror_speed}ms)"
        echo "$MIRROR_URL"
    else
        log_info "使用GitHub原站 (响应时间: ${github_speed}ms)"
        echo "$RAW_URL"
    fi
}

# 检测最佳下载源
detect_best_source() {
    log_info "检测网络环境，选择最佳下载源..."

    # 测试GitHub原站连接
    if curl -s --connect-timeout 5 --max-time 8 "${RAW_URL}/README.md" >/dev/null 2>&1; then
        log_info "GitHub原站连接正常，使用原站下载"
        echo "$RAW_URL"
        return 0
    fi

    # GitHub原站连接失败，尝试加速镜像
    log_warn "GitHub原站连接较慢，尝试使用加速镜像..."
    if curl -s --connect-timeout 5 --max-time 8 "${MIRROR_PREFIX}${RAW_URL}/README.md" >/dev/null 2>&1; then
        log_info "加速镜像连接成功，使用镜像下载"
        echo "${MIRROR_PREFIX}${RAW_URL}"
        return 0
    fi

    # 两个源都有问题，使用原站并提示用户
    log_warn "网络连接不稳定，将使用GitHub原站，可能下载较慢"
    echo "$RAW_URL"
}

# 检测系统类型
detect_system() {
    if [ -f /etc/openwrt_release ]; then
        echo "openwrt"
    elif command -v opkg >/dev/null 2>&1; then
        echo "openwrt"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

# 安装依赖
install_dependencies() {
    local system_type=$(detect_system)
    
    log_info "检测到系统类型: $system_type"
    
    case "$system_type" in
        "openwrt")
            log_info "OpenWrt系统，检查必要工具..."
            
            # 检查curl
            if ! command -v curl >/dev/null 2>&1; then
                log_info "安装curl..."
                opkg update && opkg install curl
            fi
            
            # 检查base64
            if ! command -v base64 >/dev/null 2>&1; then
                log_info "安装coreutils-base64..."
                opkg install coreutils-base64
            fi
            ;;
        "debian")
            log_info "Debian系统，检查必要工具..."
            if ! command -v curl >/dev/null 2>&1; then
                apt-get update && apt-get install -y curl
            fi
            ;;
        *)
            log_warn "未知系统类型，请手动确保curl和base64工具可用"
            ;;
    esac
}

# 下载文件
download_file() {
    local filename="$1"
    local output="$2"
    local base_url="$3"

    local full_url="${base_url}/${filename}"
    log_info "下载: $filename"

    # 尝试下载，如果失败则重试
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL "$full_url" -o "$output" 2>/dev/null; then
                return 0
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q "$full_url" -O "$output" 2>/dev/null; then
                return 0
            fi
        else
            log_error "未找到curl或wget，无法下载文件"
            exit 1
        fi

        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            log_warn "下载失败，正在重试 ($retry_count/$max_retries)..."
            sleep 2
        fi
    done

    log_error "下载失败: $filename"
    return 1
}

# 主安装函数
main_install() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                GitHub文件同步工具 - 一键安装                ║"
    echo "║              专为OpenWrt/Kwrt系统设计                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 检查是否为root用户
    if [ "$(id -u)" != "0" ]; then
        log_error "请使用root用户运行此脚本"
        exit 1
    fi
    
    # 安装依赖
    log_info "步骤 1/4: 安装系统依赖..."
    install_dependencies
    
    # 创建安装目录
    log_info "步骤 2/4: 创建安装目录..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 检测最佳下载源
    log_info "步骤 3/5: 检测最佳下载源..."
    local best_source=$(detect_best_source)

    # 下载主程序
    log_info "步骤 4/5: 下载GitHub同步工具..."
    if ! download_file "$SCRIPT_NAME" "$SCRIPT_NAME" "$best_source"; then
        log_error "下载主程序失败"
        exit 1
    fi

    if ! download_file "README.md" "README.md" "$best_source"; then
        log_warn "下载README.md失败，跳过"
    fi

    if ! download_file "github-sync.conf.example" "github-sync.conf.example" "$best_source"; then
        log_warn "下载配置示例失败，跳过"
    fi
    
    # 设置权限
    chmod +x "$SCRIPT_NAME"

    # 创建符号链接（可选）
    log_info "步骤 5/5: 配置系统..."
    if [ ! -f "/usr/local/bin/github-sync" ]; then
        ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "/usr/local/bin/github-sync" 2>/dev/null || true
    fi
    
    echo ""
    log_info "✅ 安装完成！"
    echo ""
    echo "📁 安装目录: $INSTALL_DIR"
    echo "🔧 主程序: $INSTALL_DIR/$SCRIPT_NAME"
    echo ""
    echo "🌐 项目地址: $REPO_URL"
    echo ""

    # 等待2秒后自动进入主程序
    log_info "正在启动GitHub同步工具主程序..."
    echo ""
    echo "💡 提示："
    echo "   • 首次运行将显示配置向导"
    echo "   • 可以选择快速配置或详细配置"
    echo "   • 配置完成后即可开始使用"
    echo ""
    sleep 3

    # 自动进入主程序的交互界面
    ./"$SCRIPT_NAME"
}

# 错误处理
trap 'log_error "安装过程中发生错误，请检查网络连接和权限"; exit 1' ERR

# 执行安装
main_install
