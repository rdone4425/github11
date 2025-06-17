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
    local url="$1"
    local output="$2"
    
    log_info "下载: $url"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output"
    else
        log_error "未找到curl或wget，无法下载文件"
        exit 1
    fi
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
    
    # 下载主程序
    log_info "步骤 3/4: 下载GitHub同步工具..."
    download_file "$RAW_URL/$SCRIPT_NAME" "$SCRIPT_NAME"
    download_file "$RAW_URL/README.md" "README.md"
    download_file "$RAW_URL/github-sync.conf.example" "github-sync.conf.example"
    
    # 设置权限
    chmod +x "$SCRIPT_NAME"
    
    # 创建符号链接（可选）
    log_info "步骤 4/4: 配置系统..."
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
