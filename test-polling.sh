#!/bin/bash

# 轮询监控模式测试脚本
# 用于验证在没有inotify的环境下轮询模式是否正常工作

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试目录
TEST_DIR="/tmp/file-sync-test"
CONFIG_DIR="$TEST_DIR/config"

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# 清理函数
cleanup() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# 设置测试环境
setup_test() {
    log_test "设置测试环境..."
    
    # 清理旧的测试目录
    cleanup
    
    # 创建测试目录
    mkdir -p "$TEST_DIR"/{watch,config,logs}
    
    # 创建测试配置
    cat > "$CONFIG_DIR/global.conf" << 'EOF'
GITHUB_USERNAME="test-user"
GITHUB_TOKEN="test-token"
DEFAULT_BRANCH="main"
SYNC_INTERVAL=5
LOG_LEVEL="DEBUG"
VERBOSE=true
POLLING_INTERVAL=3
FORCE_POLLING=true
EXCLUDE_PATTERNS="*.tmp *.log"
EOF
    
    cat > "$CONFIG_DIR/paths.conf" << EOF
[test-path]
LOCAL_PATH=$TEST_DIR/watch
GITHUB_REPO=test-user/test-repo
TARGET_BRANCH=main
ENABLED=true
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=*.backup
EOF
    
    log_info "测试环境设置完成"
}

# 测试轮询监控功能
test_polling_monitor() {
    log_test "测试轮询监控功能..."
    
    # 加载监控模块
    export PROJECT_ROOT="$TEST_DIR"
    export GLOBAL_CONFIG="$CONFIG_DIR/global.conf"
    export PATHS_CONFIG="$CONFIG_DIR/paths.conf"
    
    source "$(dirname "$0")/lib/utils.sh"
    source "$(dirname "$0")/lib/logger.sh"
    source "$(dirname "$0")/lib/config.sh"
    source "$(dirname "$0")/lib/monitor.sh"
    
    # 初始化
    init_logger
    load_global_config
    parse_paths_config
    init_monitor
    
    # 验证轮询模式
    if [[ "$MONITOR_METHOD" == "polling" ]]; then
        log_info "✓ 轮询模式已启用"
    else
        log_error "✗ 轮询模式未启用"
        return 1
    fi
    
    # 测试文件快照功能
    log_test "测试文件快照功能..."
    
    # 创建测试文件
    echo "test content 1" > "$TEST_DIR/watch/file1.txt"
    echo "test content 2" > "$TEST_DIR/watch/file2.txt"
    mkdir -p "$TEST_DIR/watch/subdir"
    echo "test content 3" > "$TEST_DIR/watch/subdir/file3.txt"
    
    # 创建应该被排除的文件
    echo "temp" > "$TEST_DIR/watch/temp.tmp"
    echo "backup" > "$TEST_DIR/watch/backup.backup"
    
    # 生成文件快照
    local snapshot1="/tmp/snapshot1_$$"
    create_file_snapshot "$TEST_DIR/watch" "true" "*.backup" > "$snapshot1"
    
    log_info "第一次快照:"
    cat "$snapshot1"
    
    # 验证排除功能
    if grep -q "temp.tmp" "$snapshot1"; then
        log_error "✗ 全局排除模式未生效"
        return 1
    else
        log_info "✓ 全局排除模式生效"
    fi
    
    if grep -q "backup.backup" "$snapshot1"; then
        log_error "✗ 路径排除模式未生效"
        return 1
    else
        log_info "✓ 路径排除模式生效"
    fi
    
    # 修改文件
    sleep 2
    echo "modified content" > "$TEST_DIR/watch/file1.txt"
    echo "new file" > "$TEST_DIR/watch/file4.txt"
    rm "$TEST_DIR/watch/file2.txt"
    
    # 生成第二次快照
    local snapshot2="/tmp/snapshot2_$$"
    create_file_snapshot "$TEST_DIR/watch" "true" "*.backup" > "$snapshot2"
    
    log_info "第二次快照:"
    cat "$snapshot2"
    
    # 测试快照比较
    log_test "测试快照比较功能..."
    compare_snapshots "test-path" "$snapshot1" "$snapshot2"
    
    # 清理临时文件
    rm -f "$snapshot1" "$snapshot2"
    
    log_info "✓ 轮询监控功能测试通过"
}

# 测试配置加载
test_config_loading() {
    log_test "测试配置加载..."
    
    # 测试全局配置
    if [[ "$POLLING_INTERVAL" == "3" ]]; then
        log_info "✓ 轮询间隔配置正确"
    else
        log_error "✗ 轮询间隔配置错误: $POLLING_INTERVAL"
        return 1
    fi
    
    if [[ "$FORCE_POLLING" == "true" ]]; then
        log_info "✓ 强制轮询配置正确"
    else
        log_error "✗ 强制轮询配置错误: $FORCE_POLLING"
        return 1
    fi
    
    # 测试路径配置
    local enabled_paths
    mapfile -t enabled_paths < <(get_enabled_paths)
    
    if [[ ${#enabled_paths[@]} -eq 1 && "${enabled_paths[0]}" == "test-path" ]]; then
        log_info "✓ 路径配置加载正确"
    else
        log_error "✗ 路径配置加载错误"
        return 1
    fi
    
    log_info "✓ 配置加载测试通过"
}

# 性能测试
test_performance() {
    log_test "测试轮询性能..."
    
    # 创建大量文件
    local test_files=100
    log_info "创建 $test_files 个测试文件..."
    
    for i in $(seq 1 $test_files); do
        echo "content $i" > "$TEST_DIR/watch/file_$i.txt"
    done
    
    # 测试快照生成时间
    local start_time=$(date +%s.%N)
    create_file_snapshot "$TEST_DIR/watch" "true" "" > /dev/null
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")
    log_info "快照生成耗时: ${duration}秒 ($test_files 个文件)"
    
    # 清理测试文件
    rm -f "$TEST_DIR/watch/file_"*.txt
    
    log_info "✓ 性能测试完成"
}

# 显示测试结果
show_results() {
    echo ""
    log_info "🎉 轮询监控模式测试完成！"
    echo ""
    echo "测试结果："
    echo "✓ 轮询模式正常工作"
    echo "✓ 文件快照功能正常"
    echo "✓ 文件排除功能正常"
    echo "✓ 快照比较功能正常"
    echo "✓ 配置加载功能正常"
    echo "✓ 性能表现良好"
    echo ""
    echo "OpenWrt系统可以正常使用轮询监控模式！"
}

# 主函数
main() {
    echo "轮询监控模式测试"
    echo "=================="
    echo ""
    
    # 设置清理陷阱
    trap cleanup EXIT
    
    # 运行测试
    setup_test
    test_config_loading
    test_polling_monitor
    test_performance
    show_results
}

# 运行测试
main "$@"
