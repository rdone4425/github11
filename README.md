# Linux文件监控和GitHub同步系统

一个基于Shell脚本的Linux文件监控和GitHub同步系统，支持实时监控本地文件变化并自动同步到GitHub仓库。

## 功能特性

- 🔍 **实时文件监控**: 使用inotify监控指定目录的文件变化
- 🚀 **自动GitHub同步**: 检测到文件变化时自动上传到GitHub仓库
- 📁 **多路径支持**: 支持监控多个目录，每个目录可配置不同的GitHub仓库
- ⚙️ **灵活配置**: 全局配置GitHub凭据，独立配置每个监控路径
- 🔧 **后台运行**: 支持作为系统服务在后台运行
- 📝 **完整日志**: 详细的操作日志和错误处理

## 项目结构

```
file-sync-system/
├── bin/                    # 主要可执行脚本
│   ├── file-sync          # 主程序入口
│   └── file-sync-daemon   # 守护进程脚本
├── lib/                   # 核心功能模块
│   ├── config.sh         # 配置管理模块
│   ├── monitor.sh        # 文件监控模块
│   ├── github.sh         # GitHub同步模块
│   ├── logger.sh         # 日志记录模块
│   └── utils.sh          # 工具函数
├── config/               # 配置文件目录
│   ├── global.conf       # 全局配置文件
│   └── paths.conf        # 监控路径配置
├── systemd/              # 系统服务配置
│   └── file-sync.service # systemd服务文件
├── logs/                 # 日志文件目录
└── docs/                 # 文档目录
    ├── installation.md   # 安装指南
    ├── configuration.md  # 配置说明
    └── usage.md          # 使用说明
```

## 快速开始

### 🔍 系统兼容性检查

```bash
# 检查系统是否支持安装
bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/system-check.sh)
```

### 🚀 一键安装

```bash
# 智能安装（推荐）- 自动检查包列表是否需要更新
bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/install.sh)

# 强制更新包列表后安装（网络较好时使用）
FORCE_UPDATE=1 bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/install.sh)

# 如果curl不可用（如某些OpenWrt系统）
wget -O- https://raw.githubusercontent.com/rdone4425/github11/main/install.sh | bash
```

**智能包管理特性：**
- 🧠 自动检测包列表是否过期（超过24小时）
- ⚡ 跳过不必要的包列表更新，节省时间
- 🔄 支持强制更新选项

**安装完成后会自动进入交互式主程序界面，您可以：**
- 🔧 初始化配置
- ⚙️ 配置GitHub凭据和监控路径
- 🚀 启动文件监控
- 📊 查看系统状态

### 📦 手动安装

```bash
# 下载项目
wget https://github.com/rdone4425/github11/archive/main.tar.gz -O github11.tar.gz
tar -xzf github11.tar.gz
cd github11-main

# 运行安装脚本
sudo ./install.sh

# 配置GitHub凭据
nano /file-sync-system/config/global.conf

# 配置监控路径
nano /file-sync-system/config/paths.conf

# 验证配置
file-sync validate

# 启动服务（根据系统自动选择）
systemctl start file-sync          # systemd系统
/etc/init.d/file-sync start        # OpenWrt系统
```

### 演示模式

运行演示脚本了解系统功能：

```bash
./demo.sh
```

详细说明请参考 [安装指南](docs/installation.md)。

## 主要特性

### 🔍 实时文件监控
- 基于Linux inotify机制（优先）
- 轮询监控模式（inotify不可用时）
- 支持递归目录监控
- 智能文件过滤和排除
- 自动适配OpenWrt等嵌入式系统

### 🚀 自动GitHub同步
- 实时检测文件变化
- 自动上传到指定GitHub仓库
- 支持多分支和子目录映射

### 📁 多路径支持
- 同时监控多个目录
- 每个路径独立配置
- 灵活的启用/禁用控制

### ⚙️ 灵活配置
- 全局配置和路径配置分离
- 支持环境变量覆盖
- 配置验证和错误检查

### 🔧 后台运行
- systemd服务集成
- 守护进程模式
- 自动重启和错误恢复

### 📝 完整日志
- 多级别日志记录
- 日志轮转和清理
- 详细的操作审计

### 🛡️ 安全可靠
- 错误处理和重试机制
- 网络连接检查
- 文件权限验证

## 依赖要求

### 系统要求
- Linux系统（支持inotify）
- Ubuntu 18.04+ / Debian 9+ / CentOS 7+ / RHEL 7+ / Fedora
- OpenWrt / LEDE / Kwrt（路由器系统）
- 支持systemd、SysV init、procd或service命令

### 软件依赖
- bash 4.0+
- curl
- tar
- jq（用于JSON处理）
- inotify-tools

## 文档

- [安装指南](docs/installation.md) - 详细的安装步骤
- [配置说明](docs/configuration.md) - 配置选项和示例
- [使用说明](docs/usage.md) - 日常使用和管理

## 贡献

欢迎提交Issue和Pull Request！

## 许可证

MIT License
