#!/bin/bash

# GitHub文件同步工具一键安装脚本

# 基本配置
INSTALL_DIR="/root/github-sync"
BASE_URL="https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main"

echo "=================================="
echo "GitHub文件同步工具 - 一键安装"
echo "=================================="
echo ""

# 检测最佳下载源
detect_best_source() {
    log_info "检测最佳下载源..."

    # 测试GitHub原站连接速度
    local github_speed=999
    if curl -s --connect-timeout 3 --max-time 5 "https://raw.githubusercontent.com" >/dev/null 2>&1; then
        local start_time=$(date +%s%N)
        if curl -s --connect-timeout 5 --max-time 10 "https://raw.githubusercontent.com/rdone4425/github11/main/README.md" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            github_speed=$(( (end_time - start_time) / 1000000 ))
        fi
    fi

    # 测试加速镜像连接速度
    local mirror_speed=999
    if curl -s --connect-timeout 3 --max-time 5 "https://git.910626.xyz" >/dev/null 2>&1; then
        local start_time=$(date +%s%N)
        if curl -s --connect-timeout 5 --max-time 10 "https://git.910626.xyz/rdone4425/github11/raw/branch/main/README.md" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            mirror_speed=$(( (end_time - start_time) / 1000000 ))
        fi
    fi

    # 选择最快的源
    if [ "$mirror_speed" -lt "$github_speed" ]; then
        log_info "使用加速镜像源 (响应时间: ${mirror_speed}ms)"
        echo "$MIRROR_URL"
    else
        log_info "使用GitHub原站 (响应时间: ${github_speed}ms)"
        echo "$RAW_URL"
    fi
}

# 简单安装函数
install_tool() {
    echo "1. 创建安装目录..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    echo "2. 下载主程序..."
    if ! curl -fsSL "$BASE_URL/github-sync.sh" -o github-sync.sh; then
        echo "下载失败，请检查网络连接"
        exit 1
    fi

    echo "3. 设置权限..."
    chmod +x github-sync.sh

    echo "4. 下载配置示例..."
    curl -fsSL "$BASE_URL/github-sync.conf.example" -o github-sync.conf.example 2>/dev/null || echo "配置示例下载失败，跳过"

    echo ""
    echo "✅ 安装完成！"
    echo ""
    echo "安装目录: $INSTALL_DIR"
    echo ""
    echo "正在启动程序..."
    sleep 2

    # 启动主程序
    ./github-sync.sh
}

# 主安装函数
main_install() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                GitHub文件同步工具 - 一键安装                ║"
    echo "║              专为OpenWrt/Kwrt系统设计                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 检查是否为root用户
    if [ "$(id -u)" != "0" ]; then
        log_error "请使用root用户运行此脚本"
        exit 1
    fi
    
    # 安装依赖
    log_info "步骤 1/4: 安装系统依赖..."
    install_dependencies
    
    # 创建安装目录
    log_info "步骤 2/4: 创建安装目录..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 检测最佳下载源
    log_info "步骤 3/5: 检测最佳下载源..."
    local best_source=$(detect_best_source)

    # 下载主程序
    log_info "步骤 4/5: 下载GitHub同步工具..."

    # 下载主程序（必须成功）
    if ! download_file "$SCRIPT_NAME" "$SCRIPT_NAME" "$best_source"; then
        log_warn "使用首选源下载失败，尝试备用源..."

        # 尝试备用源
        local backup_source
        if echo "$best_source" | grep -q "git.910626.xyz"; then
            backup_source="$RAW_URL"
            log_info "尝试GitHub原站..."
        else
            backup_source="${MIRROR_PREFIX}${RAW_URL}"
            log_info "尝试加速镜像..."
        fi

        if ! download_file "$SCRIPT_NAME" "$SCRIPT_NAME" "$backup_source"; then
            log_error "所有下载源都失败，无法继续安装"
            log_error "请检查网络连接或稍后重试"
            exit 1
        fi
    fi

    # 下载其他文件（可选）
    if ! download_file "README.md" "README.md" "$best_source"; then
        log_warn "下载README.md失败，跳过"
    fi

    if ! download_file "github-sync.conf.example" "github-sync.conf.example" "$best_source"; then
        log_warn "下载配置示例失败，跳过"
    fi
    
    # 设置权限
    chmod +x "$SCRIPT_NAME"

    # 创建符号链接（可选）
    log_info "步骤 5/5: 配置系统..."
    if [ ! -f "/usr/local/bin/github-sync" ]; then
        ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "/usr/local/bin/github-sync" 2>/dev/null || true
    fi
    
    echo ""
    log_info "✅ 安装完成！"
    echo ""
    echo "📁 安装目录: $INSTALL_DIR"
    echo "🔧 主程序: $INSTALL_DIR/$SCRIPT_NAME"
    echo ""
    echo "🌐 项目地址: $REPO_URL"
    echo ""

    # 等待2秒后自动进入主程序
    log_info "正在启动GitHub同步工具主程序..."
    echo ""
    echo "💡 提示："
    echo "   • 首次运行将显示配置向导"
    echo "   • 可以选择快速配置或详细配置"
    echo "   • 配置完成后即可开始使用"
    echo ""
    sleep 3

    # 自动进入主程序的交互界面
    ./"$SCRIPT_NAME"
}

# 错误处理
trap 'log_error "安装过程中发生错误，请检查网络连接和权限"; exit 1' ERR

# 执行安装
main_install
