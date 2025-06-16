#!/bin/bash

# GitHub文件同步系统 - 系统兼容性检查脚本
# 检查系统是否支持安装

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_check() {
    echo -e "${BLUE}[检查]${NC} $1"
}

# 显示标题
show_title() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║            GitHub文件同步系统 - 系统兼容性检查                ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查操作系统
check_os() {
    log_check "检查操作系统..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        return 1
    fi
    
    source /etc/os-release
    log_info "操作系统: $PRETTY_NAME"
    
    # 检查是否为Linux
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" && "$ID" != "centos" && "$ID" != "rhel" && "$ID" != "fedora" ]]; then
        log_warn "未测试的Linux发行版，可能需要手动调整"
    fi
    
    return 0
}

# 检查权限
check_permissions() {
    log_check "检查运行权限..."
    
    if [[ $EUID -eq 0 ]]; then
        log_info "以root权限运行"
        return 0
    else
        log_warn "当前非root用户，安装时需要sudo权限"
        return 0
    fi
}

# 检查init系统
check_init_system() {
    log_check "检查init系统..."
    
    if command -v systemctl >/dev/null 2>&1 && [[ -d /etc/systemd ]]; then
        log_info "支持systemd"
        echo "  - 将使用systemd服务管理"
        return 0
    elif [[ -d /etc/init.d ]]; then
        log_info "支持SysV init"
        echo "  - 将使用传统init脚本"
        return 0
    elif command -v service >/dev/null 2>&1; then
        log_info "支持service命令"
        echo "  - 将使用service脚本"
        return 0
    else
        log_warn "未检测到标准init系统"
        echo "  - 将使用手动模式"
        return 0
    fi
}

# 检查必需命令
check_required_commands() {
    log_check "检查必需命令..."
    
    local missing_commands=()
    local required_commands=("bash" "curl" "mkdir" "chmod" "chown")
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_info "$cmd: 可用"
        else
            log_error "$cmd: 不可用"
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "缺少必需命令: ${missing_commands[*]}"
        return 1
    fi
    
    return 0
}

# 检查可选命令
check_optional_commands() {
    log_check "检查可选命令..."
    
    local optional_commands=("git" "jq" "inotifywait")
    
    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_info "$cmd: 可用"
        else
            log_warn "$cmd: 不可用 (安装时会自动安装)"
        fi
    done
    
    return 0
}

# 检查包管理器
check_package_manager() {
    log_check "检查包管理器..."
    
    if command -v apt-get >/dev/null 2>&1; then
        log_info "包管理器: apt (Debian/Ubuntu)"
        return 0
    elif command -v yum >/dev/null 2>&1; then
        log_info "包管理器: yum (CentOS/RHEL)"
        return 0
    elif command -v dnf >/dev/null 2>&1; then
        log_info "包管理器: dnf (Fedora)"
        return 0
    else
        log_error "不支持的包管理器"
        return 1
    fi
}

# 检查磁盘空间
check_disk_space() {
    log_check "检查磁盘空间..."
    
    local available_space
    if command -v df >/dev/null 2>&1; then
        available_space=$(df -m / | awk 'NR==2 {print $4}')
        
        if [[ $available_space -gt 100 ]]; then
            log_info "可用磁盘空间: ${available_space}MB"
            return 0
        else
            log_warn "磁盘空间不足: 只有 ${available_space}MB 可用"
            return 1
        fi
    else
        log_warn "无法检查磁盘空间"
        return 0
    fi
}

# 检查网络连接
check_network() {
    log_check "检查网络连接..."
    
    if command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout 10 "https://github.com" >/dev/null 2>&1; then
            log_info "GitHub连接: 正常"
            return 0
        else
            log_warn "GitHub连接: 异常"
            return 1
        fi
    elif command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 5 github.com >/dev/null 2>&1; then
            log_info "网络连接: 正常"
            return 0
        else
            log_warn "网络连接: 异常"
            return 1
        fi
    else
        log_warn "无法检查网络连接"
        return 0
    fi
}

# 检查现有安装
check_existing_installation() {
    log_check "检查现有安装..."
    
    if [[ -d "/file-sync-system" ]]; then
        log_warn "检测到现有安装: /file-sync-system"
        echo "  - 安装时将覆盖现有文件"
        return 0
    fi
    
    if command -v file-sync >/dev/null 2>&1; then
        log_warn "检测到现有file-sync命令"
        return 0
    fi
    
    log_info "未检测到现有安装"
    return 0
}

# 显示总结
show_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                           检查总结                            ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ $OVERALL_STATUS -eq 0 ]]; then
        log_info "系统兼容性检查通过！"
        echo ""
        echo "您的系统支持安装GitHub文件同步系统。"
        echo ""
        echo "安装命令："
        echo -e "${YELLOW}bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/quick-install.sh)${NC}"
    else
        log_error "系统兼容性检查失败！"
        echo ""
        echo "请解决以上问题后重新检查。"
        echo ""
        echo "常见解决方案："
        echo "• 安装缺少的命令"
        echo "• 检查网络连接"
        echo "• 确保有足够的磁盘空间"
        echo "• 使用root权限运行"
    fi
    
    echo ""
}

# 主函数
main() {
    show_title
    
    local OVERALL_STATUS=0
    
    # 执行所有检查
    check_os || OVERALL_STATUS=1
    echo ""
    
    check_permissions || OVERALL_STATUS=1
    echo ""
    
    check_init_system || OVERALL_STATUS=1
    echo ""
    
    check_required_commands || OVERALL_STATUS=1
    echo ""
    
    check_optional_commands || OVERALL_STATUS=1
    echo ""
    
    check_package_manager || OVERALL_STATUS=1
    echo ""
    
    check_disk_space || OVERALL_STATUS=1
    echo ""
    
    check_network || OVERALL_STATUS=1
    echo ""
    
    check_existing_installation || OVERALL_STATUS=1
    echo ""
    
    # 显示总结
    show_summary
    
    exit $OVERALL_STATUS
}

# 运行主函数
main "$@"
