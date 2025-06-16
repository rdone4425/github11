#!/bin/bash

# GitHub文件同步系统 - 演示脚本
# 展示系统的主要功能和使用方法

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 演示配置
DEMO_DIR="$SCRIPT_DIR/demo"
DEMO_WATCH_DIR="$DEMO_DIR/watch"
DEMO_CONFIG_DIR="$DEMO_DIR/config"

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

log_demo() {
    echo -e "${PURPLE}[DEMO]${NC} $1"
}

# 显示标题
show_title() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                GitHub文件同步系统 - 演示                      ║
║                                                              ║
║  这个演示将展示系统的主要功能：                                ║
║  • 文件监控和自动同步                                         ║
║  • 配置管理                                                   ║
║  • 日志记录                                                   ║
║  • 错误处理                                                   ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查依赖
check_dependencies() {
    log_step "检查系统依赖..."
    
    local missing_deps=()
    local required_commands=("bash" "curl" "jq")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必需的依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖后重新运行演示"
        return 1
    fi
    
    log_info "依赖检查通过"
    return 0
}

# 创建演示环境
setup_demo_environment() {
    log_step "创建演示环境..."
    
    # 创建演示目录
    mkdir -p "$DEMO_WATCH_DIR"
    mkdir -p "$DEMO_CONFIG_DIR"
    
    # 创建演示配置文件
    cat > "$DEMO_CONFIG_DIR/global.conf" << 'EOF'
# 演示配置 - 请勿在生产环境使用
GITHUB_USERNAME="demo-user"
GITHUB_TOKEN="demo-token-replace-with-real-token"
DEFAULT_BRANCH="main"
SYNC_INTERVAL=3
LOG_LEVEL="INFO"
MAX_RETRIES=2
EXCLUDE_PATTERNS="*.tmp *.log *.swp .git"
VERBOSE=true
GITHUB_API_URL="https://api.github.com"
MAX_FILE_SIZE=104857600
COMMIT_MESSAGE_TEMPLATE="Demo sync: %s"
VALIDATE_BEFORE_SYNC=false
EOF
    
    cat > "$DEMO_CONFIG_DIR/paths.conf" << EOF
# 演示路径配置
[demo-documents]
LOCAL_PATH=$DEMO_WATCH_DIR
GITHUB_REPO=demo-user/demo-repo
TARGET_BRANCH=main
SUBDIR_MAPPING=documents
ENABLED=true
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=*.backup
EOF
    
    log_info "演示环境创建完成"
}

# 演示配置管理
demo_config_management() {
    log_step "演示配置管理功能..."
    
    log_demo "1. 加载配置模块"
    source "$SCRIPT_DIR/lib/utils.sh"
    source "$SCRIPT_DIR/lib/logger.sh"
    source "$SCRIPT_DIR/lib/config.sh"
    
    # 临时设置配置路径
    GLOBAL_CONFIG="$DEMO_CONFIG_DIR/global.conf"
    PATHS_CONFIG="$DEMO_CONFIG_DIR/paths.conf"
    
    log_demo "2. 解析全局配置"
    if load_global_config; then
        log_info "全局配置加载成功"
        echo "  GitHub用户名: $GITHUB_USERNAME"
        echo "  同步间隔: $SYNC_INTERVAL 秒"
        echo "  日志级别: $LOG_LEVEL"
    else
        log_warn "全局配置加载失败（演示模式）"
    fi
    
    log_demo "3. 解析路径配置"
    if parse_paths_config; then
        log_info "路径配置解析成功"
        local enabled_paths
        mapfile -t enabled_paths < <(get_enabled_paths)
        echo "  启用的路径数量: ${#enabled_paths[@]}"
        for path_id in "${enabled_paths[@]}"; do
            local local_path=$(get_path_config "$path_id" "LOCAL_PATH")
            local github_repo=$(get_path_config "$path_id" "GITHUB_REPO")
            echo "    - $path_id: $local_path -> $github_repo"
        done
    else
        log_warn "路径配置解析失败（演示模式）"
    fi
}

# 演示日志系统
demo_logging_system() {
    log_step "演示日志系统..."
    
    # 初始化日志系统
    LOG_DIR="$DEMO_DIR/logs"
    LOG_FILE="$LOG_DIR/demo.log"
    ERROR_LOG_FILE="$LOG_DIR/error.log"
    
    mkdir -p "$LOG_DIR"
    init_logger
    
    log_demo "1. 测试不同级别的日志"
    log_debug "这是一条调试信息"
    log_info "这是一条信息日志"
    log_warn "这是一条警告信息"
    log_error "这是一条错误信息"
    
    log_demo "2. 查看日志文件内容"
    if [[ -f "$LOG_FILE" ]]; then
        echo "最近的日志条目："
        tail -n 5 "$LOG_FILE" | while read line; do
            echo "  $line"
        done
    fi
    
    log_demo "3. 日志统计信息"
    get_log_stats "$LOG_FILE"
}

# 演示文件监控
demo_file_monitoring() {
    log_step "演示文件监控功能..."
    
    log_demo "1. 创建测试文件"
    echo "这是一个测试文件" > "$DEMO_WATCH_DIR/test1.txt"
    echo "另一个测试文件" > "$DEMO_WATCH_DIR/test2.md"
    
    log_demo "2. 测试文件排除功能"
    echo "临时文件" > "$DEMO_WATCH_DIR/temp.tmp"
    echo "日志文件" > "$DEMO_WATCH_DIR/debug.log"
    
    # 加载监控模块
    source "$SCRIPT_DIR/lib/monitor.sh"
    
    log_demo "3. 检查文件是否应该被排除"
    local test_files=("test1.txt" "test2.md" "temp.tmp" "debug.log")
    for file in "${test_files[@]}"; do
        local file_path="$DEMO_WATCH_DIR/$file"
        if should_exclude_file "$file_path"; then
            echo "  ❌ $file (被排除)"
        else
            echo "  ✅ $file (将被监控)"
        fi
    done
}

# 演示GitHub集成
demo_github_integration() {
    log_step "演示GitHub集成功能..."
    
    log_demo "1. 加载GitHub模块"
    source "$SCRIPT_DIR/lib/github.sh"
    
    log_demo "2. 测试GitHub连接（模拟）"
    log_info "正在测试GitHub API连接..."
    
    # 模拟GitHub API调用
    if command -v curl >/dev/null 2>&1; then
        local response=$(curl -s -I https://api.github.com | head -n 1)
        if [[ "$response" =~ "200 OK" ]]; then
            log_info "GitHub API连接正常"
        else
            log_warn "GitHub API连接可能有问题"
        fi
    else
        log_warn "curl命令不可用，跳过连接测试"
    fi
    
    log_demo "3. 文件同步模拟"
    log_info "模拟同步文件到GitHub..."
    echo "  文件: test1.txt -> demo-user/demo-repo/documents/test1.txt"
    echo "  操作: 创建/更新"
    echo "  状态: 成功（模拟）"
}

# 演示错误处理
demo_error_handling() {
    log_step "演示错误处理功能..."
    
    log_demo "1. 测试错误陷阱"
    set_error_trap
    
    log_demo "2. 模拟各种错误情况"
    
    # 模拟配置错误
    log_info "模拟配置文件不存在的错误..."
    if [[ ! -f "/nonexistent/config.conf" ]]; then
        handle_error 2 100 "demo_function" "配置文件不存在"
    fi
    
    # 模拟网络错误
    log_info "模拟网络连接错误..."
    handle_error 3 101 "demo_function" "无法连接到GitHub API"
    
    # 模拟权限错误
    log_info "模拟文件权限错误..."
    handle_error 4 102 "demo_function" "没有写入权限"
    
    clear_error_trap
}

# 演示系统健康检查
demo_health_check() {
    log_step "演示系统健康检查..."
    
    log_demo "1. 检查系统依赖"
    check_dependencies
    
    log_demo "2. 检查磁盘空间"
    if check_disk_space "$DEMO_DIR" 10; then
        log_info "磁盘空间充足"
    else
        log_warn "磁盘空间不足"
    fi
    
    log_demo "3. 检查网络连接"
    if check_network_connectivity "github.com" 5; then
        log_info "网络连接正常"
    else
        log_warn "网络连接异常"
    fi
}

# 演示命令行界面
demo_cli_interface() {
    log_step "演示命令行界面..."
    
    log_demo "1. 显示帮助信息"
    echo "模拟运行: file-sync --help"
    echo ""
    
    log_demo "2. 显示版本信息"
    echo "模拟运行: file-sync --version"
    echo "file-sync version 1.0.0"
    echo ""
    
    log_demo "3. 配置管理命令"
    echo "模拟运行: file-sync config list"
    echo "=== 全局配置 ==="
    echo "GITHUB_USERNAME=demo-user"
    echo "SYNC_INTERVAL=3"
    echo "LOG_LEVEL=INFO"
    echo ""
    echo "=== 路径配置 ==="
    echo "[demo-documents]"
    echo "LOCAL_PATH=$DEMO_WATCH_DIR"
    echo "GITHUB_REPO=demo-user/demo-repo"
    echo ""
}

# 清理演示环境
cleanup_demo() {
    log_step "清理演示环境..."
    
    if [[ -d "$DEMO_DIR" ]]; then
        rm -rf "$DEMO_DIR"
        log_info "演示环境已清理"
    fi
}

# 显示总结
show_summary() {
    echo ""
    log_info "演示完成！"
    echo ""
    echo -e "${CYAN}系统功能总结：${NC}"
    echo "✅ 配置管理 - 支持全局配置和多路径配置"
    echo "✅ 文件监控 - 基于inotify的实时文件监控"
    echo "✅ GitHub同步 - 自动同步文件到GitHub仓库"
    echo "✅ 日志系统 - 完整的日志记录和管理"
    echo "✅ 错误处理 - 健壮的错误处理机制"
    echo "✅ 服务管理 - systemd服务集成"
    echo "✅ 命令行工具 - 丰富的CLI命令"
    echo ""
    echo -e "${YELLOW}下一步：${NC}"
    echo "1. 阅读安装指南: docs/installation.md"
    echo "2. 配置系统: docs/configuration.md"
    echo "3. 开始使用: docs/usage.md"
    echo ""
    echo -e "${GREEN}感谢使用GitHub文件同步系统！${NC}"
}

# 主函数
main() {
    show_title
    
    echo "按Enter键开始演示，或按Ctrl+C退出..."
    read -r
    
    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi
    
    # 设置演示环境
    setup_demo_environment
    
    # 运行各个演示
    demo_config_management
    echo ""; read -p "按Enter键继续下一个演示..." -r; echo ""
    
    demo_logging_system
    echo ""; read -p "按Enter键继续下一个演示..." -r; echo ""
    
    demo_file_monitoring
    echo ""; read -p "按Enter键继续下一个演示..." -r; echo ""
    
    demo_github_integration
    echo ""; read -p "按Enter键继续下一个演示..." -r; echo ""
    
    demo_error_handling
    echo ""; read -p "按Enter键继续下一个演示..." -r; echo ""
    
    demo_health_check
    echo ""; read -p "按Enter键继续下一个演示..." -r; echo ""
    
    demo_cli_interface
    echo ""; read -p "按Enter键查看总结..." -r; echo ""
    
    # 显示总结
    show_summary
    
    # 清理
    cleanup_demo
}

# 运行主函数
main "$@"
