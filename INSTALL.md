# 安装指南

本文档详细介绍了GitHub文件同步工具的各种安装方法。

## 🚀 推荐安装方法

### 一键安装（最简单）

```bash
curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o /root/github-sync.sh && chmod +x /root/github-sync.sh && /root/github-sync.sh
```

这个命令会：
1. 下载主程序到 `/root/github-sync.sh`
2. 设置执行权限
3. 自动启动交互式配置向导

## 📦 手动安装

### 1. 下载文件

```bash
# 创建安装目录
mkdir -p /root/github-sync && cd /root/github-sync

# 下载主程序
curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh

# 下载配置示例（可选）
curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.conf.example -o github-sync.conf.example
```

### 2. 设置权限

```bash
chmod +x github-sync.sh
```

### 3. 启动程序

```bash
./github-sync.sh
```

## 🌐 网络加速

### 国内用户（推荐）

使用GitHub加速镜像：

```bash
curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh
```

### 国外用户

直接使用GitHub原始链接：

```bash
curl -fsSL https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh
```

## 🔧 系统特定安装

### OpenWrt/Kwrt 系统

```bash
# 更新软件包列表
opkg update

# 安装必要依赖（通常已预装）
opkg install curl ca-certificates

# 下载并安装
curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o /root/github-sync.sh
chmod +x /root/github-sync.sh
/root/github-sync.sh
```

### Ubuntu/Debian 系统

```bash
# 更新软件包列表
sudo apt update

# 安装必要依赖
sudo apt install curl ca-certificates

# 下载并安装
curl -fsSL https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh
chmod +x github-sync.sh
./github-sync.sh
```

### CentOS/RHEL 系统

```bash
# 安装必要依赖
sudo yum install curl ca-certificates

# 或者在较新版本中使用 dnf
sudo dnf install curl ca-certificates

# 下载并安装
curl -fsSL https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh
chmod +x github-sync.sh
./github-sync.sh
```

## 📁 安装位置选择

### 推荐位置

1. **系统级安装**（推荐）
   ```bash
   # 安装到 /usr/local/bin（需要root权限）
   sudo curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o /usr/local/bin/github-sync
   sudo chmod +x /usr/local/bin/github-sync
   
   # 现在可以在任何地方运行
   github-sync
   ```

2. **用户级安装**
   ```bash
   # 安装到用户主目录
   curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o ~/github-sync.sh
   chmod +x ~/github-sync.sh
   ~/github-sync.sh
   ```

3. **项目级安装**
   ```bash
   # 安装到特定项目目录
   mkdir -p /opt/github-sync && cd /opt/github-sync
   curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh
   chmod +x github-sync.sh
   ./github-sync.sh
   ```

## 🔍 安装验证

### 检查安装

```bash
# 检查文件是否存在
ls -la github-sync.sh

# 检查权限
ls -la github-sync.sh | grep -E '^-rwx'

# 测试运行
./github-sync.sh --help
```

### 检查依赖

```bash
# 检查curl
curl --version

# 检查base64
echo "test" | base64

# 检查网络连接
curl -I https://api.github.com
```

## 🛠️ 故障排除

### 下载失败

1. **网络连接问题**
   ```bash
   # 测试网络连接
   ping github.com
   curl -I https://github.com
   ```

2. **DNS解析问题**
   ```bash
   # 使用备用DNS
   echo "nameserver 8.8.8.8" >> /etc/resolv.conf
   ```

3. **证书问题**
   ```bash
   # 跳过SSL验证（不推荐，仅用于测试）
   curl -k -fsSL https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh
   ```

### 权限问题

```bash
# 检查当前用户权限
whoami
id

# 如果需要root权限
sudo chmod +x github-sync.sh
sudo ./github-sync.sh
```

### 依赖缺失

```bash
# OpenWrt系统
opkg update
opkg install curl ca-certificates

# Ubuntu/Debian系统
sudo apt update
sudo apt install curl ca-certificates

# CentOS/RHEL系统
sudo yum install curl ca-certificates
```

## 🔄 更新安装

### 更新到最新版本

```bash
# 备份当前配置
cp github-sync.conf github-sync.conf.backup

# 下载最新版本
curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh.new

# 替换旧版本
mv github-sync.sh.new github-sync.sh
chmod +x github-sync.sh

# 恢复配置
cp github-sync.conf.backup github-sync.conf
```

### 检查版本

```bash
./github-sync.sh --version
```

## 🗑️ 卸载

### 完全卸载

```bash
# 停止服务
./github-sync.sh stop

# 删除文件
rm -f github-sync.sh
rm -f github-sync.conf
rm -f github-sync.log*
rm -f github-sync.pid

# 删除系统服务（如果安装了）
sudo rm -f /etc/init.d/github-sync
sudo rm -f /usr/local/bin/github-sync
```

## 📝 安装后配置

安装完成后，请参考以下文档进行配置：

- [配置指南](CONFIG.md) - 详细的配置说明
- [使用说明](README.md#使用说明) - 基本使用方法
- [故障排除](TROUBLESHOOTING.md) - 常见问题解决

## 💡 安装建议

1. **首次安装**：建议使用一键安装方法
2. **生产环境**：建议安装到 `/usr/local/bin` 目录
3. **测试环境**：可以安装到用户目录进行测试
4. **多实例**：为不同项目创建独立的安装目录

---

如果在安装过程中遇到问题，请查看 [故障排除文档](TROUBLESHOOTING.md) 或提交 [Issue](https://github.com/rdone4425/github11/issues)。
