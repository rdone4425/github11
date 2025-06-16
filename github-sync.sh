#!/bin/sh
#
# GitHub File Sync Tool for OpenWrt/Kwrt Systems
# 专为OpenWrt/Kwrt系统设计的GitHub文件同步工具
#
# Author: GitHub Sync Tool
# Version: 1.0.0
# License: MIT
#

# 全局变量
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="${SCRIPT_DIR}/github-sync.conf"
LOG_FILE="${SCRIPT_DIR}/github-sync.log"
PID_FILE="${SCRIPT_DIR}/github-sync.pid"
LOCK_FILE="${SCRIPT_DIR}/github-sync.lock"

# 默认配置
DEFAULT_POLL_INTERVAL=30
DEFAULT_LOG_LEVEL="INFO"
DEFAULT_MAX_LOG_SIZE=1048576  # 1MB

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#==============================================================================
# 日志和输出函数
#==============================================================================

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 写入日志文件
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # 控制台输出（根据级别着色）
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $message"
            ;;
        *)
            echo "[$level] $message"
            ;;
    esac
}

log_error() { log "ERROR" "$1"; }
log_warn() { log "WARN" "$1"; }
log_info() { log "INFO" "$1"; }
log_debug() { log "DEBUG" "$1"; }

# 日志文件大小管理
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $DEFAULT_MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
        log_info "日志文件已轮转"
    fi
}

#==============================================================================
# 配置管理函数
#==============================================================================

# 创建默认配置文件
create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# GitHub Sync Tool Configuration
# GitHub同步工具配置文件

# GitHub全局配置
GITHUB_USERNAME=""
GITHUB_TOKEN=""

# 监控配置
POLL_INTERVAL=30
LOG_LEVEL="INFO"

# 监控路径配置 (格式: 本地路径|GitHub仓库|分支|目标路径)
# 示例: /etc/config|username/openwrt-config|main|config
SYNC_PATHS=""

# 排除文件模式 (用空格分隔)
EXCLUDE_PATTERNS="*.tmp *.log *.pid *.lock .git"

# 高级选项
AUTO_COMMIT=true
COMMIT_MESSAGE_TEMPLATE="Auto sync from OpenWrt: %s"
MAX_FILE_SIZE=1048576  # 1MB
EOF
    log_info "已创建默认配置文件: $CONFIG_FILE"
}

# 读取配置文件
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warn "配置文件不存在，创建默认配置"
        create_default_config
        return 1
    fi
    
    # 读取配置文件
    . "$CONFIG_FILE"
    
    # 验证必要配置
    if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
        log_error "GitHub用户名和令牌未配置，请编辑 $CONFIG_FILE"
        return 1
    fi
    
    if [ -z "$SYNC_PATHS" ]; then
        log_error "未配置监控路径，请编辑 $CONFIG_FILE"
        return 1
    fi
    
    # 设置默认值
    POLL_INTERVAL=${POLL_INTERVAL:-$DEFAULT_POLL_INTERVAL}
    LOG_LEVEL=${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}
    
    log_info "配置文件加载成功"
    return 0
}

# 验证配置
validate_config() {
    local errors=0
    
    # 验证GitHub连接
    if ! check_github_connection; then
        log_error "GitHub连接验证失败"
        errors=$((errors + 1))
    fi
    
    # 验证监控路径
    echo "$SYNC_PATHS" | while IFS='|' read -r local_path repo branch target_path; do
        if [ ! -d "$local_path" ]; then
            log_error "监控路径不存在: $local_path"
            errors=$((errors + 1))
        fi
    done
    
    return $errors
}

#==============================================================================
# GitHub API函数
#==============================================================================

# 检查GitHub连接
check_github_connection() {
    local response
    response=$(curl -s -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/user" -o /dev/null)
    
    if [ "$response" = "200" ]; then
        log_info "GitHub连接验证成功"
        return 0
    else
        log_error "GitHub连接验证失败，HTTP状态码: $response"
        return 1
    fi
}

# 获取文件的SHA值（用于更新文件）
get_file_sha() {
    local repo="$1"
    local file_path="$2"
    local branch="$3"
    
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$repo/contents/$file_path?ref=$branch")
    
    echo "$response" | grep '"sha"' | sed 's/.*"sha": *"\([^"]*\)".*/\1/'
}

# 上传文件到GitHub
upload_file_to_github() {
    local local_file="$1"
    local repo="$2"
    local branch="$3"
    local target_path="$4"
    local commit_message="$5"
    
    if [ ! -f "$local_file" ]; then
        log_error "本地文件不存在: $local_file"
        return 1
    fi
    
    # 检查文件大小
    local file_size=$(stat -c%s "$local_file" 2>/dev/null || echo 0)
    if [ "$file_size" -gt "${MAX_FILE_SIZE:-1048576}" ]; then
        log_error "文件太大，跳过: $local_file (${file_size} bytes)"
        return 1
    fi
    
    # Base64编码文件内容
    local content
    content=$(base64 -w 0 "$local_file")
    
    # 获取现有文件的SHA（如果存在）
    local sha
    sha=$(get_file_sha "$repo" "$target_path" "$branch")
    
    # 构建API请求
    local json_data
    if [ -n "$sha" ]; then
        # 更新现有文件
        json_data="{\"message\":\"$commit_message\",\"content\":\"$content\",\"sha\":\"$sha\",\"branch\":\"$branch\"}"
    else
        # 创建新文件
        json_data="{\"message\":\"$commit_message\",\"content\":\"$content\",\"branch\":\"$branch\"}"
    fi
    
    # 发送请求
    local response
    response=$(curl -s -X PUT -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$json_data" \
        "https://api.github.com/repos/$repo/contents/$target_path")
    
    if echo "$response" | grep -q '"sha"'; then
        log_info "文件上传成功: $local_file -> $repo/$target_path"
        return 0
    else
        log_error "文件上传失败: $local_file"
        log_debug "GitHub API响应: $response"
        return 1
    fi
}

#==============================================================================
# 文件监控函数
#==============================================================================

# 检查文件是否应该被排除
should_exclude_file() {
    local file="$1"
    local filename=$(basename "$file")
    
    for pattern in $EXCLUDE_PATTERNS; do
        case "$filename" in
            $pattern)
                return 0  # 应该排除
                ;;
        esac
    done
    
    return 1  # 不应该排除
}

# 获取文件的修改时间戳
get_file_mtime() {
    stat -c %Y "$1" 2>/dev/null || echo 0
}

# 扫描目录中的文件变化
scan_directory_changes() {
    local watch_path="$1"
    local state_file="${SCRIPT_DIR}/.state_$(echo "$watch_path" | tr '/' '_')"
    
    log_debug "扫描目录变化: $watch_path"
    
    # 创建状态文件（如果不存在）
    [ ! -f "$state_file" ] && touch "$state_file"
    
    # 扫描所有文件
    find "$watch_path" -type f | while read -r file; do
        # 检查是否应该排除
        if should_exclude_file "$file"; then
            continue
        fi
        
        local current_mtime=$(get_file_mtime "$file")
        local stored_mtime=$(grep "^$file:" "$state_file" | cut -d: -f2)
        
        if [ "$current_mtime" != "$stored_mtime" ]; then
            echo "$file"
            # 更新状态文件
            grep -v "^$file:" "$state_file" > "${state_file}.tmp" 2>/dev/null || true
            echo "$file:$current_mtime" >> "${state_file}.tmp"
            mv "${state_file}.tmp" "$state_file"
        fi
    done
}

#==============================================================================
# 主要功能函数
#==============================================================================

# 同步单个文件
sync_file() {
    local local_file="$1"
    local repo="$2"
    local branch="$3"
    local base_path="$4"
    local target_base="$5"
    
    # 计算相对路径
    local relative_path="${local_file#$base_path/}"
    local target_path="$target_base/$relative_path"
    
    # 清理路径
    target_path=$(echo "$target_path" | sed 's|//*|/|g' | sed 's|^/||')
    
    # 生成提交消息
    local commit_message
    if [ "$AUTO_COMMIT" = "true" ]; then
        commit_message=$(printf "$COMMIT_MESSAGE_TEMPLATE" "$relative_path")
    else
        commit_message="Update $relative_path"
    fi
    
    log_info "同步文件: $local_file -> $repo/$target_path"
    
    if upload_file_to_github "$local_file" "$repo" "$branch" "$target_path" "$commit_message"; then
        log_info "文件同步成功: $relative_path"
    else
        log_error "文件同步失败: $relative_path"
    fi
}

# 处理单个监控路径
process_sync_path() {
    local sync_config="$1"
    
    # 解析配置 (格式: 本地路径|GitHub仓库|分支|目标路径)
    local local_path=$(echo "$sync_config" | cut -d'|' -f1)
    local repo=$(echo "$sync_config" | cut -d'|' -f2)
    local branch=$(echo "$sync_config" | cut -d'|' -f3)
    local target_path=$(echo "$sync_config" | cut -d'|' -f4)
    
    # 验证配置
    if [ -z "$local_path" ] || [ -z "$repo" ] || [ -z "$branch" ]; then
        log_error "同步路径配置不完整: $sync_config"
        return 1
    fi
    
    if [ ! -d "$local_path" ]; then
        log_error "监控路径不存在: $local_path"
        return 1
    fi
    
    # 设置默认目标路径
    [ -z "$target_path" ] && target_path=""
    
    log_debug "处理同步路径: $local_path -> $repo:$branch/$target_path"
    
    # 扫描文件变化
    local changed_files
    changed_files=$(scan_directory_changes "$local_path")
    
    if [ -n "$changed_files" ]; then
        log_info "发现 $(echo "$changed_files" | wc -l) 个文件变化"
        
        echo "$changed_files" | while read -r file; do
            sync_file "$file" "$repo" "$branch" "$local_path" "$target_path"
        done
    else
        log_debug "未发现文件变化: $local_path"
    fi
}

# 主监控循环
monitor_loop() {
    log_info "开始文件监控，轮询间隔: ${POLL_INTERVAL}秒"
    
    while true; do
        # 轮转日志
        rotate_log
        
        # 处理所有同步路径
        echo "$SYNC_PATHS" | while IFS='|' read -r local_path repo branch target_path; do
            [ -n "$local_path" ] && process_sync_path "$local_path|$repo|$branch|$target_path"
        done
        
        # 等待下一次轮询
        sleep "$POLL_INTERVAL"
    done
}

#==============================================================================
# 进程管理函数
#==============================================================================

# 检查是否已经在运行
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0  # 正在运行
        else
            # PID文件存在但进程不存在，清理PID文件
            rm -f "$PID_FILE"
        fi
    fi
    return 1  # 未运行
}

# 启动守护进程
start_daemon() {
    if is_running; then
        log_error "GitHub同步服务已在运行 (PID: $(cat "$PID_FILE"))"
        return 1
    fi

    # 创建锁文件
    if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
        log_error "无法创建锁文件，可能有其他实例正在启动"
        return 1
    fi

    log_info "启动GitHub同步服务..."

    # 验证配置
    if ! load_config || ! validate_config; then
        rm -f "$LOCK_FILE"
        return 1
    fi

    # 启动后台进程
    (
        # 记录PID
        echo $$ > "$PID_FILE"

        # 清理锁文件
        rm -f "$LOCK_FILE"

        # 设置信号处理
        trap 'cleanup_and_exit' TERM INT

        # 开始监控
        monitor_loop
    ) &

    # 等待一下确保启动成功
    sleep 2

    if is_running; then
        log_info "GitHub同步服务启动成功 (PID: $(cat "$PID_FILE"))"
        return 0
    else
        log_error "GitHub同步服务启动失败"
        rm -f "$LOCK_FILE"
        return 1
    fi
}

# 停止守护进程
stop_daemon() {
    if ! is_running; then
        log_warn "GitHub同步服务未运行"
        return 1
    fi

    local pid=$(cat "$PID_FILE")
    log_info "停止GitHub同步服务 (PID: $pid)..."

    # 发送TERM信号
    if kill "$pid" 2>/dev/null; then
        # 等待进程结束
        local count=0
        while [ $count -lt 10 ] && kill -0 "$pid" 2>/dev/null; do
            sleep 1
            count=$((count + 1))
        done

        # 如果还在运行，强制杀死
        if kill -0 "$pid" 2>/dev/null; then
            log_warn "进程未响应TERM信号，发送KILL信号"
            kill -9 "$pid" 2>/dev/null
        fi

        # 清理文件
        rm -f "$PID_FILE" "$LOCK_FILE"
        log_info "GitHub同步服务已停止"
        return 0
    else
        log_error "无法停止进程 $pid"
        return 1
    fi
}

# 重启守护进程
restart_daemon() {
    log_info "重启GitHub同步服务..."
    stop_daemon
    sleep 2
    start_daemon
}

# 显示服务状态
show_status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        log_info "GitHub同步服务正在运行 (PID: $pid)"

        # 显示进程信息
        if command -v ps >/dev/null 2>&1; then
            ps | grep "$pid" | grep -v grep
        fi

        # 显示最近的日志
        if [ -f "$LOG_FILE" ]; then
            echo ""
            echo "最近的日志:"
            tail -10 "$LOG_FILE"
        fi
    else
        log_info "GitHub同步服务未运行"
    fi
}

# 清理并退出
cleanup_and_exit() {
    log_info "接收到退出信号，正在清理..."
    rm -f "$PID_FILE" "$LOCK_FILE"
    exit 0
}

#==============================================================================
# 安装和配置函数
#==============================================================================

# 检测系统类型
detect_system() {
    if [ -f /etc/openwrt_release ]; then
        echo "openwrt"
    elif command -v opkg >/dev/null 2>&1; then
        echo "openwrt"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

# 安装依赖包
install_dependencies() {
    local system_type=$(detect_system)

    log_info "检测到系统类型: $system_type"

    case "$system_type" in
        "openwrt")
            log_info "OpenWrt系统，检查必要工具..."

            # 检查curl
            if ! command -v curl >/dev/null 2>&1; then
                log_info "安装curl..."
                opkg update && opkg install curl
            fi

            # 检查base64
            if ! command -v base64 >/dev/null 2>&1; then
                log_info "安装coreutils-base64..."
                opkg install coreutils-base64
            fi
            ;;
        "debian")
            log_info "Debian系统，检查必要工具..."
            if ! command -v curl >/dev/null 2>&1; then
                apt-get update && apt-get install -y curl
            fi
            ;;
        *)
            log_warn "未知系统类型，请手动确保curl和base64工具可用"
            ;;
    esac
}

# 创建procd服务文件
create_procd_service() {
    local service_file="/etc/init.d/github-sync"

    cat > "$service_file" << EOF
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG="$SCRIPT_DIR/github-sync.sh"

start_service() {
    procd_open_instance
    procd_set_param command "\$PROG" daemon
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    "\$PROG" stop
}

restart() {
    "\$PROG" restart
}
EOF

    chmod +x "$service_file"
    log_info "已创建procd服务文件: $service_file"
}

# 安装服务
install_service() {
    local system_type=$(detect_system)

    case "$system_type" in
        "openwrt")
            create_procd_service
            /etc/init.d/github-sync enable
            log_info "已安装并启用GitHub同步服务"
            ;;
        *)
            log_warn "非OpenWrt系统，跳过服务安装"
            ;;
    esac
}

# 完整安装
install() {
    log_info "开始安装GitHub同步工具..."

    # 安装依赖
    install_dependencies

    # 创建配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        create_default_config
        log_info "请编辑配置文件: $CONFIG_FILE"
    fi

    # 安装服务
    install_service

    log_info "安装完成！"
    log_info "请编辑配置文件 $CONFIG_FILE 然后运行: $0 start"
}

#==============================================================================
# 命令行界面
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
GitHub File Sync Tool for OpenWrt/Kwrt Systems
专为OpenWrt/Kwrt系统设计的GitHub文件同步工具

用法: $0 [命令] [选项]

命令:
    start           启动同步服务
    stop            停止同步服务
    restart         重启同步服务
    status          显示服务状态
    daemon          以守护进程模式运行（内部使用）
    sync            执行一次性同步
    test            测试配置和GitHub连接
    install         安装工具和服务
    config          编辑配置文件
    logs            显示日志
    help            显示此帮助信息

选项:
    -c, --config FILE    指定配置文件路径
    -v, --verbose        详细输出
    -q, --quiet          静默模式

示例:
    $0 install          # 安装工具
    $0 config           # 编辑配置
    $0 test             # 测试配置
    $0 start            # 启动服务
    $0 status           # 查看状态

配置文件: $CONFIG_FILE
日志文件: $LOG_FILE
EOF
}

# 编辑配置文件
edit_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        create_default_config
    fi

    # 尝试使用可用的编辑器
    for editor in vi nano; do
        if command -v "$editor" >/dev/null 2>&1; then
            "$editor" "$CONFIG_FILE"
            return 0
        fi
    done

    log_error "未找到可用的编辑器，请手动编辑: $CONFIG_FILE"
    return 1
}

# 显示日志
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        if command -v less >/dev/null 2>&1; then
            less "$LOG_FILE"
        else
            cat "$LOG_FILE"
        fi
    else
        log_warn "日志文件不存在: $LOG_FILE"
    fi
}

# 执行一次性同步
run_sync_once() {
    log_info "执行一次性同步..."

    if ! load_config; then
        return 1
    fi

    # 处理所有同步路径
    echo "$SYNC_PATHS" | while IFS='|' read -r local_path repo branch target_path; do
        if [ -n "$local_path" ]; then
            log_info "同步路径: $local_path -> $repo:$branch"
            process_sync_path "$local_path|$repo|$branch|$target_path"
        fi
    done

    log_info "一次性同步完成"
}

# 测试配置
test_config() {
    log_info "测试配置和GitHub连接..."

    if ! load_config; then
        return 1
    fi

    if validate_config; then
        log_info "配置测试通过"
        return 0
    else
        log_error "配置测试失败"
        return 1
    fi
}

#==============================================================================
# 交互式菜单界面
#==============================================================================

# 显示交互式菜单
show_interactive_menu() {
    # 检查是否首次运行
    if [ ! -f "$CONFIG_FILE" ]; then
        clear
        echo "=================================="
        echo "GitHub File Sync Tool"
        echo "GitHub文件同步工具"
        echo "=================================="
        echo ""
        log_info "检测到这是首次运行，未找到配置文件"
        echo ""
        echo "建议选择以下操作之一："
        echo "1) 运行快速设置向导（推荐）"
        echo "2) 手动编辑配置文件"
        echo "3) 查看配置示例"
        echo "4) 进入主菜单"
        echo ""
        echo -n "请选择 [1-4]: "
        read -r first_choice

        case "$first_choice" in
            1)
                clear
                run_setup_wizard
                echo ""
                echo "按任意键进入主菜单..."
                read -r
                ;;
            2)
                clear
                create_default_config
                edit_config
                echo ""
                echo "按任意键进入主菜单..."
                read -r
                ;;
            3)
                clear
                show_config_example
                echo ""
                echo "按任意键进入主菜单..."
                read -r
                ;;
            *)
                # 继续到主菜单
                ;;
        esac
    fi

    while true; do
        clear
        echo "=================================="
        echo "GitHub File Sync Tool"
        echo "GitHub文件同步工具"
        echo "=================================="
        echo ""

        # 显示当前状态
        if is_running; then
            echo -e "${GREEN}● 服务状态: 运行中${NC} (PID: $(cat "$PID_FILE" 2>/dev/null || echo "未知"))"
        else
            echo -e "${RED}● 服务状态: 已停止${NC}"
        fi

        # 显示配置状态
        if [ -f "$CONFIG_FILE" ]; then
            echo -e "${GREEN}● 配置文件: 已存在${NC}"
            # 显示配置的同步路径数量
            if [ -r "$CONFIG_FILE" ]; then
                local path_count=$(grep -c "|" "$CONFIG_FILE" 2>/dev/null || echo "0")
                echo -e "${BLUE}● 同步路径: $path_count 个${NC}"
            fi
        else
            echo -e "${YELLOW}● 配置文件: 未配置${NC}"
        fi

        # 显示最近日志
        if [ -f "$LOG_FILE" ]; then
            local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
            if [ "$log_size" -gt 0 ]; then
                echo -e "${BLUE}● 日志文件: $(($log_size / 1024))KB${NC}"
                # 显示最后一条日志
                local last_log=$(tail -1 "$LOG_FILE" 2>/dev/null | cut -d']' -f3- | sed 's/^ *//')
                if [ -n "$last_log" ]; then
                    echo -e "${BLUE}● 最近日志: $last_log${NC}"
                fi
            fi
        fi

        echo ""
        echo "请选择操作："
        echo ""
        echo "  服务管理:"
        echo "    1) 启动同步服务        [s]"
        echo "    2) 停止同步服务        [x]"
        echo "    3) 重启同步服务        [r]"
        echo "    4) 查看服务状态        [t]"
        echo ""
        echo "  配置管理:"
        echo "    5) 编辑配置文件        [c]"
        echo "    6) 测试配置            [e]"
        echo "    7) 查看配置示例        [v]"
        echo ""
        echo "  同步操作:"
        echo "    8) 执行一次性同步      [y]"
        echo "    9) 查看同步日志        [l]"
        echo ""
        echo "  系统管理:"
        echo "   10) 安装/重新安装工具   [i]"
        echo "   11) 快速设置向导        [w]"
        echo "   12) 查看帮助信息        [h]"
        echo ""
        echo "    0) 退出               [q]"
        echo ""
        echo -n "请输入选项 [0-12] 或快捷键: "

        read -r choice

        case "$choice" in
            1|s|S)
                echo ""
                log_info "启动同步服务..."
                if start_daemon; then
                    echo ""
                    echo "按任意键继续..."
                    read -r
                else
                    echo ""
                    echo "启动失败，按任意键继续..."
                    read -r
                fi
                ;;
            2|x|X)
                echo ""
                log_info "停止同步服务..."
                if stop_daemon; then
                    echo ""
                    echo "按任意键继续..."
                    read -r
                else
                    echo ""
                    echo "停止失败，按任意键继续..."
                    read -r
                fi
                ;;
            3|r|R)
                echo ""
                log_info "重启同步服务..."
                if restart_daemon; then
                    echo ""
                    echo "按任意键继续..."
                    read -r
                else
                    echo ""
                    echo "重启失败，按任意键继续..."
                    read -r
                fi
                ;;
            4|t|T)
                echo ""
                show_status
                echo ""
                echo "按任意键继续..."
                read -r
                ;;
            5|c|C)
                echo ""
                log_info "编辑配置文件..."
                edit_config
                echo ""
                echo "按任意键继续..."
                read -r
                ;;
            6|e|E)
                echo ""
                if test_config; then
                    echo ""
                    echo "配置测试通过，按任意键继续..."
                    read -r
                else
                    echo ""
                    echo "配置测试失败，按任意键继续..."
                    read -r
                fi
                ;;
            7|v|V)
                echo ""
                show_config_example
                echo ""
                echo "按任意键继续..."
                read -r
                ;;
            8|y|Y)
                echo ""
                log_info "执行一次性同步..."
                if run_sync_once; then
                    echo ""
                    echo "同步完成，按任意键继续..."
                    read -r
                else
                    echo ""
                    echo "同步失败，按任意键继续..."
                    read -r
                fi
                ;;
            9|l|L)
                echo ""
                show_logs
                echo ""
                echo "按任意键继续..."
                read -r
                ;;
            10|i|I)
                echo ""
                log_info "安装/重新安装工具..."
                if install; then
                    echo ""
                    echo "安装完成，按任意键继续..."
                    read -r
                else
                    echo ""
                    echo "安装失败，按任意键继续..."
                    read -r
                fi
                ;;
            11|w|W)
                echo ""
                run_setup_wizard
                echo ""
                echo "按任意键继续..."
                read -r
                ;;
            12|h|H)
                echo ""
                show_help
                echo ""
                echo "按任意键继续..."
                read -r
                ;;
            0|q|Q)
                echo ""
                log_info "退出程序"
                exit 0
                ;;
            "")
                # 用户直接按回车，刷新菜单
                continue
                ;;
            *)
                echo ""
                log_error "无效选项: $choice"
                echo "按任意键继续..."
                read -r
                ;;
        esac
    done
}

# 快速设置向导
run_setup_wizard() {
    log_info "欢迎使用GitHub同步工具快速设置向导"
    echo ""

    # 检查是否已有配置文件
    if [ -f "$CONFIG_FILE" ]; then
        echo "检测到现有配置文件: $CONFIG_FILE"
        echo -n "是否要覆盖现有配置？[y/N]: "
        read -r overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            log_info "保留现有配置，退出向导"
            return 0
        fi
    fi

    echo ""
    echo "请按照提示输入配置信息："
    echo ""

    # 获取GitHub用户名
    echo -n "GitHub用户名: "
    read -r github_username
    while [ -z "$github_username" ]; do
        echo "用户名不能为空，请重新输入:"
        echo -n "GitHub用户名: "
        read -r github_username
    done

    # 获取GitHub令牌
    echo ""
    echo "GitHub个人访问令牌 (在 https://github.com/settings/tokens 创建):"
    echo -n "令牌: "
    read -r github_token
    while [ -z "$github_token" ]; do
        echo "令牌不能为空，请重新输入:"
        echo -n "令牌: "
        read -r github_token
    done

    # 获取轮询间隔
    echo ""
    echo -n "文件监控轮询间隔（秒，默认30）: "
    read -r poll_interval
    poll_interval=${poll_interval:-30}

    # 获取日志级别
    echo ""
    echo "日志级别选择:"
    echo "1) DEBUG - 详细调试信息"
    echo "2) INFO  - 一般信息（推荐）"
    echo "3) WARN  - 警告信息"
    echo "4) ERROR - 仅错误信息"
    echo -n "请选择 [1-4，默认2]: "
    read -r log_level_choice

    case "$log_level_choice" in
        1) log_level="DEBUG" ;;
        3) log_level="WARN" ;;
        4) log_level="ERROR" ;;
        *) log_level="INFO" ;;
    esac

    # 获取同步路径
    echo ""
    echo "配置同步路径（可以稍后在配置文件中修改）:"
    echo "格式: 本地路径|GitHub仓库|分支|目标路径"
    echo "示例: /etc/config|$github_username/openwrt-config|main|config"
    echo ""

    sync_paths=""
    path_count=1

    while true; do
        echo "同步路径 $path_count:"
        echo -n "本地路径 (留空结束): "
        read -r local_path

        if [ -z "$local_path" ]; then
            break
        fi

        echo -n "GitHub仓库 ($github_username/): "
        read -r repo_name
        if [ -z "$repo_name" ]; then
            repo_name="openwrt-config"
        fi

        echo -n "分支 (默认main): "
        read -r branch
        branch=${branch:-main}

        echo -n "目标路径 (可留空): "
        read -r target_path

        # 添加到同步路径
        if [ -z "$sync_paths" ]; then
            sync_paths="$local_path|$github_username/$repo_name|$branch|$target_path"
        else
            sync_paths="$sync_paths
$local_path|$github_username/$repo_name|$branch|$target_path"
        fi

        path_count=$((path_count + 1))
        echo ""
    done

    if [ -z "$sync_paths" ]; then
        # 提供默认配置
        sync_paths="/etc/config|$github_username/openwrt-config|main|config"
        log_warn "未配置同步路径，使用默认配置: $sync_paths"
    fi

    # 创建配置文件
    echo ""
    log_info "创建配置文件..."

    cat > "$CONFIG_FILE" << EOF
# GitHub Sync Tool Configuration
# 由快速设置向导生成

# GitHub配置
GITHUB_USERNAME="$github_username"
GITHUB_TOKEN="$github_token"

# 监控配置
POLL_INTERVAL=$poll_interval
LOG_LEVEL="$log_level"

# 同步路径配置
SYNC_PATHS="$sync_paths"

# 文件过滤
EXCLUDE_PATTERNS="*.tmp *.log *.pid *.lock .git *.swp *~ .DS_Store"

# 高级选项
AUTO_COMMIT=true
COMMIT_MESSAGE_TEMPLATE="Auto sync from OpenWrt: %s"
MAX_FILE_SIZE=1048576
EOF

    log_success "配置文件创建成功: $CONFIG_FILE"

    # 测试配置
    echo ""
    log_info "测试配置..."
    if test_config; then
        log_success "配置测试通过！"

        echo ""
        echo -n "是否现在启动同步服务？[Y/n]: "
        read -r start_service
        if [ "$start_service" != "n" ] && [ "$start_service" != "N" ]; then
            echo ""
            if start_daemon; then
                log_success "同步服务启动成功！"
            else
                log_error "同步服务启动失败，请检查配置"
            fi
        fi
    else
        log_error "配置测试失败，请检查GitHub用户名和令牌"
    fi

    echo ""
    log_info "快速设置向导完成"
}

# 显示配置示例
show_config_example() {
    cat << 'EOF'
配置文件示例 (github-sync.conf):

# GitHub配置
GITHUB_USERNAME="your-username"
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 监控配置
POLL_INTERVAL=30
LOG_LEVEL="INFO"

# 同步路径配置 (格式: 本地路径|GitHub仓库|分支|目标路径)
SYNC_PATHS="
/etc/config|your-username/openwrt-config|main|config
/root/scripts|your-username/scripts|main|scripts
/etc/firewall.user|your-username/openwrt-config|main|firewall.user
"

# 排除文件模式
EXCLUDE_PATTERNS="*.tmp *.log *.pid *.lock .git"

# 高级选项
AUTO_COMMIT=true
COMMIT_MESSAGE_TEMPLATE="Auto sync from OpenWrt: %s"
MAX_FILE_SIZE=1048576

更多配置选项请参考 github-sync.conf.example 文件
EOF
}

#==============================================================================
# 主程序入口
#==============================================================================

main() {
    # 解析命令行参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                LOG_LEVEL="DEBUG"
                shift
                ;;
            -q|--quiet)
                LOG_LEVEL="ERROR"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            start)
                start_daemon
                exit $?
                ;;
            stop)
                stop_daemon
                exit $?
                ;;
            restart)
                restart_daemon
                exit $?
                ;;
            status)
                show_status
                exit $?
                ;;
            daemon)
                # 内部使用，直接运行监控循环
                load_config && monitor_loop
                exit $?
                ;;
            sync)
                run_sync_once
                exit $?
                ;;
            test)
                test_config
                exit $?
                ;;
            install)
                install
                exit $?
                ;;
            config)
                edit_config
                exit $?
                ;;
            logs)
                show_logs
                exit $?
                ;;
            help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知命令: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 如果没有指定命令，显示交互式菜单
    show_interactive_menu
}

# 确保脚本可执行
chmod +x "$0" 2>/dev/null || true

# 运行主程序
main "$@"
