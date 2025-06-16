#!/bin/bash

# GitHub文件同步系统 - 通用服务管理脚本
# 自动检测init系统并使用相应的命令

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检测init系统
detect_init_system() {
    if command -v systemctl >/dev/null 2>&1 && [[ -f /etc/systemd/system/file-sync.service ]]; then
        echo "systemd"
    elif [[ -f /etc/init.d/file-sync ]] && grep -q "OpenWrt\|LEDE\|Kwrt" /etc/os-release 2>/dev/null; then
        echo "openwrt"
    elif [[ -f /etc/init.d/file-sync ]]; then
        echo "sysv"
    elif [[ -f /usr/local/bin/file-sync-service ]] || [[ -f /usr/bin/file-sync-service ]]; then
        echo "service"
    elif [[ -f /usr/local/bin/start-file-sync ]] || [[ -f /usr/bin/start-file-sync ]]; then
        echo "manual"
    else
        echo "unknown"
    fi
}

# 查找服务脚本路径
find_service_script() {
    local script_name="$1"

    if [[ -f "/usr/local/bin/$script_name" ]]; then
        echo "/usr/local/bin/$script_name"
    elif [[ -f "/usr/bin/$script_name" ]]; then
        echo "/usr/bin/$script_name"
    else
        echo ""
    fi
}

# 启动服务
start_service() {
    local init_system=$(detect_init_system)
    
    log_info "启动file-sync服务..."
    
    case "$init_system" in
        "systemd")
            systemctl start file-sync
            log_info "服务已启动 (systemd)"
            ;;
        "openwrt")
            /etc/init.d/file-sync start
            log_info "服务已启动 (OpenWrt procd)"
            ;;
        "sysv")
            service file-sync start
            log_info "服务已启动 (SysV init)"
            ;;
        "service")
            local service_script=$(find_service_script "file-sync-service")
            if [[ -n "$service_script" ]]; then
                "$service_script" start
                log_info "服务已启动 (service脚本)"
            else
                log_error "未找到service脚本"
                return 1
            fi
            ;;
        "manual")
            local start_script=$(find_service_script "start-file-sync")
            if [[ -n "$start_script" ]]; then
                "$start_script"
                log_info "服务已启动 (手动模式)"
            else
                log_error "未找到启动脚本"
                return 1
            fi
            ;;
        *)
            log_error "未找到服务配置"
            return 1
            ;;
    esac
}

# 停止服务
stop_service() {
    local init_system=$(detect_init_system)
    
    log_info "停止file-sync服务..."
    
    case "$init_system" in
        "systemd")
            systemctl stop file-sync
            log_info "服务已停止 (systemd)"
            ;;
        "openwrt")
            /etc/init.d/file-sync stop
            log_info "服务已停止 (OpenWrt procd)"
            ;;
        "sysv")
            service file-sync stop
            log_info "服务已停止 (SysV init)"
            ;;
        "service")
            local service_script=$(find_service_script "file-sync-service")
            if [[ -n "$service_script" ]]; then
                "$service_script" stop
                log_info "服务已停止 (service脚本)"
            else
                log_error "未找到service脚本"
                return 1
            fi
            ;;
        "manual")
            if [[ -f /file-sync-system/logs/daemon.pid ]]; then
                local pid=$(cat /file-sync-system/logs/daemon.pid)
                if kill -0 "$pid" 2>/dev/null; then
                    kill "$pid"
                    log_info "服务已停止 (手动模式)"
                else
                    log_warn "服务未运行"
                fi
            else
                log_warn "未找到PID文件"
            fi
            ;;
        *)
            log_error "未找到服务配置"
            return 1
            ;;
    esac
}

# 重启服务
restart_service() {
    local init_system=$(detect_init_system)
    
    log_info "重启file-sync服务..."
    
    case "$init_system" in
        "systemd")
            systemctl restart file-sync
            log_info "服务已重启 (systemd)"
            ;;
        "openwrt")
            /etc/init.d/file-sync restart
            log_info "服务已重启 (OpenWrt procd)"
            ;;
        "sysv")
            service file-sync restart
            log_info "服务已重启 (SysV init)"
            ;;
        "service")
            local service_script=$(find_service_script "file-sync-service")
            if [[ -n "$service_script" ]]; then
                "$service_script" restart
                log_info "服务已重启 (service脚本)"
            else
                log_error "未找到service脚本"
                return 1
            fi
            ;;
        "manual")
            stop_service
            sleep 2
            start_service
            ;;
        *)
            log_error "未找到服务配置"
            return 1
            ;;
    esac
}

# 查看服务状态
status_service() {
    local init_system=$(detect_init_system)
    
    echo "file-sync服务状态:"
    echo "Init系统: $init_system"
    echo ""
    
    case "$init_system" in
        "systemd")
            systemctl status file-sync --no-pager
            ;;
        "openwrt")
            /etc/init.d/file-sync status
            ;;
        "sysv")
            service file-sync status
            ;;
        "service")
            local service_script=$(find_service_script "file-sync-service")
            if [[ -n "$service_script" ]]; then
                "$service_script" status
            else
                log_error "未找到service脚本"
                return 1
            fi
            ;;
        "manual")
            if [[ -f /file-sync-system/logs/daemon.pid ]]; then
                local pid=$(cat /file-sync-system/logs/daemon.pid)
                if kill -0 "$pid" 2>/dev/null; then
                    log_info "服务正在运行 (PID: $pid)"
                else
                    log_warn "服务未运行 (PID文件存在但进程不存在)"
                fi
            else
                log_warn "服务未运行 (未找到PID文件)"
            fi
            ;;
        *)
            log_error "未找到服务配置"
            return 1
            ;;
    esac
    
    # 显示file-sync状态
    echo ""
    if command -v file-sync >/dev/null 2>&1; then
        file-sync status
    else
        log_warn "file-sync命令不可用"
    fi
}

# 启用开机自启
enable_service() {
    local init_system=$(detect_init_system)
    
    log_info "启用开机自启..."
    
    case "$init_system" in
        "systemd")
            systemctl enable file-sync
            log_info "已启用开机自启 (systemd)"
            ;;
        "sysv")
            if command -v chkconfig >/dev/null 2>&1; then
                chkconfig file-sync on
                log_info "已启用开机自启 (chkconfig)"
            elif command -v update-rc.d >/dev/null 2>&1; then
                update-rc.d file-sync enable
                log_info "已启用开机自启 (update-rc.d)"
            else
                log_warn "无法设置开机自启，请手动配置"
            fi
            ;;
        "service"|"manual")
            log_warn "当前模式不支持开机自启，请手动配置"
            ;;
        *)
            log_error "未找到服务配置"
            return 1
            ;;
    esac
}

# 禁用开机自启
disable_service() {
    local init_system=$(detect_init_system)
    
    log_info "禁用开机自启..."
    
    case "$init_system" in
        "systemd")
            systemctl disable file-sync
            log_info "已禁用开机自启 (systemd)"
            ;;
        "sysv")
            if command -v chkconfig >/dev/null 2>&1; then
                chkconfig file-sync off
                log_info "已禁用开机自启 (chkconfig)"
            elif command -v update-rc.d >/dev/null 2>&1; then
                update-rc.d file-sync disable
                log_info "已禁用开机自启 (update-rc.d)"
            else
                log_warn "无法禁用开机自启"
            fi
            ;;
        "service"|"manual")
            log_info "当前模式无开机自启配置"
            ;;
        *)
            log_error "未找到服务配置"
            return 1
            ;;
    esac
}

# 显示帮助信息
show_help() {
    cat << EOF
GitHub文件同步系统 - 服务管理脚本

用法: $0 <命令>

命令:
  start      启动服务
  stop       停止服务
  restart    重启服务
  status     查看状态
  enable     启用开机自启
  disable    禁用开机自启
  help       显示帮助信息

示例:
  $0 start     # 启动服务
  $0 status    # 查看状态
  $0 enable    # 启用开机自启

注意: 某些操作可能需要root权限
EOF
}

# 主函数
main() {
    local command="${1:-help}"
    
    case "$command" in
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "status")
            status_service
            ;;
        "enable")
            enable_service
            ;;
        "disable")
            disable_service
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
