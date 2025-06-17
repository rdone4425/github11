#!/bin/bash

#==============================================================================
# GitHub Sync Tool 文件迁移执行脚本
# 
# 功能: 安全迁移散落在 /root/ 目录下的 GitHub Sync Tool 相关文件
#       到标准化的项目目录结构中
#
# 作者: GitHub Sync Tool Team
# 版本: 1.0.0
# 日期: $(date +%Y-%m-%d)
#==============================================================================

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 项目目录配置
readonly PROJECT_DIR="/root/github-sync"
readonly CONFIG_DIR="${PROJECT_DIR}/config"
readonly LOG_DIR="${PROJECT_DIR}/logs"
readonly DATA_DIR="${PROJECT_DIR}/data"
readonly TEMP_DIR="${PROJECT_DIR}/tmp"
readonly BACKUP_DIR="${PROJECT_DIR}/backup"

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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 获取文件大小
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || wc -c < "$file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# 创建目录结构
create_directory_structure() {
    log_info "创建标准化目录结构..."
    
    local dirs_to_create="$PROJECT_DIR $CONFIG_DIR $LOG_DIR $DATA_DIR $TEMP_DIR $BACKUP_DIR"
    
    for dir in $dirs_to_create; do
        if [ ! -d "$dir" ]; then
            if mkdir -p "$dir" 2>/dev/null; then
                log_success "已创建目录: $dir"
            else
                log_error "无法创建目录: $dir"
                return 1
            fi
        else
            log_info "目录已存在: $dir"
        fi
    done
    
    # 设置适当的权限
    chmod 700 "$PROJECT_DIR" 2>/dev/null || true
    chmod 755 "$CONFIG_DIR" "$LOG_DIR" "$DATA_DIR" 2>/dev/null || true
    chmod 700 "$TEMP_DIR" "$BACKUP_DIR" 2>/dev/null || true
    
    log_success "目录结构创建完成"
    return 0
}

# 发现需要迁移的文件
discover_files() {
    log_info "扫描需要迁移的文件..."
    
    local total_files=0
    local total_size=0
    
    echo ""
    echo "📁 配置文件:"
    for file in /root/github-sync-*.conf; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            echo "  ✓ $file (${size}字节)"
            total_files=$((total_files + 1))
            total_size=$((total_size + size))
        fi
    done
    
    echo "📝 日志文件:"
    for file in /root/github-sync-*.log*; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            echo "  ✓ $file (${size}字节)"
            total_files=$((total_files + 1))
            total_size=$((total_size + size))
        fi
    done
    
    echo "📊 状态文件:"
    for file in /root/.state_* /root/.last_log_cleanup_*; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            echo "  ✓ $file (${size}字节)"
            total_files=$((total_files + 1))
            total_size=$((total_size + size))
        fi
    done
    
    echo "🔒 进程文件:"
    for file in /root/github-sync-*.pid /root/github-sync-*.lock; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            echo "  ✓ $file (${size}字节)"
            total_files=$((total_files + 1))
            total_size=$((total_size + size))
        fi
    done
    
    echo "💾 备份文件:"
    for file in /root/github-sync-*.conf.backup.*; do
        if [ -f "$file" ]; then
            local size=$(get_file_size "$file")
            echo "  ✓ $file (${size}字节)"
            total_files=$((total_files + 1))
            total_size=$((total_size + size))
        fi
    done
    
    echo ""
    log_info "发现 $total_files 个文件，总大小 $((total_size / 1024))KB"
    
    return $total_files
}

# 执行文件迁移
execute_migration() {
    local migrated_count=0
    local error_count=0
    local skip_count=0
    
    log_info "开始执行文件迁移..."
    
    # 创建迁移备份目录
    local migration_backup="${BACKUP_DIR}/migration_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$migration_backup" 2>/dev/null
    
    log_info "迁移备份目录: $migration_backup"
    echo ""
    
    # 迁移配置文件
    echo "📁 迁移配置文件..."
    for old_config in /root/github-sync-*.conf; do
        if [ -f "$old_config" ]; then
            local filename=$(basename "$old_config")
            local new_config="${CONFIG_DIR}/$filename"
            
            if [ ! -f "$new_config" ]; then
                # 创建备份
                cp "$old_config" "$migration_backup/" 2>/dev/null
                
                # 执行迁移
                if mv "$old_config" "$new_config" 2>/dev/null; then
                    echo "  ✅ $filename → config/"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                skip_count=$((skip_count + 1))
            fi
        fi
    done
    
    # 迁移日志文件
    echo "📝 迁移日志文件..."
    for old_log in /root/github-sync-*.log*; do
        if [ -f "$old_log" ]; then
            local filename=$(basename "$old_log")
            local new_log="${LOG_DIR}/$filename"
            
            if [ ! -f "$new_log" ]; then
                cp "$old_log" "$migration_backup/" 2>/dev/null
                if mv "$old_log" "$new_log" 2>/dev/null; then
                    echo "  ✅ $filename → logs/"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                skip_count=$((skip_count + 1))
            fi
        fi
    done
    
    # 迁移状态文件
    echo "📊 迁移状态文件..."
    for old_state in /root/.state_* /root/.last_log_cleanup_*; do
        if [ -f "$old_state" ]; then
            local filename=$(basename "$old_state")
            local new_filename="${filename#.}"
            local new_state="${DATA_DIR}/$new_filename"
            
            if [ ! -f "$new_state" ]; then
                cp "$old_state" "$migration_backup/" 2>/dev/null
                if mv "$old_state" "$new_state" 2>/dev/null; then
                    echo "  ✅ $filename → data/$new_filename"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                skip_count=$((skip_count + 1))
            fi
        fi
    done
    
    # 迁移PID和锁文件
    echo "🔒 迁移进程文件..."
    for old_file in /root/github-sync-*.pid /root/github-sync-*.lock; do
        if [ -f "$old_file" ]; then
            local filename=$(basename "$old_file")
            local new_file="${DATA_DIR}/$filename"
            
            if [ ! -f "$new_file" ]; then
                cp "$old_file" "$migration_backup/" 2>/dev/null
                if mv "$old_file" "$new_file" 2>/dev/null; then
                    echo "  ✅ $filename → data/"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                skip_count=$((skip_count + 1))
            fi
        fi
    done
    
    # 迁移备份文件
    echo "💾 迁移备份文件..."
    for old_backup in /root/github-sync-*.conf.backup.*; do
        if [ -f "$old_backup" ]; then
            local filename=$(basename "$old_backup")
            local new_backup="${BACKUP_DIR}/$filename"
            
            if [ ! -f "$new_backup" ]; then
                if mv "$old_backup" "$new_backup" 2>/dev/null; then
                    echo "  ✅ $filename → backup/"
                    migrated_count=$((migrated_count + 1))
                else
                    echo "  ❌ $filename (迁移失败)"
                    error_count=$((error_count + 1))
                fi
            else
                echo "  ⚠️  $filename (目标已存在，跳过)"
                skip_count=$((skip_count + 1))
            fi
        fi
    done
    
    echo ""
    echo "📋 迁移总结:"
    echo "  ✅ 成功迁移: $migrated_count 个文件"
    echo "  ❌ 迁移失败: $error_count 个文件"
    echo "  ⚠️  跳过文件: $skip_count 个文件"
    
    if [ "$migrated_count" -gt 0 ]; then
        echo "  💾 迁移备份: $migration_backup"
        log_success "文件迁移完成！"
    elif [ "$error_count" -eq 0 ]; then
        log_info "无需迁移文件，所有文件已在正确位置。"
        rmdir "$migration_backup" 2>/dev/null || true
    else
        log_error "迁移过程中遇到错误。"
        return 1
    fi
    
    return 0
}

# 主函数
main() {
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 GitHub Sync Tool 文件迁移工具                         ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_info "开始 GitHub Sync Tool 文件迁移计划..."
    echo ""
    
    # 步骤1: 创建目录结构
    if ! create_directory_structure; then
        log_error "目录结构创建失败"
        exit 1
    fi
    
    echo ""
    
    # 步骤2: 发现文件
    if ! discover_files; then
        log_info "未发现需要迁移的文件"
        exit 0
    fi
    
    echo ""
    
    # 步骤3: 确认迁移
    echo "是否继续执行文件迁移？"
    echo "[y] 确定迁移    [n] 取消操作"
    echo ""
    echo -n "请选择: "
    read -r confirm
    
    case "$confirm" in
        y|Y|yes|YES)
            echo ""
            if execute_migration; then
                log_success "🎉 GitHub Sync Tool 文件迁移计划执行完成！"
            else
                log_error "迁移过程中遇到错误"
                exit 1
            fi
            ;;
        *)
            log_info "迁移操作已取消"
            exit 0
            ;;
    esac
}

# 执行主函数
main "$@"
