#!/bin/bash

# GitHub文件同步系统 - 一键启动脚本
# 自动下载并运行主程序

set -euo pipefail

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}GitHub文件同步系统${NC}"
echo "===================="
echo ""

# 检查是否已安装
if [[ -f "/file-sync-system/bin/file-sync.sh" ]]; then
    echo -e "${GREEN}检测到已安装，启动主程序...${NC}"
    exec /file-sync-system/bin/file-sync.sh "$@"
else
    echo -e "${GREEN}首次运行，下载主程序...${NC}"
    
    # 创建临时目录
    temp_dir="/tmp/file-sync-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载主程序
    if command -v curl >/dev/null 2>&1; then
        curl -L "https://raw.githubusercontent.com/rdone4425/github11/main/bin/file-sync.sh" -o file-sync.sh
    elif command -v wget >/dev/null 2>&1; then
        wget "https://raw.githubusercontent.com/rdone4425/github11/main/bin/file-sync.sh" -O file-sync.sh
    else
        echo "错误: 需要curl或wget"
        exit 1
    fi
    
    # 运行主程序
    chmod +x file-sync.sh
    exec ./file-sync.sh "$@"
fi
