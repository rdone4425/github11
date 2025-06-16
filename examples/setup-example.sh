#!/bin/bash

# GitHub文件同步系统 - 配置示例脚本
# 帮助用户快速配置系统

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置文件路径
GLOBAL_CONFIG="/opt/file-sync-system/config/global.conf"
PATHS_CONFIG="/opt/file-sync-system/config/paths.conf"

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

# 检查是否已安装
check_installation() {
    if [[ ! -f "$GLOBAL_CONFIG" ]] || [[ ! -f "$PATHS_CONFIG" ]]; then
        log_error "GitHub文件同步系统未安装"
        echo "请先运行安装命令："
        echo "bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/quick-install.sh)"
        exit 1
    fi
}

# 配置GitHub凭据
setup_github_credentials() {
    log_step "配置GitHub凭据..."
    
    echo "请提供您的GitHub信息："
    echo ""
    
    # 获取GitHub用户名
    read -p "GitHub用户名: " github_username
    if [[ -z "$github_username" ]]; then
        log_error "GitHub用户名不能为空"
        exit 1
    fi
    
    # 获取GitHub Token
    echo ""
    echo "GitHub Personal Access Token获取方法："
    echo "1. 访问 https://github.com/settings/tokens"
    echo "2. 点击 'Generate new token (classic)'"
    echo "3. 选择 'repo' 权限"
    echo "4. 复制生成的token"
    echo ""
    read -s -p "GitHub Token: " github_token
    echo ""
    
    if [[ -z "$github_token" ]]; then
        log_error "GitHub Token不能为空"
        exit 1
    fi
    
    # 更新配置文件
    sed -i "s/GITHUB_USERNAME=\".*\"/GITHUB_USERNAME=\"$github_username\"/" "$GLOBAL_CONFIG"
    sed -i "s/GITHUB_TOKEN=\".*\"/GITHUB_TOKEN=\"$github_token\"/" "$GLOBAL_CONFIG"
    
    log_info "GitHub凭据配置完成"
}

# 配置监控路径
setup_monitoring_paths() {
    log_step "配置监控路径..."
    
    # 清空现有配置
    cat > "$PATHS_CONFIG" << 'EOF'
# GitHub文件同步系统 - 监控路径配置文件
# 此文件由setup-example.sh自动生成

EOF
    
    local path_count=1
    
    while true; do
        echo ""
        echo "配置监控路径 #$path_count"
        echo "按Enter跳过此路径配置"
        echo ""
        
        # 获取本地路径
        read -p "本地目录路径: " local_path
        if [[ -z "$local_path" ]]; then
            break
        fi
        
        # 检查路径是否存在
        if [[ ! -d "$local_path" ]]; then
            log_warn "目录不存在: $local_path"
            read -p "是否创建此目录? [y/N]: " create_dir
            if [[ "$create_dir" =~ ^[Yy]$ ]]; then
                mkdir -p "$local_path"
                log_info "目录已创建: $local_path"
            else
                continue
            fi
        fi
        
        # 获取GitHub仓库
        read -p "GitHub仓库 (格式: username/repo): " github_repo
        if [[ -z "$github_repo" ]]; then
            log_warn "GitHub仓库不能为空，跳过此路径"
            continue
        fi
        
        # 获取分支（可选）
        read -p "目标分支 [main]: " target_branch
        target_branch=${target_branch:-main}
        
        # 获取子目录映射（可选）
        read -p "子目录映射 (可选): " subdir_mapping
        
        # 生成路径ID
        local path_id="path$path_count"
        
        # 写入配置
        cat >> "$PATHS_CONFIG" << EOF
[$path_id]
LOCAL_PATH=$local_path
GITHUB_REPO=$github_repo
TARGET_BRANCH=$target_branch
SUBDIR_MAPPING=$subdir_mapping
ENABLED=true
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=

EOF
        
        log_info "路径配置已添加: $path_id"
        ((path_count++))
    done
    
    if [[ $path_count -eq 1 ]]; then
        log_warn "未配置任何监控路径"
        
        # 添加示例配置
        cat >> "$PATHS_CONFIG" << EOF
# 示例配置 - 请根据需要修改
[documents]
LOCAL_PATH=/home/\$USER/Documents
GITHUB_REPO=your-username/my-documents
TARGET_BRANCH=main
SUBDIR_MAPPING=
ENABLED=false
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=

[projects]
LOCAL_PATH=/home/\$USER/projects
GITHUB_REPO=your-username/my-projects
TARGET_BRANCH=main
SUBDIR_MAPPING=
ENABLED=false
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=*.log *.tmp
EOF
        log_info "已添加示例配置，请手动编辑: $PATHS_CONFIG"
    else
        log_info "监控路径配置完成"
    fi
}

# 验证配置
validate_configuration() {
    log_step "验证配置..."
    
    if file-sync validate; then
        log_info "配置验证通过"
        return 0
    else
        log_error "配置验证失败"
        return 1
    fi
}

# 启动服务
start_service() {
    log_step "启动服务..."
    
    if systemctl start file-sync; then
        log_info "服务启动成功"
        
        # 启用开机自启
        systemctl enable file-sync
        log_info "已启用开机自启"
        
        # 显示状态
        echo ""
        file-sync status
        
        return 0
    else
        log_error "服务启动失败"
        return 1
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    log_info "🎉 配置完成！"
    echo ""
    echo "常用命令："
    echo "• 查看状态: file-sync status"
    echo "• 查看日志: file-sync logs follow"
    echo "• 手动同步: file-sync sync all"
    echo "• 停止服务: systemctl stop file-sync"
    echo "• 重启服务: systemctl restart file-sync"
    echo ""
    echo "配置文件位置："
    echo "• 全局配置: $GLOBAL_CONFIG"
    echo "• 路径配置: $PATHS_CONFIG"
    echo ""
    echo "文档位置："
    echo "• /opt/file-sync-system/docs/"
    echo ""
}

# 主函数
main() {
    echo "GitHub文件同步系统 - 快速配置向导"
    echo "======================================"
    echo ""
    
    # 检查安装
    check_installation
    
    # 配置GitHub凭据
    setup_github_credentials
    
    # 配置监控路径
    setup_monitoring_paths
    
    # 验证配置
    if ! validate_configuration; then
        log_error "请检查配置后重新运行"
        exit 1
    fi
    
    # 启动服务
    if ! start_service; then
        log_error "请检查日志: journalctl -u file-sync"
        exit 1
    fi
    
    # 显示完成信息
    show_completion
}

# 运行主函数
main "$@"
