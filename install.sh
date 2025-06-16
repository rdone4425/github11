#!/bin/bash

# GitHub文件同步系统 - 一键安装脚本
# 支持从GitHub直接下载安装
# 使用方法: bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/install.sh)

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
INSTALL_DIR="/opt/file-sync-system"
SERVICE_USER="file-sync"
SERVICE_GROUP="file-sync"
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
    
    # 检查systemd
    if ! command -v systemctl >/dev/null 2>&1; then
        log_error "系统不支持systemd"
        exit 1
    fi
    
    # 检查包管理器
    if command -v apt-get >/dev/null 2>&1; then
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
        "apt")
            apt-get update
            apt-get install -y curl jq git inotify-tools bash
            ;;
        "yum")
            yum install -y curl jq git inotify-tools bash
            ;;
        "dnf")
            dnf install -y curl jq git inotify-tools bash
            ;;
    esac
    
    log_info "依赖安装完成"
}

# 创建系统用户
create_system_user() {
    log_step "创建系统用户..."
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd -r -s /bin/false -d "$INSTALL_DIR" -c "File Sync Service" "$SERVICE_USER"
        log_info "创建用户: $SERVICE_USER"
    else
        log_info "用户已存在: $SERVICE_USER"
    fi
}

# 下载源码
download_source() {
    log_step "下载源码..."

    # 创建临时目录
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"

    # 下载源码
    if command -v git >/dev/null 2>&1; then
        log_info "使用git克隆仓库..."
        git clone "https://github.com/$GITHUB_REPO.git" file-sync-system
        cd file-sync-system
        git checkout "$GITHUB_BRANCH"
    else
        log_info "使用curl下载压缩包..."
        curl -L "https://github.com/$GITHUB_REPO/archive/$GITHUB_BRANCH.tar.gz" -o source.tar.gz
        tar -xzf source.tar.gz
        mv "github11-$GITHUB_BRANCH" file-sync-system
        cd file-sync-system
    fi

    log_info "源码下载完成"
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
    
    # 设置目录权限
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"
    
    # 设置可执行文件权限
    chmod 755 "$INSTALL_DIR/bin/"*
    
    # 设置配置文件权限
    chmod 644 "$INSTALL_DIR/config/"*
    
    # 设置日志目录权限
    chmod 755 "$INSTALL_DIR/logs"
    
    log_info "权限设置完成"
}

# 安装systemd服务
install_systemd_service() {
    log_step "安装systemd服务..."
    
    # 创建服务文件
    cat > /etc/systemd/system/file-sync.service << EOF
[Unit]
Description=GitHub File Sync Service
Documentation=https://github.com/your-repo/file-sync-system
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

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR/logs $INSTALL_DIR/config

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

# 创建命令行链接
create_command_link() {
    log_step "创建命令行链接..."
    
    # 创建符号链接到系统PATH
    ln -sf "$INSTALL_DIR/bin/file-sync" /usr/local/bin/file-sync
    
    log_info "命令行工具已安装: file-sync"
}

# 初始化配置
initialize_config() {
    log_step "初始化配置..."
    
    # 运行初始化
    sudo -u "$SERVICE_USER" "$INSTALL_DIR/bin/file-sync" init
    
    log_info "配置初始化完成"
}

# 显示安装后信息
show_post_install_info() {
    echo ""
    log_info "GitHub文件同步系统安装完成！"
    echo ""
    echo "安装位置: $INSTALL_DIR"
    echo "服务用户: $SERVICE_USER"
    echo "配置文件: $INSTALL_DIR/config/"
    echo ""
    echo "下一步操作："
    echo "1. 编辑配置文件:"
    echo "   sudo nano $INSTALL_DIR/config/global.conf"
    echo "   sudo nano $INSTALL_DIR/config/paths.conf"
    echo ""
    echo "2. 验证配置:"
    echo "   file-sync validate"
    echo ""
    echo "3. 启动服务:"
    echo "   sudo systemctl start file-sync"
    echo ""
    echo "4. 查看状态:"
    echo "   sudo systemctl status file-sync"
    echo "   file-sync status"
    echo ""
    echo "5. 查看日志:"
    echo "   file-sync logs follow"
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

    # 停止并禁用服务
    systemctl stop file-sync.service 2>/dev/null || true
    systemctl disable file-sync.service 2>/dev/null || true

    # 删除服务文件
    rm -f /etc/systemd/system/file-sync.service
    systemctl daemon-reload

    # 删除命令链接
    rm -f /usr/local/bin/file-sync

    # 删除安装目录
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi

    # 删除用户
    if id "$SERVICE_USER" &>/dev/null; then
        userdel "$SERVICE_USER" 2>/dev/null || true
    fi

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
            install_systemd_service
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
