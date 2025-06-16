#!/bin/bash

# 日志记录模块
# 提供统一的日志记录功能

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 日志配置
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/file-sync.log"
ERROR_LOG_FILE="$LOG_DIR/error.log"

# 日志级别
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
)

# 当前日志级别（默认为INFO）
CURRENT_LOG_LEVEL="${LOG_LEVEL:-INFO}"

# 颜色定义
declare -A LOG_COLORS=(
    ["DEBUG"]="$CYAN"
    ["INFO"]="$GREEN"
    ["WARN"]="$YELLOW"
    ["ERROR"]="$RED"
)

# 初始化日志系统
init_logger() {
    # 确保日志目录存在
    mkdir -p "$LOG_DIR"
    
    # 设置日志文件权限
    touch "$LOG_FILE" "$ERROR_LOG_FILE"
    chmod 644 "$LOG_FILE" "$ERROR_LOG_FILE"
    
    # 日志轮转（保留最近7天的日志）
    rotate_logs
}

# 日志轮转
rotate_logs() {
    local max_days=7
    
    # 查找并删除超过指定天数的日志文件
    find "$LOG_DIR" -name "*.log.*" -type f -mtime +$max_days -delete 2>/dev/null
    
    # 如果当前日志文件过大（超过10MB），进行轮转
    if [[ -f "$LOG_FILE" ]]; then
        local file_size=$(get_file_size "$LOG_FILE")
        if [[ $file_size -gt 10485760 ]]; then  # 10MB
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            mv "$LOG_FILE" "${LOG_FILE}.${timestamp}"
            touch "$LOG_FILE"
        fi
    fi
}

# 检查日志级别
should_log() {
    local level="$1"
    local current_level_num=${LOG_LEVELS[$CURRENT_LOG_LEVEL]}
    local message_level_num=${LOG_LEVELS[$level]}
    
    [[ $message_level_num -ge $current_level_num ]]
}

# 格式化日志消息
format_log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)
    local pid=$$
    
    echo "[$timestamp] [$level] [PID:$pid] $message"
}

# 写入日志文件
write_to_log_file() {
    local level="$1"
    local message="$2"
    local formatted_message=$(format_log_message "$level" "$message")
    
    # 写入主日志文件
    echo "$formatted_message" >> "$LOG_FILE"
    
    # 错误级别的消息同时写入错误日志
    if [[ "$level" == "ERROR" ]]; then
        echo "$formatted_message" >> "$ERROR_LOG_FILE"
    fi
}

# 输出到控制台
output_to_console() {
    local level="$1"
    local message="$2"
    local color="${LOG_COLORS[$level]}"
    local timestamp=$(get_timestamp)
    
    if [[ "$VERBOSE" == "true" ]] || [[ "$level" == "ERROR" ]] || [[ "$level" == "WARN" ]]; then
        echo -e "${color}[$timestamp] [$level]${NC} $message" >&2
    fi
}

# 通用日志函数
log_message() {
    local level="$1"
    local message="$2"
    
    # 检查是否应该记录此级别的日志
    if ! should_log "$level"; then
        return 0
    fi
    
    # 写入日志文件
    write_to_log_file "$level" "$message"
    
    # 输出到控制台
    output_to_console "$level" "$message"
}

# 具体的日志函数
log_debug() {
    log_message "DEBUG" "$1"
}

log_info() {
    log_message "INFO" "$1"
}

log_warn() {
    log_message "WARN" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

# 记录函数执行
log_function_start() {
    local function_name="$1"
    log_debug "开始执行函数: $function_name"
}

log_function_end() {
    local function_name="$1"
    local exit_code="${2:-0}"
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "函数执行完成: $function_name"
    else
        log_error "函数执行失败: $function_name (退出码: $exit_code)"
    fi
}

# 记录文件操作
log_file_operation() {
    local operation="$1"
    local file_path="$2"
    local result="${3:-success}"
    
    if [[ "$result" == "success" ]]; then
        log_info "文件操作成功: $operation - $file_path"
    else
        log_error "文件操作失败: $operation - $file_path - $result"
    fi
}

# 记录GitHub操作
log_github_operation() {
    local operation="$1"
    local repo="$2"
    local file_path="$3"
    local result="${4:-success}"
    
    if [[ "$result" == "success" ]]; then
        log_info "GitHub操作成功: $operation - $repo/$file_path"
    else
        log_error "GitHub操作失败: $operation - $repo/$file_path - $result"
    fi
}

# 记录系统事件
log_system_event() {
    local event="$1"
    local details="$2"
    
    log_info "系统事件: $event - $details"
}

# 记录性能指标
log_performance() {
    local operation="$1"
    local duration="$2"
    local details="${3:-}"
    
    log_info "性能指标: $operation 耗时 ${duration}秒 $details"
}

# 获取日志统计信息
get_log_stats() {
    local log_file="${1:-$LOG_FILE}"
    
    if [[ ! -f "$log_file" ]]; then
        echo "日志文件不存在: $log_file"
        return 1
    fi
    
    local total_lines=$(wc -l < "$log_file")
    local error_count=$(grep -c "\[ERROR\]" "$log_file" 2>/dev/null || echo "0")
    local warn_count=$(grep -c "\[WARN\]" "$log_file" 2>/dev/null || echo "0")
    local info_count=$(grep -c "\[INFO\]" "$log_file" 2>/dev/null || echo "0")
    local debug_count=$(grep -c "\[DEBUG\]" "$log_file" 2>/dev/null || echo "0")
    
    echo "日志统计信息 ($log_file):"
    echo "  总行数: $total_lines"
    echo "  错误: $error_count"
    echo "  警告: $warn_count"
    echo "  信息: $info_count"
    echo "  调试: $debug_count"
}

# 清理旧日志
cleanup_logs() {
    local days="${1:-30}"
    
    log_info "清理 $days 天前的日志文件"
    
    find "$LOG_DIR" -name "*.log.*" -type f -mtime +$days -delete 2>/dev/null
    
    log_info "日志清理完成"
}

# 导出日志
export_logs() {
    local start_date="$1"
    local end_date="$2"
    local output_file="$3"
    
    if [[ -z "$start_date" || -z "$end_date" || -z "$output_file" ]]; then
        log_error "导出日志需要指定开始日期、结束日期和输出文件"
        return 1
    fi
    
    log_info "导出日志: $start_date 到 $end_date"
    
    # 使用awk过滤日期范围内的日志
    awk -v start="$start_date" -v end="$end_date" '
        $0 ~ /^\[/ {
            date_str = substr($0, 2, 19)
            if (date_str >= start && date_str <= end) {
                print $0
            }
        }
    ' "$LOG_FILE" > "$output_file"
    
    log_info "日志导出完成: $output_file"
}

# 监控日志文件
monitor_logs() {
    local follow="${1:-false}"
    
    if [[ "$follow" == "true" ]]; then
        tail -f "$LOG_FILE"
    else
        tail -n 50 "$LOG_FILE"
    fi
}
