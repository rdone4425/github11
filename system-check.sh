#!/bin/sh
#
# GitHub文件同步工具 - 一键安装
# 使用: bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/system-check.sh)
#

set -e

REPO_URL="https://raw.githubusercontent.com/rdone4425/github11/main"
INSTALL_DIR="/root/github-sync"

# 检测是否为交互式环境
INTERACTIVE=false
if [ -t 1 ] && [ -t 2 ]; then
    INTERACTIVE=true
fi

# 简单的颜色输出
log() { echo "✓ $1"; }
warn() { echo "⚠ $1"; }
error() { echo "✗ $1" >&2; exit 1; }
success() { echo "🎉 $1"; }

# 错误处理函数
handle_error() {
    error "安装过程中发生错误，请检查网络连接和系统权限"
}

# 检查并安装依赖
install_deps() {
    if [ -f /etc/openwrt_release ]; then
        # OpenWrt系统
        if ! command -v curl >/dev/null 2>&1; then
            log "安装curl..."
            opkg update && opkg install curl
        fi
        if ! command -v base64 >/dev/null 2>&1; then
            log "安装base64..."
            opkg install coreutils-base64 || opkg install coreutils
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu系统
        if ! command -v curl >/dev/null 2>&1; then
            log "安装curl..."
            apt-get update && apt-get install -y curl
        fi
    fi
}

# 下载和安装
install_tool() {
    log "创建安装目录: $INSTALL_DIR"
    if ! mkdir -p "$INSTALL_DIR"; then
        error "无法创建安装目录: $INSTALL_DIR"
    fi

    log "下载主程序..."
    if ! curl -fsSL "$REPO_URL/github-sync.sh" -o "$INSTALL_DIR/github-sync.sh"; then
        error "下载主程序失败，请检查网络连接"
    fi

    if ! chmod +x "$INSTALL_DIR/github-sync.sh"; then
        error "设置执行权限失败"
    fi

    log "下载配置示例..."
    curl -fsSL "$REPO_URL/github-sync.conf.example" -o "$INSTALL_DIR/github-sync.conf.example" || warn "配置示例下载失败，可忽略"

    # 创建符号链接
    if ln -sf "$INSTALL_DIR/github-sync.sh" "/usr/local/bin/github-sync" 2>/dev/null; then
        log "创建快捷命令: github-sync"
    else
        warn "创建快捷命令失败，请使用完整路径"
    fi

    # 创建OpenWrt服务
    if [ -f /etc/openwrt_release ]; then
        log "配置系统服务..."
        if cat > "/etc/init.d/github-sync" << 'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1
PROG="/root/github-sync/github-sync.sh"

start_service() {
    procd_open_instance
    procd_set_param command "$PROG" daemon
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    "$PROG" stop
}

restart() {
    "$PROG" restart
}
EOF
        then
            chmod +x "/etc/init.d/github-sync"
            /etc/init.d/github-sync enable 2>/dev/null || warn "服务启用失败"
            log "OpenWrt服务配置完成"
        else
            warn "服务配置失败"
        fi
    fi
}

# 验证安装
verify_installation() {
    log "验证安装..."

    if [ ! -f "$INSTALL_DIR/github-sync.sh" ]; then
        error "主程序文件不存在"
    fi

    if [ ! -x "$INSTALL_DIR/github-sync.sh" ]; then
        error "主程序没有执行权限"
    fi

    # 测试主程序是否能正常运行
    if ! "$INSTALL_DIR/github-sync.sh" help >/dev/null 2>&1; then
        error "主程序无法正常运行"
    fi

    log "安装验证通过"
}

# 启动交互式菜单
start_interactive_menu() {
    log "启动交互式配置菜单..."

    # 切换到安装目录
    cd "$INSTALL_DIR" || error "无法进入安装目录"

    # 尝试多种方式启动
    if command -v github-sync >/dev/null 2>&1; then
        exec github-sync
    elif [ -x "./github-sync.sh" ]; then
        exec ./github-sync.sh
    else
        error "无法启动交互式菜单"
    fi
}

# 主函数
main() {
    # 设置错误处理
    trap 'handle_error' ERR

    echo "GitHub文件同步工具 - 一键安装"
    echo "================================"

    # 检查权限
    if [ "$(id -u)" != "0" ]; then
        warn "建议以root用户运行以获得完整功能"
    fi

    # 安装依赖
    log "检查并安装依赖..."
    install_deps

    # 安装工具
    log "安装GitHub同步工具..."
    install_tool

    # 验证安装
    verify_installation

    echo ""
    success "安装完成！"
    echo ""
    echo "快速开始:"
    echo "  github-sync          # 运行交互式菜单"
    echo "  github-sync config   # 编辑配置"
    echo "  github-sync help     # 查看帮助"
    echo ""

    # 智能检测是否应该启动交互式菜单
    if [ "$INTERACTIVE" = "true" ]; then
        # 真正的交互式环境
        echo -n "是否现在运行配置向导？[Y/n]: "
        read -r answer
        case "$answer" in
            n|N|no|No)
                echo "稍后可运行 'github-sync' 进行配置"
                ;;
            *)
                start_interactive_menu
                ;;
        esac
    else
        # 非交互式环境（如curl管道）
        echo "检测到非交互式环境，安装完成"
        echo "请运行以下命令开始配置："
        echo ""
        echo "  cd $INSTALL_DIR && ./github-sync.sh"
        echo "  # 或者使用快捷命令："
        echo "  github-sync"
        echo ""
        echo "如果要立即启动配置，请运行："
        echo "  bash -c 'cd $INSTALL_DIR && ./github-sync.sh'"
    fi
}

main "$@"
