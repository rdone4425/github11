#!/bin/bash

# GitHub文件同步系统 - OpenWrt专用安装脚本
# 专为OpenWrt/LEDE/Kwrt系统优化

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置变量
INSTALL_DIR="/file-sync-system"
GITHUB_REPO="rdone4425/github11"
GITHUB_BRANCH="main"
TEMP_DIR="/tmp/file-sync-install-$$"

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
║            GitHub文件同步系统 - OpenWrt安装                   ║
║                                                              ║
║  🔍 实时文件监控 + 🚀 自动GitHub同步                          ║
║  📁 多路径支持 + ⚙️ 灵活配置                                  ║
║  🔧 后台运行 + 📝 完整日志                                     ║
║                                                              ║
║  专为OpenWrt/LEDE/Kwrt系统优化                               ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查OpenWrt系统
check_openwrt() {
    log_step "检查OpenWrt系统..."
    
    if ! grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        log_error "此脚本仅适用于OpenWrt系统"
        exit 1
    fi
    
    source /etc/os-release
    log_info "检测到系统: $PRETTY_NAME"
}

# 检查必需工具
check_tools() {
    log_step "检查必需工具..."
    
    local missing_tools=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        missing_tools+=("tar")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "缺少必需工具: ${missing_tools[*]}"
        log_info "请先安装: opkg update && opkg install ${missing_tools[*]}"
        exit 1
    fi
    
    log_info "必需工具检查通过"
}

# 安装依赖
install_dependencies() {
    log_step "安装OpenWrt依赖..."

    # 更新包列表
    opkg update

    # 安装基础依赖
    opkg install curl ca-certificates

    # 检查可选依赖
    if command -v inotifywait >/dev/null 2>&1; then
        log_info "检测到inotify-tools，将使用实时监控"
    else
        log_info "未检测到inotify-tools，将使用轮询监控模式"
        log_info "轮询模式同样有效，只是响应稍慢"
    fi

    log_info "依赖检查完成"
}

# 下载源码
download_source() {
    log_step "下载源码..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    if curl -L "https://github.com/$GITHUB_REPO/archive/$GITHUB_BRANCH.tar.gz" -o source.tar.gz; then
        log_info "源码下载成功"
    else
        log_error "源码下载失败"
        exit 1
    fi
    
    if tar -xzf source.tar.gz; then
        mv "github11-$GITHUB_BRANCH" file-sync-system
        log_info "源码解压完成"
    else
        log_error "源码解压失败"
        exit 1
    fi
}

# 安装文件
install_files() {
    log_step "安装程序文件..."
    
    local source_dir="$TEMP_DIR/file-sync-system"
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"/{bin,lib,config,logs,docs}
    
    # 复制文件
    cp -r "$source_dir/bin/"* "$INSTALL_DIR/bin/"
    cp -r "$source_dir/lib/"* "$INSTALL_DIR/lib/"
    cp -r "$source_dir/config/"* "$INSTALL_DIR/config/"
    
    if [[ -d "$source_dir/docs" ]]; then
        cp -r "$source_dir/docs/"* "$INSTALL_DIR/docs/"
    fi
    
    if [[ -f "$source_dir/README.md" ]]; then
        cp "$source_dir/README.md" "$INSTALL_DIR/"
    fi
    
    # 设置权限
    chmod +x "$INSTALL_DIR/bin/"*
    chmod 644 "$INSTALL_DIR/config/"*
    
    log_info "文件安装完成"
}

# 安装OpenWrt服务
install_service() {
    log_step "安装OpenWrt服务..."
    
    cat > /etc/init.d/file-sync << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG="/file-sync-system/bin/file-sync-daemon"
PIDFILE="/file-sync-system/logs/daemon.pid"

start_service() {
    procd_open_instance
    procd_set_param command $PROG start
    procd_set_param pidfile $PIDFILE
    procd_set_param respawn
    procd_set_param user root
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    $PROG stop
}

restart() {
    stop
    start
}
EOF
    
    chmod +x /etc/init.d/file-sync
    
    log_info "OpenWrt服务安装完成"
}

# 创建命令链接
create_command_link() {
    log_step "创建命令链接..."
    
    ln -sf "$INSTALL_DIR/bin/file-sync" /usr/bin/file-sync
    
    log_info "命令行工具已安装"
}

# 初始化配置
initialize_config() {
    log_step "初始化配置..."
    
    "$INSTALL_DIR/bin/file-sync" init
    
    log_info "配置初始化完成"
}

# 清理临时文件
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# 显示安装后信息
show_completion() {
    echo ""
    log_info "🎉 OpenWrt文件同步系统安装完成！"
    echo ""
    echo -e "${CYAN}下一步操作：${NC}"
    echo ""
    echo "1. 配置GitHub凭据："
    echo -e "   ${YELLOW}vi /file-sync-system/config/global.conf${NC}"
    echo ""
    echo "2. 配置监控路径："
    echo -e "   ${YELLOW}vi /file-sync-system/config/paths.conf${NC}"
    echo ""
    echo "3. 验证配置："
    echo -e "   ${YELLOW}file-sync validate${NC}"
    echo ""
    echo "4. 启动服务："
    echo -e "   ${YELLOW}/etc/init.d/file-sync start${NC}"
    echo -e "   ${YELLOW}/etc/init.d/file-sync enable${NC}  # 开机自启"
    echo ""
    echo "5. 查看状态："
    echo -e "   ${YELLOW}file-sync status${NC}"
    echo -e "   ${YELLOW}/etc/init.d/file-sync status${NC}"
    echo ""
    echo "6. 查看日志："
    echo -e "   ${YELLOW}file-sync logs follow${NC}"
    echo -e "   ${YELLOW}logread -f | grep file-sync${NC}"
    echo ""
    echo -e "${BLUE}OpenWrt特别说明：${NC}"
    echo "• 配置文件位于: /file-sync-system/config/"
    echo "• 日志文件位于: /file-sync-system/logs/"
    echo "• 使用vi编辑器编辑配置文件"
    echo "• 重启路由器后服务会自动启动（如果已启用）"
    echo "• 系统将使用轮询模式监控文件变化（默认10秒间隔）"
    echo "• 可在global.conf中调整POLLING_INTERVAL参数"
    echo ""
    echo -e "${GREEN}安装完成！${NC}"
}

# 主函数
main() {
    # 设置清理陷阱
    trap cleanup EXIT
    
    show_welcome
    
    check_openwrt
    check_tools
    install_dependencies
    download_source
    install_files
    install_service
    create_command_link
    initialize_config
    
    show_completion
}

# 运行主函数
main "$@"
