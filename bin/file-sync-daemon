#!/bin/bash

# GitHub文件同步系统 - 守护进程脚本
# 用于系统服务管理

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载核心模块
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/logger.sh"
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/monitor.sh"

# 守护进程配置
DAEMON_NAME="file-sync-daemon"
DAEMON_USER="${DAEMON_USER:-$(whoami)}"
DAEMON_GROUP="${DAEMON_GROUP:-$(id -gn)}"

# PID和锁文件
PID_FILE="$PROJECT_ROOT/logs/daemon.pid"
LOCK_FILE="$PROJECT_ROOT/logs/daemon.lock"

# 日志文件
DAEMON_LOG="$PROJECT_ROOT/logs/daemon.log"

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# 创建守护进程用户
create_daemon_user() {
    if check_root; then
        if ! id "$DAEMON_USER" &>/dev/null; then
            useradd -r -s /bin/false -d "$PROJECT_ROOT" "$DAEMON_USER"
            log_info "创建守护进程用户: $DAEMON_USER"
        fi
    fi
}

# 设置文件权限
setup_permissions() {
    # 确保目录存在
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/config"
    
    # 设置权限
    chmod 755 "$PROJECT_ROOT"
    chmod 755 "$PROJECT_ROOT/bin"
    chmod 755 "$PROJECT_ROOT/lib"
    chmod 755 "$PROJECT_ROOT/logs"
    chmod 755 "$PROJECT_ROOT/config"
    
    # 设置脚本执行权限
    chmod +x "$PROJECT_ROOT/bin/file-sync"
    chmod +x "$PROJECT_ROOT/bin/file-sync-daemon"
    
    # 如果以root运行，设置用户权限
    if check_root && [[ "$DAEMON_USER" != "root" ]]; then
        chown -R "$DAEMON_USER:$DAEMON_GROUP" "$PROJECT_ROOT/logs"
        chown -R "$DAEMON_USER:$DAEMON_GROUP" "$PROJECT_ROOT/config"
    fi
}

# 检查守护进程是否运行
is_daemon_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # PID文件存在但进程不存在，清理PID文件
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# 启动守护进程
start_daemon() {
    echo "启动 $DAEMON_NAME..."
    
    # 检查是否已经运行
    if is_daemon_running; then
        echo "$DAEMON_NAME 已在运行"
        return 1
    fi
    
    # 设置权限
    setup_permissions
    
    # 加载配置
    if ! load_global_config; then
        echo "错误: 无法加载配置文件"
        return 1
    fi
    
    if ! parse_paths_config; then
        echo "错误: 无法解析路径配置"
        return 1
    fi
    
    # 验证配置
    if ! validate_global_config; then
        echo "错误: 配置验证失败"
        return 1
    fi
    
    # 创建锁文件
    (
        flock -n 9 || {
            echo "错误: 无法获取锁，可能已有实例在运行"
            exit 1
        }
        
        # 启动监控
        echo "正在启动文件监控..."
        
        # 重定向输出到日志文件
        exec 1>>"$DAEMON_LOG"
        exec 2>>"$DAEMON_LOG"
        
        # 记录启动信息
        echo "$(get_timestamp) - $DAEMON_NAME 启动" >> "$DAEMON_LOG"
        
        # 初始化模块
        init_logger
        init_monitor
        init_github
        
        # 启动监控
        start_monitoring
        
        # 记录PID
        echo $$ > "$PID_FILE"
        
        # 等待信号
        trap 'stop_daemon_internal; exit 0' TERM INT
        
        # 保持运行
        while true; do
            sleep 60
            
            # 检查监控是否还在运行
            if ! is_monitor_running; then
                log_warn "监控进程意外停止，尝试重启"
                start_monitoring
            fi
        done
        
    ) 9>"$LOCK_FILE" &
    
    # 等待一下确保启动成功
    sleep 2
    
    if is_daemon_running; then
        echo "$DAEMON_NAME 启动成功"
        return 0
    else
        echo "$DAEMON_NAME 启动失败"
        return 1
    fi
}

# 停止守护进程
stop_daemon() {
    echo "停止 $DAEMON_NAME..."
    
    if ! is_daemon_running; then
        echo "$DAEMON_NAME 未运行"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    
    # 发送TERM信号
    kill -TERM "$pid" 2>/dev/null
    
    # 等待进程结束
    local count=0
    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 30 ]]; do
        sleep 1
        ((count++))
    done
    
    # 如果进程仍在运行，强制终止
    if kill -0 "$pid" 2>/dev/null; then
        echo "强制终止进程..."
        kill -KILL "$pid" 2>/dev/null
    fi
    
    # 清理文件
    rm -f "$PID_FILE"
    rm -f "$LOCK_FILE"
    
    echo "$DAEMON_NAME 已停止"
    return 0
}

# 内部停止函数（由守护进程调用）
stop_daemon_internal() {
    echo "$(get_timestamp) - 接收到停止信号" >> "$DAEMON_LOG"
    
    # 停止监控
    stop_monitoring
    
    # 清理文件
    rm -f "$PID_FILE"
    rm -f "$LOCK_FILE"
    
    echo "$(get_timestamp) - $DAEMON_NAME 已停止" >> "$DAEMON_LOG"
}

# 重启守护进程
restart_daemon() {
    stop_daemon
    sleep 2
    start_daemon
}

# 获取守护进程状态
get_daemon_status() {
    if is_daemon_running; then
        local pid=$(cat "$PID_FILE")
        echo "$DAEMON_NAME 正在运行 (PID: $pid)"
        
        # 显示监控状态
        source "$PROJECT_ROOT/lib/monitor.sh"
        load_global_config
        parse_paths_config
        get_monitor_status
    else
        echo "$DAEMON_NAME 未运行"
    fi
}

# 重新加载配置
reload_daemon() {
    if is_daemon_running; then
        local pid=$(cat "$PID_FILE")
        kill -HUP "$pid" 2>/dev/null
        echo "配置重新加载信号已发送"
    else
        echo "$DAEMON_NAME 未运行"
        return 1
    fi
}

# 安装系统服务
install_service() {
    if ! check_root; then
        echo "错误: 需要root权限来安装系统服务"
        return 1
    fi
    
    echo "安装系统服务..."
    
    # 创建systemd服务文件
    cat > /etc/systemd/system/file-sync.service << EOF
[Unit]
Description=GitHub File Sync Service
After=network.target

[Service]
Type=forking
User=$DAEMON_USER
Group=$DAEMON_GROUP
WorkingDirectory=$PROJECT_ROOT
ExecStart=$PROJECT_ROOT/bin/file-sync-daemon start
ExecStop=$PROJECT_ROOT/bin/file-sync-daemon stop
ExecReload=$PROJECT_ROOT/bin/file-sync-daemon reload
PIDFile=$PID_FILE
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable file-sync.service
    
    echo "系统服务安装完成"
    echo "使用以下命令管理服务:"
    echo "  systemctl start file-sync    # 启动服务"
    echo "  systemctl stop file-sync     # 停止服务"
    echo "  systemctl status file-sync   # 查看状态"
    echo "  systemctl enable file-sync   # 开机自启"
}

# 卸载系统服务
uninstall_service() {
    if ! check_root; then
        echo "错误: 需要root权限来卸载系统服务"
        return 1
    fi
    
    echo "卸载系统服务..."
    
    # 停止并禁用服务
    systemctl stop file-sync.service 2>/dev/null
    systemctl disable file-sync.service 2>/dev/null
    
    # 删除服务文件
    rm -f /etc/systemd/system/file-sync.service
    
    # 重新加载systemd
    systemctl daemon-reload
    
    echo "系统服务已卸载"
}

# 显示帮助信息
show_help() {
    cat << EOF
GitHub文件同步系统 - 守护进程管理

用法: $0 <命令>

命令:
  start                   启动守护进程
  stop                    停止守护进程
  restart                 重启守护进程
  status                  显示守护进程状态
  reload                  重新加载配置
  install                 安装为系统服务 (需要root权限)
  uninstall               卸载系统服务 (需要root权限)

示例:
  $0 start                # 启动守护进程
  $0 status               # 查看状态
  sudo $0 install         # 安装系统服务
EOF
}

# 主函数
main() {
    case "${1:-}" in
        start)
            start_daemon
            ;;
        stop)
            stop_daemon
            ;;
        restart)
            restart_daemon
            ;;
        status)
            get_daemon_status
            ;;
        reload)
            reload_daemon
            ;;
        install)
            install_service
            ;;
        uninstall)
            uninstall_service
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
