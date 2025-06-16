#!/bin/bash

# GitHub文件同步系统 - 通用安装脚本
# 自动适配所有Linux系统（包括OpenWrt）
# 使用方法: bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/install.sh)

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
INSTALL_DIR="/file-sync-system"
SERVICE_USER="root"
SERVICE_GROUP="root"
GITHUB_REPO="rdone4425/github11"
GITHUB_BRANCH="main"
TEMP_DIR="/tmp/file-sync-install-$$"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "$TEMP_DIR")"

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

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
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

    # 检查init系统
    if command -v systemctl >/dev/null 2>&1 && [[ -d /etc/systemd ]]; then
        INIT_SYSTEM="systemd"
        log_info "检测到systemd支持"
    elif [[ -f /etc/init.d ]] || [[ -d /etc/init.d ]]; then
        INIT_SYSTEM="sysv"
        log_info "检测到SysV init支持"
    elif command -v procd >/dev/null 2>&1 || [[ -d /etc/init.d ]] && grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        INIT_SYSTEM="openwrt"
        log_info "检测到OpenWrt/procd支持"
    elif command -v service >/dev/null 2>&1; then
        INIT_SYSTEM="service"
        log_info "检测到service命令支持"
    else
        INIT_SYSTEM="manual"
        log_warn "未检测到标准init系统，将使用手动模式"
    fi

    # 检查包管理器
    if command -v opkg >/dev/null 2>&1; then
        PACKAGE_MANAGER="opkg"
    elif command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
    else
        log_error "不支持的包管理器"
        exit 1
    fi

    log_info "使用包管理器: $PACKAGE_MANAGER"
}

# 安装依赖
install_dependencies() {
    log_step "安装系统依赖..."

    case "$PACKAGE_MANAGER" in
        "opkg")
            opkg update
            # 尝试安装基础依赖，失败不退出
            install_openwrt_deps
            ;;
        "apt")
            apt-get update
            apt-get install -y curl jq inotify-tools bash tar ca-certificates
            ;;
        "yum")
            yum install -y curl jq inotify-tools bash tar ca-certificates
            ;;
        "dnf")
            dnf install -y curl jq inotify-tools bash tar ca-certificates
            ;;
    esac

    log_info "依赖安装完成"
}

# OpenWrt依赖安装
install_openwrt_deps() {
    # 检查并安装下载工具
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        opkg install wget 2>/dev/null || opkg install curl 2>/dev/null || log_warn "无法安装下载工具"
    fi

    # 尝试安装SSL证书
    opkg install ca-certificates 2>/dev/null || log_warn "ca-certificates安装失败"

    # 检查tar
    if ! command -v tar >/dev/null 2>&1; then
        opkg install tar 2>/dev/null || log_warn "tar安装失败"
    fi

    # 可选依赖
    if ! command -v jq >/dev/null 2>&1; then
        log_info "jq不可用，将使用简化JSON处理"
    fi

    if ! command -v inotifywait >/dev/null 2>&1; then
        log_info "inotify-tools不可用，将使用轮询监控模式"
    fi
}

# 创建系统用户（使用root用户）
create_system_user() {
    log_step "配置运行用户..."

    # 使用root用户运行，无需创建新用户
    log_info "使用root用户运行服务"
}

# 下载源码
download_source() {
    log_step "下载源码..."

    # 创建临时目录
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"

    local download_url="https://github.com/$GITHUB_REPO/archive/$GITHUB_BRANCH.tar.gz"

    # 尝试使用curl或wget下载
    log_info "下载源码压缩包..."
    if command -v curl >/dev/null 2>&1; then
        if curl -L "$download_url" -o source.tar.gz; then
            log_info "源码下载成功"
        else
            log_error "curl下载失败"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget "$download_url" -O source.tar.gz; then
            log_info "源码下载成功"
        else
            log_error "wget下载失败"
            exit 1
        fi
    else
        log_error "没有可用的下载工具（curl或wget）"
        exit 1
    fi

    # 解压源码
    log_info "解压源码..."
    if tar -xzf source.tar.gz; then
        mv "github11-$GITHUB_BRANCH" file-sync-system
        log_info "源码解压完成"
    else
        log_error "源码解压失败"
        exit 1
    fi
}

# 创建安装目录
create_install_directory() {
    log_step "创建安装目录..."

    # 创建主目录
    mkdir -p "$INSTALL_DIR"

    # 创建子目录
    mkdir -p "$INSTALL_DIR/bin"
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/docs"

    log_info "安装目录创建完成: $INSTALL_DIR"
}

# 复制文件
copy_files() {
    log_step "复制程序文件..."

    local source_dir="$TEMP_DIR/file-sync-system"

    # 复制可执行文件
    if [[ -d "$source_dir/bin" ]]; then
        cp -r "$source_dir/bin/"* "$INSTALL_DIR/bin/"
        chmod +x "$INSTALL_DIR/bin/"*

        # 创建无后缀的符号链接
        if [[ -f "$INSTALL_DIR/bin/file-sync.sh" ]]; then
            ln -sf "$INSTALL_DIR/bin/file-sync.sh" "$INSTALL_DIR/bin/file-sync"
        fi
        if [[ -f "$INSTALL_DIR/bin/file-sync-daemon.sh" ]]; then
            ln -sf "$INSTALL_DIR/bin/file-sync-daemon.sh" "$INSTALL_DIR/bin/file-sync-daemon"
        fi
    fi

    # 复制库文件
    if [[ -d "$source_dir/lib" ]]; then
        cp -r "$source_dir/lib/"* "$INSTALL_DIR/lib/"
    fi

    # 复制配置文件模板
    if [[ -d "$source_dir/config" ]]; then
        cp -r "$source_dir/config/"* "$INSTALL_DIR/config/"
    fi

    # 复制文档
    if [[ -d "$source_dir/docs" ]]; then
        cp -r "$source_dir/docs/"* "$INSTALL_DIR/docs/"
    fi

    # 复制README
    if [[ -f "$source_dir/README.md" ]]; then
        cp "$source_dir/README.md" "$INSTALL_DIR/"
    fi

    log_info "文件复制完成"
}

# 设置权限
set_permissions() {
    log_step "设置文件权限..."

    # 设置目录权限（root用户拥有）
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"

    # 设置可执行文件权限
    chmod 755 "$INSTALL_DIR/bin/"*

    # 设置配置文件权限
    chmod 644 "$INSTALL_DIR/config/"*

    # 设置日志目录权限
    chmod 755 "$INSTALL_DIR/logs"

    log_info "权限设置完成"
}

# 安装系统服务
install_system_service() {
    log_step "安装系统服务..."

    case "$INIT_SYSTEM" in
        "systemd")
            install_systemd_service
            ;;
        "sysv")
            install_sysv_service
            ;;
        "openwrt")
            install_openwrt_service
            ;;
        "service")
            install_service_script
            ;;
        "manual")
            install_manual_service
            ;;
        *)
            log_error "不支持的init系统: $INIT_SYSTEM"
            return 1
            ;;
    esac
}

# 安装systemd服务
install_systemd_service() {
    log_step "安装systemd服务..."

    # 确保systemd目录存在
    mkdir -p /etc/systemd/system

    # 创建服务文件
    cat > /etc/systemd/system/file-sync.service << EOF
[Unit]
Description=GitHub File Sync Service
Documentation=https://github.com/rdone4425/github11
After=network-online.target
Wants=network-online.target
RequiresMountsFor=$INSTALL_DIR

[Service]
Type=forking
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$INSTALL_DIR
ExecStartPre=$INSTALL_DIR/bin/file-sync validate
ExecStart=$INSTALL_DIR/bin/file-sync-daemon start
ExecStop=$INSTALL_DIR/bin/file-sync-daemon stop
ExecReload=$INSTALL_DIR/bin/file-sync-daemon reload
PIDFile=$INSTALL_DIR/logs/daemon.pid
Restart=always
RestartSec=10
RestartPreventExitStatus=2

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

# 环境变量
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=LOG_LEVEL=INFO

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable file-sync.service
    
    log_info "systemd服务安装完成"
}

# 安装SysV init服务
install_sysv_service() {
    log_step "安装SysV init服务..."

    # 创建init脚本
    cat > /etc/init.d/file-sync << 'EOF'
#!/bin/bash
# file-sync        GitHub文件同步系统
# chkconfig: 35 80 20
# description: GitHub File Sync Service

. /etc/rc.d/init.d/functions

USER="root"
DAEMON="file-sync-daemon"
ROOT_DIR="/file-sync-system"

SERVER="$ROOT_DIR/bin/$DAEMON"
LOCK_FILE="/var/lock/subsys/file-sync"

start() {
    echo -n $"Starting $DAEMON: "
    daemon --user "$USER" --pidfile="$ROOT_DIR/logs/daemon.pid" "$SERVER" start
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && touch $LOCK_FILE
    return $RETVAL
}

stop() {
    echo -n $"Shutting down $DAEMON: "
    pid=`ps -aefw | grep "$DAEMON" | grep -v " grep " | awk '{print $2}'`
    kill -9 $pid > /dev/null 2>&1
    [ $? -eq 0 ] && echo_success || echo_failure
    echo
    [ $RETVAL -eq 0 ] && rm -f $LOCK_FILE
    return $RETVAL
}

restart() {
    stop
    start
}

status() {
    if [ -f $LOCK_FILE ]; then
        echo "$DAEMON is running."
    else
        echo "$DAEMON is stopped."
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        restart
        ;;
    *)
        echo "Usage: {start|stop|status|restart}"
        exit 1
        ;;
esac

exit $?
EOF

    chmod +x /etc/init.d/file-sync

    # 添加到启动项
    if command -v chkconfig >/dev/null 2>&1; then
        chkconfig --add file-sync
        chkconfig file-sync on
    elif command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d file-sync defaults
    fi

    log_info "SysV init服务安装完成"
}

# 安装OpenWrt procd服务
install_openwrt_service() {
    log_step "安装OpenWrt procd服务..."

    # 创建procd init脚本
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

    # 启用服务
    /etc/init.d/file-sync enable

    log_info "OpenWrt procd服务安装完成"
}

# 安装service脚本
install_service_script() {
    log_step "安装service脚本..."

    # 选择合适的bin目录
    local bin_dir=""
    if [[ -d "/usr/local/bin" ]]; then
        bin_dir="/usr/local/bin"
    elif [[ -d "/usr/bin" ]]; then
        bin_dir="/usr/bin"
    else
        mkdir -p /usr/local/bin
        bin_dir="/usr/local/bin"
    fi

    # 创建简单的服务脚本
    cat > "$bin_dir/file-sync-service" << EOF
#!/bin/bash
# GitHub文件同步系统服务管理脚本

DAEMON_DIR="/file-sync-system"
DAEMON_SCRIPT="\$DAEMON_DIR/bin/file-sync-daemon"

case "\$1" in
    start)
        echo "启动file-sync服务..."
        \$DAEMON_SCRIPT start
        ;;
    stop)
        echo "停止file-sync服务..."
        \$DAEMON_SCRIPT stop
        ;;
    restart)
        echo "重启file-sync服务..."
        \$DAEMON_SCRIPT restart
        ;;
    status)
        \$DAEMON_SCRIPT status
        ;;
    *)
        echo "用法: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

    chmod +x "$bin_dir/file-sync-service"

    log_info "service脚本安装完成: $bin_dir/file-sync-service"
    log_info "使用 'file-sync-service start' 启动服务"
}

# 手动模式安装
install_manual_service() {
    log_step "配置手动模式..."

    # 选择合适的bin目录
    local bin_dir=""
    if [[ -d "/usr/local/bin" ]]; then
        bin_dir="/usr/local/bin"
    elif [[ -d "/usr/bin" ]]; then
        bin_dir="/usr/bin"
    else
        mkdir -p /usr/local/bin
        bin_dir="/usr/local/bin"
    fi

    # 创建启动脚本
    cat > "$bin_dir/start-file-sync" << EOF
#!/bin/bash
# GitHub文件同步系统手动启动脚本

echo "启动GitHub文件同步系统..."
cd /file-sync-system
nohup ./bin/file-sync-daemon start > /dev/null 2>&1 &
echo "服务已在后台启动"
echo "使用 'file-sync status' 查看状态"
EOF

    chmod +x "$bin_dir/start-file-sync"

    log_info "手动模式配置完成: $bin_dir/start-file-sync"
    log_info "使用 'start-file-sync' 启动服务"
    log_warn "注意: 系统重启后需要手动启动服务"
}

# 创建命令行链接
create_command_link() {
    log_step "创建命令行链接..."

    # 根据系统选择合适的bin目录
    local bin_dir=""

    if [[ -d "/usr/local/bin" ]]; then
        bin_dir="/usr/local/bin"
    elif [[ -d "/usr/bin" ]]; then
        bin_dir="/usr/bin"
    else
        # 创建/usr/local/bin目录
        mkdir -p /usr/local/bin
        bin_dir="/usr/local/bin"
    fi

    # 创建符号链接
    ln -sf "$INSTALL_DIR/bin/file-sync" "$bin_dir/file-sync"

    log_info "命令行工具已安装: $bin_dir/file-sync"
}

# 初始化配置
initialize_config() {
    log_step "初始化配置..."

    # 运行初始化（以root用户运行）
    "$INSTALL_DIR/bin/file-sync" init

    log_info "配置初始化完成"
}

# 显示安装后信息并启动主程序
show_post_install_info() {
    echo ""
    log_info "🎉 GitHub文件同步系统安装完成！"
    echo ""
    echo "安装位置: $INSTALL_DIR"
    echo "服务用户: $SERVICE_USER"
    echo "配置文件: $INSTALL_DIR/config/"
    echo ""

    # 询问是否立即配置和启动
    echo "现在可以："
    echo "1. 立即配置并启动系统"
    echo "2. 稍后手动配置"
    echo ""

    while true; do
        read -p "是否现在配置并启动？[Y/n]: " yn
        case $yn in
            [Yy]* | "" )
                start_main_program
                break
                ;;
            [Nn]* )
                show_manual_steps
                break
                ;;
            * )
                echo "请输入 y 或 n"
                ;;
        esac
    done
}

# 启动主程序
start_main_program() {
    echo ""
    log_info "🚀 启动GitHub文件同步系统主程序..."
    echo ""

    # 检查主程序文件
    local main_program=""
    if [[ -f "$INSTALL_DIR/bin/file-sync" ]]; then
        main_program="$INSTALL_DIR/bin/file-sync"
    elif [[ -f "$INSTALL_DIR/bin/file-sync.sh" ]]; then
        main_program="$INSTALL_DIR/bin/file-sync.sh"
    else
        log_error "找不到主程序文件"
        return 1
    fi

    # 直接运行主程序
    exec "$main_program"
}

# 显示手动配置步骤
show_manual_steps() {
    echo ""
    log_info "稍后配置时，请按以下步骤操作："
    echo ""
    echo "1. 编辑配置文件:"
    echo "   nano $INSTALL_DIR/config/global.conf"
    echo "   nano $INSTALL_DIR/config/paths.conf"
    echo ""
    echo "2. 验证配置:"
    echo "   file-sync validate"
    echo ""
    echo "3. 启动服务:"
    case "$INIT_SYSTEM" in
        "systemd")
            echo "   systemctl start file-sync"
            echo ""
            echo "4. 查看状态:"
            echo "   systemctl status file-sync"
            ;;
        "sysv")
            echo "   service file-sync start"
            echo ""
            echo "4. 查看状态:"
            echo "   service file-sync status"
            ;;
        "openwrt")
            echo "   /etc/init.d/file-sync start"
            echo ""
            echo "4. 查看状态:"
            echo "   /etc/init.d/file-sync status"
            ;;
        "service")
            echo "   file-sync-service start"
            echo ""
            echo "4. 查看状态:"
            echo "   file-sync-service status"
            ;;
        "manual")
            echo "   start-file-sync"
            echo ""
            echo "4. 查看状态:"
            echo "   file-sync status"
            ;;
    esac
    echo "   file-sync status"
    echo ""
    echo "5. 查看日志:"
    echo "   file-sync logs follow"
    echo ""
    echo "或者直接运行主程序:"
    echo "   file-sync"
    echo ""
    echo "更多信息请参考: $INSTALL_DIR/README.md"
}

# 清理临时文件
cleanup_temp() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# 卸载函数
uninstall() {
    log_step "卸载GitHub文件同步系统..."

    # 检测当前init系统并停止服务
    if command -v systemctl >/dev/null 2>&1 && [[ -f /etc/systemd/system/file-sync.service ]]; then
        systemctl stop file-sync.service 2>/dev/null || true
        systemctl disable file-sync.service 2>/dev/null || true
        rm -f /etc/systemd/system/file-sync.service
        systemctl daemon-reload
    elif [[ -f /etc/init.d/file-sync ]]; then
        # 检查是否为OpenWrt系统
        if grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
            /etc/init.d/file-sync stop 2>/dev/null || true
            /etc/init.d/file-sync disable 2>/dev/null || true
        else
            service file-sync stop 2>/dev/null || true
            if command -v chkconfig >/dev/null 2>&1; then
                chkconfig file-sync off
                chkconfig --del file-sync
            elif command -v update-rc.d >/dev/null 2>&1; then
                update-rc.d -f file-sync remove
            fi
        fi
        rm -f /etc/init.d/file-sync
    fi

    # 删除服务脚本
    rm -f /usr/local/bin/file-sync-service /usr/bin/file-sync-service
    rm -f /usr/local/bin/start-file-sync /usr/bin/start-file-sync

    # 删除命令链接
    rm -f /usr/local/bin/file-sync /usr/bin/file-sync

    # 删除安装目录
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi

    # 无需删除root用户
    log_info "保留root用户"

    log_info "卸载完成"
}

# 显示帮助信息
show_help() {
    cat << EOF
GitHub文件同步系统 - 一键安装脚本

用法:
  # 在线安装
  bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/install.sh)

  # 本地安装
  sudo $0 [选项]

选项:
  install     安装系统 (默认)
  uninstall   卸载系统
  --help      显示此帮助信息

示例:
  sudo $0 install     # 安装系统
  sudo $0 uninstall   # 卸载系统
EOF
}

# 主函数
main() {
    local action="${1:-install}"
    
    case "$action" in
        "install")
            # 设置清理陷阱
            trap cleanup_temp EXIT

            check_root
            check_system
            install_dependencies
            create_system_user
            download_source
            create_install_directory
            copy_files
            set_permissions
            install_system_service
            create_command_link
            initialize_config
            show_post_install_info
            cleanup_temp
            ;;
        "uninstall")
            check_root
            uninstall
            ;;
        "--help"|"-h")
            show_help
            ;;
        *)
            log_error "未知选项: $action"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
