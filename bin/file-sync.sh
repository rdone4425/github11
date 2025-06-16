#!/bin/bash

# GitHub文件同步系统 - 主程序入口
# 提供命令行界面和主要功能

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载核心模块
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/monitor.sh"
source "$PROJECT_ROOT/lib/github.sh"

# 程序信息
PROGRAM_NAME="file-sync"
VERSION="1.0.0"

# 显示帮助信息
show_help() {
    cat << EOF
GitHub文件同步系统 v$VERSION

用法: $PROGRAM_NAME [选项] <命令> [参数]

命令:
  init                    初始化配置文件
  start                   启动文件监控
  stop                    停止文件监控
  restart                 重启文件监控
  status                  显示监控状态
  config                  配置管理
  sync                    手动同步
  validate                验证配置
  logs                    查看日志

选项:
  -h, --help             显示此帮助信息
  -v, --verbose          启用详细输出
  -c, --config DIR       指定配置目录
  --version              显示版本信息

配置命令:
  config list            列出所有配置
  config edit            编辑配置文件
  config validate        验证配置
  config reset           重置配置

同步命令:
  sync all               同步所有启用的路径
  sync <path_id>         同步指定路径
  sync --force <path_id> 强制同步指定路径

日志命令:
  logs show              显示最近的日志
  logs follow            实时跟踪日志
  logs stats             显示日志统计
  logs clean             清理旧日志

示例:
  $PROGRAM_NAME init                    # 初始化配置
  $PROGRAM_NAME start                   # 启动监控
  $PROGRAM_NAME sync documents          # 同步documents路径
  $PROGRAM_NAME logs follow             # 实时查看日志

更多信息请参考: https://github.com/your-repo/file-sync-system
EOF
}

# 显示版本信息
show_version() {
    echo "$PROGRAM_NAME version $VERSION"
}

# 显示交互式菜单
show_interactive_menu() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              GitHub文件同步系统 v$VERSION                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # 检查配置状态
    local config_status="未配置"
    if [[ -f "$PROJECT_ROOT/config/global.conf" ]] && [[ -f "$PROJECT_ROOT/config/paths.conf" ]]; then
        config_status="已配置"
    fi

    echo "系统状态: $config_status"
    echo "安装位置: $PROJECT_ROOT"
    echo ""

    while true; do
        echo "请选择操作："
        echo ""
        echo "1) 🔧 初始化配置"
        echo "2) ⚙️  配置管理"
        echo "3) ✅ 验证配置"
        echo "4) 🚀 启动监控"
        echo "5) ⏹️  停止监控"
        echo "6) 📊 查看状态"
        echo "7) 🔄 手动同步"
        echo "8) 📝 查看日志"
        echo "9) ❓ 帮助信息"
        echo "0) 🚪 退出"
        echo ""
        read -p "请输入选择 [0-9]: " choice

        case $choice in
            1)
                echo ""
                init_system
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            2)
                echo ""
                config_submenu
                clear
                ;;
            3)
                echo ""
                validate_all_config
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            4)
                echo ""
                echo "启动文件监控..."
                load_global_config
                parse_paths_config
                start_monitoring
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            5)
                echo ""
                echo "停止文件监控..."
                stop_monitoring
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            6)
                echo ""
                load_global_config
                parse_paths_config
                get_monitor_status
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            7)
                echo ""
                sync_submenu
                clear
                ;;
            8)
                echo ""
                logs_submenu
                clear
                ;;
            9)
                echo ""
                show_help
                echo ""
                read -p "按Enter键继续..."
                clear
                ;;
            0)
                echo ""
                echo "感谢使用GitHub文件同步系统！"
                exit 0
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}

# 配置子菜单
config_submenu() {
    while true; do
        echo "配置管理："
        echo ""
        echo "1) 📋 列出配置"
        echo "2) ✏️  编辑配置"
        echo "3) ✅ 验证配置"
        echo "4) 🔄 重置配置"
        echo "0) 🔙 返回主菜单"
        echo ""
        read -p "请选择 [0-4]: " choice

        case $choice in
            1)
                echo ""
                manage_config "list"
                echo ""
                read -p "按Enter键继续..."
                ;;
            2)
                echo ""
                manage_config "edit"
                echo ""
                read -p "按Enter键继续..."
                ;;
            3)
                echo ""
                manage_config "validate"
                echo ""
                read -p "按Enter键继续..."
                ;;
            4)
                echo ""
                manage_config "reset"
                echo ""
                read -p "按Enter键继续..."
                ;;
            0)
                return
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}

# 同步子菜单
sync_submenu() {
    while true; do
        echo "手动同步："
        echo ""
        echo "1) 🔄 同步所有路径"
        echo "2) 📁 同步指定路径"
        echo "3) ⚡ 强制同步指定路径"
        echo "0) 🔙 返回主菜单"
        echo ""
        read -p "请选择 [0-3]: " choice

        case $choice in
            1)
                echo ""
                manual_sync "all" false
                echo ""
                read -p "按Enter键继续..."
                ;;
            2)
                echo ""
                echo "可用路径："
                load_global_config
                parse_paths_config
                local enabled_paths
                mapfile -t enabled_paths < <(get_enabled_paths)
                for path_id in "${enabled_paths[@]}"; do
                    echo "  - $path_id"
                done
                echo ""
                read -p "请输入路径ID: " path_id
                if [[ -n "$path_id" ]]; then
                    manual_sync "$path_id" false
                fi
                echo ""
                read -p "按Enter键继续..."
                ;;
            3)
                echo ""
                echo "可用路径："
                load_global_config
                parse_paths_config
                local enabled_paths
                mapfile -t enabled_paths < <(get_enabled_paths)
                for path_id in "${enabled_paths[@]}"; do
                    echo "  - $path_id"
                done
                echo ""
                read -p "请输入路径ID: " path_id
                if [[ -n "$path_id" ]]; then
                    manual_sync "$path_id" true
                fi
                echo ""
                read -p "按Enter键继续..."
                ;;
            0)
                return
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}

# 日志子菜单
logs_submenu() {
    while true; do
        echo "日志管理："
        echo ""
        echo "1) 📄 显示最近日志"
        echo "2) 👁️  实时跟踪日志"
        echo "3) 📊 日志统计"
        echo "4) 🧹 清理旧日志"
        echo "0) 🔙 返回主菜单"
        echo ""
        read -p "请选择 [0-4]: " choice

        case $choice in
            1)
                echo ""
                manage_logs "show"
                echo ""
                read -p "按Enter键继续..."
                ;;
            2)
                echo ""
                echo "按Ctrl+C退出日志跟踪"
                manage_logs "follow"
                echo ""
                read -p "按Enter键继续..."
                ;;
            3)
                echo ""
                manage_logs "stats"
                echo ""
                read -p "按Enter键继续..."
                ;;
            4)
                echo ""
                manage_logs "clean"
                echo ""
                read -p "按Enter键继续..."
                ;;
            0)
                return
                ;;
            *)
                echo ""
                echo "无效选择，请重新输入"
                echo ""
                ;;
        esac
    done
}

# 初始化系统
init_system() {
    echo "正在初始化GitHub文件同步系统..."
    
    # 检查依赖
    if ! check_dependencies; then
        echo "错误: 缺少必需的依赖，请先安装"
        exit 1
    fi
    
    # 初始化各个模块
    init_logger
    init_config
    init_monitor
    init_github
    
    echo "初始化完成！"
    echo ""
    echo "下一步："
    echo "1. 编辑全局配置文件: $PROJECT_ROOT/config/global.conf"
    echo "2. 配置监控路径: $PROJECT_ROOT/config/paths.conf"
    echo "3. 运行 '$PROGRAM_NAME validate' 验证配置"
    echo "4. 运行 '$PROGRAM_NAME start' 启动监控"
}

# 配置管理
manage_config() {
    local action="$1"
    
    case "$action" in
        "list")
            echo "=== 全局配置 ==="
            if [[ -f "$PROJECT_ROOT/config/global.conf" ]]; then
                grep -v '^#' "$PROJECT_ROOT/config/global.conf" | grep -v '^$'
            else
                echo "配置文件不存在"
            fi
            
            echo ""
            echo "=== 路径配置 ==="
            if [[ -f "$PROJECT_ROOT/config/paths.conf" ]]; then
                grep -v '^#' "$PROJECT_ROOT/config/paths.conf" | grep -v '^$'
            else
                echo "配置文件不存在"
            fi
            ;;
        "edit")
            local editor="${EDITOR:-nano}"
            echo "选择要编辑的配置文件:"
            echo "1) 全局配置 (global.conf)"
            echo "2) 路径配置 (paths.conf)"
            read -p "请选择 [1-2]: " choice
            
            case "$choice" in
                1)
                    "$editor" "$PROJECT_ROOT/config/global.conf"
                    ;;
                2)
                    "$editor" "$PROJECT_ROOT/config/paths.conf"
                    ;;
                *)
                    echo "无效选择"
                    exit 1
                    ;;
            esac
            ;;
        "validate")
            validate_all_config
            ;;
        "reset")
            if confirm_action "确定要重置所有配置吗？这将删除现有配置"; then
                rm -f "$PROJECT_ROOT/config/global.conf"
                rm -f "$PROJECT_ROOT/config/paths.conf"
                init_config
                echo "配置已重置"
            fi
            ;;
        *)
            echo "未知的配置命令: $action"
            echo "可用命令: list, edit, validate, reset"
            exit 1
            ;;
    esac
}

# 验证所有配置
validate_all_config() {
    echo "正在验证配置..."
    
    local errors=0
    
    # 验证全局配置
    if ! validate_global_config; then
        ((errors++))
    fi
    
    # 验证路径配置
    parse_paths_config
    local enabled_paths
    mapfile -t enabled_paths < <(get_enabled_paths)
    
    for path_id in "${enabled_paths[@]}"; do
        echo "验证路径配置: $path_id"
        
        local local_path=$(get_path_config "$path_id" "LOCAL_PATH")
        local github_repo=$(get_path_config "$path_id" "GITHUB_REPO")
        
        # 检查本地路径
        if [[ ! -d "$local_path" ]]; then
            echo "错误: 本地路径不存在: $local_path"
            ((errors++))
        fi
        
        # 验证GitHub配置
        if ! validate_path_github_config "$path_id"; then
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        echo "配置验证通过！"
        return 0
    else
        echo "配置验证失败，发现 $errors 个错误"
        return 1
    fi
}

# 手动同步
manual_sync() {
    local target="$1"
    local force="$2"
    
    # 加载配置
    load_global_config
    parse_paths_config
    
    case "$target" in
        "all")
            echo "开始同步所有启用的路径..."
            local enabled_paths
            mapfile -t enabled_paths < <(get_enabled_paths)
            
            for path_id in "${enabled_paths[@]}"; do
                echo "同步路径: $path_id"
                sync_directory_to_github "$path_id" "$force"
            done
            ;;
        *)
            if [[ -n "$target" ]]; then
                echo "同步路径: $target"
                sync_directory_to_github "$target" "$force"
            else
                echo "错误: 请指定要同步的路径或使用 'all'"
                exit 1
            fi
            ;;
    esac
}

# 日志管理
manage_logs() {
    local action="$1"
    
    case "$action" in
        "show")
            if [[ -f "$PROJECT_ROOT/logs/file-sync.log" ]]; then
                tail -n 50 "$PROJECT_ROOT/logs/file-sync.log"
            else
                echo "日志文件不存在"
            fi
            ;;
        "follow")
            if [[ -f "$PROJECT_ROOT/logs/file-sync.log" ]]; then
                tail -f "$PROJECT_ROOT/logs/file-sync.log"
            else
                echo "日志文件不存在"
            fi
            ;;
        "stats")
            get_log_stats
            ;;
        "clean")
            if confirm_action "确定要清理旧日志吗？"; then
                cleanup_logs 7
            fi
            ;;
        *)
            echo "未知的日志命令: $action"
            echo "可用命令: show, follow, stats, clean"
            exit 1
            ;;
    esac
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--config)
                CONFIG_DIR="$2"
                shift 2
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    # 检查是否有命令
    if [[ $# -eq 0 ]]; then
        show_interactive_menu
        return 0
    fi
    
    local command="$1"
    shift
    
    # 执行命令
    case "$command" in
        "init")
            init_system
            ;;
        "start")
            load_global_config
            parse_paths_config
            start_monitoring
            ;;
        "stop")
            stop_monitoring
            ;;
        "restart")
            restart_monitoring
            ;;
        "status")
            load_global_config
            parse_paths_config
            get_monitor_status
            ;;
        "config")
            manage_config "$1"
            ;;
        "sync")
            local force=false
            if [[ "$1" == "--force" ]]; then
                force=true
                shift
            fi
            manual_sync "$1" "$force"
            ;;
        "validate")
            validate_all_config
            ;;
        "logs")
            manage_logs "$1"
            ;;
        *)
            echo "未知命令: $command"
            echo "运行 '$PROGRAM_NAME --help' 查看帮助"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
