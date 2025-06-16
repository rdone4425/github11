#!/bin/bash

# GitHub文件同步系统 - 一体化版本
# 所有功能集成在一个文件中，无需复杂的目录结构

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

# 全局变量
GITHUB_USERNAME=""
GITHUB_TOKEN=""
DEFAULT_BRANCH="main"
SYNC_INTERVAL=30
POLLING_INTERVAL=10
FORCE_POLLING=false
LOG_LEVEL="INFO"
VERBOSE=true
EXCLUDE_PATTERNS="*.tmp *.log .git"

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

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "[DEBUG] $1"
    fi
}

# 工具函数
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查基础依赖
check_basic_deps() {
    local missing_deps=()
    
    if ! command_exists "tar"; then
        missing_deps+=("tar")
    fi
    
    if ! command_exists "curl" && ! command_exists "wget"; then
        missing_deps+=("curl或wget")
    fi
    
    if ! command_exists "jq"; then
        log_warn "jq不可用，将使用简化JSON处理"
    fi
    
    if ! command_exists "inotifywait"; then
        log_warn "inotify-tools不可用，将使用轮询监控模式"
        FORCE_POLLING=true
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必需的依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖："
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "curl或wget")
                    log_info "  - OpenWrt: opkg install curl wget"
                    log_info "  - Ubuntu/Debian: sudo apt-get install curl wget"
                    ;;
                "tar")
                    log_info "  - OpenWrt: opkg install tar"
                    log_info "  - Ubuntu/Debian: sudo apt-get install tar"
                    ;;
            esac
        done
        return 1
    fi
    
    return 0
}

# 检查是否已安装
check_installation() {
    [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/config/global.conf" ]]
}

# OpenWrt智能包管理
install_openwrt_deps() {
    log_step "OpenWrt智能包管理..."
    
    local need_update=false
    if [[ -f /var/opkg-lists/kwrt_core ]]; then
        local last_update=$(stat -c %Y /var/opkg-lists/kwrt_core 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_update))
        local hours=$((time_diff / 3600))
        
        if [[ $time_diff -gt 86400 ]]; then
            need_update=true
            log_info "包列表已过期（${hours}小时前），需要更新"
        else
            log_info "包列表较新（${hours}小时前），跳过更新"
        fi
    else
        need_update=true
    fi
    
    if [[ "$need_update" == "true" ]]; then
        opkg update
    fi
    
    if ! command_exists curl && ! command_exists wget; then
        opkg install wget 2>/dev/null || log_warn "下载工具安装失败"
    fi
    
    if ! command_exists tar; then
        opkg install tar 2>/dev/null || log_warn "tar安装失败"
    fi
}

# 创建配置文件
create_config() {
    mkdir -p "$INSTALL_DIR"/{config,logs}
    
    # 全局配置
    cat > "$INSTALL_DIR/config/global.conf" << EOF
# GitHub文件同步系统 - 全局配置
GITHUB_USERNAME="$GITHUB_USERNAME"
GITHUB_TOKEN="$GITHUB_TOKEN"
DEFAULT_BRANCH="$DEFAULT_BRANCH"
SYNC_INTERVAL=$SYNC_INTERVAL
POLLING_INTERVAL=$POLLING_INTERVAL
FORCE_POLLING=$FORCE_POLLING
LOG_LEVEL="$LOG_LEVEL"
VERBOSE=$VERBOSE
EXCLUDE_PATTERNS="$EXCLUDE_PATTERNS"
EOF
    
    log_info "配置文件已创建: $INSTALL_DIR/config/global.conf"
}

# 加载配置
load_config() {
    if [[ -f "$INSTALL_DIR/config/global.conf" ]]; then
        source "$INSTALL_DIR/config/global.conf"
        return 0
    else
        log_warn "配置文件不存在，使用默认配置"
        return 1
    fi
}

# 创建OpenWrt服务
create_openwrt_service() {
    cat > /etc/init.d/file-sync << EOF
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG="$0"

start_service() {
    procd_open_instance
    procd_set_param command \$PROG daemon
    procd_set_param respawn
    procd_set_param user root
    procd_close_instance
}
EOF
    
    chmod +x /etc/init.d/file-sync
    /etc/init.d/file-sync enable
    log_info "OpenWrt服务已创建"
}

# GitHub API调用
github_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    
    local url="https://api.github.com$endpoint"
    local response
    
    if command_exists curl; then
        if [[ -n "$data" ]]; then
            response=$(curl -s -X "$method" \
                -H "Authorization: token $GITHUB_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url")
        else
            response=$(curl -s -X "$method" \
                -H "Authorization: token $GITHUB_TOKEN" \
                "$url")
        fi
    elif command_exists wget; then
        log_error "wget不支持复杂的API调用，请安装curl"
        return 1
    else
        log_error "没有可用的HTTP客户端"
        return 1
    fi
    
    echo "$response"
}

# 文件监控（轮询模式）
monitor_files() {
    local watch_path="$1"
    local repo="$2"
    
    log_info "开始监控: $watch_path -> $repo"
    log_info "使用轮询模式，间隔: ${POLLING_INTERVAL}秒"
    
    local last_snapshot="/tmp/file-sync-snapshot-$$"
    
    while true; do
        # 创建当前文件快照
        find "$watch_path" -type f ! -name "*.tmp" ! -name "*.log" -exec stat -c "%n %Y %s" {} \; 2>/dev/null > "/tmp/current-snapshot-$$" || true
        
        # 比较快照
        if [[ -f "$last_snapshot" ]] && ! diff -q "$last_snapshot" "/tmp/current-snapshot-$$" >/dev/null 2>&1; then
            log_info "检测到文件变化，开始同步..."
            sync_to_github "$watch_path" "$repo"
        fi
        
        # 更新快照
        mv "/tmp/current-snapshot-$$" "$last_snapshot"
        
        sleep "$POLLING_INTERVAL"
    done
}

# 同步到GitHub
sync_to_github() {
    local local_path="$1"
    local repo="$2"
    
    log_info "同步 $local_path 到 $repo"
    
    # 获取仓库信息
    local repo_info
    repo_info=$(github_api "GET" "/repos/$repo")
    
    if [[ $? -ne 0 ]]; then
        log_error "无法访问仓库: $repo"
        return 1
    fi
    
    # 遍历文件并上传
    find "$local_path" -type f ! -name "*.tmp" ! -name "*.log" | while read -r file; do
        local relative_path="${file#$local_path/}"
        upload_file_to_github "$file" "$relative_path" "$repo"
    done
}

# 上传文件到GitHub
upload_file_to_github() {
    local file_path="$1"
    local github_path="$2"
    local repo="$3"
    
    log_debug "上传文件: $github_path"
    
    # 读取文件内容并编码
    local content
    content=$(base64 -w 0 "$file_path")
    
    # 检查文件是否已存在
    local existing_file
    existing_file=$(github_api "GET" "/repos/$repo/contents/$github_path" 2>/dev/null || echo "")
    
    local sha=""
    if [[ -n "$existing_file" ]] && echo "$existing_file" | grep -q '"sha"'; then
        sha=$(echo "$existing_file" | grep -o '"sha":"[^"]*"' | cut -d'"' -f4)
    fi
    
    # 构建请求数据
    local data
    if [[ -n "$sha" ]]; then
        data="{\"message\":\"Update $github_path\",\"content\":\"$content\",\"sha\":\"$sha\",\"branch\":\"$DEFAULT_BRANCH\"}"
    else
        data="{\"message\":\"Add $github_path\",\"content\":\"$content\",\"branch\":\"$DEFAULT_BRANCH\"}"
    fi
    
    # 上传文件
    local result
    result=$(github_api "PUT" "/repos/$repo/contents/$github_path" "$data")
    
    if echo "$result" | grep -q '"sha"'; then
        log_debug "文件上传成功: $github_path"
    else
        log_error "文件上传失败: $github_path"
        log_debug "响应: $result"
    fi
}

# 交互式配置
interactive_config() {
    clear
    echo "GitHub文件同步系统配置"
    echo "======================"
    echo ""

    echo "请输入GitHub配置信息："
    read -p "GitHub用户名: " GITHUB_USERNAME
    read -p "GitHub Token: " GITHUB_TOKEN
    read -p "默认分支 [main]: " input_branch
    DEFAULT_BRANCH=${input_branch:-main}

    echo ""
    echo "监控设置："
    read -p "同步间隔(秒) [30]: " input_sync
    SYNC_INTERVAL=${input_sync:-30}
    read -p "轮询间隔(秒) [10]: " input_poll
    POLLING_INTERVAL=${input_poll:-10}

    create_config

    echo ""
    log_info "配置完成！"
    echo ""
    echo "下一步："
    echo "  $0 add <本地路径> <GitHub仓库>  # 添加监控路径"
    echo "  $0 start                      # 启动监控"
    echo "  $0 status                     # 查看状态"
}

# 添加监控路径
add_watch_path() {
    local local_path="$1"
    local repo="$2"

    if [[ ! -d "$local_path" ]]; then
        log_error "本地路径不存在: $local_path"
        return 1
    fi

    # 添加到配置文件
    echo "$local_path|$repo" >> "$INSTALL_DIR/config/paths.conf"
    log_info "已添加监控路径: $local_path -> $repo"
}

# 启动监控
start_monitoring() {
    if [[ ! -f "$INSTALL_DIR/config/global.conf" ]]; then
        log_error "请先运行配置: $0 config"
        return 1
    fi

    load_config

    if [[ ! -f "$INSTALL_DIR/config/paths.conf" ]]; then
        log_error "没有配置监控路径，请先添加: $0 add <路径> <仓库>"
        return 1
    fi

    log_info "启动文件监控..."

    # 读取监控路径并启动监控
    while IFS='|' read -r local_path repo; do
        if [[ -n "$local_path" && -n "$repo" ]]; then
            monitor_files "$local_path" "$repo" &
        fi
    done < "$INSTALL_DIR/config/paths.conf"

    log_info "监控已启动，按Ctrl+C停止"
    wait
}

# 守护进程模式
daemon_mode() {
    load_config

    # 创建PID文件
    echo $$ > "$INSTALL_DIR/logs/daemon.pid"

    # 重定向输出到日志
    exec 1>> "$INSTALL_DIR/logs/file-sync.log"
    exec 2>> "$INSTALL_DIR/logs/file-sync.log"

    log_info "守护进程启动 (PID: $$)"

    start_monitoring
}

# 停止监控
stop_monitoring() {
    if [[ -f "$INSTALL_DIR/logs/daemon.pid" ]]; then
        local pid=$(cat "$INSTALL_DIR/logs/daemon.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$INSTALL_DIR/logs/daemon.pid"
            log_info "监控已停止"
        else
            log_warn "进程不存在"
            rm -f "$INSTALL_DIR/logs/daemon.pid"
        fi
    else
        pkill -f "file-sync.sh" || log_warn "没有运行的监控进程"
    fi
}

# 查看状态
show_status() {
    echo "GitHub文件同步系统状态"
    echo "====================="
    echo ""

    if [[ -f "$INSTALL_DIR/config/global.conf" ]]; then
        load_config
        echo "配置状态: 已配置"
        echo "GitHub用户: $GITHUB_USERNAME"
        echo "默认分支: $DEFAULT_BRANCH"
        echo "同步间隔: ${SYNC_INTERVAL}秒"
        echo "轮询间隔: ${POLLING_INTERVAL}秒"
    else
        echo "配置状态: 未配置"
    fi

    echo ""

    if [[ -f "$INSTALL_DIR/logs/daemon.pid" ]]; then
        local pid=$(cat "$INSTALL_DIR/logs/daemon.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo "运行状态: 运行中 (PID: $pid)"
        else
            echo "运行状态: 已停止"
            rm -f "$INSTALL_DIR/logs/daemon.pid"
        fi
    else
        echo "运行状态: 已停止"
    fi

    echo ""

    if [[ -f "$INSTALL_DIR/config/paths.conf" ]]; then
        echo "监控路径:"
        while IFS='|' read -r local_path repo; do
            if [[ -n "$local_path" && -n "$repo" ]]; then
                echo "  $local_path -> $repo"
            fi
        done < "$INSTALL_DIR/config/paths.conf"
    else
        echo "监控路径: 无"
    fi
}

# 手动同步
manual_sync() {
    if [[ ! -f "$INSTALL_DIR/config/global.conf" ]]; then
        log_error "请先运行配置: $0 config"
        return 1
    fi

    load_config

    if [[ ! -f "$INSTALL_DIR/config/paths.conf" ]]; then
        log_error "没有配置监控路径"
        return 1
    fi

    log_info "开始手动同步..."

    while IFS='|' read -r local_path repo; do
        if [[ -n "$local_path" && -n "$repo" ]]; then
            sync_to_github "$local_path" "$repo"
        fi
    done < "$INSTALL_DIR/config/paths.conf"

    log_info "手动同步完成"
}

# 安装系统
install_system() {
    clear
    echo "GitHub文件同步系统安装"
    echo "====================="
    echo ""

    log_step "检测系统环境..."

    if [[ $EUID -ne 0 ]]; then
        log_error "需要root权限进行安装"
        echo "请使用: sudo $0 install"
        exit 1
    fi

    if ! check_basic_deps; then
        echo "请先安装缺少的依赖，然后重新运行"
        exit 1
    fi

    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        exit 1
    fi

    source /etc/os-release
    log_info "检测到系统: $PRETTY_NAME"

    # 安装依赖
    if grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        install_openwrt_deps
        create_openwrt_service
        ln -sf "$0" /usr/bin/file-sync
    else
        log_info "通用Linux系统，跳过包管理"
        ln -sf "$0" /usr/local/bin/file-sync
    fi

    # 创建安装目录
    mkdir -p "$INSTALL_DIR"/{config,logs}

    log_info "安装完成！"
    echo ""
    echo "下一步："
    echo "  file-sync config    # 配置GitHub凭据"
    echo "  file-sync add <路径> <仓库>  # 添加监控路径"
    echo "  file-sync start     # 启动监控"
}

# 显示帮助
show_help() {
    cat << EOF
GitHub文件同步系统 v$VERSION

用法: $0 <命令> [参数]

命令:
  install                安装系统
  config                 交互式配置
  add <路径> <仓库>       添加监控路径
  start                  启动监控
  stop                   停止监控
  restart                重启监控
  status                 查看状态
  sync                   手动同步
  daemon                 守护进程模式
  help                   显示帮助

示例:
  $0 install                           # 安装系统
  $0 config                            # 配置GitHub凭据
  $0 add /etc/config user/openwrt-config  # 添加监控路径
  $0 start                             # 启动监控
  $0 status                            # 查看状态

更多信息: https://github.com/rdone4425/github11
EOF
}

# 主函数
main() {
    case "${1:-help}" in
        "install")
            install_system
            ;;
        "config")
            interactive_config
            ;;
        "add")
            if [[ $# -lt 3 ]]; then
                log_error "用法: $0 add <本地路径> <GitHub仓库>"
                exit 1
            fi
            add_watch_path "$2" "$3"
            ;;
        "start")
            start_monitoring
            ;;
        "stop")
            stop_monitoring
            ;;
        "restart")
            stop_monitoring
            sleep 2
            start_monitoring
            ;;
        "status")
            show_status
            ;;
        "sync")
            manual_sync
            ;;
        "daemon")
            daemon_mode
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            if check_installation; then
                show_status
            else
                echo "GitHub文件同步系统未安装"
                echo "运行: $0 install"
            fi
            ;;
    esac
}

# 运行主函数
main "$@"
