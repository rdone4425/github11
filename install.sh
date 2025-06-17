#!/bin/bash

# GitHub文件同步工具一键安装脚本

# 基本配置
INSTALL_DIR="/root/github-sync"
BASE_URL="https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main"

echo "=================================="
echo "GitHub文件同步工具 - 一键安装"
echo "=================================="
echo ""

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

# 执行安装
install_tool
