#!/bin/bash

# 工具函数模块
# 提供通用的工具函数和辅助功能

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 获取当前时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 获取脚本根目录
get_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(dirname "$script_dir")"
}

# 确保目录存在
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查必需的依赖
check_dependencies() {
    local missing_deps=()
    
    # 检查必需的命令
    local required_commands=("git" "curl" "jq" "inotifywait")
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必需的依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖："
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "inotifywait")
                    log_info "  - Ubuntu/Debian: sudo apt-get install inotify-tools"
                    log_info "  - CentOS/RHEL: sudo yum install inotify-tools"
                    ;;
                "jq")
                    log_info "  - Ubuntu/Debian: sudo apt-get install jq"
                    log_info "  - CentOS/RHEL: sudo yum install jq"
                    ;;
                *)
                    log_info "  - $dep: 请使用系统包管理器安装"
                    ;;
            esac
        done
        return 1
    fi
    
    return 0
}

# 获取文件的相对路径
get_relative_path() {
    local file_path="$1"
    local base_path="$2"
    
    # 使用realpath获取绝对路径，然后计算相对路径
    if command_exists realpath; then
        local abs_file=$(realpath "$file_path")
        local abs_base=$(realpath "$base_path")
        echo "${abs_file#$abs_base/}"
    else
        # 简单的相对路径计算
        echo "${file_path#$base_path/}"
    fi
}

# URL编码
url_encode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o
    
    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * ) printf -v o '%%%02x' "'$c" ;;
        esac
        encoded+="${o}"
    done
    
    echo "${encoded}"
}

# 检查文件是否应该被排除
should_exclude_file() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    # 检查全局排除模式
    if [[ -n "$EXCLUDE_PATTERNS" ]]; then
        for pattern in $EXCLUDE_PATTERNS; do
            if [[ "$filename" == $pattern ]]; then
                return 0  # 应该排除
            fi
        done
    fi
    
    # 检查隐藏文件
    if [[ "$filename" =~ ^\. ]]; then
        return 0  # 排除隐藏文件
    fi
    
    return 1  # 不排除
}

# 获取文件MIME类型
get_mime_type() {
    local file_path="$1"
    
    if command_exists file; then
        file -b --mime-type "$file_path"
    else
        echo "application/octet-stream"
    fi
}

# 检查文件是否为二进制文件
is_binary_file() {
    local file_path="$1"
    local mime_type=$(get_mime_type "$file_path")
    
    case "$mime_type" in
        text/*|application/json|application/xml|application/javascript)
            return 1  # 不是二进制文件
            ;;
        *)
            return 0  # 是二进制文件
            ;;
    esac
}

# 生成随机字符串
generate_random_string() {
    local length="${1:-8}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# 获取文件大小（字节）
get_file_size() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# 格式化文件大小
format_file_size() {
    local size="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit_index=0
    
    while [[ $size -gt 1024 && $unit_index -lt $((${#units[@]} - 1)) ]]; do
        size=$((size / 1024))
        ((unit_index++))
    done
    
    echo "${size}${units[$unit_index]}"
}

# 创建备份文件
create_backup() {
    local file_path="$1"
    local backup_dir="${2:-$(dirname "$file_path")}"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename=$(basename "$file_path")
    local backup_path="$backup_dir/${filename}.backup.$timestamp"
    
    if [[ -f "$file_path" ]]; then
        cp "$file_path" "$backup_path"
        echo "$backup_path"
    fi
}

# 验证JSON格式
validate_json() {
    local json_string="$1"
    echo "$json_string" | jq . >/dev/null 2>&1
}

# 安全地读取用户输入
read_secure() {
    local prompt="$1"
    local var_name="$2"
    local is_password="${3:-false}"
    
    if [[ "$is_password" == "true" ]]; then
        read -s -p "$prompt" "$var_name"
        echo  # 换行
    else
        read -p "$prompt" "$var_name"
    fi
}

# 确认操作
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    local response
    
    if [[ "$default" == "y" ]]; then
        read -p "$message [Y/n]: " response
        response=${response:-y}
    else
        read -p "$message [y/N]: " response
        response=${response:-n}
    fi
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 重试执行函数
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local command=("$@")

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "${command[@]}"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "命令执行失败，${delay}秒后重试 (尝试 $attempt/$max_attempts)"
            sleep "$delay"
        fi

        ((attempt++))
    done

    log_error "命令执行失败，已达到最大重试次数 ($max_attempts)"
    return 1
}

# 错误处理函数
handle_error() {
    local exit_code="$1"
    local line_number="$2"
    local function_name="${3:-unknown}"
    local error_message="${4:-未知错误}"

    log_error "错误发生在函数 $function_name, 行号 $line_number: $error_message (退出码: $exit_code)"

    # 记录调用栈
    log_error "调用栈:"
    local frame=0
    while caller $frame; do
        ((frame++))
    done | while read line func file; do
        log_error "  在 $file:$line 的函数 $func"
    done

    # 根据错误类型执行不同的处理
    case $exit_code in
        1)
            log_error "一般错误，继续执行"
            ;;
        2)
            log_error "配置错误，请检查配置文件"
            ;;
        3)
            log_error "网络错误，请检查网络连接"
            ;;
        4)
            log_error "权限错误，请检查文件权限"
            ;;
        *)
            log_error "未知错误类型"
            ;;
    esac
}

# 设置错误陷阱
set_error_trap() {
    set -eE  # 启用错误退出和ERR陷阱继承
    trap 'handle_error $? $LINENO "${FUNCNAME[1]}" "脚本执行失败"' ERR
}

# 清除错误陷阱
clear_error_trap() {
    set +eE
    trap - ERR
}

# 安全执行函数
safe_execute() {
    local description="$1"
    shift
    local command=("$@")

    log_debug "执行: $description"

    if "${command[@]}"; then
        log_debug "成功: $description"
        return 0
    else
        local exit_code=$?
        log_error "失败: $description (退出码: $exit_code)"
        return $exit_code
    fi
}

# 检查磁盘空间
check_disk_space() {
    local path="$1"
    local min_space_mb="${2:-100}"  # 默认最小100MB

    local available_space
    if command_exists df; then
        available_space=$(df -m "$path" | awk 'NR==2 {print $4}')

        if [[ $available_space -lt $min_space_mb ]]; then
            log_error "磁盘空间不足: $path 只有 ${available_space}MB 可用空间"
            return 1
        fi
    fi

    return 0
}

# 检查网络连接
check_network_connectivity() {
    local host="${1:-github.com}"
    local timeout="${2:-10}"

    if command_exists ping; then
        if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
            return 0
        else
            log_error "网络连接失败: 无法连接到 $host"
            return 1
        fi
    elif command_exists curl; then
        if curl -s --connect-timeout "$timeout" "https://$host" >/dev/null 2>&1; then
            return 0
        else
            log_error "网络连接失败: 无法连接到 $host"
            return 1
        fi
    else
        log_warn "无法检查网络连接: 缺少ping或curl命令"
        return 0
    fi
}

# 系统健康检查
system_health_check() {
    log_info "执行系统健康检查..."

    local errors=0

    # 检查依赖
    if ! check_dependencies; then
        ((errors++))
    fi

    # 检查磁盘空间
    if ! check_disk_space "$PROJECT_ROOT" 100; then
        ((errors++))
    fi

    # 检查网络连接
    if ! check_network_connectivity "api.github.com"; then
        ((errors++))
    fi

    # 检查配置文件
    if [[ ! -f "$PROJECT_ROOT/config/global.conf" ]]; then
        log_error "全局配置文件不存在"
        ((errors++))
    fi

    if [[ ! -f "$PROJECT_ROOT/config/paths.conf" ]]; then
        log_error "路径配置文件不存在"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        log_info "系统健康检查通过"
        return 0
    else
        log_error "系统健康检查失败，发现 $errors 个问题"
        return 1
    fi
}
