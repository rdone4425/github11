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

    # 检查下载的文件
    if [ ! -f "github-sync.sh" ]; then
        echo "错误: 主程序文件下载失败"
        exit 1
    fi

    # 检查文件大小
    file_size=$(wc -c < github-sync.sh 2>/dev/null || echo 0)
    if [ "$file_size" -lt 1000 ]; then
        echo "错误: 下载的文件太小，可能下载不完整"
        echo "文件大小: $file_size bytes"
        exit 1
    fi

    # 检查文件是否是shell脚本
    if ! head -1 github-sync.sh | grep -q "#!/"; then
        echo "错误: 下载的文件不是有效的shell脚本"
        exit 1
    fi

    echo "3. 设置权限..."
    chmod +x github-sync.sh

    # 验证权限设置
    if [ ! -x "github-sync.sh" ]; then
        echo "错误: 无法设置执行权限"
        exit 1
    fi

    echo "4. 下载配置示例..."
    curl -fsSL "$BASE_URL/github-sync.conf.example" -o github-sync.conf.example 2>/dev/null || echo "配置示例下载失败，跳过"

    echo ""
    echo "[成功] 安装完成！"
    echo ""
    echo "安装目录: $INSTALL_DIR"
    echo "文件大小: $file_size bytes"
    echo ""
    echo "正在启动程序..."
    sleep 2

    # 启动主程序
    echo "执行: ./github-sync.sh"
    if ! ./github-sync.sh; then
        echo ""
        echo "程序启动失败，请手动检查："
        echo "  cd $INSTALL_DIR"
        echo "  ls -la github-sync.sh"
        echo "  head -5 github-sync.sh"
        echo "  ./github-sync.sh"
    fi
}

# 执行安装
install_tool
