#!/bin/bash

# GitHub文件同步系统 - 主程序
# 自动安装、配置和运行

set -euo pipefail

# 程序信息
PROGRAM_NAME="file-sync"
VERSION="1.0.0"
INSTALL_DIR="/file-sync-system"

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

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 检查是否已安装
check_installation() {
    if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/bin/file-sync.sh" ]]; then
        return 0  # 已安装
    else
        return 1  # 未安装
    fi
}

# 自动安装系统
auto_install() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              GitHub文件同步系统 v$VERSION                     ║"
    echo "║                    首次运行自动安装                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    log_step "检测系统环境..."

    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        log_error "需要root权限进行安装"
        echo "请使用: sudo $0"
        exit 1
    fi

    # 检测系统类型
    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        exit 1
    fi

    source /etc/os-release
    log_info "检测到系统: $PRETTY_NAME"

    # 检测OpenWrt
    if grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        install_openwrt
    elif command -v apt-get >/dev/null 2>&1; then
        install_debian
    elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        install_redhat
    else
        log_error "不支持的系统类型"
        exit 1
    fi

    log_info "🎉 安装完成！"
    echo ""

    # 重新加载模块
    load_modules

    # 进入主界面
    show_main_menu
}

# OpenWrt安装
install_openwrt() {
    log_step "安装OpenWrt依赖..."

    # 智能包管理
    local need_update=false
    if [[ -f /var/opkg-lists/kwrt_core ]]; then
        local last_update=$(stat -c %Y /var/opkg-lists/kwrt_core 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_update))
        local hours=$((time_diff / 3600))

        if [[ $time_diff -gt 86400 ]]; then
            need_update=true
            log_info "包列表已过期，需要更新"
        else
            log_info "包列表较新（${hours}小时前），跳过更新 ⚡"
        fi
    else
        need_update=true
    fi

    if [[ "$need_update" == "true" ]]; then
        opkg update
    fi

    # 安装基础依赖
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        opkg install wget 2>/dev/null || log_warn "下载工具安装失败"
    fi

    if ! command -v tar >/dev/null 2>&1; then
        opkg install tar 2>/dev/null || log_warn "tar安装失败"
    fi

    # 下载并安装程序
    download_and_install

    # 创建OpenWrt服务
    create_openwrt_service

    # 创建命令链接
    ln -sf "$INSTALL_DIR/bin/file-sync.sh" /usr/bin/file-sync
}

# Debian/Ubuntu安装
install_debian() {
    log_step "安装Debian/Ubuntu依赖..."

    apt-get update
    apt-get install -y curl wget tar ca-certificates

    download_and_install
    create_systemd_service
    ln -sf "$INSTALL_DIR/bin/file-sync.sh" /usr/local/bin/file-sync
}

# RedHat/CentOS安装
install_redhat() {
    log_step "安装RedHat/CentOS依赖..."

    if command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget tar ca-certificates
    else
        yum install -y curl wget tar ca-certificates
    fi

    download_and_install
    create_systemd_service
    ln -sf "$INSTALL_DIR/bin/file-sync.sh" /usr/local/bin/file-sync
}

# 下载并安装程序文件
download_and_install() {
    log_step "下载程序文件..."

    local temp_dir="/tmp/file-sync-install-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # 下载源码
    local download_url="https://github.com/rdone4425/github11/archive/main.tar.gz"

    if command -v curl >/dev/null 2>&1; then
        curl -L "$download_url" -o source.tar.gz
    elif command -v wget >/dev/null 2>&1; then
        wget "$download_url" -O source.tar.gz
    else
        log_error "没有可用的下载工具"
        exit 1
    fi

    # 解压并安装
    tar -xzf source.tar.gz
    mv github11-main file-sync-system

    # 创建安装目录
    mkdir -p "$INSTALL_DIR"/{bin,lib,config,logs,docs}

    # 复制文件
    cp -r file-sync-system/bin/* "$INSTALL_DIR/bin/"
    cp -r file-sync-system/lib/* "$INSTALL_DIR/lib/"
    cp -r file-sync-system/config/* "$INSTALL_DIR/config/"

    if [[ -d file-sync-system/docs ]]; then
        cp -r file-sync-system/docs/* "$INSTALL_DIR/docs/"
    fi

    # 设置权限
    chmod +x "$INSTALL_DIR/bin/"*
    chown -R root:root "$INSTALL_DIR"

    # 清理
    cd /
    rm -rf "$temp_dir"

    log_info "程序文件安装完成"
}

# 创建OpenWrt服务
create_openwrt_service() {
    cat > /etc/init.d/file-sync << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG="/file-sync-system/bin/file-sync.sh"

start_service() {
    procd_open_instance
    procd_set_param command $PROG daemon
    procd_set_param respawn
    procd_set_param user root
    procd_close_instance
}
EOF

    chmod +x /etc/init.d/file-sync
    /etc/init.d/file-sync enable
}

# 创建systemd服务
create_systemd_service() {
    cat > /etc/systemd/system/file-sync.service << EOF
[Unit]
Description=GitHub File Sync Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$INSTALL_DIR/bin/file-sync.sh daemon
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable file-sync
}

# 加载核心模块
load_modules() {
    if [[ -f "$PROJECT_ROOT/lib/utils.sh" ]]; then
        source "$PROJECT_ROOT/lib/utils.sh"
        source "$PROJECT_ROOT/lib/logger.sh"
        source "$PROJECT_ROOT/lib/config.sh"
        source "$PROJECT_ROOT/lib/monitor.sh"
        source "$PROJECT_ROOT/lib/github.sh"
    else
        log_error "核心模块未找到，请重新安装"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
GitHub文件同步系统 v$VERSION

用法: $PROGRAM_NAME [选项] <命令> [参数]

命令:
  init                    初始化配置文件
  start                   启动文件监控
  stop                    停止文件监控
  restart                 重启文件监控
  status                  显示监控状态
  config                  配置管理
  sync                    手动同步
  validate                验证配置
  logs                    查看日志

选项:
  -h, --help             显示此帮助信息
  -v, --verbose          启用详细输出
  -c, --config DIR       指定配置目录
  --version              显示版本信息

配置命令:
  config list            列出所有配置
  config edit            编辑配置文件
  config validate        验证配置
  config reset           重置配置

同步命令:
  sync all               同步所有启用的路径
  sync <path_id>         同步指定路径
  sync --force <path_id> 强制同步指定路径

日志命令:
  logs show              显示最近的日志
  logs follow            实时跟踪日志
  logs stats             显示日志统计
  logs clean             清理旧日志

示例:
  $PROGRAM_NAME init                    # 初始化配置
  $PROGRAM_NAME start                   # 启动监控
  $PROGRAM_NAME sync documents          # 同步documents路径
  $PROGRAM_NAME logs follow             # 实时查看日志

更多信息请参考: https://github.com/your-repo/file-sync-system
EOF
}

# 显示版本信息
show_version() {
    echo "$PROGRAM_NAME version $VERSION"
}

# 显示主菜单
show_main_menu() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              GitHub文件同步系统 v$VERSION                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # 检查配置状态
    local config_status="未配置"
    if [[ -f "$INSTALL_DIR/config/global.conf" ]] && [[ -f "$INSTALL_DIR/config/paths.conf" ]]; then
        config_status="已配置"
    fi

    echo "系统状态: $config_status"
    echo "安装位置: $INSTALL_DIR"
    echo ""

    while true; do
        echo "请选择操作："
        echo ""
        echo "1) 🔧 初始化配置"
        echo "2) ⚙️  配置管理"
        echo "3) ✅ 验证配置"
        echo "4) 🚀 启动监控"
        echo "5) ⏹️  停止监控"
        echo "6) 📊 查看状态"
        echo "7) 🔄 手动同步"
        echo "8) 📝 查看日志"
        echo "9) 🛠️  系统管理"
        echo "0) 🚪 退出"
        echo ""
        read -p "请输入选择 [0-9]: " choice

        case $choice in
            1)
                echo ""
                init_config_interactive
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            2)
                echo ""
                config_submenu
                clear
                ;;
            3)
                echo ""
                validate_config_interactive
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            4)
                echo ""
                start_monitoring_interactive
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            5)
                echo ""
                stop_monitoring_interactive
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            6)
                echo ""
                show_status_interactive
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            7)
                echo ""
                sync_submenu
                clear
                ;;
            8)
                echo ""
                logs_submenu
                clear
                ;;
            9)
                echo ""
                system_submenu
                clear
                ;;
            0)
                echo ""
                echo "感谢使用GitHub文件同步系统！"
                exit 0
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}

# 交互式初始化配置
init_config_interactive() {
    echo "🔧 初始化配置"
    echo "============="
    echo ""

    # 创建配置目录
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/logs"

    # GitHub配置
    echo "请输入GitHub配置信息："
    read -p "GitHub用户名: " github_username
    read -p "GitHub Token: " github_token
    read -p "默认分支 [main]: " default_branch
    default_branch=${default_branch:-main}

    # 创建全局配置
    cat > "$INSTALL_DIR/config/global.conf" << EOF
# GitHub文件同步系统 - 全局配置

# GitHub凭据
GITHUB_USERNAME="$github_username"
GITHUB_TOKEN="$github_token"
DEFAULT_BRANCH="$default_branch"

# 监控设置
SYNC_INTERVAL=30
POLLING_INTERVAL=10
FORCE_POLLING=false

# 日志设置
LOG_LEVEL="INFO"
VERBOSE=true

# 排除模式
EXCLUDE_PATTERNS="*.tmp *.log .git"
EOF

    # 路径配置
    echo ""
    echo "配置监控路径："
    read -p "本地路径: " local_path
    read -p "GitHub仓库 (用户名/仓库名): " github_repo
    read -p "路径ID [default]: " path_id
    path_id=${path_id:-default}

    # 创建路径配置
    cat > "$INSTALL_DIR/config/paths.conf" << EOF
# GitHub文件同步系统 - 路径配置

[$path_id]
LOCAL_PATH=$local_path
GITHUB_REPO=$github_repo
TARGET_BRANCH=$default_branch
ENABLED=true
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=*.backup
EOF

    echo ""
    log_info "配置初始化完成！"
    echo ""
    echo "配置文件位置："
    echo "  全局配置: $INSTALL_DIR/config/global.conf"
    echo "  路径配置: $INSTALL_DIR/config/paths.conf"
}

# 交互式验证配置
validate_config_interactive() {
    echo "✅ 验证配置"
    echo "==========="
    echo ""

    local errors=0

    # 检查配置文件
    if [[ ! -f "$INSTALL_DIR/config/global.conf" ]]; then
        log_error "全局配置文件不存在"
        ((errors++))
    else
        log_info "全局配置文件存在 ✓"
    fi

    if [[ ! -f "$INSTALL_DIR/config/paths.conf" ]]; then
        log_error "路径配置文件不存在"
        ((errors++))
    else
        log_info "路径配置文件存在 ✓"
    fi

    # 检查GitHub连接
    if [[ -f "$INSTALL_DIR/config/global.conf" ]]; then
        source "$INSTALL_DIR/config/global.conf"

        if [[ -n "$GITHUB_USERNAME" ]] && [[ -n "$GITHUB_TOKEN" ]]; then
            log_info "GitHub凭据已配置 ✓"

            # 测试GitHub连接
            if command -v curl >/dev/null 2>&1; then
                if curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user >/dev/null; then
                    log_info "GitHub连接测试成功 ✓"
                else
                    log_warn "GitHub连接测试失败"
                    ((errors++))
                fi
            fi
        else
            log_error "GitHub凭据未配置"
            ((errors++))
        fi
    fi

    if [[ $errors -eq 0 ]]; then
        echo ""
        log_info "🎉 配置验证通过！"
    else
        echo ""
        log_error "发现 $errors 个配置问题"
    fi
}

# 交互式启动监控
start_monitoring_interactive() {
    echo "🚀 启动文件监控"
    echo "==============="
    echo ""

    if [[ ! -f "$INSTALL_DIR/config/global.conf" ]]; then
        log_error "请先初始化配置"
        return 1
    fi

    # 检测系统类型并启动服务
    if grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        log_info "启动OpenWrt服务..."
        /etc/init.d/file-sync start
        log_info "服务已启动"
    elif command -v systemctl >/dev/null 2>&1; then
        log_info "启动systemd服务..."
        systemctl start file-sync
        log_info "服务已启动"
    else
        log_info "启动后台监控..."
        nohup "$INSTALL_DIR/bin/file-sync.sh" daemon >/dev/null 2>&1 &
        log_info "后台监控已启动"
    fi
}

# 交互式停止监控
stop_monitoring_interactive() {
    echo "⏹️ 停止文件监控"
    echo "==============="
    echo ""

    if grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        /etc/init.d/file-sync stop
        log_info "OpenWrt服务已停止"
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl stop file-sync
        log_info "systemd服务已停止"
    else
        pkill -f "file-sync.sh daemon" || true
        log_info "后台监控已停止"
    fi
}

# 交互式状态显示
show_status_interactive() {
    echo "📊 系统状态"
    echo "==========="
    echo ""

    # 检查服务状态
    if grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        if /etc/init.d/file-sync status >/dev/null 2>&1; then
            log_info "OpenWrt服务: 运行中 ✓"
        else
            log_warn "OpenWrt服务: 已停止"
        fi
    elif command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active file-sync >/dev/null 2>&1; then
            log_info "systemd服务: 运行中 ✓"
        else
            log_warn "systemd服务: 已停止"
        fi
    else
        if pgrep -f "file-sync.sh daemon" >/dev/null; then
            log_info "后台进程: 运行中 ✓"
        else
            log_warn "后台进程: 已停止"
        fi
    fi

    # 显示配置信息
    if [[ -f "$INSTALL_DIR/config/global.conf" ]]; then
        source "$INSTALL_DIR/config/global.conf"
        echo ""
        echo "配置信息："
        echo "  GitHub用户: $GITHUB_USERNAME"
        echo "  默认分支: $DEFAULT_BRANCH"
        echo "  同步间隔: ${SYNC_INTERVAL}秒"
    fi

    # 显示日志统计
    if [[ -f "$INSTALL_DIR/logs/file-sync.log" ]]; then
        local log_lines=$(wc -l < "$INSTALL_DIR/logs/file-sync.log")
        echo "  日志行数: $log_lines"
    fi
}

# 配置子菜单
config_submenu() {
    while true; do
        echo "配置管理："
        echo ""
        echo "1) 📋 列出配置"
        echo "2) ✏️  编辑配置"
        echo "3) ✅ 验证配置"
        echo "4) 🔄 重置配置"
        echo "0) 🔙 返回主菜单"
        echo ""
        read -p "请选择 [0-4]: " choice

        case $choice in
            1)
                echo ""
                manage_config "list"
                echo ""
                read -p "按Enter键继续..."
                ;;
            2)
                echo ""
                manage_config "edit"
                echo ""
                read -p "按Enter键继续..."
                ;;
            3)
                echo ""
                manage_config "validate"
                echo ""
                read -p "按Enter键继续..."
                ;;
            4)
                echo ""
                manage_config "reset"
                echo ""
                read -p "按Enter键继续..."
                ;;
            0)
                return
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}

# 同步子菜单
sync_submenu() {
    while true; do
        echo "手动同步："
        echo ""
        echo "1) 🔄 同步所有路径"
        echo "2) 📁 同步指定路径"
        echo "3) ⚡ 强制同步指定路径"
        echo "0) 🔙 返回主菜单"
        echo ""
        read -p "请选择 [0-3]: " choice

        case $choice in
            1)
                echo ""
                manual_sync "all" false
                echo ""
                read -p "按Enter键继续..."
                ;;
            2)
                echo ""
                echo "可用路径："
                load_global_config
                parse_paths_config
                local enabled_paths
                mapfile -t enabled_paths < <(get_enabled_paths)
                for path_id in "${enabled_paths[@]}"; do
                    echo "  - $path_id"
                done
                echo ""
                read -p "请输入路径ID: " path_id
                if [[ -n "$path_id" ]]; then
                    manual_sync "$path_id" false
                fi
                echo ""
                read -p "按Enter键继续..."
                ;;
            3)
                echo ""
                echo "可用路径："
                load_global_config
                parse_paths_config
                local enabled_paths
                mapfile -t enabled_paths < <(get_enabled_paths)
                for path_id in "${enabled_paths[@]}"; do
                    echo "  - $path_id"
                done
                echo ""
                read -p "请输入路径ID: " path_id
                if [[ -n "$path_id" ]]; then
                    manual_sync "$path_id" true
                fi
                echo ""
                read -p "按Enter键继续..."
                ;;
            0)
                return
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}

# 日志子菜单
logs_submenu() {
    while true; do
        echo "日志管理："
        echo ""
        echo "1) 📄 显示最近日志"
        echo "2) 👁️  实时跟踪日志"
        echo "3) 📊 日志统计"
        echo "4) 🧹 清理旧日志"
        echo "0) 🔙 返回主菜单"
        echo ""
        read -p "请选择 [0-4]: " choice

        case $choice in
            1)
                echo ""
                manage_logs "show"
                echo ""
                read -p "按Enter键继续..."
                ;;
            2)
                echo ""
                echo "按Ctrl+C退出日志跟踪"
                manage_logs "follow"
                echo ""
                read -p "按Enter键继续..."
                ;;
            3)
                echo ""
                manage_logs "stats"
                echo ""
                read -p "按Enter键继续..."
                ;;
            4)
                echo ""
                manage_logs "clean"
                echo ""
                read -p "按Enter键继续..."
                ;;
            0)
                return
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}



# 配置管理
manage_config() {
    local action="$1"
    
    case "$action" in
        "list")
            echo "=== 全局配置 ==="
            if [[ -f "$PROJECT_ROOT/config/global.conf" ]]; then
                grep -v '^#' "$PROJECT_ROOT/config/global.conf" | grep -v '^$'
            else
                echo "配置文件不存在"
            fi
            
            echo ""
            echo "=== 路径配置 ==="
            if [[ -f "$PROJECT_ROOT/config/paths.conf" ]]; then
                grep -v '^#' "$PROJECT_ROOT/config/paths.conf" | grep -v '^$'
            else
                echo "配置文件不存在"
            fi
            ;;
        "edit")
            local editor="${EDITOR:-nano}"
            echo "选择要编辑的配置文件:"
            echo "1) 全局配置 (global.conf)"
            echo "2) 路径配置 (paths.conf)"
            read -p "请选择 [1-2]: " choice
            
            case "$choice" in
                1)
                    "$editor" "$PROJECT_ROOT/config/global.conf"
                    ;;
                2)
                    "$editor" "$PROJECT_ROOT/config/paths.conf"
                    ;;
                *)
                    echo "无效选择"
                    exit 1
                    ;;
            esac
            ;;
        "validate")
            validate_all_config
            ;;
        "reset")
            if confirm_action "确定要重置所有配置吗？这将删除现有配置"; then
                rm -f "$PROJECT_ROOT/config/global.conf"
                rm -f "$PROJECT_ROOT/config/paths.conf"
                init_config
                echo "配置已重置"
            fi
            ;;
        *)
            echo "未知的配置命令: $action"
            echo "可用命令: list, edit, validate, reset"
            exit 1
            ;;
    esac
}

# 验证所有配置
validate_all_config() {
    echo "正在验证配置..."
    
    local errors=0
    
    # 验证全局配置
    if ! validate_global_config; then
        ((errors++))
    fi
    
    # 验证路径配置
    parse_paths_config
    local enabled_paths
    mapfile -t enabled_paths < <(get_enabled_paths)
    
    for path_id in "${enabled_paths[@]}"; do
        echo "验证路径配置: $path_id"
        
        local local_path=$(get_path_config "$path_id" "LOCAL_PATH")
        local github_repo=$(get_path_config "$path_id" "GITHUB_REPO")
        
        # 检查本地路径
        if [[ ! -d "$local_path" ]]; then
            echo "错误: 本地路径不存在: $local_path"
            ((errors++))
        fi
        
        # 验证GitHub配置
        if ! validate_path_github_config "$path_id"; then
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        echo "配置验证通过！"
        return 0
    else
        echo "配置验证失败，发现 $errors 个错误"
        return 1
    fi
}

# 手动同步
manual_sync() {
    local target="$1"
    local force="$2"
    
    # 加载配置
    load_global_config
    parse_paths_config
    
    case "$target" in
        "all")
            echo "开始同步所有启用的路径..."
            local enabled_paths
            mapfile -t enabled_paths < <(get_enabled_paths)
            
            for path_id in "${enabled_paths[@]}"; do
                echo "同步路径: $path_id"
                sync_directory_to_github "$path_id" "$force"
            done
            ;;
        *)
            if [[ -n "$target" ]]; then
                echo "同步路径: $target"
                sync_directory_to_github "$target" "$force"
            else
                echo "错误: 请指定要同步的路径或使用 'all'"
                exit 1
            fi
            ;;
    esac
}

# 日志管理
manage_logs() {
    local action="$1"
    
    case "$action" in
        "show")
            if [[ -f "$PROJECT_ROOT/logs/file-sync.log" ]]; then
                tail -n 50 "$PROJECT_ROOT/logs/file-sync.log"
            else
                echo "日志文件不存在"
            fi
            ;;
        "follow")
            if [[ -f "$PROJECT_ROOT/logs/file-sync.log" ]]; then
                tail -f "$PROJECT_ROOT/logs/file-sync.log"
            else
                echo "日志文件不存在"
            fi
            ;;
        "stats")
            get_log_stats
            ;;
        "clean")
            if confirm_action "确定要清理旧日志吗？"; then
                cleanup_logs 7
            fi
            ;;
        *)
            echo "未知的日志命令: $action"
            echo "可用命令: show, follow, stats, clean"
            exit 1
            ;;
    esac
}



# 守护进程模式
daemon_mode() {
    echo "启动守护进程模式..."

    # 加载模块
    load_modules

    # 初始化
    init_logger
    load_global_config
    parse_paths_config
    init_monitor

    # 启动监控
    start_monitoring
}

# 系统管理子菜单
system_submenu() {
    while true; do
        echo "🛠️ 系统管理"
        echo "==========="
        echo ""
        echo "1) 🔄 重启服务"
        echo "2) 🗑️  卸载系统"
        echo "3) 📋 查看系统信息"
        echo "4) 🔧 重新安装"
        echo "0) 🔙 返回主菜单"
        echo ""
        read -p "请选择 [0-4]: " choice

        case $choice in
            1)
                echo ""
                restart_service
                echo ""
                read -p "按Enter键继续..."
                ;;
            2)
                echo ""
                uninstall_system
                echo ""
                read -p "按Enter键继续..."
                ;;
            3)
                echo ""
                show_system_info
                echo ""
                read -p "按Enter键继续..."
                ;;
            4)
                echo ""
                reinstall_system
                echo ""
                read -p "按Enter键继续..."
                ;;
            0)
                return
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}

# 重启服务
restart_service() {
    echo "🔄 重启服务"
    echo "==========="
    echo ""

    stop_monitoring_interactive
    sleep 2
    start_monitoring_interactive

    log_info "服务重启完成"
}

# 卸载系统
uninstall_system() {
    echo "🗑️ 卸载系统"
    echo "==========="
    echo ""

    read -p "确定要卸载GitHub文件同步系统吗？[y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # 停止服务
        stop_monitoring_interactive

        # 删除服务文件
        rm -f /etc/init.d/file-sync
        rm -f /etc/systemd/system/file-sync.service

        # 删除命令链接
        rm -f /usr/bin/file-sync /usr/local/bin/file-sync

        # 删除安装目录
        rm -rf "$INSTALL_DIR"

        log_info "系统已卸载"
        echo "感谢使用GitHub文件同步系统！"
        exit 0
    else
        log_info "取消卸载"
    fi
}

# 显示系统信息
show_system_info() {
    echo "📋 系统信息"
    echo "==========="
    echo ""

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "操作系统: $PRETTY_NAME"
    fi

    echo "架构: $(uname -m)"
    echo "内核: $(uname -r)"
    echo "安装位置: $INSTALL_DIR"
    echo "程序版本: $VERSION"

    if command -v free >/dev/null 2>&1; then
        echo "可用内存: $(free -h | awk 'NR==2{print $7}')"
    fi

    if [[ -d "$INSTALL_DIR" ]]; then
        echo "占用空间: $(du -sh "$INSTALL_DIR" | cut -f1)"
    fi
}

# 重新安装
reinstall_system() {
    echo "🔧 重新安装"
    echo "==========="
    echo ""

    read -p "确定要重新安装吗？这将覆盖现有安装 [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # 备份配置
        if [[ -d "$INSTALL_DIR/config" ]]; then
            cp -r "$INSTALL_DIR/config" /tmp/file-sync-config-backup
            log_info "配置已备份到 /tmp/file-sync-config-backup"
        fi

        # 重新安装
        auto_install

        # 恢复配置
        if [[ -d /tmp/file-sync-config-backup ]]; then
            cp -r /tmp/file-sync-config-backup/* "$INSTALL_DIR/config/"
            rm -rf /tmp/file-sync-config-backup
            log_info "配置已恢复"
        fi

        log_info "重新安装完成"
    else
        log_info "取消重新安装"
    fi
}

# 主函数
main() {
    # 检查是否已安装
    if ! check_installation; then
        # 首次运行，自动安装
        auto_install
        return
    fi

    # 已安装，加载模块
    load_modules

    # 处理命令行参数
    if [[ $# -eq 0 ]]; then
        # 无参数，显示主菜单
        show_main_menu
    else
        # 有参数，处理命令
        local command="$1"
        shift

        case "$command" in
            "daemon")
                daemon_mode
                ;;
            "install")
                auto_install
                ;;
            "start")
                start_monitoring_interactive
                ;;
            "stop")
                stop_monitoring_interactive
                ;;
            "status")
                show_status_interactive
                ;;
            "config")
                init_config_interactive
                ;;
            "validate")
                validate_config_interactive
                ;;
            *)
                echo "未知命令: $command"
                echo "可用命令: install, start, stop, status, config, validate, daemon"
                exit 1
                ;;
        esac
    fi
}

# 运行主函数
main "$@"
