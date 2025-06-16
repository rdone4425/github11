#!/bin/bash

# 文件监控模块
# 使用inotify实现实时文件监控功能

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载依赖模块
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/config.sh"

# 监控事件类型
declare -A INOTIFY_EVENTS=(
    ["CREATE"]="create"
    ["MODIFY"]="modify" 
    ["DELETE"]="delete"
    ["MOVE"]="move"
)

# 事件队列文件
EVENT_QUEUE_FILE="$PROJECT_ROOT/logs/event_queue.tmp"

# 监控进程PID文件
MONITOR_PID_FILE="$PROJECT_ROOT/logs/monitor.pid"

# 初始化监控系统
init_monitor() {
    log_function_start "init_monitor"
    
    # 检查inotify工具
    if ! command_exists inotifywait; then
        log_error "inotifywait 命令不存在，请安装 inotify-tools"
        return 1
    fi
    
    # 创建必要的目录和文件
    ensure_dir "$(dirname "$EVENT_QUEUE_FILE")"
    touch "$EVENT_QUEUE_FILE"
    
    log_info "文件监控系统初始化完成"
    log_function_end "init_monitor"
    return 0
}

# 启动文件监控
start_monitoring() {
    log_function_start "start_monitoring"
    
    # 检查是否已有监控进程在运行
    if is_monitor_running; then
        log_warn "监控进程已在运行"
        return 1
    fi
    
    # 获取启用的监控路径
    local enabled_paths
    mapfile -t enabled_paths < <(get_enabled_paths)
    
    if [[ ${#enabled_paths[@]} -eq 0 ]]; then
        log_error "没有启用的监控路径"
        return 1
    fi
    
    log_info "开始监控 ${#enabled_paths[@]} 个路径"
    
    # 为每个路径启动监控
    for path_id in "${enabled_paths[@]}"; do
        start_path_monitoring "$path_id" &
    done
    
    # 记录主监控进程PID
    echo $$ > "$MONITOR_PID_FILE"
    
    # 启动事件处理器
    start_event_processor &
    
    log_info "文件监控已启动"
    log_function_end "start_monitoring"
    return 0
}

# 停止文件监控
stop_monitoring() {
    log_function_start "stop_monitoring"
    
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local main_pid=$(cat "$MONITOR_PID_FILE")
        
        # 停止所有相关进程
        pkill -P "$main_pid" 2>/dev/null
        kill "$main_pid" 2>/dev/null
        
        # 清理PID文件
        rm -f "$MONITOR_PID_FILE"
        
        log_info "文件监控已停止"
    else
        log_warn "监控进程未运行"
    fi
    
    log_function_end "stop_monitoring"
    return 0
}

# 检查监控进程是否运行
is_monitor_running() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # PID文件存在但进程不存在，清理PID文件
            rm -f "$MONITOR_PID_FILE"
        fi
    fi
    return 1
}

# 为指定路径启动监控
start_path_monitoring() {
    local path_id="$1"
    local local_path=$(get_path_config "$path_id" "LOCAL_PATH")
    local watch_subdirs=$(get_path_config "$path_id" "WATCH_SUBDIRS" "true")
    local exclude_patterns=$(get_path_config "$path_id" "EXCLUDE_PATTERNS")
    
    if [[ ! -d "$local_path" ]]; then
        log_error "监控路径不存在: $local_path"
        return 1
    fi
    
    log_info "开始监控路径: $path_id -> $local_path"
    
    # 构建inotifywait参数
    local inotify_args=("-m" "-e" "create,modify,delete,move")
    
    # 是否递归监控子目录
    if [[ "$watch_subdirs" == "true" ]]; then
        inotify_args+=("-r")
    fi
    
    # 添加排除模式
    if [[ -n "$exclude_patterns" ]]; then
        for pattern in $exclude_patterns; do
            inotify_args+=("--exclude" "$pattern")
        done
    fi
    
    # 添加全局排除模式
    if [[ -n "$EXCLUDE_PATTERNS" ]]; then
        for pattern in $EXCLUDE_PATTERNS; do
            inotify_args+=("--exclude" "$pattern")
        done
    fi
    
    # 添加监控路径
    inotify_args+=("$local_path")
    
    # 启动inotifywait并处理事件
    inotifywait "${inotify_args[@]}" --format '%w%f|%e|%T' --timefmt '%Y-%m-%d %H:%M:%S' | \
    while IFS='|' read -r file_path event_type timestamp; do
        process_file_event "$path_id" "$file_path" "$event_type" "$timestamp"
    done
}

# 处理文件事件
process_file_event() {
    local path_id="$1"
    local file_path="$2"
    local event_type="$3"
    local timestamp="$4"
    
    # 检查文件是否应该被排除
    if should_exclude_file "$file_path"; then
        log_debug "跳过排除的文件: $file_path"
        return 0
    fi
    
    # 标准化事件类型
    local normalized_event=$(normalize_event_type "$event_type")
    
    log_debug "文件事件: $normalized_event - $file_path"
    
    # 将事件添加到队列
    add_event_to_queue "$path_id" "$file_path" "$normalized_event" "$timestamp"
}

# 标准化事件类型
normalize_event_type() {
    local event_type="$1"
    
    case "$event_type" in
        *CREATE*|*MOVED_TO*)
            echo "create"
            ;;
        *MODIFY*)
            echo "modify"
            ;;
        *DELETE*|*MOVED_FROM*)
            echo "delete"
            ;;
        *MOVE*)
            echo "move"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 将事件添加到队列
add_event_to_queue() {
    local path_id="$1"
    local file_path="$2"
    local event_type="$3"
    local timestamp="$4"
    
    # 创建事件记录
    local event_record="${timestamp}|${path_id}|${event_type}|${file_path}"
    
    # 使用文件锁确保线程安全
    (
        flock -x 200
        echo "$event_record" >> "$EVENT_QUEUE_FILE"
    ) 200>"$EVENT_QUEUE_FILE.lock"
    
    log_debug "事件已加入队列: $event_record"
}

# 启动事件处理器
start_event_processor() {
    log_info "启动事件处理器"
    
    while true; do
        process_event_queue
        sleep "${SYNC_INTERVAL:-5}"
    done
}

# 处理事件队列
process_event_queue() {
    if [[ ! -f "$EVENT_QUEUE_FILE" ]] || [[ ! -s "$EVENT_QUEUE_FILE" ]]; then
        return 0
    fi
    
    local temp_file="${EVENT_QUEUE_FILE}.processing"
    
    # 原子性地移动队列文件
    (
        flock -x 200
        if [[ -s "$EVENT_QUEUE_FILE" ]]; then
            mv "$EVENT_QUEUE_FILE" "$temp_file"
            touch "$EVENT_QUEUE_FILE"
        fi
    ) 200>"$EVENT_QUEUE_FILE.lock"
    
    if [[ ! -f "$temp_file" ]]; then
        return 0
    fi
    
    log_info "处理事件队列，共 $(wc -l < "$temp_file") 个事件"
    
    # 按路径分组处理事件
    local -A path_events
    while IFS='|' read -r timestamp path_id event_type file_path; do
        local key="$path_id"
        path_events["$key"]+="$timestamp|$event_type|$file_path"$'\n'
    done < "$temp_file"
    
    # 处理每个路径的事件
    for path_id in "${!path_events[@]}"; do
        process_path_events "$path_id" "${path_events[$path_id]}"
    done
    
    # 清理临时文件
    rm -f "$temp_file"
}

# 处理特定路径的事件
process_path_events() {
    local path_id="$1"
    local events="$2"
    
    log_debug "处理路径 $path_id 的事件"
    
    # 加载GitHub同步模块
    source "$SCRIPT_DIR/github.sh"
    
    # 去重和合并事件
    local -A unique_files
    while IFS='|' read -r timestamp event_type file_path; do
        [[ -z "$file_path" ]] && continue
        unique_files["$file_path"]="$event_type"
    done <<< "$events"
    
    # 同步文件到GitHub
    for file_path in "${!unique_files[@]}"; do
        local event_type="${unique_files[$file_path]}"
        sync_file_to_github "$path_id" "$file_path" "$event_type"
    done
}

# 获取监控状态
get_monitor_status() {
    if is_monitor_running; then
        local pid=$(cat "$MONITOR_PID_FILE")
        echo "监控状态: 运行中 (PID: $pid)"
        
        # 显示监控的路径
        local enabled_paths
        mapfile -t enabled_paths < <(get_enabled_paths)
        echo "监控路径数量: ${#enabled_paths[@]}"
        
        for path_id in "${enabled_paths[@]}"; do
            local local_path=$(get_path_config "$path_id" "LOCAL_PATH")
            local github_repo=$(get_path_config "$path_id" "GITHUB_REPO")
            echo "  - $path_id: $local_path -> $github_repo"
        done
    else
        echo "监控状态: 未运行"
    fi
}

# 重启监控
restart_monitoring() {
    log_info "重启文件监控"
    stop_monitoring
    sleep 2
    start_monitoring
}
