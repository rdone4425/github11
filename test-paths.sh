#!/bin/bash

# 路径兼容性测试脚本
# 测试不同系统的目录结构兼容性

set -euo pipefail

echo "测试系统路径兼容性"
echo "==================="
echo ""

# 检查系统信息
echo "系统信息:"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  操作系统: $PRETTY_NAME"
else
    echo "  操作系统: 未知"
fi
echo "  架构: $(uname -m)"
echo ""

# 检查目录结构
echo "目录结构检查:"

# 检查/usr/local/bin
if [[ -d "/usr/local/bin" ]]; then
    echo "  ✓ /usr/local/bin 存在"
    echo "    权限: $(ls -ld /usr/local/bin | awk '{print $1}')"
    echo "    所有者: $(ls -ld /usr/local/bin | awk '{print $3":"$4}')"
else
    echo "  ✗ /usr/local/bin 不存在"
    echo "    尝试创建..."
    if mkdir -p /usr/local/bin 2>/dev/null; then
        echo "    ✓ 创建成功"
    else
        echo "    ✗ 创建失败，权限不足"
    fi
fi

# 检查/usr/bin
if [[ -d "/usr/bin" ]]; then
    echo "  ✓ /usr/bin 存在"
    echo "    权限: $(ls -ld /usr/bin | awk '{print $1}')"
    echo "    所有者: $(ls -ld /usr/bin | awk '{print $3":"$4}')"
else
    echo "  ✗ /usr/bin 不存在（异常）"
fi

echo ""

# 测试路径选择逻辑
echo "路径选择测试:"

select_bin_dir() {
    if [[ -d "/usr/local/bin" ]]; then
        echo "/usr/local/bin"
    elif [[ -d "/usr/bin" ]]; then
        echo "/usr/bin"
    else
        echo "none"
    fi
}

selected_dir=$(select_bin_dir)
echo "  选择的目录: $selected_dir"

if [[ "$selected_dir" != "none" ]]; then
    # 测试写入权限
    test_file="$selected_dir/test-file-sync-$$"
    if touch "$test_file" 2>/dev/null; then
        echo "  ✓ 目录可写"
        rm -f "$test_file"
    else
        echo "  ✗ 目录不可写，需要sudo权限"
    fi
fi

echo ""

# 检查PATH环境变量
echo "PATH环境变量检查:"
echo "  PATH: $PATH"

if echo "$PATH" | grep -q "/usr/local/bin"; then
    echo "  ✓ /usr/local/bin 在PATH中"
else
    echo "  ✗ /usr/local/bin 不在PATH中"
fi

if echo "$PATH" | grep -q "/usr/bin"; then
    echo "  ✓ /usr/bin 在PATH中"
else
    echo "  ✗ /usr/bin 不在PATH中（异常）"
fi

echo ""

# 检查现有的file-sync安装
echo "现有安装检查:"

if command -v file-sync >/dev/null 2>&1; then
    file_sync_path=$(which file-sync)
    echo "  ✓ file-sync 命令可用: $file_sync_path"
    
    if [[ -L "$file_sync_path" ]]; then
        target=$(readlink "$file_sync_path")
        echo "    -> 链接目标: $target"
        
        if [[ -f "$target" ]]; then
            echo "    ✓ 目标文件存在"
        else
            echo "    ✗ 目标文件不存在（损坏的链接）"
        fi
    fi
else
    echo "  - file-sync 命令不可用"
fi

# 检查安装目录
if [[ -d "/file-sync-system" ]]; then
    echo "  ✓ 安装目录存在: /file-sync-system"
    echo "    大小: $(du -sh /file-sync-system 2>/dev/null | cut -f1)"
    
    if [[ -f "/file-sync-system/bin/file-sync" ]]; then
        echo "    ✓ 主程序存在"
    else
        echo "    ✗ 主程序不存在"
    fi
else
    echo "  - 安装目录不存在"
fi

echo ""

# 检查服务
echo "服务检查:"

if [[ -f "/etc/init.d/file-sync" ]]; then
    echo "  ✓ OpenWrt服务脚本存在"
elif [[ -f "/etc/systemd/system/file-sync.service" ]]; then
    echo "  ✓ systemd服务文件存在"
else
    echo "  - 未找到服务配置"
fi

echo ""
echo "测试完成！"

# 给出建议
echo ""
echo "建议:"
if [[ ! -d "/usr/local/bin" ]]; then
    echo "- 系统缺少 /usr/local/bin 目录，安装脚本会自动创建"
fi

if ! echo "$PATH" | grep -q "/usr/local/bin"; then
    echo "- /usr/local/bin 不在PATH中，可能需要重新登录或添加到PATH"
fi

if [[ "$selected_dir" == "none" ]]; then
    echo "- 系统目录结构异常，建议手动创建 /usr/local/bin"
fi
