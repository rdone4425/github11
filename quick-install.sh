#!/bin/bash

# GitHub文件同步系统 - 快速安装脚本
# 一键安装命令: bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/quick-install.sh)

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
GITHUB_REPO="rdone4425/github11"
GITHUB_BRANCH="main"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/install.sh"

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

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║              GitHub文件同步系统 - 快速安装                    ║
║                                                              ║
║  🔍 实时文件监控 + 🚀 自动GitHub同步                          ║
║  📁 多路径支持 + ⚙️ 灵活配置                                  ║
║  🔧 后台运行 + 📝 完整日志                                     ║
║                                                              ║
║  项目地址: https://github.com/rdone4425/github11             ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo ""
        echo "请使用以下命令重新运行："
        echo -e "${YELLOW}sudo bash <(curl -Ls https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/quick-install.sh)${NC}"
        exit 1
    fi
}

# 检查系统兼容性
check_system() {
    log_step "检查系统兼容性..."

    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        exit 1
    fi

    source /etc/os-release
    log_info "检测到系统: $PRETTY_NAME"

    # 检查init系统支持
    local init_supported=false

    if command -v systemctl >/dev/null 2>&1 && [[ -d /etc/systemd ]]; then
        log_info "检测到systemd支持"
        init_supported=true
    elif grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        log_info "检测到OpenWrt系统，支持procd"
        init_supported=true
    elif [[ -d /etc/init.d ]]; then
        log_info "检测到SysV init支持"
        init_supported=true
    elif command -v service >/dev/null 2>&1; then
        log_info "检测到service命令支持"
        init_supported=true
    fi

    if [[ "$init_supported" != "true" ]]; then
        log_warn "未检测到标准init系统，将使用手动模式"
    fi

    # 检查curl
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl命令不可用，请先安装curl"
        exit 1
    fi

    log_info "系统兼容性检查通过"
}

# 确认安装
confirm_install() {
    echo ""
    echo -e "${YELLOW}即将安装GitHub文件同步系统到您的系统${NC}"
    echo ""
    echo "安装内容："
    echo "• 系统服务 (file-sync)"
    echo "• 命令行工具 (/usr/local/bin/file-sync)"
    echo "• 程序文件 (/file-sync-system)"
    echo "• 配置文件模板"
    echo "• 完整文档"
    echo ""
    
    while true; do
        read -p "确定要继续安装吗？[y/N]: " yn
        case $yn in
            [Yy]* ) 
                break
                ;;
            [Nn]* | "" ) 
                log_info "安装已取消"
                exit 0
                ;;
            * ) 
                echo "请输入 y 或 n"
                ;;
        esac
    done
}

# 下载并执行安装脚本
download_and_install() {
    log_step "下载安装脚本..."
    
    local temp_script="/tmp/file-sync-install-$$.sh"
    
    # 下载安装脚本
    if curl -Ls "$INSTALL_SCRIPT_URL" -o "$temp_script"; then
        log_info "安装脚本下载成功"
    else
        log_error "下载安装脚本失败"
        exit 1
    fi
    
    # 验证脚本
    if [[ ! -s "$temp_script" ]]; then
        log_error "下载的安装脚本为空"
        rm -f "$temp_script"
        exit 1
    fi
    
    # 执行安装脚本
    log_step "执行安装..."
    chmod +x "$temp_script"
    
    if bash "$temp_script" install; then
        log_info "安装完成！"
    else
        log_error "安装失败"
        rm -f "$temp_script"
        exit 1
    fi
    
    # 清理临时文件
    rm -f "$temp_script"
}

# 显示安装后信息
show_post_install() {
    echo ""
    echo -e "${GREEN}🎉 GitHub文件同步系统安装成功！${NC}"
    echo ""
    echo -e "${CYAN}下一步操作：${NC}"
    echo ""
    echo "1. 配置GitHub凭据："
    echo -e "   ${YELLOW}nano /file-sync-system/config/global.conf${NC}"
    echo "   • 设置 GITHUB_USERNAME"
    echo "   • 设置 GITHUB_TOKEN (Personal Access Token)"
    echo ""
    echo "2. 配置监控路径："
    echo -e "   ${YELLOW}nano /file-sync-system/config/paths.conf${NC}"
    echo "   • 设置要监控的本地目录"
    echo "   • 设置对应的GitHub仓库"
    echo ""
    echo "3. 验证配置："
    echo -e "   ${YELLOW}file-sync validate${NC}"
    echo ""
    echo "4. 启动服务："

    # 根据系统类型显示不同的启动命令
    if grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        echo -e "   ${YELLOW}/etc/init.d/file-sync start${NC}"
        echo -e "   ${YELLOW}/etc/init.d/file-sync enable${NC}  # 开机自启"
    elif command -v systemctl >/dev/null 2>&1 && [[ -d /etc/systemd ]]; then
        echo -e "   ${YELLOW}systemctl start file-sync${NC}"
        echo -e "   ${YELLOW}systemctl enable file-sync${NC}  # 开机自启"
    else
        echo -e "   ${YELLOW}service file-sync start${NC}"
    fi

    echo ""
    echo "5. 查看状态："
    echo -e "   ${YELLOW}file-sync status${NC}"
    echo -e "   ${YELLOW}file-sync logs follow${NC}"
    echo ""
    echo -e "${BLUE}📚 文档位置：${NC}"
    echo "• 安装指南: /file-sync-system/docs/installation.md"
    echo "• 配置说明: /file-sync-system/docs/configuration.md"
    echo "• 使用说明: /file-sync-system/docs/usage.md"
    echo ""
    echo -e "${PURPLE}🔗 项目地址: https://github.com/$GITHUB_REPO${NC}"
    echo ""
    echo -e "${GREEN}感谢使用GitHub文件同步系统！${NC}"
}

# 错误处理
handle_error() {
    local exit_code=$?
    log_error "安装过程中发生错误 (退出码: $exit_code)"
    echo ""
    echo "如果问题持续存在，请："
    echo "1. 检查网络连接"
    echo "2. 确保有足够的磁盘空间"
    echo "3. 查看系统日志: journalctl -xe"
    echo "4. 在GitHub上报告问题: https://github.com/$GITHUB_REPO/issues"
    exit $exit_code
}

# 主函数
main() {
    # 设置错误处理
    trap handle_error ERR
    
    # 显示欢迎信息
    show_welcome
    
    # 检查权限
    check_root
    
    # 检查系统
    check_system
    
    # 确认安装
    confirm_install
    
    # 执行安装
    download_and_install
    
    # 显示安装后信息
    show_post_install
}

# 运行主函数
main "$@"
