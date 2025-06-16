# 安装指南

本文档将指导您完成GitHub文件同步系统的安装和初始配置。

## 系统要求

### 操作系统
- Linux发行版（支持systemd）
- Ubuntu 18.04+ / Debian 9+ / CentOS 7+ / RHEL 7+

### 硬件要求
- CPU: 1核心以上
- 内存: 512MB以上
- 磁盘空间: 100MB以上可用空间
- 网络: 稳定的互联网连接

### 软件依赖
系统会自动安装以下依赖：
- bash 4.0+
- curl
- jq
- git
- inotify-tools

## 快速安装

### 1. 下载源码

```bash
# 克隆仓库
git clone https://github.com/your-repo/file-sync-system.git
cd file-sync-system

# 或者下载压缩包
wget https://github.com/your-repo/file-sync-system/archive/main.zip
unzip main.zip
cd file-sync-system-main
```

### 2. 运行安装脚本

```bash
# 使用root权限运行安装脚本
sudo ./install.sh
```

安装脚本将自动完成以下操作：
- 检查系统兼容性
- 安装必需的依赖包
- 创建系统用户和组
- 复制程序文件到 `/opt/file-sync-system`
- 设置正确的文件权限
- 安装systemd服务
- 创建命令行工具链接
- 初始化配置文件

### 3. 验证安装

```bash
# 检查命令是否可用
file-sync --version

# 检查服务状态
sudo systemctl status file-sync
```

## 手动安装

如果您不想使用自动安装脚本，可以按照以下步骤手动安装：

### 1. 安装依赖

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y curl jq git inotify-tools bash
```

#### CentOS/RHEL
```bash
sudo yum install -y curl jq git inotify-tools bash
```

#### Fedora
```bash
sudo dnf install -y curl jq git inotify-tools bash
```

### 2. 创建系统用户

```bash
sudo useradd -r -s /bin/false -d /opt/file-sync-system -c "File Sync Service" file-sync
```

### 3. 创建目录结构

```bash
sudo mkdir -p /opt/file-sync-system/{bin,lib,config,logs,docs}
```

### 4. 复制文件

```bash
# 复制程序文件
sudo cp -r bin/* /opt/file-sync-system/bin/
sudo cp -r lib/* /opt/file-sync-system/lib/
sudo cp -r config/* /opt/file-sync-system/config/
sudo cp README.md /opt/file-sync-system/

# 设置执行权限
sudo chmod +x /opt/file-sync-system/bin/*
```

### 5. 设置权限

```bash
sudo chown -R file-sync:file-sync /opt/file-sync-system
sudo chmod 755 /opt/file-sync-system/logs
```

### 6. 安装systemd服务

```bash
sudo cp systemd/file-sync.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable file-sync.service
```

### 7. 创建命令链接

```bash
sudo ln -sf /opt/file-sync-system/bin/file-sync /usr/local/bin/file-sync
```

## 配置GitHub凭据

安装完成后，您需要配置GitHub访问凭据：

### 1. 获取GitHub Personal Access Token

1. 登录GitHub
2. 进入 Settings → Developer settings → Personal access tokens
3. 点击 "Generate new token"
4. 选择以下权限：
   - `repo` (完整仓库访问权限)
   - `workflow` (如果需要访问GitHub Actions)
5. 复制生成的token

### 2. 编辑全局配置

```bash
sudo nano /opt/file-sync-system/config/global.conf
```

填入您的GitHub信息：
```bash
GITHUB_USERNAME="your-username"
GITHUB_TOKEN="your-personal-access-token"
```

### 3. 配置监控路径

```bash
sudo nano /opt/file-sync-system/config/paths.conf
```

根据需要修改监控路径配置。

## 验证配置

```bash
# 验证配置文件
file-sync validate

# 如果验证通过，启动服务
sudo systemctl start file-sync

# 检查服务状态
sudo systemctl status file-sync
file-sync status
```

## 开机自启

```bash
# 启用开机自启
sudo systemctl enable file-sync

# 禁用开机自启
sudo systemctl disable file-sync
```

## 卸载

如果需要卸载系统：

```bash
# 使用安装脚本卸载
sudo ./install.sh uninstall

# 或者手动卸载
sudo systemctl stop file-sync
sudo systemctl disable file-sync
sudo rm /etc/systemd/system/file-sync.service
sudo rm /usr/local/bin/file-sync
sudo rm -rf /opt/file-sync-system
sudo userdel file-sync
```

## 故障排除

### 常见问题

1. **权限错误**
   ```bash
   # 重新设置权限
   sudo chown -R file-sync:file-sync /opt/file-sync-system
   ```

2. **依赖缺失**
   ```bash
   # 检查依赖
   file-sync validate
   ```

3. **网络连接问题**
   ```bash
   # 测试GitHub连接
   curl -I https://api.github.com
   ```

4. **服务启动失败**
   ```bash
   # 查看详细日志
   sudo journalctl -u file-sync -f
   file-sync logs follow
   ```

### 日志位置

- 系统日志: `/opt/file-sync-system/logs/file-sync.log`
- 错误日志: `/opt/file-sync-system/logs/error.log`
- 守护进程日志: `/opt/file-sync-system/logs/daemon.log`
- systemd日志: `journalctl -u file-sync`

## 下一步

安装完成后，请参考以下文档：
- [配置说明](configuration.md) - 详细的配置选项说明
- [使用说明](usage.md) - 日常使用和管理指南
