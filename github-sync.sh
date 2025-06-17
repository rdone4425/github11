#!/bin/sh
#
# GitHub File Sync Tool for OpenWrt/Kwrt Systems
# 专为OpenWrt/Kwrt系统设计的GitHub文件同步工具
#
# Author: GitHub Sync Tool
# Version: 2.1.0
# License: MIT
#

#==============================================================================
# 版本信息和常量定义
#==============================================================================

readonly GITHUB_SYNC_VERSION="2.1.0"
readonly GITHUB_SYNC_NAME="GitHub File Sync Tool"

# 全局变量
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# 项目目录 - 根据环境自动选择
if [ -w "/root" ] 2>/dev/null; then
    readonly PROJECT_DIR="/root/github-sync"
else
    # 在当前目录下创建测试目录
    readonly PROJECT_DIR="$(pwd)/github-sync-test"
fi

# 子目录结构
readonly CONFIG_DIR="${PROJECT_DIR}/config"
readonly LOG_DIR="${PROJECT_DIR}/logs"
readonly DATA_DIR="${PROJECT_DIR}/data"
readonly TEMP_DIR="${PROJECT_DIR}/tmp"
readonly BACKUP_DIR="${PROJECT_DIR}/backup"

# 全面的文件发现和分析
discover_github_sync_files() {
    local discovery_report=$(create_temp_file "discovery_report")

    echo "🔍 正在扫描 GitHub Sync Tool 相关文件..."
    echo ""

    # 扫描当前目录下的相关文件
    local scan_dir="$(dirname "$PROJECT_DIR")"
    echo "扫描范围: $scan_dir 目录"
    echo "搜索模式: github-sync 相关文件"
    echo ""

    # 发现配置文件
    echo "📁 配置文件:" >> "$discovery_report"
    find "$scan_dir" -maxdepth 1 -name "github-sync-*.conf" -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            local mtime=$(get_file_mtime "$file")
            local readable=$([ -r "$file" ] && echo "可读" || echo "不可读")
            echo "  ✓ $file (${size}字节, 修改时间:$(date -d @$mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知"), $readable)" >> "$discovery_report"
        fi
    done

    # 发现日志文件
    echo "📝 日志文件:" >> "$discovery_report"
    find "$scan_dir" -maxdepth 1 -name "github-sync-*.log*" -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            local mtime=$(get_file_mtime "$file")
            local readable=$([ -r "$file" ] && echo "可读" || echo "不可读")
            echo "  ✓ $file (${size}字节, 修改时间:$(date -d @$mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知"), $readable)" >> "$discovery_report"
        fi
    done

    # 发现状态文件
    echo "📊 状态文件:" >> "$discovery_report"
    find /root -maxdepth 1 -name ".state_*" -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            local mtime=$(get_file_mtime "$file")
            local readable=$([ -r "$file" ] && echo "可读" || echo "不可读")
            echo "  ✓ $file (${size}字节, 修改时间:$(date -d @$mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知"), $readable)" >> "$discovery_report"
        fi
    done

    # 发现PID和锁文件
    echo "🔒 进程文件:" >> "$discovery_report"
    find /root -maxdepth 1 \( -name "github-sync-*.pid" -o -name "github-sync-*.lock" \) -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            local mtime=$(get_file_mtime "$file")
            local readable=$([ -r "$file" ] && echo "可读" || echo "不可读")
            echo "  ✓ $file (${size}字节, 修改时间:$(date -d @$mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知"), $readable)" >> "$discovery_report"
        fi
    done

    # 发现备份文件
    echo "💾 备份文件:" >> "$discovery_report"
    find /root -maxdepth 1 -name "github-sync-*.conf.backup.*" -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            local mtime=$(get_file_mtime "$file")
            local readable=$([ -r "$file" ] && echo "可读" || echo "不可读")
            echo "  ✓ $file (${size}字节, 修改时间:$(date -d @$mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知"), $readable)" >> "$discovery_report"
        fi
    done

    # 发现主脚本文件
    echo "🚀 主程序文件:" >> "$discovery_report"
    find /root -maxdepth 1 -name "github-sync.sh" -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            local mtime=$(get_file_mtime "$file")
            local executable=$([ -x "$file" ] && echo "可执行" || echo "不可执行")
            echo "  ✓ $file (${size}字节, 修改时间:$(date -d @$mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "未知"), $executable)" >> "$discovery_report"
        fi
    done

    # 显示发现报告
    cat "$discovery_report"

    # 清理临时文件
    rm -f "$discovery_report"

    echo ""
    echo "文件发现完成"
}

# 安全的文件迁移功能
migrate_existing_files() {
    local migrated_count=0
    local error_count=0
    local migration_log=$(create_temp_file "migration_log")

    echo "🚀 开始执行文件迁移计划..."
    echo ""

    # 创建迁移备份目录
    local migration_backup="${BACKUP_DIR}/migration_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$migration_backup" 2>/dev/null

    echo "迁移备份目录: $migration_backup" >> "$migration_log"
    echo "迁移开始时间: $(date)" >> "$migration_log"
    echo "" >> "$migration_log"

    # 迁移配置文件
    echo "📁 迁移配置文件..."
    for old_config in /root/github-sync-*.conf; do
        if [ -f "$old_config" ] && [ "$(dirname "$old_config")" = "/root" ]; then
            local filename=$(basename "$old_config")
            local new_config="${CONFIG_DIR}/$filename"

            if [ ! -f "$new_config" ]; then
                # 创建备份
                cp "$old_config" "$migration_backup/" 2>/dev/null

                # 执行迁移
                if mv "$old_config" "$new_config" 2>/dev/null; then
                    echo "  ✅ $filename → config/"
                    echo "SUCCESS: $old_config → $new_config" >> "$migration_log"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    echo "ERROR: Failed to migrate $old_config" >> "$migration_log"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                echo "SKIP: $new_config already exists" >> "$migration_log"
            fi
        fi
    done

    # 迁移日志文件
    echo "📝 迁移日志文件..."
    for old_log in /root/github-sync-*.log*; do
        if [ -f "$old_log" ] && [ "$(dirname "$old_log")" = "/root" ]; then
            local filename=$(basename "$old_log")
            local new_log="${LOG_DIR}/$filename"

            if [ ! -f "$new_log" ]; then
                # 创建备份
                cp "$old_log" "$migration_backup/" 2>/dev/null

                # 执行迁移
                if mv "$old_log" "$new_log" 2>/dev/null; then
                    echo "  ✅ $filename → logs/"
                    echo "SUCCESS: $old_log → $new_log" >> "$migration_log"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    echo "ERROR: Failed to migrate $old_log" >> "$migration_log"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                echo "SKIP: $new_log already exists" >> "$migration_log"
            fi
        fi
    done

    # 迁移状态文件
    echo "📊 迁移状态文件..."
    for old_state in /root/.state_* /root/.last_log_cleanup_*; do
        if [ -f "$old_state" ] && [ "$(dirname "$old_state")" = "/root" ]; then
            local filename=$(basename "$old_state")
            # 移除开头的点
            local new_filename="${filename#.}"
            local new_state="${DATA_DIR}/$new_filename"

            if [ ! -f "$new_state" ]; then
                # 创建备份
                cp "$old_state" "$migration_backup/" 2>/dev/null

                # 执行迁移
                if mv "$old_state" "$new_state" 2>/dev/null; then
                    echo "  ✅ $filename → data/$new_filename"
                    echo "SUCCESS: $old_state → $new_state" >> "$migration_log"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    echo "ERROR: Failed to migrate $old_state" >> "$migration_log"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                echo "SKIP: $new_state already exists" >> "$migration_log"
            fi
        fi
    done

    # 迁移PID和锁文件
    echo "🔒 迁移进程文件..."
    for old_file in /root/github-sync-*.pid /root/github-sync-*.lock; do
        if [ -f "$old_file" ] && [ "$(dirname "$old_file")" = "/root" ]; then
            local filename=$(basename "$old_file")
            local new_file="${DATA_DIR}/$filename"

            if [ ! -f "$new_file" ]; then
                # 创建备份
                cp "$old_file" "$migration_backup/" 2>/dev/null

                # 执行迁移
                if mv "$old_file" "$new_file" 2>/dev/null; then
                    echo "  ✅ $filename → data/"
                    echo "SUCCESS: $old_file → $new_file" >> "$migration_log"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    echo "ERROR: Failed to migrate $old_file" >> "$migration_log"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                echo "SKIP: $new_file already exists" >> "$migration_log"
            fi
        fi
    done

    # 迁移备份文件
    echo "💾 迁移备份文件..."
    for old_backup in /root/github-sync-*.conf.backup.*; do
        if [ -f "$old_backup" ] && [ "$(dirname "$old_backup")" = "/root" ]; then
            local filename=$(basename "$old_backup")
            local new_backup="${BACKUP_DIR}/$filename"

            if [ ! -f "$new_backup" ]; then
                # 执行迁移（备份文件不需要再备份）
                if mv "$old_backup" "$new_backup" 2>/dev/null; then
                    echo "  ✅ $filename → backup/"
                    echo "SUCCESS: $old_backup → $new_backup" >> "$migration_log"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    echo "ERROR: Failed to migrate $old_backup" >> "$migration_log"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                echo "SKIP: $new_backup already exists" >> "$migration_log"
            fi
        fi
    done

    # 记录迁移完成时间
    echo "" >> "$migration_log"
    echo "迁移完成时间: $(date)" >> "$migration_log"
    echo "成功迁移: $migrated_count 个文件" >> "$migration_log"
    echo "迁移失败: $error_count 个文件" >> "$migration_log"

    # 保存迁移日志
    local final_log="${BACKUP_DIR}/migration_$(date +%Y%m%d_%H%M%S).log"
    mv "$migration_log" "$final_log" 2>/dev/null

    echo ""
    echo "📋 迁移总结:"
    echo "  ✅ 成功迁移: $migrated_count 个文件"
    echo "  ❌ 迁移失败: $error_count 个文件"
    echo "  📄 迁移日志: $final_log"

    if [ "$migrated_count" -gt 0 ]; then
        echo "  💾 迁移备份: $migration_backup"
        echo ""
        echo "🎉 文件迁移完成！所有文件已安全迁移到标准化目录结构中。"
    elif [ "$error_count" -eq 0 ]; then
        echo ""
        echo "ℹ️  无需迁移文件，所有文件已在正确位置。"
        # 清理空的备份目录
        rmdir "$migration_backup" 2>/dev/null || true
    else
        echo ""
        echo "⚠️  迁移过程中遇到错误，请检查迁移日志获取详细信息。"
    fi
}

# 手动执行文件迁移
manual_migration() {
    clear
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          🚀 GitHub Sync Tool 文件迁移                       ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    echo "此功能将扫描并迁移散落在 /root/ 目录下的 GitHub Sync Tool 相关文件"
    echo "到标准化的项目目录结构中。"
    echo ""

    # 首先发现文件
    discover_github_sync_files

    echo ""
    echo "是否继续执行文件迁移？"
    echo ""
    echo "[y] 确定迁移    [n] 取消操作"
    echo ""
    echo -n "请选择: "
    read -r confirm

    case "$confirm" in
        y|Y|yes|YES)
            echo ""
            migrate_existing_files
            ;;
        *)
            echo ""
            echo "迁移操作已取消"
            ;;
    esac

    echo ""
    echo "按任意键返回主菜单..."
    read -r
}

# 验证迁移结果
verify_migration() {
    clear
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          🔍 迁移结果验证                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    local issues=0

    echo "正在验证项目目录结构..."
    echo ""

    # 验证目录结构
    echo "📁 目录结构验证:"
    for dir in "$PROJECT_DIR" "$CONFIG_DIR" "$LOG_DIR" "$DATA_DIR" "$TEMP_DIR" "$BACKUP_DIR"; do
        if [ -d "$dir" ]; then
            local perm=$(stat -c%a "$dir" 2>/dev/null || stat -f%A "$dir" 2>/dev/null || echo "未知")
            echo "  ✅ $dir (权限: $perm)"
        else
            echo "  ❌ $dir (不存在)"
            issues=$((issues + 1))
        fi
    done

    echo ""
    echo "📄 文件位置验证:"

    # 验证配置文件
    if [ -f "$CONFIG_FILE" ]; then
        local size=$(get_file_size "$CONFIG_FILE")
        echo "  ✅ 配置文件: $CONFIG_FILE (${size}字节)"
    else
        echo "  ⚠️  配置文件: $CONFIG_FILE (不存在)"
    fi

    # 验证日志文件
    if [ -f "$LOG_FILE" ]; then
        local size=$(get_file_size "$LOG_FILE")
        echo "  ✅ 日志文件: $LOG_FILE (${size}字节)"
    else
        echo "  ⚠️  日志文件: $LOG_FILE (不存在)"
    fi

    # 验证数据文件
    local data_files=0
    for file in "$DATA_DIR"/*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local size=$(get_file_size "$file")
            echo "  ✅ 数据文件: $filename (${size}字节)"
            data_files=$((data_files + 1))
        fi
    done

    if [ "$data_files" -eq 0 ]; then
        echo "  ℹ️  数据目录为空"
    fi

    # 验证备份文件
    local backup_files=0
    for file in "$BACKUP_DIR"/*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local size=$(get_file_size "$file")
            echo "  ✅ 备份文件: $filename (${size}字节)"
            backup_files=$((backup_files + 1))
        fi
    done

    if [ "$backup_files" -eq 0 ]; then
        echo "  ℹ️  备份目录为空"
    fi

    echo ""
    echo "🔍 残留文件检查:"

    # 检查根目录下是否还有残留文件
    local remaining_files=0
    for pattern in "github-sync-*.conf" "github-sync-*.log*" ".state_*" "github-sync-*.pid" "github-sync-*.lock" "github-sync-*.conf.backup.*"; do
        for file in /root/$pattern; do
            if [ -f "$file" ]; then
                echo "  ⚠️  残留文件: $file"
                remaining_files=$((remaining_files + 1))
            fi
        done
    done

    if [ "$remaining_files" -eq 0 ]; then
        echo "  ✅ 无残留文件"
    else
        echo "  ⚠️  发现 $remaining_files 个残留文件"
        issues=$((issues + 1))
    fi

    echo ""
    echo "📊 验证总结:"
    if [ "$issues" -eq 0 ]; then
        echo "  ✅ 迁移验证通过，所有文件已正确迁移到标准化目录结构"
    else
        echo "  ⚠️  发现 $issues 个问题，建议检查迁移结果"
    fi

    echo ""
    echo "按任意键返回主菜单..."
    read -r
}

# 确保项目目录结构存在
ensure_project_directory() {
    local dirs_to_create="$PROJECT_DIR $CONFIG_DIR $LOG_DIR $DATA_DIR $TEMP_DIR $BACKUP_DIR"

    for dir in $dirs_to_create; do
        if [ ! -d "$dir" ]; then
            if ! mkdir -p "$dir" 2>/dev/null; then
                echo "错误: 无法创建目录 $dir" >&2
                exit 1
            fi
            echo "已创建目录: $dir"
        fi
    done

    # 设置适当的权限
    chmod 700 "$PROJECT_DIR" 2>/dev/null || true
    chmod 755 "$CONFIG_DIR" "$LOG_DIR" "$DATA_DIR" 2>/dev/null || true
    chmod 700 "$TEMP_DIR" "$BACKUP_DIR" 2>/dev/null || true

    # 迁移现有文件
    migrate_existing_files

    echo "项目目录结构初始化完成: $PROJECT_DIR"
}

# 初始化项目目录
ensure_project_directory

# 支持多实例 - 可通过环境变量或参数指定实例名
INSTANCE_NAME="${GITHUB_SYNC_INSTANCE:-default}"

# 文件路径配置 - 使用结构化目录
CONFIG_FILE="${CONFIG_DIR}/github-sync-${INSTANCE_NAME}.conf"
LOG_FILE="${LOG_DIR}/github-sync-${INSTANCE_NAME}.log"
PID_FILE="${DATA_DIR}/github-sync-${INSTANCE_NAME}.pid"
LOCK_FILE="${DATA_DIR}/github-sync-${INSTANCE_NAME}.lock"

#==============================================================================
# 默认配置常量
#==============================================================================

readonly DEFAULT_POLL_INTERVAL=30
readonly DEFAULT_LOG_LEVEL="INFO"
# 文件大小常量
readonly ONE_MB=1048576                # 1MB in bytes
readonly ONE_DAY_SECONDS=86400         # 24 * 60 * 60

# 默认配置值
readonly DEFAULT_MAX_LOG_SIZE=$ONE_MB  # 1MB
readonly DEFAULT_LOG_KEEP_DAYS=7       # 保留7天的日志
readonly DEFAULT_LOG_MAX_FILES=10      # 最多保留10个日志文件
readonly DEFAULT_MAX_FILE_SIZE=$ONE_MB # 1MB
readonly DEFAULT_HTTP_TIMEOUT=30
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_RETRY_INTERVAL=5

# 颜色输出常量
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# 系统工具缓存 - 避免重复检查
STAT_CMD=""
STAT_FORMAT=""
SYSTEM_TOOLS_INITIALIZED=false

# 菜单系统缓存
MENU_CONFIG_CACHE=""
MENU_STATUS_CACHE=""
MENU_CACHE_TIME=0
MENU_CACHE_DURATION=5  # 缓存5秒

#==============================================================================
# 代码质量和健康检查
#==============================================================================

# 代码质量检查
check_code_health() {
    local issues=0

    echo "代码健康检查报告:"
    echo "=================="

    # 检查函数数量
    local func_count=$(grep -c '^[a-zA-Z_][a-zA-Z0-9_]*()' "$0")
    echo "• 函数数量: $func_count"
    if [ "$func_count" -gt 100 ]; then
        echo "  ⚠️  函数数量过多，建议模块化"
        issues=$((issues + 1))
    fi

    # 检查文件大小
    local file_size=$(wc -l < "$0")
    echo "• 文件行数: $file_size"
    if [ "$file_size" -gt 3000 ]; then
        echo "  ⚠️  文件过大，建议拆分"
        issues=$((issues + 1))
    fi

    # 检查TODO项目
    local todo_count=$(grep -c "TODO\|FIXME\|XXX\|HACK" "$0" 2>/dev/null || echo "0")
    echo "• 待办事项: $todo_count"

    # 检查错误处理
    local error_handling=$(grep -c "trap\|return 1\|exit 1" "$0" 2>/dev/null || echo "0")
    echo "• 错误处理点: $error_handling"

    echo ""
    if [ "$issues" -eq 0 ]; then
        echo "✅ 代码健康状况良好"
    else
        echo "⚠️  发现 $issues 个需要关注的问题"
    fi

    return $issues
}

#==============================================================================
# 核心工具函数
#==============================================================================

# 创建临时文件
# 功能: 创建安全的临时文件
# 参数: $1 - 文件前缀
# 返回: 临时文件路径
create_temp_file() {
    local prefix="${1:-temp}"
    local temp_file="${TEMP_DIR}/${prefix}_$$_$(date +%s)"
    touch "$temp_file" 2>/dev/null || {
        echo "错误: 无法创建临时文件" >&2
        return 1
    }
    echo "$temp_file"
}

# 清理临时文件
# 功能: 清理指定的临时文件或所有临时文件
# 参数: $1 - 临时文件路径（可选，为空则清理所有）
cleanup_temp_files() {
    local temp_file="$1"

    if [ -n "$temp_file" ]; then
        # 清理指定文件
        rm -f "$temp_file" 2>/dev/null || true
    else
        # 清理所有临时文件
        find "$TEMP_DIR" -name "temp_*" -type f -mtime +1 -delete 2>/dev/null || true
        find "$TEMP_DIR" -name "*_$$_*" -type f -delete 2>/dev/null || true
    fi
}

# 初始化系统工具检查
# 功能: 检测并缓存系统工具的可用性和格式，避免重复检查
# 参数: 无
# 返回: 0-成功, 1-失败
# 副作用: 设置全局变量 STAT_CMD 和 STAT_FORMAT
init_system_tools() {
    if [ "$SYSTEM_TOOLS_INITIALIZED" = "true" ]; then
        return 0
    fi

    # 检查stat命令和格式
    if command -v stat >/dev/null 2>&1; then
        # 测试GNU stat格式 (Linux)
        if stat -c%s "$0" >/dev/null 2>&1; then
            STAT_CMD="stat"
            STAT_FORMAT="gnu"
        # 测试BSD stat格式 (macOS, FreeBSD)
        elif stat -f%z "$0" >/dev/null 2>&1; then
            STAT_CMD="stat"
            STAT_FORMAT="bsd"
        fi
    fi

    SYSTEM_TOOLS_INITIALIZED=true
    log_debug "系统工具初始化: STAT_CMD=$STAT_CMD, STAT_FORMAT=$STAT_FORMAT"
    return 0
}

# 检查命令是否存在
# 功能: 检查指定命令是否在系统中可用
# 参数: $1 - 命令名称
# 返回: 0-存在, 1-不存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 验证数字
# 功能: 验证字符串是否为有效的正整数
# 参数: $1 - 要验证的字符串
# 返回: 0-有效, 1-无效
is_valid_number() {
    echo "$1" | grep -qE '^[0-9]+$'
}

# 转义JSON字符串
# 功能: 转义JSON字符串中的特殊字符
# 参数: $1 - 要转义的字符串
# 返回: 转义后的字符串
escape_json_string() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g'
}

# 标准化路径格式
# 功能: 清理和标准化文件路径
# 参数: $1 - 原始路径
# 返回: 标准化后的路径
normalize_path() {
    local path="$1"

    # 移除前后空格
    path=$(echo "$path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # 展开波浪号
    case "$path" in
        "~"*) path="$HOME${path#~}" ;;
    esac

    # 移除多余的斜杠
    path=$(echo "$path" | sed 's|//*|/|g')

    # 移除末尾的斜杠（除非是根目录）
    case "$path" in
        "/") ;;
        */) path="${path%/}" ;;
    esac

    echo "$path"
}

# 验证GitHub仓库名格式
# 功能: 验证GitHub仓库名是否符合规范
# 参数: $1 - 仓库名
# 返回: 0-有效, 1-无效
validate_repo_name() {
    local repo="$1"

    # 检查基本格式
    if ! echo "$repo" | grep -qE '^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$'; then
        return 1
    fi

    # 检查长度限制
    local username=$(echo "$repo" | cut -d'/' -f1)
    local reponame=$(echo "$repo" | cut -d'/' -f2)

    if [ ${#username} -gt 39 ] || [ ${#reponame} -gt 100 ]; then
        return 1
    fi

    # 检查是否以点或连字符开头/结尾
    case "$username" in
        .*|*.|_*|*_|-*|*-) return 1 ;;
    esac

    case "$reponame" in
        .*|*.|_*|*_|-*|*-) return 1 ;;
    esac

    return 0
}

# 验证分支名格式
# 功能: 验证Git分支名是否符合规范
# 参数: $1 - 分支名
# 返回: 0-有效, 1-无效
validate_branch_name() {
    local branch="$1"

    # 检查基本字符
    if ! echo "$branch" | grep -qE '^[a-zA-Z0-9._/-]+$'; then
        return 1
    fi

    # 检查长度
    if [ ${#branch} -gt 250 ]; then
        return 1
    fi

    # 检查不能以斜杠开头或结尾
    case "$branch" in
        /*|*/) return 1 ;;
    esac

    # 检查不能包含连续斜杠
    if echo "$branch" | grep -q '//'; then
        return 1
    fi

    return 0
}

#==============================================================================
# 日志和输出函数
#==============================================================================

# 日志级别定义
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4
readonly LOG_LEVEL_SUCCESS=3  # SUCCESS 等同于 INFO 级别

# 获取日志级别数值
get_log_level_value() {
    case "${LOG_LEVEL:-INFO}" in
        "ERROR") echo $LOG_LEVEL_ERROR ;;
        "WARN")  echo $LOG_LEVEL_WARN ;;
        "INFO")  echo $LOG_LEVEL_INFO ;;
        "DEBUG") echo $LOG_LEVEL_DEBUG ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

# 检查是否应该输出日志
should_log() {
    local level="$1"
    local level_value
    local current_level_value=$(get_log_level_value)

    case "$level" in
        "ERROR")   level_value=$LOG_LEVEL_ERROR ;;
        "WARN")    level_value=$LOG_LEVEL_WARN ;;
        "INFO")    level_value=$LOG_LEVEL_INFO ;;
        "SUCCESS") level_value=$LOG_LEVEL_SUCCESS ;;
        "DEBUG")   level_value=$LOG_LEVEL_DEBUG ;;
        *) return 1 ;;
    esac

    [ "$level_value" -le "$current_level_value" ]
}

# 核心日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # 检查日志级别
    if ! should_log "$level"; then
        return 0
    fi

    # 确保日志文件存在
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || return 1
    fi

    # 写入日志文件
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || return 1

    # 控制台输出（只在交互模式下显示）
    # 在守护进程模式下绝对不输出到控制台
    if [ "${DAEMON_MODE:-false}" != "true" ] && [ "${GITHUB_SYNC_QUIET:-false}" != "true" ]; then
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
            "SUCCESS")
                echo -e "${GREEN}[SUCCESS]${NC} $message"
                ;;
            "DEBUG")
                echo -e "${BLUE}[DEBUG]${NC} $message"
                ;;
            *)
                echo "[$level] $message"
                ;;
        esac
    fi

    return 0
}

# 便捷日志函数
log_error() {
    log "ERROR" "$1"
    return 1  # 错误日志返回非零值，便于错误处理
}

log_warn() {
    log "WARN" "$1"
    return 0
}

log_info() {
    log "INFO" "$1"
    return 0
}

log_debug() {
    log "DEBUG" "$1"
    return 0
}

log_success() {
    log "SUCCESS" "$1"
    return 0
}

#==============================================================================
# 文件操作函数
#==============================================================================

# 获取文件大小（兼容不同系统）
# 功能: 获取指定文件的字节大小，兼容GNU和BSD系统
# 参数: $1 - 文件路径
# 返回: 文件大小（字节），如果文件不存在返回0
get_file_size() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo 0
        return
    fi

    init_system_tools

    # 使用缓存的系统工具信息
    case "$STAT_FORMAT" in
        "gnu")
            stat -c%s "$file" 2>/dev/null || wc -c < "$file" 2>/dev/null || echo 0
            ;;
        "bsd")
            stat -f%z "$file" 2>/dev/null || wc -c < "$file" 2>/dev/null || echo 0
            ;;
        *)
            wc -c < "$file" 2>/dev/null || echo 0
            ;;
    esac
}

# 获取文件修改时间戳（兼容不同系统）
# 功能: 获取文件的修改时间戳（Unix时间戳）
# 参数: $1 - 文件路径
# 返回: Unix时间戳，如果文件不存在返回0
get_file_mtime() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo 0
        return
    fi

    init_system_tools

    # 使用缓存的系统工具信息
    case "$STAT_FORMAT" in
        "gnu")
            stat -c %Y "$file" 2>/dev/null || echo 0
            ;;
        "bsd")
            stat -f %m "$file" 2>/dev/null || echo 0
            ;;
        *)
            echo 0
            ;;
    esac
}

# 获取文件修改时间（天数）
# 功能: 计算文件距离现在的天数
# 参数: $1 - 文件路径
# 返回: 天数，如果文件不存在返回999
get_file_age_days() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo 999
        return
    fi

    local file_mtime=$(get_file_mtime "$file")
    local current_time=$(date +%s)
    local age_seconds=$((current_time - file_mtime))
    local age_days=$((age_seconds / ONE_DAY_SECONDS))

    echo $age_days
}

# 清理旧日志文件
cleanup_old_logs() {
    local log_dir=$(dirname "$LOG_FILE")
    local log_basename=$(basename "$LOG_FILE")
    local keep_days=${LOG_KEEP_DAYS:-$DEFAULT_LOG_KEEP_DAYS}
    local max_files=${LOG_MAX_FILES:-$DEFAULT_LOG_MAX_FILES}
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local deleted_count=0
    local total_size_freed=0
    local temp_stats="${TEMP_DIR}/cleanup_stats_$$"

    # 清理基于时间的旧日志 - 避免管道子shell问题
    find "$log_dir" -name "${log_basename}.*" -type f > "${temp_stats}_files" 2>/dev/null || true

    if [ -f "${temp_stats}_files" ]; then
        while read -r old_log; do
            [ -z "$old_log" ] && continue
            local age_days=$(get_file_age_days "$old_log")
            if [ "$age_days" -gt "$keep_days" ]; then
                local file_size=$(get_file_size "$old_log")
                if rm -f "$old_log" 2>/dev/null; then
                    deleted_count=$((deleted_count + 1))
                    total_size_freed=$((total_size_freed + file_size))
                    echo "[$timestamp] [INFO] 已删除过期日志文件: $old_log (年龄: ${age_days}天, 大小: ${file_size}字节)" >> "$LOG_FILE"
                fi
            fi
        done < "${temp_stats}_files"
        rm -f "${temp_stats}_files"
    fi

    # 限制日志文件数量
    local log_count=$(find "$log_dir" -name "${log_basename}.*" -type f 2>/dev/null | wc -l)
    if [ "$log_count" -gt "$max_files" ]; then
        # 删除最旧的日志文件 - 避免管道子shell问题
        find "$log_dir" -name "${log_basename}.*" -type f -exec ls -t {} + 2>/dev/null | \
        tail -n +$((max_files + 1)) > "${temp_stats}_excess" 2>/dev/null || true

        if [ -f "${temp_stats}_excess" ]; then
            while read -r old_log; do
                [ -z "$old_log" ] && continue
                local file_size=$(get_file_size "$old_log")
                if rm -f "$old_log" 2>/dev/null; then
                    deleted_count=$((deleted_count + 1))
                    total_size_freed=$((total_size_freed + file_size))
                    echo "[$timestamp] [INFO] 已删除多余日志文件: $old_log (大小: ${file_size}字节)" >> "$LOG_FILE"
                fi
            done < "${temp_stats}_excess"
            rm -f "${temp_stats}_excess"
        fi
    fi

    # 记录清理统计
    if [ "$deleted_count" -gt 0 ]; then
        local size_mb=$(echo "scale=2; $total_size_freed/1024/1024" | bc 2>/dev/null || echo "N/A")
        echo "[$timestamp] [INFO] 日志清理完成: 删除 $deleted_count 个文件, 释放 $total_size_freed 字节 (${size_mb}MB)" >> "$LOG_FILE"
    else
        echo "[$timestamp] [INFO] 日志清理完成: 无需删除文件" >> "$LOG_FILE"
    fi

    # 清理临时文件
    rm -f "${temp_stats}"_* 2>/dev/null || true
}

# 日志文件轮转和清理
rotate_log() {
    if [ ! -f "$LOG_FILE" ]; then
        return
    fi

    local file_size=$(get_file_size "$LOG_FILE")
    local max_size=${LOG_MAX_SIZE:-$DEFAULT_MAX_LOG_SIZE}

    # 基于文件大小轮转
    if [ "$file_size" -gt "$max_size" ]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        local rotated_log="${LOG_FILE}.${timestamp}"

        # 轮转当前日志文件
        mv "$LOG_FILE" "$rotated_log"
        touch "$LOG_FILE"

        # 记录轮转信息
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 日志文件已轮转: $rotated_log (大小: ${file_size} bytes)" >> "$LOG_FILE"

        # 清理旧日志文件
        cleanup_old_logs
    fi
}

# 定期清理日志（每天执行一次）
periodic_log_cleanup() {
    local cleanup_marker="${DATA_DIR}/last_log_cleanup_$(echo "$INSTANCE_NAME" | tr '/' '_')"
    local today=$(date '+%Y%m%d')
    local current_hour=$(date '+%H')

    # 检查是否今天已经清理过
    if [ -f "$cleanup_marker" ]; then
        local last_cleanup=$(cat "$cleanup_marker" 2>/dev/null || echo "")
        if [ "$last_cleanup" = "$today" ]; then
            return  # 今天已经清理过了
        fi
    fi

    # 只在凌晨2点到6点之间执行清理（避免在业务繁忙时间清理）
    if [ "$current_hour" -ge 2 ] && [ "$current_hour" -le 6 ]; then
        # 执行清理
        cleanup_old_logs

        # 记录清理时间
        echo "$today" > "$cleanup_marker"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 执行每日日志清理 (实例: $INSTANCE_NAME)" >> "$LOG_FILE"
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

# 日志管理选项
LOG_MAX_SIZE=1048576   # 日志文件最大大小 (1MB)
LOG_KEEP_DAYS=7        # 保留日志天数
LOG_MAX_FILES=10       # 最多保留日志文件数
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
    MAX_FILE_SIZE=${MAX_FILE_SIZE:-$DEFAULT_MAX_FILE_SIZE}
    HTTP_TIMEOUT=${HTTP_TIMEOUT:-$DEFAULT_HTTP_TIMEOUT}
    MAX_RETRIES=${MAX_RETRIES:-$DEFAULT_MAX_RETRIES}
    RETRY_INTERVAL=${RETRY_INTERVAL:-$DEFAULT_RETRY_INTERVAL}
    LOG_MAX_SIZE=${LOG_MAX_SIZE:-$DEFAULT_MAX_LOG_SIZE}
    LOG_KEEP_DAYS=${LOG_KEEP_DAYS:-$DEFAULT_LOG_KEEP_DAYS}
    LOG_MAX_FILES=${LOG_MAX_FILES:-$DEFAULT_LOG_MAX_FILES}

    # 设置默认布尔值
    AUTO_COMMIT=${AUTO_COMMIT:-true}
    VERIFY_SSL=${VERIFY_SSL:-true}

    # 设置默认字符串值
    COMMIT_MESSAGE_TEMPLATE=${COMMIT_MESSAGE_TEMPLATE:-"Auto sync from OpenWrt: %s"}
    EXCLUDE_PATTERNS=${EXCLUDE_PATTERNS:-"*.tmp *.log *.pid *.lock .git"}

    log_info "配置文件加载成功"
    return 0
}

# 验证配置
# 功能: 验证配置的有效性
# 参数: 无
# 返回: 0-成功, 非零-失败
validate_config() {
    local errors=0

    # 验证数值配置
    if ! is_valid_number "$POLL_INTERVAL" || [ "$POLL_INTERVAL" -lt 5 ]; then
        log_error "无效的轮询间隔: $POLL_INTERVAL (必须是大于等于5的数字)"
        errors=$((errors + 1))
    fi

    if ! is_valid_number "$MAX_FILE_SIZE" || [ "$MAX_FILE_SIZE" -lt 1 ]; then
        log_error "无效的最大文件大小: $MAX_FILE_SIZE (必须是正整数)"
        errors=$((errors + 1))
    fi

    if ! is_valid_number "$HTTP_TIMEOUT" || [ "$HTTP_TIMEOUT" -lt 1 ]; then
        log_error "无效的HTTP超时时间: $HTTP_TIMEOUT (必须是正整数)"
        errors=$((errors + 1))
    fi

    # 验证日志级别
    case "$LOG_LEVEL" in
        "DEBUG"|"INFO"|"WARN"|"ERROR") ;;
        *)
            log_error "无效的日志级别: $LOG_LEVEL (必须是 DEBUG, INFO, WARN, ERROR 之一)"
            errors=$((errors + 1))
            ;;
    esac

    # 验证GitHub配置
    if [ -z "$GITHUB_USERNAME" ]; then
        log_error "GitHub用户名未配置"
        errors=$((errors + 1))
    fi

    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GitHub令牌未配置"
        errors=$((errors + 1))
    elif [ ${#GITHUB_TOKEN} -lt 20 ]; then
        log_error "GitHub令牌格式可能不正确 (长度太短)"
        errors=$((errors + 1))
    fi

    # 验证GitHub连接
    if ! check_github_connection; then
        log_error "GitHub连接验证失败"
        errors=$((errors + 1))
    fi

    # 验证同步路径
    if [ -z "$SYNC_PATHS" ]; then
        log_error "未配置同步路径"
        errors=$((errors + 1))
    else
        validate_sync_paths || errors=$((errors + 1))
    fi

    return $errors
}

# 验证同步路径配置
# 功能: 验证同步路径配置的格式和有效性
# 参数: 无
# 返回: 0-成功, 非零-失败
validate_sync_paths() {
    local path_errors=0
    local line_num=0
    local temp_file=$(create_temp_file "validate_paths")

    # 将错误信息写入临时文件，避免子shell问题
    echo "$SYNC_PATHS" | while IFS='|' read -r local_path repo branch target_path; do
        line_num=$((line_num + 1))

        # 跳过空行
        [ -z "$local_path" ] && continue

        # 清理路径（移除前后空格）
        local_path=$(echo "$local_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        repo=$(echo "$repo" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        branch=$(echo "$branch" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        target_path=$(echo "$target_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 验证本地路径
        if [ -z "$local_path" ]; then
            echo "ERROR:同步路径 $line_num: 本地路径为空" >> "$temp_file"
        elif [ ! -e "$local_path" ]; then
            echo "ERROR:同步路径 $line_num: 本地路径不存在: $local_path" >> "$temp_file"
            echo "SUGGESTION:请检查路径是否正确，或创建该路径" >> "$temp_file"
        elif [ -f "$local_path" ]; then
            if [ ! -r "$local_path" ]; then
                echo "ERROR:同步路径 $line_num: 文件不可读: $local_path" >> "$temp_file"
                echo "SUGGESTION:请检查文件权限: chmod +r '$local_path'" >> "$temp_file"
            fi
        elif [ -d "$local_path" ]; then
            if [ ! -r "$local_path" ]; then
                echo "ERROR:同步路径 $line_num: 目录不可读: $local_path" >> "$temp_file"
                echo "SUGGESTION:请检查目录权限: chmod +r '$local_path'" >> "$temp_file"
            fi
        fi

        # 验证仓库格式
        if [ -z "$repo" ]; then
            echo "ERROR:同步路径 $line_num: GitHub仓库未指定" >> "$temp_file"
            echo "SUGGESTION:格式应为: 用户名/仓库名" >> "$temp_file"
        elif ! echo "$repo" | grep -qE '^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$'; then
            echo "ERROR:同步路径 $line_num: GitHub仓库格式错误: $repo" >> "$temp_file"
            echo "SUGGESTION:正确格式: 用户名/仓库名 (只能包含字母、数字、点、下划线、连字符)" >> "$temp_file"
        fi

        # 验证分支名
        if [ -z "$branch" ]; then
            echo "ERROR:同步路径 $line_num: 分支未指定" >> "$temp_file"
            echo "SUGGESTION:常用分支名: main, master, develop" >> "$temp_file"
        elif ! echo "$branch" | grep -qE '^[a-zA-Z0-9._/-]+$'; then
            echo "ERROR:同步路径 $line_num: 分支名格式错误: $branch" >> "$temp_file"
            echo "SUGGESTION:分支名只能包含字母、数字、点、下划线、连字符、斜杠" >> "$temp_file"
        fi

        # 验证目标路径格式（如果不为空）
        if [ -n "$target_path" ]; then
            # 检查是否包含非法字符
            if echo "$target_path" | grep -q '[<>:"|?*]'; then
                echo "ERROR:同步路径 $line_num: 目标路径包含非法字符: $target_path" >> "$temp_file"
                echo "SUGGESTION:避免使用 < > : \" | ? * 等字符" >> "$temp_file"
            fi
            # 检查是否以斜杠开头或结尾
            if echo "$target_path" | grep -qE '^/|/$'; then
                echo "WARNING:同步路径 $line_num: 目标路径不应以斜杠开头或结尾: $target_path" >> "$temp_file"
                echo "SUGGESTION:使用相对路径，如: config/file.txt" >> "$temp_file"
            fi
        fi

        log_debug "验证同步路径 $line_num: $local_path -> $repo:$branch/$target_path"
    done

    # 处理验证结果
    if [ -f "$temp_file" ]; then
        while read -r line; do
            case "$line" in
                ERROR:*)
                    log_error "${line#ERROR:}"
                    path_errors=$((path_errors + 1))
                    ;;
                WARNING:*)
                    log_warn "${line#WARNING:}"
                    ;;
                SUGGESTION:*)
                    log_info "  💡 ${line#SUGGESTION:}"
                    ;;
            esac
        done < "$temp_file"
        rm -f "$temp_file"
    fi

    return $path_errors
}

# 重试机制包装器
# 功能: 为GitHub API调用提供重试机制
# 参数: $1 - 函数名, $2... - 函数参数
# 返回: 函数执行结果
github_api_with_retry() {
    local func_name="$1"
    shift
    local max_retries=${MAX_RETRIES:-$DEFAULT_MAX_RETRIES}
    local retry_interval=${RETRY_INTERVAL:-$DEFAULT_RETRY_INTERVAL}
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        log_debug "GitHub API调用尝试 $attempt/$max_retries: $func_name"

        if "$func_name" "$@"; then
            return 0
        fi

        if [ $attempt -lt $max_retries ]; then
            log_warn "GitHub API调用失败，${retry_interval}秒后重试 ($attempt/$max_retries)"
            sleep "$retry_interval"
        else
            log_error "GitHub API调用失败，已达到最大重试次数 ($max_retries)"
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

#==============================================================================
# GitHub API函数
#==============================================================================

# 检查GitHub连接
# 功能: 验证GitHub API连接和令牌有效性
# 参数: 无
# 返回: 0-成功, 1-失败
check_github_connection() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GitHub令牌未配置"
        return 1
    fi

    log_debug "检查GitHub连接..."

    local response
    local http_code

    # 使用curl检查GitHub API连接
    response=$(curl -s -w "%{http_code}" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "User-Agent: github-sync-tool/$GITHUB_SYNC_VERSION" \
        --connect-timeout "${HTTP_TIMEOUT:-30}" \
        --max-time "${HTTP_TIMEOUT:-30}" \
        "https://api.github.com/user" \
        -o /dev/null 2>/dev/null)

    http_code="$response"

    case "$http_code" in
        "200")
            log_info "GitHub连接验证成功"
            return 0
            ;;
        "401")
            log_error "GitHub令牌无效或已过期"
            return 1
            ;;
        "403")
            log_error "GitHub API访问被拒绝，可能是令牌权限不足或API限制"
            return 1
            ;;
        "")
            log_error "无法连接到GitHub API，请检查网络连接"
            return 1
            ;;
        *)
            log_error "GitHub连接验证失败，HTTP状态码: $http_code"
            return 1
            ;;
    esac
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
    local file_size=$(get_file_size "$local_file")
    local max_size=${MAX_FILE_SIZE:-$DEFAULT_MAX_FILE_SIZE}

    if [ "$file_size" -gt "$max_size" ]; then
        log_error "文件太大，跳过: $local_file (${file_size} bytes > ${max_size} bytes)"
        return 1
    fi
    
    # 检查必要工具
    if ! command_exists base64; then
        log_error "base64 命令不可用，无法编码文件"
        return 1
    fi

    if ! command_exists curl; then
        log_error "curl 命令不可用，无法上传文件"
        return 1
    fi

    # Base64编码文件内容
    local content
    if ! content=$(base64 -w 0 "$local_file" 2>/dev/null); then
        log_error "文件Base64编码失败: $local_file"
        return 1
    fi

    # 验证编码结果
    if [ -z "$content" ]; then
        log_error "文件编码结果为空: $local_file"
        return 1
    fi

    # 获取现有文件的SHA（如果存在）
    local sha
    sha=$(get_file_sha "$repo" "$target_path" "$branch")

    # 验证必要参数
    if [ -z "$commit_message" ]; then
        commit_message="Update $target_path"
        log_warn "提交消息为空，使用默认消息: $commit_message"
    fi

    # 转义JSON字符串中的特殊字符
    local escaped_message=$(escape_json_string "$commit_message")

    # 构建API请求
    local json_data
    if [ -n "$sha" ]; then
        # 更新现有文件
        json_data="{\"message\":\"$escaped_message\",\"content\":\"$content\",\"sha\":\"$sha\",\"branch\":\"$branch\"}"
        log_debug "更新现有文件，SHA: $sha"
    else
        # 创建新文件
        json_data="{\"message\":\"$escaped_message\",\"content\":\"$content\",\"branch\":\"$branch\"}"
        log_debug "创建新文件"
    fi

    # 发送请求
    local response
    local curl_exit_code
    response=$(curl -s -X PUT -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$json_data" \
        "https://api.github.com/repos/$repo/contents/$target_path" 2>&1)
    curl_exit_code=$?

    # 检查curl命令是否成功
    if [ $curl_exit_code -ne 0 ]; then
        log_error "curl命令执行失败 (退出码: $curl_exit_code): $local_file"
        log_debug "curl错误信息: $response"
        return 1
    fi

    # 检查API响应
    if echo "$response" | grep -q '"sha"'; then
        log_info "文件上传成功: $local_file -> $repo/$target_path"
        return 0
    elif echo "$response" | grep -q '"message".*"error"'; then
        local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        log_error "GitHub API错误: $error_msg"
        log_debug "完整API响应: $response"
        return 1
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

    # 检查排除模式
    for pattern in ${EXCLUDE_PATTERNS:-"*.tmp *.log *.pid *.lock .git"}; do
        case "$filename" in
            $pattern)
                log_debug "文件被排除: $file (匹配模式: $pattern)"
                return 0  # 应该排除
                ;;
        esac
    done

    # 检查文件大小
    local file_size=$(get_file_size "$file")
    local max_size=${MAX_FILE_SIZE:-$DEFAULT_MAX_FILE_SIZE}

    if [ "$file_size" -gt "$max_size" ]; then
        log_debug "文件被排除: $file (大小: ${file_size} > ${max_size})"
        return 0  # 应该排除
    fi

    return 1  # 不应该排除
}



# 扫描目录中的文件变化
scan_directory_changes() {
    local watch_path="$1"
    local state_file="${DATA_DIR}/state_$(echo "$watch_path" | tr '/' '_')"

    # 创建状态文件（如果不存在）
    [ ! -f "$state_file" ] && touch "$state_file"

    # 检查是文件还是目录
    if [ -f "$watch_path" ]; then
        # 单个文件监控
        # 检查是否应该排除
        if should_exclude_file "$watch_path"; then
            return
        fi

        local current_mtime=$(get_file_mtime "$watch_path")
        local stored_mtime=$(grep "^$watch_path:" "$state_file" | cut -d: -f2)

        if [ "$current_mtime" != "$stored_mtime" ]; then
            # 再次检查文件修改时间，确保文件稳定（避免正在写入的文件）
            sleep 0.1
            local verify_mtime=$(get_file_mtime "$watch_path")

            if [ "$current_mtime" = "$verify_mtime" ]; then
                echo "$watch_path"
                # 原子性更新状态文件
                local temp_state="${state_file}.tmp.$$"
                {
                    grep -v "^$watch_path:" "$state_file" 2>/dev/null || true
                    echo "$watch_path:$verify_mtime"
                } > "$temp_state"

                if mv "$temp_state" "$state_file" 2>/dev/null; then
                    log_debug "状态文件更新成功: $watch_path"
                else
                    log_warn "状态文件更新失败: $watch_path"
                    rm -f "$temp_state" 2>/dev/null || true
                fi
            else
                log_debug "文件仍在变化，跳过: $watch_path"
            fi
        fi
    elif [ -d "$watch_path" ]; then
        # 目录监控
        # 扫描目录中的所有文件
        find "$watch_path" -type f | while read -r file; do
            # 检查是否应该排除
            if should_exclude_file "$file"; then
                continue
            fi

            local current_mtime=$(get_file_mtime "$file")
            local stored_mtime=$(grep "^$file:" "$state_file" | cut -d: -f2)

            if [ "$current_mtime" != "$stored_mtime" ]; then
                echo "$file"
            fi
        done

        # 批量更新状态文件（在循环外）
        local temp_state="${state_file}.tmp"
        find "$watch_path" -type f | while read -r file; do
            if ! should_exclude_file "$file"; then
                local current_mtime=$(get_file_mtime "$file")
                echo "$file:$current_mtime"
            fi
        done > "$temp_state"

        if [ -f "$temp_state" ]; then
            mv "$temp_state" "$state_file"
        fi
    else
        # 将错误输出到stderr，不影响函数返回值
        echo "监控路径既不是文件也不是目录: $watch_path" >&2
    fi
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
    local relative_path
    if [ -f "$base_path" ]; then
        # 如果base_path是文件，则使用文件名作为相对路径
        relative_path=$(basename "$local_file")
    else
        # 如果base_path是目录，则计算相对路径
        relative_path="${local_file#$base_path/}"
    fi

    # 构建目标路径
    local target_path
    if [ -n "$target_base" ]; then
        target_path="$target_base/$relative_path"
    else
        target_path="$relative_path"
    fi
    
    # 清理路径（移除多余的斜杠和开头的斜杠）
    target_path=$(echo "$target_path" | sed 's|//*|/|g' | sed 's|^/||' | sed 's|/$||')
    
    # 生成提交消息
    local commit_message
    if [ "$AUTO_COMMIT" = "true" ]; then
        commit_message=$(printf "$COMMIT_MESSAGE_TEMPLATE" "$relative_path")
    else
        commit_message="Update $relative_path"
    fi
    
    log_info "同步文件: $local_file -> $repo/$target_path"

    # 使用重试机制上传文件
    if github_api_with_retry upload_file_to_github "$local_file" "$repo" "$branch" "$target_path" "$commit_message"; then
        log_success "文件同步成功: $relative_path"
        return 0
    else
        log_error "文件同步失败: $relative_path"
        return 1
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
    
    if [ ! -e "$local_path" ]; then
        log_error "监控路径不存在: $local_path"
        return 1
    fi
    
    # 设置默认目标路径
    [ -z "$target_path" ] && target_path=""
    
    log_debug "处理同步路径: $local_path -> $repo:$branch/$target_path"

    # 扫描文件变化
    local changed_files
    # 完全静默执行，避免任何输出混乱
    changed_files=$(scan_directory_changes "$local_path" 2>/dev/null | grep -v "^$")

    if [ -n "$changed_files" ]; then
        # 计算实际的文件数量（过滤空行）
        local file_count=0
        local valid_files=""

        echo "$changed_files" | while read -r file; do
            if [ -n "$file" ] && [ -f "$file" ]; then
                file_count=$((file_count + 1))
                valid_files="$valid_files$file\n"
            fi
        done

        # 重新计算文件数量
        file_count=$(echo "$changed_files" | grep -c "^/" 2>/dev/null || echo "0")
        if [ "$file_count" -gt 0 ]; then
            log_info "发现 $file_count 个文件变化"

            echo "$changed_files" | while read -r file; do
                if [ -n "$file" ] && [ -f "$file" ]; then
                    sync_file "$file" "$repo" "$branch" "$local_path" "$target_path"
                fi
            done
        fi
    else
        log_debug "未发现文件变化: $local_path"
    fi
}

# 主监控循环
monitor_loop() {
    # 验证轮询间隔
    local poll_interval=${POLL_INTERVAL:-$DEFAULT_POLL_INTERVAL}

    # 确保轮询间隔是有效数字且不小于5秒
    if ! is_valid_number "$poll_interval" || [ "$poll_interval" -lt 5 ]; then
        log_warn "无效的轮询间隔: $poll_interval，使用默认值: $DEFAULT_POLL_INTERVAL"
        poll_interval=$DEFAULT_POLL_INTERVAL
    fi

    log_info "开始文件监控，轮询间隔: ${poll_interval}秒"

    # 启动时检查是否需要清理日志
    periodic_log_cleanup

    # 循环计数器，用于调试和监控
    local loop_count=0

    while true; do
        loop_count=$((loop_count + 1))
        log_debug "监控循环第 $loop_count 次"

        # 轮转日志（基于文件大小）
        rotate_log

        # 每天清理一次日志
        periodic_log_cleanup

        # 验证同步路径配置
        if [ -z "$SYNC_PATHS" ]; then
            log_error "同步路径配置为空，停止监控"
            break
        fi

        # 处理所有同步路径
        echo "$SYNC_PATHS" | while IFS='|' read -r local_path repo branch target_path; do
            if [ -n "$local_path" ]; then
                process_sync_path "$local_path|$repo|$branch|$target_path" || {
                    log_warn "处理同步路径失败: $local_path"
                }
            fi
        done

        # 等待下一次轮询，确保sleep命令成功
        log_debug "等待 ${poll_interval} 秒后进行下一次轮询"
        if ! sleep "$poll_interval"; then
            log_error "sleep命令失败，可能收到信号，退出监控循环"
            break
        fi
    done

    log_info "监控循环结束"
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

    # 设置清理函数，确保异常退出时清理资源
    cleanup_on_error() {
        log_error "启动过程中发生错误，清理资源..."
        rm -f "$LOCK_FILE" "$PID_FILE"
        exit 1
    }

    # 设置错误处理
    trap 'cleanup_on_error' ERR

    log_info "启动GitHub同步服务..."

    # 验证配置
    if ! load_config; then
        log_error "配置文件加载失败"
        rm -f "$LOCK_FILE"
        return 1
    fi

    if ! validate_config; then
        log_error "配置验证失败"
        rm -f "$LOCK_FILE"
        return 1
    fi

    # 检查日志文件目录是否可写
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        if ! mkdir -p "$log_dir" 2>/dev/null; then
            log_error "无法创建日志目录: $log_dir"
            rm -f "$LOCK_FILE"
            return 1
        fi
    fi

    if [ ! -w "$log_dir" ]; then
        log_error "日志目录不可写: $log_dir"
        rm -f "$LOCK_FILE"
        return 1
    fi

    # 启动后台进程
    {
        # 设置守护进程模式标志
        export DAEMON_MODE=true
        export GITHUB_SYNC_QUIET=true

        # 记录PID
        echo $$ > "$PID_FILE"

        # 验证PID文件写入成功
        if [ ! -f "$PID_FILE" ]; then
            log_error "无法创建PID文件: $PID_FILE"
            rm -f "$LOCK_FILE"
            exit 1
        fi

        # 清理锁文件
        rm -f "$LOCK_FILE"

        # 设置信号处理
        trap 'cleanup_and_exit' TERM INT HUP

        # 开始监控
        monitor_loop
    } >> "$LOG_FILE" 2>&1 &

    # 记录后台进程PID
    local daemon_pid=$!

    # 等待一下确保启动成功
    sleep 2

    # 验证启动状态
    if is_running; then
        log_info "GitHub同步服务启动成功 (PID: $(cat "$PID_FILE"))"
        # 清理错误处理
        trap - ERR
        return 0
    else
        log_error "GitHub同步服务启动失败"
        # 清理资源
        rm -f "$LOCK_FILE" "$PID_FILE"
        # 尝试杀死可能的僵尸进程
        if kill -0 "$daemon_pid" 2>/dev/null; then
            kill "$daemon_pid" 2>/dev/null || true
        fi
        # 清理错误处理
        trap - ERR
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
PROG="$PROJECT_DIR/github-sync.sh"

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

# 创建便捷启动脚本
create_launcher_script() {
    local launcher_script="${PROJECT_DIR}/github-sync-launcher.sh"

    cat > "$launcher_script" << 'EOF'
#!/bin/sh
#
# GitHub 同步工具启动脚本
# 这个脚本可以放在 /usr/local/bin/ 目录中，方便从任何地方调用
#

# 项目目录
PROJECT_DIR="/root/github-sync"
MAIN_SCRIPT="$PROJECT_DIR/github-sync.sh"

# 检查项目目录是否存在
if [ ! -d "$PROJECT_DIR" ]; then
    echo "错误: 项目目录不存在: $PROJECT_DIR"
    echo "请先运行安装程序或手动创建项目目录"
    exit 1
fi

# 检查主脚本是否存在
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo "错误: 主脚本不存在: $MAIN_SCRIPT"
    echo "请先运行安装程序"
    exit 1
fi

# 检查主脚本是否可执行
if [ ! -x "$MAIN_SCRIPT" ]; then
    echo "警告: 主脚本不可执行，正在修复权限..."
    chmod +x "$MAIN_SCRIPT"
fi

# 切换到项目目录并执行主脚本
cd "$PROJECT_DIR" || {
    echo "错误: 无法切换到项目目录: $PROJECT_DIR"
    exit 1
}

# 传递所有参数给主脚本
exec "$MAIN_SCRIPT" "$@"
EOF

    chmod +x "$launcher_script" 2>/dev/null || true

    log_info "已创建启动脚本: $launcher_script"

    # 尝试安装到系统路径
    if [ -w "/usr/local/bin" ] 2>/dev/null; then
        if cp "$launcher_script" "/usr/local/bin/github-sync" 2>/dev/null; then
            chmod +x "/usr/local/bin/github-sync" 2>/dev/null || true
            log_info "启动脚本已安装到: /usr/local/bin/github-sync"
            log_info "现在可以在任何地方使用 'github-sync' 命令"
        fi
    elif [ -w "/usr/bin" ] 2>/dev/null; then
        if cp "$launcher_script" "/usr/bin/github-sync" 2>/dev/null; then
            chmod +x "/usr/bin/github-sync" 2>/dev/null || true
            log_info "启动脚本已安装到: /usr/bin/github-sync"
            log_info "现在可以在任何地方使用 'github-sync' 命令"
        fi
    else
        log_warn "无法安装到系统路径，请手动复制 $launcher_script 到 /usr/local/bin/github-sync"
    fi
}

# 完整安装
install() {
    log_info "开始安装GitHub同步工具..."

    # 确保项目目录存在
    ensure_project_directory

    # 复制脚本到项目目录（如果不在项目目录中运行）
    local current_script="$(readlink -f "$0")"
    local target_script="${PROJECT_DIR}/github-sync.sh"

    if [ "$current_script" != "$target_script" ]; then
        log_info "复制脚本到项目目录..."
        if cp "$current_script" "$target_script" 2>/dev/null; then
            chmod +x "$target_script"
            log_info "脚本已复制到: $target_script"
        else
            log_warn "无法复制脚本到项目目录，继续使用当前位置"
        fi
    fi

    # 安装依赖
    install_dependencies

    # 创建配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        create_default_config
        log_info "请编辑配置文件: $CONFIG_FILE"
    fi

    # 创建便捷启动脚本
    create_launcher_script

    # 安装服务
    install_service

    log_info "安装完成！"
    log_info "项目目录: $PROJECT_DIR"
    log_info "配置文件: $CONFIG_FILE"
    log_info "便捷命令: github-sync (如果安装到系统路径)"
    log_info "请编辑配置文件然后运行: $target_script start"
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
    cleanup         清理日志文件
    list            列出所有实例
    help            显示此帮助信息

选项:
    -i, --instance NAME  指定实例名称（默认: default）
    -c, --config FILE    指定配置文件路径
    -v, --verbose        详细输出
    -q, --quiet          静默模式

多实例支持:
    # 为不同项目创建独立实例
    $0 -i project1 config    # 配置project1实例
    $0 -i project1 start     # 启动project1实例
    $0 -i project2 config    # 配置project2实例
    $0 -i project2 start     # 启动project2实例
    $0 list                  # 列出所有实例

示例:
    $0 install               # 安装工具
    $0 config                # 编辑默认实例配置
    $0 -i subs-check config  # 编辑subs-check实例配置
    $0 test                  # 测试默认实例
    $0 -i subs-check start   # 启动subs-check实例
    $0 status                # 查看默认实例状态
    $0 list                  # 列出所有实例状态

日志管理:
    • 自动轮转: 文件大小超过1MB时自动轮转
    • 自动清理: 每天凌晨2-6点清理过期日志
    • 保留策略: 默认保留7天，最多10个文件

项目目录结构:
  $PROJECT_DIR/
  ├── config/          # 配置文件目录
  ├── logs/            # 日志文件目录
  ├── data/            # 数据文件目录 (PID, 锁文件, 状态文件)
  ├── tmp/             # 临时文件目录
  └── backup/          # 备份文件目录

当前实例: $INSTANCE_NAME
配置文件: $CONFIG_FILE
日志文件: $LOG_FILE
EOF
}

# 交互式配置编辑
edit_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        log_warn "配置文件不存在，将创建新配置"
        echo ""
        echo "选择创建方式："
        echo "1) 使用配置向导创建"
        echo "2) 创建默认配置文件"
        echo "3) 取消"
        echo ""
        echo -n "请选择 [1-3]: "
        read -r create_choice

        case "$create_choice" in
            1)
                run_setup_wizard
                return $?
                ;;
            2)
                create_default_config
                ;;
            *)
                log_info "取消创建配置文件"
                return 0
                ;;
        esac
    fi

    # 显示交互式配置编辑菜单
    show_config_edit_menu
}

# 显示配置摘要
show_config_summary() {
    # 加载并显示当前配置
    if load_config 2>/dev/null; then
        echo "[配置] 当前配置摘要:"
        echo "=================================================================="
        echo "  GitHub用户: ${GITHUB_USERNAME:-未设置}"
        echo "  轮询间隔: ${POLL_INTERVAL:-未设置}秒"
        echo "  日志级别: ${LOG_LEVEL:-未设置}"

        # 统计同步路径数量
        if [ -n "$SYNC_PATHS" ]; then
            local path_count=$(echo "$SYNC_PATHS" | grep -c "|" 2>/dev/null || echo "0")
            echo "  同步路径: $path_count 个"
        else
            echo "  同步路径: 未配置"
        fi

        echo "  自动提交: ${AUTO_COMMIT:-未设置}"
        echo "=================================================================="
    else
        echo "[警告] 无法加载配置文件或配置文件格式错误"
        echo "=================================================================="
    fi
}

# 显示配置编辑菜单选项
show_config_menu_options() {
    echo ""
    echo "[编辑] 配置编辑选项:"
    echo ""
    echo "  基本配置:"
    echo "    1) 编辑GitHub凭据        [g]"
    echo "    2) 编辑同步路径          [p]"
    echo "    3) 编辑监控设置          [m]"
    echo ""
    echo "  高级配置:"
    echo "    4) 编辑文件过滤规则      [f]"
    echo "    5) 编辑提交设置          [t]"
    echo "    6) 编辑网络设置          [n]"
    echo ""
    echo "  配置管理:"
    echo "    7) 查看完整配置文件      [v]"
    echo "    8) 重置为默认配置        [r]"
    echo "    9) 使用文本编辑器        [e]"
    echo "   10) 运行配置向导          [w]"
    echo ""
    echo "   11) 测试配置             [s]"
    echo "   12) 保存并退出           [q]"
    echo ""
    echo -n "请选择操作 [1-12] 或快捷键: "
}

# 显示配置编辑菜单
show_config_edit_menu() {
    while true; do
        clear
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    配置文件编辑器                            ║"
        echo "║                Configuration File Editor                     ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""

        # 显示配置摘要
        show_config_summary

        # 显示菜单选项
        show_config_menu_options

        read -r edit_choice

        case "$edit_choice" in
            1|g|G)
                edit_github_section
                ;;
            2|p|P)
                edit_sync_paths_section
                ;;
            3|m|M)
                edit_monitoring_section
                ;;
            4|f|F)
                edit_filter_section
                ;;
            5|t|T)
                edit_commit_section
                ;;
            6|n|N)
                edit_network_section
                ;;
            7|v|V)
                show_full_config
                ;;
            8|r|R)
                reset_to_default_config
                ;;
            9|e|E)
                edit_with_text_editor
                ;;
            10|w|W)
                run_setup_wizard
                return $?
                ;;
            11|s|S)
                test_current_config
                ;;
            12|q|Q)
                echo ""
                log_info "配置编辑完成"
                return 0
                ;;
            "")
                # 刷新菜单
                continue
                ;;
            *)
                echo ""
                log_error "无效选项: $edit_choice"
                echo "按任意键继续..."
                read -r
                ;;
        esac
    done
}

# 编辑GitHub凭据部分
edit_github_section() {
    echo ""
    echo "[GitHub] 编辑GitHub凭据"
    echo "=================="
    echo ""

    # 显示当前设置
    if [ -n "$GITHUB_USERNAME" ]; then
        echo "当前GitHub用户名: $GITHUB_USERNAME"
    else
        echo "当前GitHub用户名: 未设置"
    fi

    if [ -n "$GITHUB_TOKEN" ]; then
        echo "当前GitHub令牌: ${GITHUB_TOKEN:0:10}... (已隐藏)"
    else
        echo "当前GitHub令牌: 未设置"
    fi

    echo ""
    echo "1) 修改GitHub用户名"
    echo "2) 修改GitHub令牌"
    echo "3) 同时修改用户名和令牌"
    echo "4) 返回上级菜单"
    echo ""
    echo -n "请选择 [1-4]: "
    read -r github_choice

    case "$github_choice" in
        1)
            echo ""
            echo -n "新的GitHub用户名: "
            read -r new_username
            if [ -n "$new_username" ]; then
                update_config_value "GITHUB_USERNAME" "$new_username"
                log_info "GitHub用户名已更新"
            fi
            ;;
        2)
            echo ""
            echo -n "新的GitHub令牌: "
            read -r new_token
            if [ -n "$new_token" ]; then
                update_config_value "GITHUB_TOKEN" "$new_token"
                log_info "GitHub令牌已更新"
            fi
            ;;
        3)
            get_github_credentials
            update_config_value "GITHUB_USERNAME" "$github_username"
            update_config_value "GITHUB_TOKEN" "$github_token"
            log_info "GitHub凭据已更新"
            ;;
        *)
            return 0
            ;;
    esac

    echo ""
    echo "按任意键继续..."
    read -r
}

# 通用的等待用户输入函数
wait_for_user_input() {
    echo ""
    echo "按任意键继续..."
    read -r
}

# 显示进度指示器
show_progress() {
    local message="$1"
    local duration="${2:-3}"

    echo -n "$message"
    for i in $(seq 1 "$duration"); do
        echo -n "."
        sleep 1
    done
    echo " 完成"
}

# 显示加载动画
show_loading() {
    local message="$1"
    local pid="$2"
    local delay=0.1
    local spinstr='|/-\'

    echo -n "$message "
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo " 完成"
}

# 确认操作函数增强
confirm_action_enhanced() {
    local prompt="$1"
    local default="${2:-N}"
    local warning="$3"

    echo ""
    if [ -n "$warning" ]; then
        echo -e "${YELLOW}⚠️  警告: $warning${NC}"
        echo ""
    fi

    while true; do
        echo -n "$prompt [$default]: "
        read -r response
        response=${response:-$default}

        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "请输入 Y/yes 或 N/no"
                ;;
        esac
    done
}

# 菜单缓存管理
update_menu_cache() {
    local current_time=$(date +%s)

    # 检查缓存是否过期
    if [ $((current_time - MENU_CACHE_TIME)) -lt $MENU_CACHE_DURATION ]; then
        return 0  # 缓存仍然有效
    fi

    # 更新配置状态缓存
    if [ -f "$CONFIG_FILE" ]; then
        MENU_CONFIG_CACHE="已配置"
        # 快速获取同步路径数量
        local path_count=$(grep -c "|" "$CONFIG_FILE" 2>/dev/null || echo "0")
        MENU_CONFIG_CACHE="$MENU_CONFIG_CACHE ($path_count 个路径)"
    else
        MENU_CONFIG_CACHE="未配置"
    fi

    # 更新服务状态缓存
    if is_running; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        MENU_STATUS_CACHE="运行中 (PID: $pid)"
    else
        MENU_STATUS_CACHE="已停止"
    fi

    MENU_CACHE_TIME=$current_time
}

# 获取缓存的状态信息
get_cached_status() {
    update_menu_cache
    echo "服务状态: $MENU_STATUS_CACHE"
    echo "配置状态: $MENU_CONFIG_CACHE"
}

# 菜单搜索功能
search_menu_options() {
    local search_term="$1"
    echo ""
    echo "搜索结果 (关键词: $search_term):"
    echo "================================"

    # 定义菜单项和对应的关键词
    local menu_items="
    1:启动服务:start,service,daemon,启动,服务
    2:停止服务:stop,service,daemon,停止,服务
    3:重启服务:restart,service,daemon,重启,服务
    4:查看状态:status,show,查看,状态
    5:编辑配置:config,edit,配置,编辑
    6:测试配置:test,config,测试,配置
    7:查看示例:example,config,示例,配置
    8:一次性同步:sync,once,同步,一次
    9:查看日志:log,show,日志,查看
    10:安装工具:install,tool,安装,工具
    11:配置向导:wizard,setup,向导,配置
    12:查看帮助:help,show,帮助,查看
    "

    local found=false
    echo "$menu_items" | while read -r line; do
        [ -z "$line" ] && continue

        local option=$(echo "$line" | cut -d: -f1)
        local name=$(echo "$line" | cut -d: -f2)
        local keywords=$(echo "$line" | cut -d: -f3)

        if echo "$keywords" | grep -qi "$search_term"; then
            echo "  $option) $name"
            found=true
        fi
    done

    if [ "$found" = "false" ]; then
        echo "  未找到匹配的菜单项"
    fi

    echo ""
    echo "输入对应数字执行操作，或按回车返回主菜单"
    echo -n "选择: "
    read -r choice
    echo "$choice"
}

# 通用的确认输入函数
confirm_action() {
    local prompt="$1"
    local default="${2:-N}"

    echo ""
    echo -n "$prompt [$default]: "
    read -r response

    # 如果用户没有输入，使用默认值
    response=${response:-$default}

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 编辑同步路径部分
edit_sync_paths_section() {
    echo ""
    echo "[路径] 编辑同步路径"
    echo "==============="
    echo ""

    # 显示当前同步路径
    if [ -n "$SYNC_PATHS" ]; then
        echo "当前同步路径:"
        local count=1
        echo "$SYNC_PATHS" | while IFS='|' read -r local_path repo branch target_path; do
            if [ -n "$local_path" ]; then
                echo "  $count) $local_path → $repo:$branch/$target_path"
                count=$((count + 1))
            fi
        done
    else
        echo "当前同步路径: 未配置"
    fi

    echo ""
    echo "1) 添加新的同步路径"
    echo "2) 删除现有同步路径"
    echo "3) 修改现有同步路径"
    echo "4) 清空所有同步路径"
    echo "5) 重新配置所有路径"
    echo "6) 返回上级菜单"
    echo ""
    echo -n "请选择 [1-6]: "
    read -r path_choice

    case "$path_choice" in
        1)
            add_sync_path
            ;;
        2)
            remove_sync_path
            ;;
        3)
            modify_sync_path
            ;;
        4)
            echo ""
            echo -n "确认清空所有同步路径？[y/N]: "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                update_config_value "SYNC_PATHS" ""
                log_info "已清空所有同步路径"
            fi
            ;;
        5)
            get_detailed_sync_paths
            update_config_value "SYNC_PATHS" "$sync_paths"
            log_info "同步路径已重新配置"
            ;;
        *)
            return 0
            ;;
    esac

    wait_for_user_input
}

# 编辑监控设置部分
edit_monitoring_section() {
    echo ""
    echo "[监控] 编辑监控设置"
    echo "==============="
    echo ""

    echo "当前监控设置:"
    echo "  轮询间隔: ${POLL_INTERVAL:-未设置}秒"
    echo "  日志级别: ${LOG_LEVEL:-未设置}"
    echo ""

    echo "1) 修改轮询间隔"
    echo "2) 修改日志级别"
    echo "3) 同时修改两项设置"
    echo "4) 返回上级菜单"
    echo ""
    echo -n "请选择 [1-4]: "
    read -r monitor_choice

    case "$monitor_choice" in
        1)
            echo ""
            echo "轮询间隔建议:"
            echo "  10秒 - 高频监控（开发环境）"
            echo "  30秒 - 标准监控（推荐）"
            echo "  60秒 - 低频监控（生产环境）"
            echo ""
            echo -n "新的轮询间隔（秒）: "
            read -r new_interval
            if echo "$new_interval" | grep -qE '^[0-9]+$' && [ "$new_interval" -ge 5 ]; then
                update_config_value "POLL_INTERVAL" "$new_interval"
                log_info "轮询间隔已更新为 ${new_interval}秒"
            else
                log_error "无效的轮询间隔"
            fi
            ;;
        2)
            echo ""
            echo "日志级别选择:"
            echo "1) DEBUG - 详细调试信息"
            echo "2) INFO  - 一般信息（推荐）"
            echo "3) WARN  - 仅警告和错误"
            echo "4) ERROR - 仅错误信息"
            echo ""
            echo -n "请选择 [1-4]: "
            read -r log_choice

            case "$log_choice" in
                1) new_log_level="DEBUG" ;;
                2) new_log_level="INFO" ;;
                3) new_log_level="WARN" ;;
                4) new_log_level="ERROR" ;;
                *) new_log_level="" ;;
            esac

            if [ -n "$new_log_level" ]; then
                update_config_value "LOG_LEVEL" "$new_log_level"
                log_info "日志级别已更新为 $new_log_level"
            fi
            ;;
        3)
            get_monitoring_settings
            update_config_value "POLL_INTERVAL" "$poll_interval"
            update_config_value "LOG_LEVEL" "$log_level"
            log_info "监控设置已更新"
            ;;
        *)
            return 0
            ;;
    esac

    wait_for_user_input
}

# 更新配置文件中的值
update_config_value() {
    local key="$1"
    local value="$2"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在"
        return 1
    fi

    # 创建临时文件
    local temp_file="${CONFIG_FILE}.tmp"

    # 检查键是否存在
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        # 更新现有值
        sed "s|^${key}=.*|${key}=\"${value}\"|" "$CONFIG_FILE" > "$temp_file"
    else
        # 添加新值
        cp "$CONFIG_FILE" "$temp_file"
        echo "${key}=\"${value}\"" >> "$temp_file"
    fi

    # 替换原文件
    mv "$temp_file" "$CONFIG_FILE"
}

# 添加同步路径
add_sync_path() {
    echo ""
    echo "[添加] 添加新的同步路径"
    echo "==================="
    echo ""

    # 获取本地路径
    local local_path=""
    while true; do
        echo -n "本地路径: "
        read -r local_path

        if [ -z "$local_path" ]; then
            log_error "本地路径不能为空"
            continue
        fi

        # 清理路径
        local_path=$(echo "$local_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 展开波浪号
        case "$local_path" in
            "~"*) local_path="$HOME${local_path#~}" ;;
        esac

        if [ ! -e "$local_path" ]; then
            echo "[警告] 路径不存在: $local_path"
            echo -n "是否继续添加？[y/N]: "
            read -r continue_add
            if [ "$continue_add" != "y" ] && [ "$continue_add" != "Y" ]; then
                continue
            fi
        elif [ ! -r "$local_path" ]; then
            log_error "路径不可读: $local_path"
            echo -n "是否继续添加？[y/N]: "
            read -r continue_add
            if [ "$continue_add" != "y" ] && [ "$continue_add" != "Y" ]; then
                continue
            fi
        fi
        break
    done

    # 获取GitHub仓库
    local repo=""
    while true; do
        echo -n "GitHub仓库 (格式: 用户名/仓库名): "
        read -r repo

        if [ -z "$repo" ]; then
            log_error "GitHub仓库不能为空"
            continue
        fi

        # 清理仓库名
        repo=$(echo "$repo" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 验证仓库格式
        if ! echo "$repo" | grep -qE '^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$'; then
            log_error "GitHub仓库格式错误: $repo"
            echo "正确格式: 用户名/仓库名 (只能包含字母、数字、点、下划线、连字符)"
            continue
        fi
        break
    done

    # 获取分支名
    local branch=""
    while true; do
        echo -n "分支 (默认main): "
        read -r branch
        branch=${branch:-main}

        # 清理分支名
        branch=$(echo "$branch" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 验证分支名格式
        if ! echo "$branch" | grep -qE '^[a-zA-Z0-9._/-]+$'; then
            log_error "分支名格式错误: $branch"
            echo "分支名只能包含字母、数字、点、下划线、连字符、斜杠"
            continue
        fi
        break
    done

    # 获取目标路径
    echo -n "目标路径 (可留空): "
    read -r target_path

    # 清理目标路径
    target_path=$(echo "$target_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # 验证目标路径格式（如果不为空）
    if [ -n "$target_path" ]; then
        if echo "$target_path" | grep -q '[<>:"|?*]'; then
            log_warn "目标路径包含可能有问题的字符: $target_path"
            echo -n "是否继续？[y/N]: "
            read -r continue_target
            if [ "$continue_target" != "y" ] && [ "$continue_target" != "Y" ]; then
                return 0
            fi
        fi

        # 清理路径格式
        target_path=$(echo "$target_path" | sed 's|^/||' | sed 's|/$||' | sed 's|//*|/|g')
    fi

    # 检查是否已存在相同的路径配置
    if [ -n "$SYNC_PATHS" ]; then
        local existing_check=$(echo "$SYNC_PATHS" | grep "^$local_path|")
        if [ -n "$existing_check" ]; then
            log_warn "本地路径已存在于配置中: $local_path"
            echo -n "是否继续添加？[y/N]: "
            read -r continue_duplicate
            if [ "$continue_duplicate" != "y" ] && [ "$continue_duplicate" != "Y" ]; then
                return 0
            fi
        fi
    fi

    # 构建新的同步路径条目
    local new_path="$local_path|$repo|$branch|$target_path"

    # 添加到现有路径
    if [ -n "$SYNC_PATHS" ]; then
        local updated_paths="$SYNC_PATHS
$new_path"
    else
        local updated_paths="$new_path"
    fi

    # 更新配置并重新加载
    update_config_value "SYNC_PATHS" "$updated_paths"
    load_config

    log_success "已添加同步路径: $local_path → $repo:$branch/$target_path"

    # 询问是否测试新添加的路径
    echo ""
    echo -n "是否测试新添加的同步路径？[Y/n]: "
    read -r test_new
    if [ "$test_new" != "n" ] && [ "$test_new" != "N" ]; then
        echo ""
        echo "测试同步路径..."
        if process_sync_path "$new_path"; then
            log_success "同步路径测试成功"
        else
            log_error "同步路径测试失败，请检查配置"
        fi
    fi
}

# 删除同步路径
remove_sync_path() {
    echo ""
    echo "[删除] 删除同步路径"
    echo "==============="
    echo ""

    if [ -z "$SYNC_PATHS" ]; then
        log_warn "没有配置的同步路径"
        return 0
    fi

    # 显示当前同步路径并收集到数组
    echo "当前同步路径:"
    local count=1
    local temp_file=$(create_temp_file "paths_list")

    echo "$SYNC_PATHS" | while IFS='|' read -r local_path repo branch target_path; do
        if [ -n "$local_path" ]; then
            echo "  $count) $local_path → $repo:$branch/$target_path"
            echo "$local_path|$repo|$branch|$target_path" >> "$temp_file"
            count=$((count + 1))
        fi
    done

    # 获取路径总数
    local total_paths=$(wc -l < "$temp_file" 2>/dev/null || echo "0")

    if [ "$total_paths" -eq 0 ]; then
        log_warn "没有有效的同步路径"
        rm -f "$temp_file"
        return 0
    fi

    echo ""
    echo -n "请输入要删除的路径编号 (1-$total_paths, 0取消): "
    read -r delete_num

    if [ "$delete_num" = "0" ] || [ -z "$delete_num" ]; then
        rm -f "$temp_file"
        return 0
    fi

    # 验证输入
    if ! is_valid_number "$delete_num" || [ "$delete_num" -lt 1 ] || [ "$delete_num" -gt "$total_paths" ]; then
        log_error "无效的路径编号: $delete_num"
        rm -f "$temp_file"
        return 1
    fi

    # 获取要删除的路径信息
    local target_line=$(sed -n "${delete_num}p" "$temp_file")
    local target_local_path=$(echo "$target_line" | cut -d'|' -f1)
    local target_repo=$(echo "$target_line" | cut -d'|' -f2)
    local target_branch=$(echo "$target_line" | cut -d'|' -f3)
    local target_target_path=$(echo "$target_line" | cut -d'|' -f4)

    echo ""
    echo "要删除的同步路径:"
    echo "  本地路径: $target_local_path"
    echo "  GitHub仓库: $target_repo"
    echo "  分支: $target_branch"
    echo "  目标路径: $target_target_path"
    echo ""
    echo -n "确认删除此同步路径？[y/N]: "
    read -r confirm

    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        # 构建新的SYNC_PATHS（排除要删除的路径）
        local new_sync_paths=""
        local current_line=1

        while read -r line; do
            if [ "$current_line" -ne "$delete_num" ]; then
                if [ -z "$new_sync_paths" ]; then
                    new_sync_paths="$line"
                else
                    new_sync_paths="$new_sync_paths
$line"
                fi
            fi
            current_line=$((current_line + 1))
        done < "$temp_file"

        # 更新配置文件
        update_config_value "SYNC_PATHS" "$new_sync_paths"
        log_success "已删除同步路径: $target_local_path → $target_repo:$target_branch"

        # 重新加载配置
        load_config
    else
        log_info "取消删除操作"
    fi

    rm -f "$temp_file"
}

# 修改同步路径
modify_sync_path() {
    echo ""
    echo "[编辑] 修改同步路径"
    echo "==============="
    echo ""

    if [ -z "$SYNC_PATHS" ]; then
        log_warn "没有配置的同步路径"
        return 0
    fi

    # 显示当前同步路径
    echo "当前同步路径:"
    local count=1
    local temp_file=$(create_temp_file "paths_modify")

    echo "$SYNC_PATHS" | while IFS='|' read -r local_path repo branch target_path; do
        if [ -n "$local_path" ]; then
            echo "  $count) $local_path → $repo:$branch/$target_path"
            echo "$local_path|$repo|$branch|$target_path" >> "$temp_file"
            count=$((count + 1))
        fi
    done

    # 获取路径总数
    local total_paths=$(wc -l < "$temp_file" 2>/dev/null || echo "0")

    if [ "$total_paths" -eq 0 ]; then
        log_warn "没有有效的同步路径"
        rm -f "$temp_file"
        return 0
    fi

    echo ""
    echo "选择操作:"
    echo "1) 修改指定路径"
    echo "2) 重新配置所有路径"
    echo "3) 返回上级菜单"
    echo ""
    echo -n "请选择 [1-3]: "
    read -r modify_choice

    case "$modify_choice" in
        1)
            echo ""
            echo -n "请输入要修改的路径编号 (1-$total_paths): "
            read -r modify_num

            if ! is_valid_number "$modify_num" || [ "$modify_num" -lt 1 ] || [ "$modify_num" -gt "$total_paths" ]; then
                log_error "无效的路径编号: $modify_num"
                rm -f "$temp_file"
                return 1
            fi

            # 获取要修改的路径信息
            local target_line=$(sed -n "${modify_num}p" "$temp_file")
            local old_local_path=$(echo "$target_line" | cut -d'|' -f1)
            local old_repo=$(echo "$target_line" | cut -d'|' -f2)
            local old_branch=$(echo "$target_line" | cut -d'|' -f3)
            local old_target_path=$(echo "$target_line" | cut -d'|' -f4)

            echo ""
            echo "当前配置:"
            echo "  本地路径: $old_local_path"
            echo "  GitHub仓库: $old_repo"
            echo "  分支: $old_branch"
            echo "  目标路径: $old_target_path"
            echo ""

            # 获取新配置
            echo "输入新配置 (直接按回车保持原值):"

            echo -n "本地路径 [$old_local_path]: "
            read -r new_local_path
            new_local_path=${new_local_path:-$old_local_path}
            new_local_path=$(normalize_path "$new_local_path")

            echo -n "GitHub仓库 [$old_repo]: "
            read -r new_repo
            new_repo=${new_repo:-$old_repo}

            echo -n "分支 [$old_branch]: "
            read -r new_branch
            new_branch=${new_branch:-$old_branch}

            echo -n "目标路径 [$old_target_path]: "
            read -r new_target_path
            new_target_path=${new_target_path:-$old_target_path}

            # 验证新配置
            if [ -n "$new_local_path" ] && [ ! -e "$new_local_path" ]; then
                log_warn "新本地路径不存在: $new_local_path"
                echo -n "是否继续？[y/N]: "
                read -r continue_modify
                if [ "$continue_modify" != "y" ] && [ "$continue_modify" != "Y" ]; then
                    rm -f "$temp_file"
                    return 0
                fi
            fi

            if ! validate_repo_name "$new_repo"; then
                log_error "GitHub仓库格式错误: $new_repo"
                rm -f "$temp_file"
                return 1
            fi

            if ! validate_branch_name "$new_branch"; then
                log_error "分支名格式错误: $new_branch"
                rm -f "$temp_file"
                return 1
            fi

            # 构建新的SYNC_PATHS
            local new_sync_paths=""
            local current_line=1

            while read -r line; do
                if [ "$current_line" -eq "$modify_num" ]; then
                    local new_line="$new_local_path|$new_repo|$new_branch|$new_target_path"
                    if [ -z "$new_sync_paths" ]; then
                        new_sync_paths="$new_line"
                    else
                        new_sync_paths="$new_sync_paths
$new_line"
                    fi
                else
                    if [ -z "$new_sync_paths" ]; then
                        new_sync_paths="$line"
                    else
                        new_sync_paths="$new_sync_paths
$line"
                    fi
                fi
                current_line=$((current_line + 1))
            done < "$temp_file"

            # 更新配置文件
            update_config_value "SYNC_PATHS" "$new_sync_paths"
            load_config
            log_success "同步路径已修改: $new_local_path → $new_repo:$new_branch"
            ;;
        2)
            get_detailed_sync_paths
            update_config_value "SYNC_PATHS" "$sync_paths"
            load_config
            log_success "同步路径已重新配置"
            ;;
        *)
            ;;
    esac

    rm -f "$temp_file"
}

# 编辑文件过滤规则
edit_filter_section() {
    echo ""
    echo "[过滤] 编辑文件过滤规则"
    echo "==================="
    echo ""

    echo "当前排除模式:"
    echo "  ${EXCLUDE_PATTERNS:-未设置}"
    echo ""

    echo "1) 使用预设过滤规则"
    echo "2) 自定义过滤规则"
    echo "3) 添加额外过滤规则"
    echo "4) 返回上级菜单"
    echo ""
    echo -n "请选择 [1-4]: "
    read -r filter_choice

    case "$filter_choice" in
        1)
            echo ""
            echo "预设过滤规则:"
            echo "1) 基础过滤 - *.tmp *.log *.pid *.lock .git"
            echo "2) 开发环境 - 基础 + *.swp *~ .DS_Store *.pyc __pycache__"
            echo "3) 生产环境 - 基础 + *.backup *.cache *.orig"
            echo "4) OpenWrt - 基础 + .uci-* *.orig"
            echo ""
            echo -n "请选择预设 [1-4]: "
            read -r preset_choice

            case "$preset_choice" in
                1) new_patterns="*.tmp *.log *.pid *.lock .git" ;;
                2) new_patterns="*.tmp *.log *.pid *.lock .git *.swp *~ .DS_Store *.pyc __pycache__" ;;
                3) new_patterns="*.tmp *.log *.pid *.lock .git *.backup *.cache *.orig" ;;
                4) new_patterns="*.tmp *.log *.pid *.lock .git .uci-* *.orig" ;;
                *) new_patterns="" ;;
            esac

            if [ -n "$new_patterns" ]; then
                update_config_value "EXCLUDE_PATTERNS" "$new_patterns"
                log_info "过滤规则已更新"
            fi
            ;;
        2)
            echo ""
            echo -n "自定义过滤规则 (用空格分隔): "
            read -r custom_patterns
            if [ -n "$custom_patterns" ]; then
                update_config_value "EXCLUDE_PATTERNS" "$custom_patterns"
                log_info "过滤规则已更新"
            fi
            ;;
        3)
            echo ""
            echo -n "额外过滤规则 (用空格分隔): "
            read -r extra_patterns
            if [ -n "$extra_patterns" ]; then
                local combined_patterns="$EXCLUDE_PATTERNS $extra_patterns"
                update_config_value "EXCLUDE_PATTERNS" "$combined_patterns"
                log_info "过滤规则已更新"
            fi
            ;;
        *)
            return 0
            ;;
    esac

    wait_for_user_input
}

# 编辑提交设置
edit_commit_section() {
    echo ""
    echo "[提交] 编辑提交设置"
    echo "==============="
    echo ""

    echo "当前提交设置:"
    echo "  自动提交: ${AUTO_COMMIT:-未设置}"
    echo "  提交消息模板: ${COMMIT_MESSAGE_TEMPLATE:-未设置}"
    echo ""

    echo "1) 修改自动提交设置"
    echo "2) 修改提交消息模板"
    echo "3) 同时修改两项设置"
    echo "4) 返回上级菜单"
    echo ""
    echo -n "请选择 [1-4]: "
    read -r commit_choice

    case "$commit_choice" in
        1)
            echo ""
            echo -n "启用自动提交？[Y/n]: "
            read -r auto_choice
            if [ "$auto_choice" = "n" ] || [ "$auto_choice" = "N" ]; then
                update_config_value "AUTO_COMMIT" "false"
                log_info "自动提交已禁用"
            else
                update_config_value "AUTO_COMMIT" "true"
                log_info "自动提交已启用"
            fi
            ;;
        2)
            echo ""
            echo "提交消息模板变量:"
            echo "  %s - 文件相对路径"
            echo "  \$(hostname) - 主机名"
            echo "  \$(date) - 当前日期"
            echo ""
            echo -n "新的提交消息模板: "
            read -r new_template
            if [ -n "$new_template" ]; then
                update_config_value "COMMIT_MESSAGE_TEMPLATE" "$new_template"
                log_info "提交消息模板已更新"
            fi
            ;;
        3)
            get_basic_advanced_options
            update_config_value "AUTO_COMMIT" "$auto_commit"
            update_config_value "COMMIT_MESSAGE_TEMPLATE" "$commit_template"
            log_info "提交设置已更新"
            ;;
        *)
            return 0
            ;;
    esac

    echo ""
    echo "按任意键继续..."
    read -r
}

# 编辑网络设置
edit_network_section() {
    echo ""
    echo "[网络] 编辑网络设置"
    echo "==============="
    echo ""

    echo "当前网络设置:"
    echo "  HTTP超时: ${HTTP_TIMEOUT:-未设置}秒"
    echo "  SSL验证: ${VERIFY_SSL:-未设置}"
    echo "  最大重试: ${MAX_RETRIES:-未设置}次"
    echo "  重试间隔: ${RETRY_INTERVAL:-未设置}秒"
    echo ""

    echo "1) 修改HTTP超时时间"
    echo "2) 修改SSL验证设置"
    echo "3) 修改重试设置"
    echo "4) 配置代理设置"
    echo "5) 重新配置所有网络设置"
    echo "6) 返回上级菜单"
    echo ""
    echo -n "请选择 [1-6]: "
    read -r network_choice

    case "$network_choice" in
        1)
            echo ""
            echo -n "HTTP超时时间（秒，默认30）: "
            read -r timeout
            timeout=${timeout:-30}
            if echo "$timeout" | grep -qE '^[0-9]+$'; then
                update_config_value "HTTP_TIMEOUT" "$timeout"
                log_info "HTTP超时时间已更新为 ${timeout}秒"
            fi
            ;;
        2)
            echo ""
            echo -n "启用SSL证书验证？[Y/n]: "
            read -r ssl_choice
            if [ "$ssl_choice" = "n" ] || [ "$ssl_choice" = "N" ]; then
                update_config_value "VERIFY_SSL" "false"
                log_info "SSL验证已禁用"
            else
                update_config_value "VERIFY_SSL" "true"
                log_info "SSL验证已启用"
            fi
            ;;
        3)
            echo ""
            echo -n "最大重试次数（默认3）: "
            read -r retries
            retries=${retries:-3}
            echo -n "重试间隔（秒，默认5）: "
            read -r interval
            interval=${interval:-5}

            update_config_value "MAX_RETRIES" "$retries"
            update_config_value "RETRY_INTERVAL" "$interval"
            log_info "重试设置已更新"
            ;;
        4)
            echo ""
            echo -n "是否配置HTTP代理？[y/N]: "
            read -r use_proxy
            if [ "$use_proxy" = "y" ] || [ "$use_proxy" = "Y" ]; then
                echo -n "HTTP代理地址: "
                read -r proxy_addr
                if [ -n "$proxy_addr" ]; then
                    update_config_value "HTTP_PROXY" "$proxy_addr"
                    update_config_value "HTTPS_PROXY" "$proxy_addr"
                    log_info "代理设置已更新"
                fi
            else
                # 删除代理设置
                sed -i '/^HTTP_PROXY=/d' "$CONFIG_FILE" 2>/dev/null || true
                sed -i '/^HTTPS_PROXY=/d' "$CONFIG_FILE" 2>/dev/null || true
                log_info "代理设置已清除"
            fi
            ;;
        5)
            echo -n "HTTP超时时间（秒，默认30）: "
            read -r http_timeout
            http_timeout=${http_timeout:-30}
            update_config_value "HTTP_TIMEOUT" "$http_timeout"
            log_info "网络设置已更新"
            ;;
        *)
            return 0
            ;;
    esac

    echo ""
    echo "按任意键继续..."
    read -r
}

# 显示完整配置文件
show_full_config() {
    echo ""
    echo "[文件] 完整配置文件内容"
    echo "==================="
    echo ""

    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        log_error "配置文件不存在"
    fi

    echo ""
    echo "按任意键继续..."
    read -r
}

# 重置为默认配置
reset_to_default_config() {
    echo ""
    echo "[逆时针] 重置为默认配置"
    echo "=================="
    echo ""

    echo "[警告]  警告: 这将删除所有当前配置并创建默认配置文件"
    echo ""
    echo -n "确认重置配置？[y/N]: "
    read -r confirm_reset

    if [ "$confirm_reset" = "y" ] || [ "$confirm_reset" = "Y" ]; then
        # 备份当前配置
        if [ -f "$CONFIG_FILE" ]; then
            local backup_file="${BACKUP_DIR}/github-sync-${INSTANCE_NAME}.conf.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$CONFIG_FILE" "$backup_file"
            log_info "当前配置已备份到: $backup_file"
        fi

        # 创建默认配置
        create_default_config
        log_info "已重置为默认配置"

        echo ""
        echo "建议运行配置向导来设置基本参数"
        echo -n "是否现在运行配置向导？[Y/n]: "
        read -r run_wizard

        if [ "$run_wizard" != "n" ] && [ "$run_wizard" != "N" ]; then
            run_setup_wizard
        fi
    else
        log_info "取消重置操作"
    fi

    echo ""
    echo "按任意键继续..."
    read -r
}

# 使用文本编辑器
edit_with_text_editor() {
    echo ""
    echo "[提交] 使用文本编辑器"
    echo "=================="
    echo ""

    echo "[警告]  注意: 直接编辑配置文件可能导致格式错误"
    echo "建议使用交互式编辑功能来修改配置"
    echo ""
    echo -n "确认使用文本编辑器？[y/N]: "
    read -r confirm_editor

    if [ "$confirm_editor" = "y" ] || [ "$confirm_editor" = "Y" ]; then
        # 尝试使用可用的编辑器
        for editor in vi nano; do
            if command -v "$editor" >/dev/null 2>&1; then
                "$editor" "$CONFIG_FILE"
                log_info "配置文件编辑完成"
                return 0
            fi
        done

        log_error "未找到可用的文本编辑器"
        echo "可用编辑器: vi, nano"
        echo "配置文件路径: $CONFIG_FILE"
    fi

    echo ""
    echo "按任意键继续..."
    read -r
}

# 测试当前配置
test_current_config() {
    echo ""
    echo "[测试] 测试当前配置"
    echo "==============="
    echo ""

    if test_config; then
        echo ""
        log_info "[成功] 配置测试通过"
    else
        echo ""
        log_error "[失败] 配置测试失败"
        echo ""
        echo "常见问题:"
        echo "• 检查GitHub用户名和令牌是否正确"
        echo "• 确认网络连接正常"
        echo "• 验证同步路径是否存在"
    fi

    echo ""
    echo "按任意键继续..."
    read -r
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

# 清理日志文件
cleanup_logs() {
    echo "日志清理工具"
    echo "============"
    echo ""

    local log_dir=$(dirname "$LOG_FILE")
    local log_basename=$(basename "$LOG_FILE")

    # 显示当前日志文件状态
    echo "当前日志文件状态:"
    echo "  主日志文件: $LOG_FILE"
    if [ -f "$LOG_FILE" ]; then
        local size=$(get_file_size "$LOG_FILE")
        echo "    大小: $size bytes ($(echo "scale=2; $size/1024/1024" | bc 2>/dev/null || echo "N/A") MB)"
        local age=$(get_file_age_days "$LOG_FILE")
        echo "    年龄: $age 天"
    else
        echo "    状态: 不存在"
    fi

    echo ""
    echo "历史日志文件:"
    local old_logs=$(find "$log_dir" -name "${log_basename}.*" -type f 2>/dev/null | sort)
    if [ -n "$old_logs" ]; then
        echo "$old_logs" | while read -r old_log; do
            local size=$(get_file_size "$old_log")
            local age=$(get_file_age_days "$old_log")
            echo "  $old_log (大小: $size bytes, 年龄: $age 天)"
        done
    else
        echo "  无历史日志文件"
    fi

    echo ""
    echo "清理选项:"
    echo "1) 清理超过 ${LOG_KEEP_DAYS:-$DEFAULT_LOG_KEEP_DAYS} 天的日志文件"
    echo "2) 清理所有历史日志文件"
    echo "3) 轮转当前日志文件"
    echo "4) 查看日志配置"
    echo "5) 返回"
    echo ""
    echo -n "请选择 [1-5]: "
    read -r choice

    case "$choice" in
        1)
            echo ""
            echo "清理过期日志文件..."
            cleanup_old_logs
            echo "清理完成"
            ;;
        2)
            echo ""
            echo -n "确认清理所有历史日志文件？[y/N]: "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                find "$log_dir" -name "${log_basename}.*" -type f -delete
                echo "所有历史日志文件已清理"
            else
                echo "操作已取消"
            fi
            ;;
        3)
            echo ""
            echo "轮转当前日志文件..."
            rotate_log
            echo "日志文件已轮转"
            ;;
        4)
            echo ""
            echo "日志配置:"
            echo "  最大文件大小: ${LOG_MAX_SIZE:-$DEFAULT_MAX_LOG_SIZE} bytes"
            echo "  保留天数: ${LOG_KEEP_DAYS:-$DEFAULT_LOG_KEEP_DAYS} 天"
            echo "  最大文件数: ${LOG_MAX_FILES:-$DEFAULT_LOG_MAX_FILES} 个"
            echo "  当前日志级别: ${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"
            ;;
        5|*)
            return 0
            ;;
    esac

    echo ""
    echo "按任意键继续..."
    read -r
}

# 列出所有实例
list_instances() {
    echo "GitHub同步工具实例列表:"
    echo "========================"
    echo ""

    local found_instances=0

    # 查找所有配置文件
    for config_file in "${PROJECT_DIR}"/github-sync-*.conf; do
        if [ -f "$config_file" ]; then
            local instance_name=$(basename "$config_file" | sed 's/github-sync-//' | sed 's/.conf$//')
            local pid_file="${PROJECT_DIR}/github-sync-${instance_name}.pid"
            local log_file="${PROJECT_DIR}/github-sync-${instance_name}.log"

            found_instances=$((found_instances + 1))

            echo "实例: $instance_name"
            echo "  配置文件: $config_file"
            echo "  日志文件: $log_file"

            # 检查运行状态
            if [ -f "$pid_file" ]; then
                local pid=$(cat "$pid_file")
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                    echo "  状态: 运行中 (PID: $pid)"
                else
                    echo "  状态: 已停止"
                fi
            else
                echo "  状态: 已停止"
            fi

            # 显示同步路径数量
            if [ -f "$config_file" ]; then
                local sync_paths=$(grep "SYNC_PATHS" "$config_file" | cut -d'"' -f2)
                if [ -n "$sync_paths" ]; then
                    local path_count=$(echo "$sync_paths" | grep -c "|" 2>/dev/null || echo "0")
                    echo "  同步路径: $path_count 个"
                else
                    echo "  同步路径: 未配置"
                fi
            fi

            echo ""
        fi
    done

    if [ $found_instances -eq 0 ]; then
        echo "未找到任何实例配置文件"
        echo ""
        echo "使用以下命令创建新实例:"
        echo "  $0 -i <实例名> config"
    else
        echo "总计: $found_instances 个实例"
    fi
}

# 解析命令行参数
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -i|--instance)
                if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
                    INSTANCE_NAME="$2"
                    # 重新设置文件路径
                    CONFIG_FILE="${PROJECT_DIR}/github-sync-${INSTANCE_NAME}.conf"
                    LOG_FILE="${PROJECT_DIR}/github-sync-${INSTANCE_NAME}.log"
                    PID_FILE="${PROJECT_DIR}/github-sync-${INSTANCE_NAME}.pid"
                    LOCK_FILE="${PROJECT_DIR}/github-sync-${INSTANCE_NAME}.lock"
                    shift 2
                else
                    log_error "选项 -i/--instance 需要指定实例名"
                    exit 1
                fi
                ;;
            -c|--config)
                if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
                    CONFIG_FILE="$2"
                    shift 2
                else
                    log_error "选项 -c/--config 需要指定配置文件路径"
                    exit 1
                fi
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
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                # 非选项参数，结束解析
                break
                ;;
        esac
    done
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

# 简化的菜单界面设计
show_interactive_menu() {
    while true; do
        show_simple_menu
        handle_simple_input
    done
}

# 显示简化菜单
show_simple_menu() {
    clear

    # 简洁标题
    echo "=================================="
    echo "🚀 GitHub File Sync Tool"
    echo "=================================="
    echo ""

    # 简化状态显示
    show_simple_status
    echo ""

    # 简化菜单选项
    show_simple_options
    echo ""

    echo -n "请选择操作 [1-9, h, q]: "
}

# 简化状态显示
show_simple_status() {
    # 服务状态
    if is_running; then
        echo "📊 状态: 🟢 运行中 (PID: $(cat "$PID_FILE" 2>/dev/null || echo "未知"))"
    else
        echo "📊 状态: 🔴 已停止"
    fi

    # 配置状态
    if [ -f "$CONFIG_FILE" ]; then
        local path_count=$(grep -c "|" "$CONFIG_FILE" 2>/dev/null || echo "0")
        echo "⚙️  配置: ✅ 已配置 ($path_count 个同步路径)"
    else
        echo "⚙️  配置: ⚠️  未配置"
    fi

    # 实例信息
    echo "📁 实例: $INSTANCE_NAME"
}

# 简化菜单选项
show_simple_options() {
    if [ ! -f "$CONFIG_FILE" ]; then
        # 首次使用菜单
        echo "🎯 首次配置:"
        echo "  [1] 快速配置向导 (推荐)"
        echo "  [2] 手动编辑配置"
        echo "  [3] 查看配置示例"
        echo ""
        echo "🛠️  系统:"
        echo "  [4] 安装系统服务"
        echo "  [5] 查看帮助"
    else
        # 正常使用菜单
        echo "🎛️  服务控制:"
        if is_running; then
            echo "  [1] 停止服务    [2] 重启服务    [3] 查看状态"
        else
            echo "  [1] 启动服务    [2] 重启服务    [3] 查看状态"
        fi
        echo ""
        echo "⚙️  配置管理:"
        echo "  [4] 编辑配置    [5] 测试配置    [6] 配置向导"
        echo ""
        echo "🔄 同步操作:"
        echo "  [7] 立即同步    [8] 查看日志"
        echo ""
        echo "🛠️  系统:"
        echo "  [9] 系统工具"
    fi
    echo ""
    echo "其他: [h] 帮助  [q] 退出"
}

# 显示状态面板
show_status_panel() {
    echo "┌─ 📊 系统状态 ─────────────────────────────────────────────────────────────────┐"

    # 服务状态
    local service_status_icon service_status_text service_status_color
    if is_running; then
        service_status_icon="🟢"
        service_status_text="运行中"
        service_status_color="${GREEN}"
        local pid=$(cat "$PID_FILE" 2>/dev/null || echo "未知")
        echo "│ ${service_status_icon} 服务状态: ${service_status_color}${service_status_text}${NC} (PID: $pid)"
    else
        service_status_icon="🔴"
        service_status_text="已停止"
        service_status_color="${RED}"
        echo "│ ${service_status_icon} 服务状态: ${service_status_color}${service_status_text}${NC}"
    fi

    # 配置状态
    local config_status_icon config_status_text config_status_color
    if [ -f "$CONFIG_FILE" ]; then
        config_status_icon="✅"
        config_status_text="已配置"
        config_status_color="${GREEN}"
        local path_count=$(grep -c "|" "$CONFIG_FILE" 2>/dev/null || echo "0")
        echo "│ ${config_status_icon} 配置状态: ${config_status_color}${config_status_text}${NC} ($path_count 个同步路径)"
    else
        config_status_icon="⚠️"
        config_status_text="未配置"
        config_status_color="${YELLOW}"
        echo "│ ${config_status_icon} 配置状态: ${config_status_color}${config_status_text}${NC}"
    fi

    # 实例信息
    echo "│ 📁 项目目录: ${BLUE}$PROJECT_DIR${NC}"
    echo "│ 🏷️  当前实例: ${BLUE}$INSTANCE_NAME${NC}"

    # 日志状态
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        if [ "$log_size" -gt 0 ]; then
            local log_size_kb=$(($log_size / 1024))
            echo "│ 📝 日志大小: ${BLUE}${log_size_kb}KB${NC}"

            # 显示最后一条日志（截断显示）
            local last_log=$(tail -1 "$LOG_FILE" 2>/dev/null | cut -d']' -f3- | sed 's/^ *//')
            if [ -n "$last_log" ]; then
                # 截断过长的日志
                if [ ${#last_log} -gt 50 ]; then
                    last_log="${last_log:0:47}..."
                fi
                echo "│ 📄 最近日志: ${BLUE}$last_log${NC}"
            fi
        fi
    fi

    echo "└───────────────────────────────────────────────────────────────────────────────┘"
}

# 显示主菜单面板
show_main_menu_panel() {
    # 根据配置状态显示不同的菜单布局
    if [ ! -f "$CONFIG_FILE" ]; then
        show_first_time_menu
    else
        show_normal_menu
    fi
}

# 首次使用菜单
show_first_time_menu() {
    echo "┌─ 🎯 首次配置向导 ─────────────────────────────────────────────────────────────┐"
    echo "│                                                                               │"
    echo "│  ${YELLOW}🚀 快速开始${NC}                    ${BLUE}📚 学习资源${NC}                      │"
    echo "│  ${YELLOW}[w]${NC} 快速设置向导 (推荐)        ${BLUE}[v]${NC} 查看配置示例                │"
    echo "│  ${YELLOW}[c]${NC} 手动编辑配置               ${BLUE}[h]${NC} 查看帮助文档                │"
    echo "│                                                                               │"
    echo "└───────────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "┌─ ⚙️  系统管理 ────────────────────────────────────────────────────────────────┐"
    echo "│  [i] 安装系统服务    [t] 查看系统状态    [/] 搜索功能    [?] 快速帮助        │"
    echo "└───────────────────────────────────────────────────────────────────────────────┘"
}

# 正常使用菜单
show_normal_menu() {
    echo "┌─ 🎛️  服务控制 ────────────────────────────────────────────────────────────────┐"
    echo "│                                                                               │"
    if is_running; then
        echo "│  ${GREEN}[x]${NC} 停止服务      ${BLUE}[r]${NC} 重启服务      ${BLUE}[t]${NC} 查看状态      ${BLUE}[l]${NC} 查看日志    │"
    else
        echo "│  ${GREEN}[s]${NC} 启动服务      ${BLUE}[r]${NC} 重启服务      ${BLUE}[t]${NC} 查看状态      ${BLUE}[l]${NC} 查看日志    │"
    fi
    echo "│                                                                               │"
    echo "└───────────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "┌─ ⚙️  配置管理 ────────────────────────────────────────────────────────────────┐"
    echo "│                                                                               │"
    echo "│  ${BLUE}[c]${NC} 编辑配置      ${BLUE}[e]${NC} 测试配置      ${BLUE}[w]${NC} 配置向导      ${BLUE}[v]${NC} 配置示例    │"
    echo "│                                                                               │"
    echo "└───────────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "┌─ 🔄 同步操作 ─────────────────────────────────────────────────────────────────┐"
    echo "│                                                                               │"
    echo "│  ${GREEN}[y]${NC} 立即同步      ${BLUE}[l]${NC} 查看日志      ${BLUE}[t]${NC} 同步状态      ${BLUE}[h]${NC} 帮助文档    │"
    echo "│                                                                               │"
    echo "└───────────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "┌─ 🛠️  系统工具 ────────────────────────────────────────────────────────────────┐"
    echo "│  [i] 系统安装    [m] 文件迁移    [/] 搜索功能    [?] 快速帮助    [0] 退出    │"
    echo "└───────────────────────────────────────────────────────────────────────────────┘"
}

# 显示底部操作栏
show_bottom_action_bar() {
    echo "┌─ 💡 操作提示 ─────────────────────────────────────────────────────────────────┐"
    echo "│ • 输入字母快捷键或数字选择功能  • 输入 / 搜索菜单  • 输入 ? 获取帮助         │"
    echo "│ • 直接按回车刷新界面           • 输入 0 或 q 退出程序                        │"
    echo "└───────────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo -n "🎯 请选择操作: "
}

# 简化输入处理
handle_simple_input() {
    read -r choice

    if [ ! -f "$CONFIG_FILE" ]; then
        # 首次使用菜单处理
        case "$choice" in
            1|w|W) run_setup_wizard ;;
            2|c|C) edit_config && echo "按任意键继续..." && read -r ;;
            3|v|V) show_simple_config_example && echo "按任意键继续..." && read -r ;;
            4|i|I) install && echo "按任意键继续..." && read -r ;;
            5|h|H) show_simple_help && echo "按任意键继续..." && read -r ;;
            q|Q|0) exit 0 ;;
            "") return 0 ;;
            *) echo "无效选项: $choice" && sleep 1 ;;
        esac
    else
        # 正常使用菜单处理
        case "$choice" in
            1)
                if is_running; then
                    execute_simple "停止服务" stop_daemon
                else
                    execute_simple "启动服务" start_daemon
                fi
                echo "按任意键继续..." && read -r
                ;;
            2|r|R) execute_simple "重启服务" restart_daemon && echo "按任意键继续..." && read -r ;;
            3|t|T) show_simple_detailed_status && echo "按任意键继续..." && read -r ;;
            4|c|C) edit_config && echo "按任意键继续..." && read -r ;;
            5|e|E) test_config && echo "按任意键继续..." && read -r ;;
            6|w|W) run_setup_wizard ;;
            7|y|Y) execute_simple "立即同步" run_sync_once && echo "按任意键继续..." && read -r ;;
            8|l|L) show_simple_logs && echo "按任意键继续..." && read -r ;;
            9) show_system_tools_menu ;;
            h|H) show_simple_help && echo "按任意键继续..." && read -r ;;
            q|Q|0) exit 0 ;;
            "") return 0 ;;
            *) echo "无效选项: $choice" && sleep 1 ;;
        esac
    fi
}

# 系统工具子菜单
show_system_tools_menu() {
    while true; do
        clear
        echo "=================================="
        echo "🛠️  系统工具"
        echo "=================================="
        echo ""
        echo "  [1] 安装/重新安装"
        echo "  [2] 文件迁移"
        echo "  [3] 查看帮助"
        echo "  [4] 代码健康检查"
        echo ""
        echo "  [0] 返回主菜单"
        echo ""
        echo -n "请选择: "
        read -r tool_choice

        case "$tool_choice" in
            1) execute_simple "安装系统" install && echo "按任意键继续..." && read -r ;;
            2) manual_migration ;;
            3) show_simple_help && echo "按任意键继续..." && read -r ;;
            4) check_code_health && echo "按任意键继续..." && read -r ;;
            0) break ;;
            "") continue ;;
            *) echo "无效选项: $tool_choice" && sleep 1 ;;
        esac
    done
}

# 处理菜单输入
handle_menu_input() {
    read -r choice

    case "$choice" in
        # 服务管理
        s|S|start|1)
            execute_with_feedback "启动同步服务" start_daemon "🚀"
            ;;
        x|X|stop|2)
            execute_with_feedback "停止同步服务" stop_daemon "🛑"
            ;;
        r|R|restart|3)
            execute_with_feedback "重启同步服务" restart_daemon "🔄"
            ;;
        t|T|status|4)
            show_detailed_status
            ;;

        # 配置管理
        c|C|config|5)
            execute_with_feedback "编辑配置文件" edit_config "⚙️"
            ;;
        e|E|test|6)
            execute_with_feedback "测试配置" test_config "🧪"
            ;;
        v|V|example|7)
            show_config_example_modern
            ;;
        w|W|wizard|11)
            run_setup_wizard
            ;;

        # 同步操作
        y|Y|sync|8)
            execute_with_feedback "执行一次性同步" run_sync_once "🔄"
            ;;
        l|L|logs|9)
            show_logs_modern
            ;;

        # 系统管理
        i|I|install|10)
            execute_with_feedback "安装/重新安装工具" install "🛠️"
            ;;
        m|M|migrate)
            manual_migration
            ;;
        h|H|help|12)
            show_help_modern
            ;;

        # 特殊功能
        /|search)
            handle_search_function
            ;;
        \?|help)
            show_quick_help
            ;;
        0|q|Q|exit)
            show_exit_confirmation
            ;;
        "")
            # 用户直接按回车，刷新菜单
            return 0
            ;;
        *)
            show_invalid_input_message "$choice"
            ;;
    esac
}

# 简化的操作执行
execute_simple() {
    local action_name="$1"
    local command="$2"

    echo "正在执行: $action_name..."

    if $command; then
        echo "✅ $action_name 成功"
    else
        echo "❌ $action_name 失败"
    fi
}

# 简化状态显示
show_simple_detailed_status() {
    clear
    echo "=================================="
    echo "📊 系统状态详情"
    echo "=================================="
    echo ""

    # 调用原有的状态显示函数
    show_status

    echo ""
    echo "📈 性能统计:"

    # 显示内存使用情况
    if is_running; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            local mem_usage=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
            local mem_mb=$((mem_usage / 1024))
            echo "  💾 内存使用: ${mem_mb}MB"

            local cpu_usage=$(ps -o %cpu= -p "$pid" 2>/dev/null || echo "0.0")
            echo "  🖥️  CPU使用: ${cpu_usage}%"
        fi
    fi

    # 显示日志统计
    if [ -f "$LOG_FILE" ]; then
        local log_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
        echo "  📝 日志行数: $log_lines"

        local error_count=$(grep -c "ERROR" "$LOG_FILE" 2>/dev/null || echo "0")
        local warn_count=$(grep -c "WARN" "$LOG_FILE" 2>/dev/null || echo "0")
        echo "  ⚠️  警告数量: $warn_count"
        echo "  ❌ 错误数量: $error_count"
    fi
}

# 简化配置示例显示
show_simple_config_example() {
    clear
    echo "=================================="
    echo "📚 配置文件示例"
    echo "=================================="
    echo ""

    show_config_example
}

# 简化日志显示
show_simple_logs() {
    clear
    echo "=================================="
    echo "📄 同步日志"
    echo "=================================="
    echo ""

    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        local log_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
        echo "📊 日志统计: $(($log_size / 1024))KB, $log_lines 行"
        echo ""

        echo "最近的日志记录:"
        echo "----------------------------------"
        tail -20 "$LOG_FILE" 2>/dev/null || echo "无法读取日志文件"
        echo "----------------------------------"
    else
        echo "⚠️  日志文件不存在: $LOG_FILE"
        echo "请先启动同步服务以生成日志文件"
    fi
}

# 简化帮助显示
show_simple_help() {
    clear
    echo "=================================="
    echo "📖 帮助文档"
    echo "=================================="
    echo ""

    show_help
}

# 简化的快速帮助
show_simple_quick_help() {
    clear
    echo "=================================="
    echo "💡 快速帮助"
    echo "=================================="
    echo ""
    echo "🎯 快捷键说明:"
    echo "  数字键: 选择对应功能"
    echo "  [h]: 查看帮助"
    echo "  [q]: 退出程序"
    echo "  回车: 刷新界面"
    echo ""
    echo "🔧 使用技巧:"
    echo "  • 首次使用请选择 [1] 运行配置向导"
    echo "  • 直接按回车可以刷新界面状态"
    echo ""
    echo "按任意键返回主菜单..."
    read -r
}

# 处理菜单选择（用于搜索结果）
handle_menu_choice() {
    local choice="$1"

    case "$choice" in
        # 服务管理
        s|S|start|1)
            execute_with_feedback "启动同步服务" start_daemon "🚀"
            ;;
        x|X|stop|2)
            execute_with_feedback "停止同步服务" stop_daemon "🛑"
            ;;
        r|R|restart|3)
            execute_with_feedback "重启同步服务" restart_daemon "🔄"
            ;;
        t|T|status|4)
            show_detailed_status
            ;;

        # 配置管理
        c|C|config|5)
            execute_with_feedback "编辑配置文件" edit_config "⚙️"
            ;;
        e|E|test|6)
            execute_with_feedback "测试配置" test_config "🧪"
            ;;
        v|V|example|7)
            show_config_example_modern
            ;;
        w|W|wizard|11)
            run_setup_wizard
            ;;

        # 同步操作
        y|Y|sync|8)
            execute_with_feedback "执行一次性同步" run_sync_once "🔄"
            ;;
        l|L|logs|9)
            show_logs_modern
            ;;

        # 系统管理
        i|I|install|10)
            execute_with_feedback "安装/重新安装工具" install "🛠️"
            ;;
        m|M|migrate)
            manual_migration
            ;;
        h|H|help|12)
            show_help_modern
            ;;

        # 特殊功能
        /|search)
            handle_search_function
            ;;
        \?|help)
            show_quick_help
            ;;
        0|q|Q|exit)
            show_exit_confirmation
            ;;
        "")
            # 用户直接按回车，刷新菜单
            return 0
            ;;
        *)
            show_invalid_input_message "$choice"
            ;;
    esac
}

# 增强的交互式配置向导
run_setup_wizard() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                GitHub同步工具配置向导                       ║"
    echo "║              GitHub File Sync Configuration Wizard          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "欢迎使用GitHub同步工具配置向导"
    echo ""

    # 检查是否已有配置文件
    if [ -f "$CONFIG_FILE" ]; then
        echo "[测试] 检测到现有配置文件: $CONFIG_FILE"
        echo ""
        echo "请选择操作："
        echo "1) 覆盖现有配置（重新配置）"
        echo "2) 编辑现有配置（修改部分设置）"
        echo "3) 备份并重新配置"
        echo "4) 取消配置"
        echo ""
        echo -n "请选择 [1-4]: "
        read -r config_action

        case "$config_action" in
            1)
                log_info "将覆盖现有配置"
                ;;
            2)
                edit_existing_config
                return $?
                ;;
            3)
                backup_file="${BACKUP_DIR}/github-sync-${INSTANCE_NAME}.conf.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$CONFIG_FILE" "$backup_file"
                log_info "配置文件已备份到: $backup_file"
                ;;
            *)
                log_info "取消配置向导"
                return 0
                ;;
        esac
        echo ""
    fi

    # 显示配置向导菜单
    show_wizard_menu
}

# 简化的向导菜单
show_wizard_menu() {
    echo "[配置] 选择配置方式："
    echo ""
    echo "1) [快速] 快速配置 - 使用预设模板，只需输入基本信息"
    echo "2) [自定义] 自定义配置 - 手动配置所有选项"
    echo ""
    echo -n "请选择 [1-2]: "
    read -r wizard_mode

    case "$wizard_mode" in
        1) run_quick_wizard ;;
        2) run_standard_wizard ;;
        *)
            log_info "使用快速配置模式"
            run_quick_wizard
            ;;
    esac
}

# 快速配置向导
run_quick_wizard() {
    echo ""
    echo "[快速] 快速配置向导"
    echo "================"
    echo ""

    # 获取GitHub基本信息
    get_github_credentials

    # 使用简化的配置方法
    setup_basic_config

    create_config_file
    test_and_finish
}

# 获取GitHub凭据
get_github_credentials() {
    echo "[GitHub] GitHub账户配置"
    echo "=================="
    echo ""

    # 获取GitHub用户名
    while true; do
        echo -n "GitHub用户名: "
        read -r github_username

        if [ -z "$github_username" ]; then
            echo "[错误] 用户名不能为空，请重新输入"
            continue
        fi

        # 验证用户名格式
        if echo "$github_username" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$'; then
            echo "[成功] 用户名格式正确"
            break
        else
            echo "[错误] 用户名格式不正确，只能包含字母、数字和连字符"
        fi
    done

    # 获取GitHub令牌
    echo ""
    echo "[令牌] GitHub个人访问令牌配置"
    echo ""
    echo "[说明] 如何获取令牌："
    echo "   1. 访问 https://github.com/settings/tokens"
    echo "   2. 点击 'Generate new token (classic)'"
    echo "   3. 选择 'repo' 权限（完整仓库访问）"
    echo "   4. 复制生成的令牌"
    echo ""

    while true; do
        echo -n "GitHub令牌: "
        read -r github_token

        if [ -z "$github_token" ]; then
            echo "[失败] 令牌不能为空，请重新输入"
            continue
        fi

        # 验证令牌格式（GitHub classic token格式）
        if echo "$github_token" | grep -qE '^ghp_[a-zA-Z0-9]{36}$'; then
            echo "[成功] 令牌格式正确"
            break
        elif echo "$github_token" | grep -qE '^github_pat_[a-zA-Z0-9_]{82}$'; then
            echo "[成功] 令牌格式正确（Fine-grained token）"
            break
        else
            echo "[警告]  令牌格式可能不正确，但将继续使用"
            echo -n "确认使用此令牌？[y/N]: "
            read -r confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                break
            fi
        fi
    done

    # 测试GitHub连接
    echo ""
    echo "[测试] 测试GitHub连接..."
    if test_github_connection_with_token "$github_username" "$github_token"; then
        echo "[成功] GitHub连接测试成功"
    else
        echo "[失败] GitHub连接测试失败"
        echo -n "是否继续配置？[y/N]: "
        read -r continue_config
        if [ "$continue_config" != "y" ] && [ "$continue_config" != "Y" ]; then
            log_info "配置已取消"
            return 1
        fi
    fi
}

# 测试GitHub连接（带凭据）
test_github_connection_with_token() {
    local username="$1"
    local token="$2"

    local response
    response=$(curl -s -w "%{http_code}" -H "Authorization: token $token" \
        "https://api.github.com/user" -o /dev/null 2>/dev/null)

    [ "$response" = "200" ]
}





# 标准配置向导
run_standard_wizard() {
    echo ""
    echo "[标准]  标准配置向导"
    echo "==============="
    echo ""

    # 获取GitHub凭据
    get_github_credentials

    # 获取同步路径
    get_detailed_sync_paths

    # 获取监控设置
    get_monitoring_settings

    # 获取高级选项
    get_basic_advanced_options

    create_config_file
    test_and_finish
}

# 获取详细同步路径配置
get_detailed_sync_paths() {
    echo ""
    echo "[路径] 同步路径配置"
    echo "==============="
    echo ""
    echo "配置要同步的文件和目录路径"
    echo "格式: 本地路径|GitHub仓库|分支|目标路径"
    echo ""

    sync_paths=""
    path_count=1

    while true; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "同步路径 $path_count 配置:"
        echo ""

        # 本地路径
        while true; do
            echo -n "本地路径 (留空结束配置): "
            read -r local_path

            if [ -z "$local_path" ]; then
                break 2
            fi

            # 验证路径
            if [ -e "$local_path" ]; then
                if [ -d "$local_path" ]; then
                    echo "[成功] 目录存在: $local_path"
                else
                    echo "[成功] 文件存在: $local_path"
                fi
                break
            else
                echo "[警告]  路径不存在: $local_path"
                echo -n "是否继续使用此路径？[y/N]: "
                read -r use_path
                if [ "$use_path" = "y" ] || [ "$use_path" = "Y" ]; then
                    break
                fi
            fi
        done

        # GitHub仓库
        echo -n "GitHub仓库名称 ($github_username/): "
        read -r repo_name
        if [ -z "$repo_name" ]; then
            repo_name="config-backup"
            echo "使用默认仓库名: $repo_name"
        fi

        # 分支
        echo -n "目标分支 (默认main): "
        read -r branch
        branch=${branch:-main}

        # 目标路径
        echo -n "仓库中的目标路径 (可留空): "
        read -r target_path

        # 添加到同步路径
        if [ -z "$sync_paths" ]; then
            sync_paths="$local_path|$github_username/$repo_name|$branch|$target_path"
        else
            sync_paths="$sync_paths
$local_path|$github_username/$repo_name|$branch|$target_path"
        fi

        echo "[成功] 已添加: $local_path → $github_username/$repo_name:$branch/$target_path"
        path_count=$((path_count + 1))
        echo ""
    done

    if [ -z "$sync_paths" ]; then
        echo "[警告]  未配置同步路径，使用默认配置"
        sync_paths="/etc/config|$github_username/config-backup|main|config"
    fi

    echo ""
    echo "[配置] 已配置的同步路径:"
    echo "$sync_paths" | while IFS='|' read -r lpath repo branch tpath; do
        echo "  • $lpath → $repo:$branch/$tpath"
    done
}

# 获取监控设置
get_monitoring_settings() {
    echo ""
    echo "[监控]  监控设置配置"
    echo "==============="
    echo ""

    # 轮询间隔
    echo "文件监控轮询间隔设置:"
    echo "• 10秒 - 高频监控（适合开发环境）"
    echo "• 30秒 - 标准监控（推荐）"
    echo "• 60秒 - 低频监控（适合生产环境）"
    echo "• 300秒 - 极低频监控（适合大文件）"
    echo ""
    echo -n "轮询间隔（秒，默认30）: "
    read -r poll_interval
    poll_interval=${poll_interval:-30}

    # 验证输入
    if ! echo "$poll_interval" | grep -qE '^[0-9]+$' || [ "$poll_interval" -lt 5 ]; then
        echo "[警告]  无效输入，使用默认值30秒"
        poll_interval=30
    fi

    # 日志级别
    echo ""
    echo "日志级别选择:"
    echo "1) DEBUG - 详细调试信息（开发调试用）"
    echo "2) INFO  - 一般信息（推荐）"
    echo "3) WARN  - 仅警告和错误"
    echo "4) ERROR - 仅错误信息"
    echo ""
    echo -n "请选择日志级别 [1-4，默认2]: "
    read -r log_level_choice

    case "$log_level_choice" in
        1) log_level="DEBUG" ;;
        3) log_level="WARN" ;;
        4) log_level="ERROR" ;;
        *) log_level="INFO" ;;
    esac

    echo "[成功] 监控设置: 轮询间隔${poll_interval}秒, 日志级别${log_level}"
}

# 获取基本高级选项
get_basic_advanced_options() {
    echo ""
    echo "[高级] 高级选项配置"
    echo "==============="
    echo ""

    # 自动提交
    echo -n "启用自动提交？[Y/n]: "
    read -r auto_commit_choice
    if [ "$auto_commit_choice" = "n" ] || [ "$auto_commit_choice" = "N" ]; then
        auto_commit=false
    else
        auto_commit=true
    fi

    # 提交消息模板
    if [ "$auto_commit" = "true" ]; then
        echo ""
        echo "提交消息模板配置:"
        echo "可用变量: %s (文件路径), \$(hostname) (主机名), \$(date) (日期)"
        echo ""
        echo -n "提交消息模板 (默认: Auto sync %s): "
        read -r commit_template
        commit_template=${commit_template:-"Auto sync %s"}
    else
        commit_template="Manual sync %s"
    fi

    # 文件过滤
    echo ""
    echo "文件过滤规则 (用空格分隔的模式):"
    echo "默认: *.tmp *.log *.pid *.lock .git *.swp *~"
    echo ""
    echo -n "排除模式 (回车使用默认): "
    read -r exclude_input
    if [ -n "$exclude_input" ]; then
        exclude_patterns="$exclude_input"
    else
        exclude_patterns="*.tmp *.log *.pid *.lock .git *.swp *~ .DS_Store"
    fi

    echo "[成功] 高级选项配置完成"
}





# 简化的配置方法
setup_basic_config() {
    echo ""
    echo "[配置] 基本同步配置"
    echo ""

    # 获取GitHub仓库名称
    echo -n "GitHub仓库名称 (默认: config-backup): "
    read -r repo_name
    repo_name=${repo_name:-config-backup}

    # 获取本地路径
    echo -n "本地文件/目录路径 (默认: /etc/config): "
    read -r local_path
    local_path=${local_path:-/etc/config}

    # 获取目标路径
    echo -n "仓库中的目标路径 (可留空): "
    read -r target_path

    # 设置同步路径
    sync_paths="$local_path|$github_username/$repo_name|main|$target_path"

    # 设置默认配置
    poll_interval=60
    log_level="INFO"
    auto_commit=true
    commit_template="Auto sync %s"
    exclude_patterns="*.tmp *.log *.pid *.lock .git *.swp *~"
    max_file_size=1048576

    echo ""
    echo "[配置] 已设置同步路径: $local_path -> $github_username/$repo_name"
}

# 创建配置文件
create_config_file() {
    echo ""
    log_info "创建配置文件..."

    # 生成时间戳
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$CONFIG_FILE" << EOF
# GitHub Sync Tool Configuration
# 配置文件生成时间: $timestamp
# 生成方式: 交互式配置向导

#==============================================================================
# GitHub配置
#==============================================================================

# GitHub用户名
GITHUB_USERNAME="$github_username"

# GitHub个人访问令牌
GITHUB_TOKEN="$github_token"

#==============================================================================
# 监控配置
#==============================================================================

# 文件监控轮询间隔（秒）
POLL_INTERVAL=$poll_interval

# 日志级别: DEBUG, INFO, WARN, ERROR
LOG_LEVEL="$log_level"

#==============================================================================
# 同步路径配置
#==============================================================================

# 同步路径配置
# 格式: 本地路径|GitHub仓库|分支|目标路径
SYNC_PATHS="$sync_paths"

#==============================================================================
# 文件过滤配置
#==============================================================================

# 排除文件模式（用空格分隔）
EXCLUDE_PATTERNS="$exclude_patterns"

#==============================================================================
# 高级选项
#==============================================================================

# 自动提交
AUTO_COMMIT=$auto_commit

# 提交消息模板
COMMIT_MESSAGE_TEMPLATE="$commit_template"

# 最大文件大小（字节）
MAX_FILE_SIZE=${max_file_size:-1048576}

# 最大日志文件大小（字节）
MAX_LOG_SIZE=1048576

#==============================================================================
# 网络配置
#==============================================================================

# HTTP超时时间（秒）
HTTP_TIMEOUT=${http_timeout:-30}

# 重试次数
MAX_RETRIES=${max_retries:-3}

# 重试间隔（秒）
RETRY_INTERVAL=${retry_interval:-5}

# SSL证书验证
VERIFY_SSL=${verify_ssl:-true}

EOF

    # 添加代理配置（如果有）
    if [ -n "$http_proxy" ]; then
        cat >> "$CONFIG_FILE" << EOF
# 代理配置
HTTP_PROXY="$http_proxy"
HTTPS_PROXY="$https_proxy"

EOF
    fi

    # 添加配置说明
    cat >> "$CONFIG_FILE" << 'EOF'
#==============================================================================
# 配置说明
#==============================================================================

# 1. GitHub令牌权限要求：
#    - repo: 完整的仓库访问权限
#    - 如果是私有仓库，确保令牌有相应权限
#
# 2. 同步路径格式说明：
#    - 本地路径: 要监控的本地文件或目录的绝对路径
#    - GitHub仓库: 格式为 "用户名/仓库名"
#    - 分支: 目标分支名称，通常是 "main" 或 "master"
#    - 目标路径: 在GitHub仓库中的目标路径，可以为空
#
# 3. 修改配置后需要重启服务：
#    github-sync restart
EOF

    log_success "配置文件创建成功: $CONFIG_FILE"
}

# 测试配置并完成设置
test_and_finish() {
    echo ""
    log_info "测试配置..."

    if test_config; then
        log_success "[成功] 配置测试通过！"

        echo ""
        echo "[完成] 配置向导完成！"
        echo ""
        echo "[配置] 配置摘要:"
        echo "  • GitHub用户: $github_username"
        echo "  • 轮询间隔: ${poll_interval}秒"
        echo "  • 日志级别: $log_level"
        echo "  • 同步路径: $(echo "$sync_paths" | wc -l)个"
        echo "  • 自动提交: $auto_commit"
        echo ""

        echo -n "是否现在启动同步服务？[Y/n]: "
        read -r start_service
        if [ "$start_service" != "n" ] && [ "$start_service" != "N" ]; then
            echo ""
            if start_daemon; then
                log_success "[快速] 同步服务启动成功！"
                echo ""
                echo "服务管理命令:"
                echo "  github-sync status   # 查看状态"
                echo "  github-sync stop     # 停止服务"
                echo "  github-sync restart  # 重启服务"
            else
                log_error "[失败] 同步服务启动失败，请检查配置"
            fi
        else
            echo ""
            echo "稍后可使用以下命令启动服务:"
            echo "  github-sync start"
        fi
    else
        log_error "[失败] 配置测试失败，请检查GitHub用户名和令牌"
        echo ""
        echo "可以稍后编辑配置文件: $CONFIG_FILE"
        echo "然后运行: github-sync test"
    fi

    echo ""
    log_info "配置向导完成"
}

# 编辑现有配置
edit_existing_config() {
    echo ""
    echo "[编辑]  编辑现有配置"
    echo "==============="
    echo ""

    # 加载现有配置
    if ! load_config; then
        log_error "无法加载现有配置文件"
        return 1
    fi

    echo "当前配置摘要:"
    echo "  • GitHub用户: $GITHUB_USERNAME"
    echo "  • 轮询间隔: ${POLL_INTERVAL}秒"
    echo "  • 日志级别: $LOG_LEVEL"
    echo "  • 同步路径: $(echo "$SYNC_PATHS" | wc -l)个"
    echo ""

    echo "选择要修改的配置项:"
    echo "1) GitHub凭据"
    echo "2) 同步路径"
    echo "3) 监控设置"
    echo "4) 高级选项"
    echo "5) 完整重新配置"
    echo "6) 取消"
    echo ""
    echo -n "请选择 [1-6]: "
    read -r edit_choice

    case "$edit_choice" in
        1) edit_github_credentials ;;
        2) edit_sync_paths ;;
        3) edit_monitoring_settings ;;
        4) edit_advanced_options ;;
        5) run_standard_wizard ;;
        *) log_info "取消编辑"; return 0 ;;
    esac
}

# 编辑GitHub凭据
edit_github_credentials() {
    echo ""
    echo "[GitHub] 编辑GitHub凭据"
    echo "=================="
    echo ""
    echo "当前GitHub用户: $GITHUB_USERNAME"
    echo ""
    echo -n "是否修改GitHub用户名？[y/N]: "
    read -r change_username

    if [ "$change_username" = "y" ] || [ "$change_username" = "Y" ]; then
        echo -n "新的GitHub用户名: "
        read -r new_username
        if [ -n "$new_username" ]; then
            github_username="$new_username"
        else
            github_username="$GITHUB_USERNAME"
        fi
    else
        github_username="$GITHUB_USERNAME"
    fi

    echo ""
    echo -n "是否修改GitHub令牌？[y/N]: "
    read -r change_token

    if [ "$change_token" = "y" ] || [ "$change_token" = "Y" ]; then
        echo -n "新的GitHub令牌: "
        read -r new_token
        if [ -n "$new_token" ]; then
            github_token="$new_token"
        else
            github_token="$GITHUB_TOKEN"
        fi
    else
        github_token="$GITHUB_TOKEN"
    fi

    # 保留其他设置
    poll_interval="$POLL_INTERVAL"
    log_level="$LOG_LEVEL"
    sync_paths="$SYNC_PATHS"
    exclude_patterns="$EXCLUDE_PATTERNS"
    auto_commit="$AUTO_COMMIT"
    commit_template="$COMMIT_MESSAGE_TEMPLATE"
    max_file_size="$MAX_FILE_SIZE"

    create_config_file
    test_and_finish
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
    # 初始化系统工具缓存
    init_system_tools

    # 解析命令行参数（选项）
    parse_arguments "$@"

    # 重新获取剩余参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -i|--instance|-c|--config|-v|--verbose|-q|--quiet)
                # 这些选项已经在parse_arguments中处理了
                if [ "$1" = "-i" ] || [ "$1" = "--instance" ] || [ "$1" = "-c" ] || [ "$1" = "--config" ]; then
                    shift 2  # 跳过选项和值
                else
                    shift    # 跳过标志选项
                fi
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
                export DAEMON_MODE=true
                export GITHUB_SYNC_QUIET=true
                # 重定向所有输出到日志文件
                {
                    load_config && monitor_loop
                } >> "$LOG_FILE" 2>&1
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
            cleanup)
                cleanup_logs
                exit $?
                ;;
            list)
                list_instances
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
