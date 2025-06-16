#!/bin/bash

# 测试主程序的基本功能

echo "测试主程序基本功能"
echo "=================="
echo ""

# 下载主程序
echo "下载主程序..."
if command -v curl >/dev/null 2>&1; then
    curl -L "https://raw.githubusercontent.com/rdone4425/github11/main/bin/file-sync.sh" -o file-sync.sh
elif command -v wget >/dev/null 2>&1; then
    wget "https://raw.githubusercontent.com/rdone4425/github11/main/bin/file-sync.sh" -O file-sync.sh
else
    echo "错误: 需要curl或wget"
    exit 1
fi

chmod +x file-sync.sh

echo "主程序下载完成"
echo ""

# 测试帮助信息
echo "测试帮助信息..."
./file-sync.sh --help

echo ""
echo "测试完成！"
echo ""
echo "现在可以运行主程序："
echo "sudo ./file-sync.sh"
