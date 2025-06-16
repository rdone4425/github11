#!/bin/bash

# GitHub同步模块
# 集成GitHub API，实现文件上传、仓库操作和分支管理功能

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载依赖模块
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/config.sh"

# GitHub API配置
GITHUB_API_BASE="${GITHUB_API_URL:-https://api.github.com}"

# 初始化GitHub同步模块
init_github() {
    log_function_start "init_github"
    
    # 验证GitHub配置
    if ! validate_github_credentials; then
        log_error "GitHub凭据验证失败"
        return 1
    fi
    
    log_info "GitHub同步模块初始化完成"
    log_function_end "init_github"
    return 0
}

# 同步文件到GitHub
sync_file_to_github() {
    local path_id="$1"
    local file_path="$2"
    local event_type="$3"
    
    log_function_start "sync_file_to_github"
    
    # 获取路径配置
    local local_path=$(get_path_config "$path_id" "LOCAL_PATH")
    local github_repo=$(get_path_config "$path_id" "GITHUB_REPO")
    local target_branch=$(get_path_config "$path_id" "TARGET_BRANCH" "$DEFAULT_BRANCH")
    local subdir_mapping=$(get_path_config "$path_id" "SUBDIR_MAPPING")
    
    # 计算相对路径
    local relative_path=$(get_relative_path "$file_path" "$local_path")
    
    # 应用子目录映射
    local github_path="$relative_path"
    if [[ -n "$subdir_mapping" ]]; then
        github_path="$subdir_mapping/$relative_path"
    fi
    
    log_info "同步文件: $event_type - $file_path -> $github_repo/$github_path"
    
    case "$event_type" in
        "create"|"modify")
            upload_file_to_github "$github_repo" "$github_path" "$file_path" "$target_branch"
            ;;
        "delete")
            delete_file_from_github "$github_repo" "$github_path" "$target_branch"
            ;;
        *)
            log_warn "未知的事件类型: $event_type"
            ;;
    esac
    
    log_function_end "sync_file_to_github"
}

# 上传文件到GitHub
upload_file_to_github() {
    local repo="$1"
    local github_path="$2"
    local local_file="$3"
    local branch="$4"
    
    log_function_start "upload_file_to_github"
    
    # 检查文件是否存在
    if [[ ! -f "$local_file" ]]; then
        log_error "本地文件不存在: $local_file"
        return 1
    fi
    
    # 检查文件大小
    local file_size=$(get_file_size "$local_file")
    if [[ $file_size -gt ${MAX_FILE_SIZE:-104857600} ]]; then
        log_error "文件过大，超过GitHub限制: $local_file ($(format_file_size $file_size))"
        return 1
    fi
    
    # 获取文件内容（Base64编码）
    local file_content
    if is_binary_file "$local_file"; then
        file_content=$(base64 -w 0 "$local_file")
    else
        file_content=$(base64 -w 0 "$local_file")
    fi
    
    # 获取现有文件的SHA（如果存在）
    local existing_sha
    existing_sha=$(get_file_sha "$repo" "$github_path" "$branch")
    
    # 构建API请求数据
    local api_data
    api_data=$(jq -n \
        --arg message "$(printf "$COMMIT_MESSAGE_TEMPLATE" "$(basename "$local_file")")" \
        --arg content "$file_content" \
        --arg branch "$branch" \
        --arg sha "$existing_sha" \
        '{
            message: $message,
            content: $content,
            branch: $branch
        } + (if $sha != "" then {sha: $sha} else {} end)')
    
    # 发送API请求
    local response
    response=$(curl -s -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$api_data" \
        "$GITHUB_API_BASE/repos/$repo/contents/$(url_encode "$github_path")")
    
    # 检查响应
    if echo "$response" | jq -e '.sha' > /dev/null 2>&1; then
        local new_sha=$(echo "$response" | jq -r '.sha')
        log_github_operation "upload" "$repo" "$github_path" "success"
        log_info "文件上传成功: SHA $new_sha"
        return 0
    else
        local error_message=$(echo "$response" | jq -r '.message // "Unknown error"')
        log_github_operation "upload" "$repo" "$github_path" "failed: $error_message"
        return 1
    fi
    
    log_function_end "upload_file_to_github"
}

# 从GitHub删除文件
delete_file_from_github() {
    local repo="$1"
    local github_path="$2"
    local branch="$3"
    
    log_function_start "delete_file_from_github"
    
    # 获取文件SHA
    local file_sha
    file_sha=$(get_file_sha "$repo" "$github_path" "$branch")
    
    if [[ -z "$file_sha" ]]; then
        log_warn "文件在GitHub上不存在，跳过删除: $github_path"
        return 0
    fi
    
    # 构建API请求数据
    local api_data
    api_data=$(jq -n \
        --arg message "$(printf "$COMMIT_MESSAGE_TEMPLATE" "Delete $(basename "$github_path")")" \
        --arg sha "$file_sha" \
        --arg branch "$branch" \
        '{
            message: $message,
            sha: $sha,
            branch: $branch
        }')
    
    # 发送删除请求
    local response
    response=$(curl -s -X DELETE \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$api_data" \
        "$GITHUB_API_BASE/repos/$repo/contents/$(url_encode "$github_path")")
    
    # 检查响应
    if echo "$response" | jq -e '.commit' > /dev/null 2>&1; then
        log_github_operation "delete" "$repo" "$github_path" "success"
        return 0
    else
        local error_message=$(echo "$response" | jq -r '.message // "Unknown error"')
        log_github_operation "delete" "$repo" "$github_path" "failed: $error_message"
        return 1
    fi
    
    log_function_end "delete_file_from_github"
}

# 获取文件SHA值
get_file_sha() {
    local repo="$1"
    local file_path="$2"
    local branch="$3"
    
    local response
    response=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB_API_BASE/repos/$repo/contents/$(url_encode "$file_path")?ref=$branch")
    
    if echo "$response" | jq -e '.sha' > /dev/null 2>&1; then
        echo "$response" | jq -r '.sha'
    else
        echo ""
    fi
}

# 检查仓库是否存在
check_repository_exists() {
    local repo="$1"
    
    local response
    response=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB_API_BASE/repos/$repo")
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 创建仓库
create_repository() {
    local repo_name="$1"
    local description="$2"
    local is_private="${3:-false}"
    
    log_function_start "create_repository"
    
    local api_data
    api_data=$(jq -n \
        --arg name "$repo_name" \
        --arg description "$description" \
        --argjson private "$is_private" \
        '{
            name: $name,
            description: $description,
            private: $private,
            auto_init: true
        }')
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$api_data" \
        "$GITHUB_API_BASE/user/repos")
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        local repo_url=$(echo "$response" | jq -r '.html_url')
        log_info "仓库创建成功: $repo_url"
        return 0
    else
        local error_message=$(echo "$response" | jq -r '.message // "Unknown error"')
        log_error "仓库创建失败: $error_message"
        return 1
    fi
    
    log_function_end "create_repository"
}

# 检查分支是否存在
check_branch_exists() {
    local repo="$1"
    local branch="$2"
    
    local response
    response=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB_API_BASE/repos/$repo/branches/$branch")
    
    if echo "$response" | jq -e '.name' > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 创建分支
create_branch() {
    local repo="$1"
    local new_branch="$2"
    local source_branch="${3:-main}"
    
    log_function_start "create_branch"
    
    # 获取源分支的SHA
    local source_sha
    source_sha=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB_API_BASE/repos/$repo/git/refs/heads/$source_branch" | \
        jq -r '.object.sha // empty')
    
    if [[ -z "$source_sha" ]]; then
        log_error "无法获取源分支SHA: $source_branch"
        return 1
    fi
    
    # 创建新分支
    local api_data
    api_data=$(jq -n \
        --arg ref "refs/heads/$new_branch" \
        --arg sha "$source_sha" \
        '{
            ref: $ref,
            sha: $sha
        }')
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$api_data" \
        "$GITHUB_API_BASE/repos/$repo/git/refs")
    
    if echo "$response" | jq -e '.ref' > /dev/null 2>&1; then
        log_info "分支创建成功: $new_branch"
        return 0
    else
        local error_message=$(echo "$response" | jq -r '.message // "Unknown error"')
        log_error "分支创建失败: $error_message"
        return 1
    fi
    
    log_function_end "create_branch"
}

# 验证路径配置的GitHub设置
validate_path_github_config() {
    local path_id="$1"
    
    local github_repo=$(get_path_config "$path_id" "GITHUB_REPO")
    local target_branch=$(get_path_config "$path_id" "TARGET_BRANCH" "$DEFAULT_BRANCH")
    
    # 检查仓库是否存在
    if ! check_repository_exists "$github_repo"; then
        log_error "GitHub仓库不存在: $github_repo"
        return 1
    fi
    
    # 检查分支是否存在
    if ! check_branch_exists "$github_repo" "$target_branch"; then
        log_warn "目标分支不存在: $target_branch，将尝试创建"
        if ! create_branch "$github_repo" "$target_branch"; then
            return 1
        fi
    fi
    
    log_info "路径 $path_id 的GitHub配置验证通过"
    return 0
}

# 批量同步目录
sync_directory_to_github() {
    local path_id="$1"
    local force_sync="${2:-false}"
    
    log_function_start "sync_directory_to_github"
    
    local local_path=$(get_path_config "$path_id" "LOCAL_PATH")
    
    if [[ ! -d "$local_path" ]]; then
        log_error "本地路径不存在: $local_path"
        return 1
    fi
    
    log_info "开始批量同步目录: $local_path"
    
    # 查找所有文件
    local file_count=0
    while IFS= read -r -d '' file; do
        if ! should_exclude_file "$file"; then
            sync_file_to_github "$path_id" "$file" "create"
            ((file_count++))
        fi
    done < <(find "$local_path" -type f -print0)
    
    log_info "批量同步完成，共处理 $file_count 个文件"
    log_function_end "sync_directory_to_github"
}
