#!/bin/bash

# 配置管理模块
# 负责处理全局配置和路径配置的读取、验证和管理

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 配置文件路径
GLOBAL_CONFIG="$PROJECT_ROOT/config/global.conf"
PATHS_CONFIG="$PROJECT_ROOT/config/paths.conf"

# 加载工具函数
source "$SCRIPT_DIR/utils.sh"

# 创建默认全局配置文件
create_global_config() {
    local config_file="$1"
    
    cat > "$config_file" << 'EOF'
# GitHub文件同步系统 - 全局配置文件
# 
# GitHub用户名
GITHUB_USERNAME=""

# GitHub访问令牌 (Personal Access Token)
# 需要具有repo权限的token
GITHUB_TOKEN=""

# 默认分支名称
DEFAULT_BRANCH="main"

# 同步间隔（秒）- 批量处理文件变化的间隔
SYNC_INTERVAL=5

# 日志级别 (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL="INFO"

# 最大重试次数
MAX_RETRIES=3

# 排除的文件模式（用空格分隔）
EXCLUDE_PATTERNS="*.tmp *.log *.swp .git .DS_Store"

# 是否启用详细输出
VERBOSE=false
EOF
    
    log_info "已创建全局配置文件模板: $config_file"
    log_info "请编辑配置文件并填入您的GitHub凭据"
}

# 创建默认路径配置文件
create_paths_config() {
    local config_file="$1"
    
    cat > "$config_file" << 'EOF'
# GitHub文件同步系统 - 监控路径配置文件
#
# 配置格式：
# [路径标识符]
# LOCAL_PATH=/path/to/local/directory
# GITHUB_REPO=username/repository
# TARGET_BRANCH=main
# SUBDIR_MAPPING=optional/subdirectory
# ENABLED=true
#
# 示例配置：

[documents]
LOCAL_PATH=/home/user/documents
GITHUB_REPO=myuser/my-documents
TARGET_BRANCH=main
SUBDIR_MAPPING=
ENABLED=true

[projects]
LOCAL_PATH=/home/user/projects
GITHUB_REPO=myuser/my-projects
TARGET_BRANCH=develop
SUBDIR_MAPPING=src
ENABLED=true

[backup]
LOCAL_PATH=/home/user/backup
GITHUB_REPO=myuser/backup-repo
TARGET_BRANCH=main
SUBDIR_MAPPING=daily
ENABLED=false
EOF
    
    log_info "已创建路径配置文件模板: $config_file"
    log_info "请根据需要修改监控路径配置"
}

# 验证全局配置
validate_global_config() {
    local config_file="$GLOBAL_CONFIG"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "全局配置文件不存在: $config_file"
        return 1
    fi
    
    source "$config_file"
    
    # 检查必需的配置项
    if [[ -z "$GITHUB_USERNAME" ]]; then
        log_error "GITHUB_USERNAME 未配置"
        return 1
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "GITHUB_TOKEN 未配置"
        return 1
    fi
    
    # 验证GitHub凭据
    if ! validate_github_credentials; then
        log_error "GitHub凭据验证失败"
        return 1
    fi
    
    log_info "全局配置验证通过"
    return 0
}

# 验证GitHub凭据
validate_github_credentials() {
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3+json" \
                   "https://api.github.com/user")
    
    if echo "$response" | jq -e '.login' > /dev/null 2>&1; then
        local username
        username=$(echo "$response" | jq -r '.login')
        if [[ "$username" == "$GITHUB_USERNAME" ]]; then
            return 0
        else
            log_error "GitHub用户名不匹配: 配置为 $GITHUB_USERNAME, 实际为 $username"
            return 1
        fi
    else
        log_error "GitHub API访问失败，请检查token是否有效"
        return 1
    fi
}

# 加载全局配置
load_global_config() {
    if [[ ! -f "$GLOBAL_CONFIG" ]]; then
        log_warn "全局配置文件不存在，创建默认配置"
        create_global_config "$GLOBAL_CONFIG"
        return 1
    fi
    
    source "$GLOBAL_CONFIG"
    return 0
}

# 解析路径配置文件
parse_paths_config() {
    local config_file="$PATHS_CONFIG"
    local current_section=""
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "路径配置文件不存在，创建默认配置"
        create_paths_config "$config_file"
        return 1
    fi
    
    # 清空现有的路径配置数组
    unset MONITOR_PATHS
    declare -gA MONITOR_PATHS
    
    while IFS= read -r line; do
        # 跳过空行和注释
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # 检查是否是节标题
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # 解析配置项
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]] && [[ -n "$current_section" ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            MONITOR_PATHS["${current_section}.${key}"]="$value"
        fi
    done < "$config_file"
    
    return 0
}

# 获取启用的监控路径
get_enabled_paths() {
    local -a enabled_paths=()
    local sections=()
    
    # 获取所有节名称
    for key in "${!MONITOR_PATHS[@]}"; do
        local section="${key%%.*}"
        if [[ ! " ${sections[*]} " =~ " ${section} " ]]; then
            sections+=("$section")
        fi
    done
    
    # 检查每个节是否启用
    for section in "${sections[@]}"; do
        local enabled="${MONITOR_PATHS["${section}.ENABLED"]:-true}"
        if [[ "$enabled" == "true" ]]; then
            enabled_paths+=("$section")
        fi
    done
    
    printf '%s\n' "${enabled_paths[@]}"
}

# 获取路径配置值
get_path_config() {
    local section="$1"
    local key="$2"
    local default_value="$3"
    
    local config_key="${section}.${key}"
    echo "${MONITOR_PATHS[$config_key]:-$default_value}"
}

# 初始化配置
init_config() {
    # 确保配置目录存在
    mkdir -p "$(dirname "$GLOBAL_CONFIG")"
    mkdir -p "$(dirname "$PATHS_CONFIG")"
    
    # 加载配置
    load_global_config
    parse_paths_config
    
    log_info "配置系统初始化完成"
}
