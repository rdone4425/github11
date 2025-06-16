#!/bin/bash

# OpenWrt依赖检查和安装脚本
# 专门处理OpenWrt系统的包依赖问题

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查OpenWrt系统
check_openwrt() {
    if ! grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        log_error "此脚本仅适用于OpenWrt系统"
        exit 1
    fi
    
    source /etc/os-release
    log_info "检测到系统: $PRETTY_NAME"
}

# 检查包是否已安装
is_package_installed() {
    local package="$1"
    opkg list-installed | grep -q "^$package "
}

# 检查命令是否可用
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 尝试安装包
try_install_package() {
    local package="$1"
    local description="$2"
    
    log_info "尝试安装 $package ($description)..."
    
    if opkg install "$package" 2>/dev/null; then
        log_info "✓ $package 安装成功"
        return 0
    else
        log_warn "✗ $package 安装失败"
        return 1
    fi
}

# 安装下载工具
install_download_tools() {
    log_step "检查和安装下载工具..."
    
    # 检查curl
    if command_exists curl; then
        log_info "✓ curl已可用"
        return 0
    fi
    
    # 检查wget
    if command_exists wget; then
        log_info "✓ wget已可用"
        return 0
    fi
    
    # 尝试安装curl的不同变体
    local curl_packages=("curl" "libcurl4" "libcurl" "curl-full")
    for pkg in "${curl_packages[@]}"; do
        if try_install_package "$pkg" "HTTP客户端"; then
            if command_exists curl; then
                return 0
            fi
        fi
    done
    
    # 尝试安装wget
    local wget_packages=("wget" "wget-ssl" "wget-nossl")
    for pkg in "${wget_packages[@]}"; do
        if try_install_package "$pkg" "下载工具"; then
            if command_exists wget; then
                # 创建curl兼容脚本
                create_curl_wrapper
                return 0
            fi
        fi
    done
    
    log_error "无法安装任何下载工具"
    return 1
}

# 创建curl兼容包装器
create_curl_wrapper() {
    if [[ ! -f /usr/bin/curl ]] && command_exists wget; then
        log_info "创建curl兼容包装器..."
        
        cat > /usr/bin/curl << 'EOF'
#!/bin/sh
# wget wrapper for curl compatibility

# 简单的参数转换
args=""
output_file=""
url=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -L|--location)
            # wget默认跟随重定向
            shift
            ;;
        -o|--output)
            output_file="$2"
            shift 2
            ;;
        -O|--remote-name)
            # 使用远程文件名
            shift
            ;;
        -s|--silent)
            args="$args -q"
            shift
            ;;
        -*)
            # 忽略其他curl选项
            shift
            ;;
        *)
            url="$1"
            shift
            ;;
    esac
done

# 执行wget命令
if [[ -n "$output_file" ]]; then
    exec wget $args "$url" -O "$output_file"
else
    exec wget $args "$url"
fi
EOF
        
        chmod +x /usr/bin/curl
        log_info "✓ curl兼容包装器已创建"
    fi
}

# 安装SSL证书
install_ssl_certs() {
    log_step "检查SSL证书..."
    
    # 检查ca-certificates
    if is_package_installed ca-certificates; then
        log_info "✓ ca-certificates已安装"
        return 0
    fi
    
    # 尝试安装SSL证书包
    local cert_packages=("ca-certificates" "ca-bundle" "openssl-util")
    for pkg in "${cert_packages[@]}"; do
        if try_install_package "$pkg" "SSL证书"; then
            break
        fi
    done
    
    # 检查证书目录
    if [[ -d /etc/ssl/certs ]] || [[ -f /etc/ssl/cert.pem ]]; then
        log_info "✓ SSL证书可用"
    else
        log_warn "SSL证书可能不可用，HTTPS连接可能失败"
    fi
}

# 安装基础工具
install_basic_tools() {
    log_step "检查基础工具..."
    
    # 检查tar
    if ! command_exists tar; then
        try_install_package "tar" "压缩工具"
    else
        log_info "✓ tar已可用"
    fi
    
    # 检查find
    if ! command_exists find; then
        try_install_package "findutils" "查找工具"
    else
        log_info "✓ find已可用"
    fi
    
    # 检查stat
    if ! command_exists stat; then
        try_install_package "coreutils-stat" "文件状态工具"
    else
        log_info "✓ stat已可用"
    fi
}

# 检查可选工具
check_optional_tools() {
    log_step "检查可选工具..."
    
    # 检查jq
    if command_exists jq; then
        log_info "✓ jq已可用（JSON处理）"
    else
        log_warn "jq不可用，将使用简化的JSON处理"
    fi
    
    # 检查inotify-tools
    if command_exists inotifywait; then
        log_info "✓ inotify-tools已可用（实时监控）"
    else
        log_info "inotify-tools不可用，将使用轮询监控"
    fi
}

# 测试网络连接
test_network() {
    log_step "测试网络连接..."
    
    local test_urls=("https://github.com" "https://api.github.com")
    
    for url in "${test_urls[@]}"; do
        log_info "测试连接: $url"
        
        if command_exists curl; then
            if curl -s --connect-timeout 10 "$url" >/dev/null 2>&1; then
                log_info "✓ $url 连接成功"
            else
                log_warn "✗ $url 连接失败"
            fi
        elif command_exists wget; then
            if wget --timeout=10 --tries=1 -q --spider "$url" 2>/dev/null; then
                log_info "✓ $url 连接成功"
            else
                log_warn "✗ $url 连接失败"
            fi
        fi
    done
}

# 显示系统信息
show_system_info() {
    log_step "系统信息..."
    
    echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "架构: $(uname -m)"
    echo "内核: $(uname -r)"
    echo "可用内存: $(free -m | awk 'NR==2{printf "%.0fMB", $7}')"
    echo "可用存储: $(df -h / | awk 'NR==2{print $4}')"
    
    echo ""
    echo "已安装的相关包:"
    opkg list-installed | grep -E "(curl|wget|tar|ca-cert)" || echo "  无相关包"
}

# 修复常见问题
fix_common_issues() {
    log_step "修复常见问题..."
    
    # 修复opkg源问题
    if ! opkg update >/dev/null 2>&1; then
        log_warn "opkg更新失败，尝试修复..."
        
        # 清理opkg缓存
        rm -rf /var/opkg-lists/*
        
        # 重新更新
        if opkg update; then
            log_info "✓ opkg源修复成功"
        else
            log_error "opkg源仍有问题，请检查网络连接"
        fi
    fi
    
    # 检查存储空间
    local available_space=$(df / | awk 'NR==2{print $4}')
    if [[ $available_space -lt 10240 ]]; then  # 小于10MB
        log_warn "存储空间不足，可能影响安装"
        echo "可用空间: $(df -h / | awk 'NR==2{print $4}')"
    fi
}

# 主函数
main() {
    echo "OpenWrt依赖检查和安装工具"
    echo "============================"
    echo ""
    
    check_openwrt
    show_system_info
    echo ""
    
    fix_common_issues
    install_download_tools
    install_ssl_certs
    install_basic_tools
    check_optional_tools
    test_network
    
    echo ""
    log_info "🎉 依赖检查完成！"
    echo ""
    echo "现在可以运行GitHub文件同步系统安装："
    echo "bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/openwrt-install.sh)"
    echo ""
    echo "或者如果curl不可用："
    echo "wget -O- https://raw.githubusercontent.com/rdone4425/github11/main/openwrt-install.sh | bash"
}

# 运行主函数
main "$@"
