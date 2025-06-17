#!/bin/bash

# GitHub文件同步工具一键安装脚本 - 调试版本
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

# 测试URL连接
test_url() {
    local url="$1"
    local name="$2"
    
    log_debug "测试连接: $name"
    log_debug "URL: $url"
    
    if curl -s --connect-timeout 10 --max-time 15 "$url" >/dev/null 2>&1; then
        log_info "✅ $name 连接成功"
        return 0
    else
        log_warn "❌ $name 连接失败"
        return 1
    fi
}

# 主要测试函数
main_test() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                GitHub同步工具 - 连接测试                    ║"
    echo "║              专为OpenWrt/Kwrt系统设计                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "开始网络连接测试..."
    echo ""
    
    # 测试基本网络连接
    log_info "1. 测试基本网络连接..."
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_info "✅ 网络连接正常"
    else
        log_warn "❌ 网络连接可能有问题"
    fi
    echo ""
    
    # 测试GitHub原站
    log_info "2. 测试GitHub原站..."
    test_url "https://raw.githubusercontent.com" "GitHub原站域名"
    test_url "${RAW_URL}/README.md" "GitHub原站文件"
    echo ""
    
    # 测试加速镜像
    log_info "3. 测试加速镜像..."
    test_url "https://git.910626.xyz" "加速镜像域名"
    test_url "${MIRROR_PREFIX}${RAW_URL}/README.md" "加速镜像文件"
    echo ""
    
    # 测试下载
    log_info "4. 测试实际下载..."
    local temp_file="/tmp/test_download_$$"
    
    log_debug "测试GitHub原站下载..."
    if curl -fsSL "${RAW_URL}/README.md" -o "$temp_file" 2>/dev/null && [ -s "$temp_file" ]; then
        local size=$(wc -c < "$temp_file")
        log_info "✅ GitHub原站下载成功 (${size} bytes)"
        rm -f "$temp_file"
    else
        log_warn "❌ GitHub原站下载失败"
    fi
    
    log_debug "测试加速镜像下载..."
    if curl -fsSL "${MIRROR_PREFIX}${RAW_URL}/README.md" -o "$temp_file" 2>/dev/null && [ -s "$temp_file" ]; then
        local size=$(wc -c < "$temp_file")
        log_info "✅ 加速镜像下载成功 (${size} bytes)"
        rm -f "$temp_file"
    else
        log_warn "❌ 加速镜像下载失败"
    fi
    
    echo ""
    log_info "测试完成！"
    echo ""
    echo "如果所有测试都通过，可以继续安装："
    echo "bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/install.sh)"
    echo ""
    echo "如果测试失败，请检查网络连接或联系技术支持。"
}

# 错误处理
trap 'log_error "测试过程中发生错误"; exit 1' ERR

# 执行测试
main_test
