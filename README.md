# GitHub文件同步工具

专为OpenWrt/Kwrt系统设计的GitHub文件同步工具，支持自动监控本地文件变化并同步到GitHub仓库。

## ✨ 功能特性

- 🔄 **自动同步**: 实时监控文件变化，自动同步到GitHub
- 📁 **多路径支持**: 支持同时监控多个文件或目录
- 🏠 **多实例支持**: 支持为不同项目创建独立实例
- 🎛️ **交互式配置**: 友好的配置向导和菜单界面
- 📊 **智能日志**: 自动日志轮转和清理
- 🛡️ **后台运行**: 守护进程模式，稳定可靠

## 🚀 快速开始

### 一键安装（推荐）

```bash
# 一键安装（使用加速镜像，适合国内用户）
bash <(curl -Ls https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/install.sh)
```

**安装过程**：
1. 下载文件到 `/root/github-sync`
2. 设置执行权限
3. **自动启动交互式主程序**

### 手动安装

```bash
# 下载文件
mkdir -p /root/github-sync && cd /root/github-sync
curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.sh -o github-sync.sh
curl -fsSL https://git.910626.xyz/https://raw.githubusercontent.com/rdone4425/github11/main/github-sync.conf.example -o github-sync.conf.example

# 设置权限并启动
chmod +x github-sync.sh
./github-sync.sh
```

### 配置工具
```bash
# 启动配置向导
./github-sync.sh config
```

配置项说明：
- **GitHub用户名**: 您的GitHub用户名
- **GitHub令牌**: 在GitHub Settings > Developer settings > Personal access tokens 创建
- **同步路径**: 要监控的本地文件或目录路径
- **目标仓库**: GitHub仓库名（格式：用户名/仓库名）

### 启动服务
```bash
# 测试配置
./github-sync.sh test

# 启动同步服务
./github-sync.sh start

# 查看状态
./github-sync.sh status
```

## 📋 命令说明

```bash
./github-sync.sh [命令] [选项]
```

### 基本命令
- `start` - 启动同步服务
- `stop` - 停止同步服务
- `restart` - 重启同步服务
- `status` - 显示服务状态
- `config` - 编辑配置文件
- `test` - 测试配置和GitHub连接
- `logs` - 显示日志
- `cleanup` - 清理日志文件

### 多实例支持
```bash
# 为不同项目创建独立实例
./github-sync.sh -i project1 config
./github-sync.sh -i project1 start

./github-sync.sh -i project2 config
./github-sync.sh -i project2 start

# 查看所有实例
./github-sync.sh list
```

## ⚙️ 配置示例

### 单文件同步
```bash
# 同步单个配置文件
本地路径: /etc/config/network
GitHub仓库: username/openwrt-config
分支: main
目标路径: config/network
```

### 目录同步
```bash
# 同步整个脚本目录
本地路径: /root/scripts
GitHub仓库: username/my-scripts
分支: main
目标路径: scripts
```

### 多路径配置
可以在一个实例中配置多个同步路径，每个路径可以指向不同的GitHub仓库。

## 📊 日志管理

### 自动日志管理
- **自动轮转**: 文件大小超过1MB时自动轮转
- **自动清理**: 每天凌晨2-6点清理过期日志
- **保留策略**: 默认保留7天，最多10个文件

### 手动日志管理
```bash
# 查看日志
./github-sync.sh logs

# 清理日志
./github-sync.sh cleanup
```

## 🔧 高级配置

### 配置文件位置
- 默认实例: `github-sync.conf`
- 命名实例: `github-sync-<实例名>.conf`

### 主要配置项
```bash
# GitHub配置
GITHUB_USERNAME="your-username"
GITHUB_TOKEN="ghp_your-token"

# 监控配置
POLL_INTERVAL=30          # 轮询间隔（秒）
LOG_LEVEL="INFO"          # 日志级别

# 同步路径（格式：本地路径|仓库|分支|目标路径）
SYNC_PATHS="/path/to/file|username/repo|main|target/path"

# 日志管理
LOG_MAX_SIZE=1048576      # 日志文件最大大小
LOG_KEEP_DAYS=7           # 保留日志天数
LOG_MAX_FILES=10          # 最多保留日志文件数
```

## 🛠️ 故障排除

### 常见问题

1. **路径不存在错误**
   ```bash
   # 检查文件是否存在
   ls -la /path/to/your/file

   # 重新配置路径
   ./github-sync.sh config
   ```

2. **GitHub连接失败**
   ```bash
   # 测试连接
   ./github-sync.sh test

   # 检查令牌权限（需要repo权限）
   ```

3. **服务无法启动**
   ```bash
   # 查看详细日志
   ./github-sync.sh logs

   # 检查配置
   ./github-sync.sh config
   ```

### 日志位置
- 默认实例: `github-sync.log`
- 命名实例: `github-sync-<实例名>.log`

## 📝 注意事项

1. **GitHub令牌权限**: 确保令牌有repo权限
2. **文件大小限制**: 默认限制1MB，可在配置中调整
3. **网络连接**: 需要稳定的网络连接到GitHub
4. **文件权限**: 确保有读取监控文件的权限

## 🔗 GitHub令牌创建

1. 登录GitHub，进入 Settings > Developer settings > Personal access tokens
2. 点击 "Generate new token"
3. 选择权限：至少需要 `repo` 权限
4. 复制生成的令牌（只显示一次）

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交Issue和Pull Request！

---

**提示**: 首次使用建议先用测试仓库进行配置和测试，确认工作正常后再用于重要文件的同步。

## 🚀 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/system-check.sh)
```

> 🎯 **零配置安装**: 自动检测系统、安装依赖、配置服务，一条命令完成所有设置！

## 特性

- 🚀 **单脚本设计**: 所有功能集成在一个Shell脚本中，易于部署和维护
- 🔄 **自动同步**: 监控本地文件变化，自动同步到GitHub仓库
- 🎯 **多路径支持**: 支持同时监控多个目录，同步到不同的GitHub仓库
- 🛡️ **OpenWrt优化**: 专为OpenWrt/Kwrt系统优化，支持procd服务管理
- 📊 **轮询监控**: 使用轮询方式监控文件变化，无需inotify-tools
- 🔧 **灵活配置**: 支持文件过滤、自定义提交消息等高级配置
- 📝 **完善日志**: 详细的日志记录和错误处理机制
- 🔒 **安全可靠**: 支持GitHub API认证，安全传输文件

## 系统要求

- OpenWrt/Kwrt系统（推荐）或其他Linux系统
- curl工具（用于GitHub API调用）
- base64工具（用于文件编码）
- 稳定的网络连接

> 💡 **提示**: 一键安装脚本会自动检测系统并安装所需依赖，无需手动准备。

## 🚀 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/system-check.sh)
```

就这么简单！脚本会自动：
- 检测系统类型（OpenWrt/Debian/Ubuntu等）
- 安装必要依赖（curl、base64等）
- 下载并配置同步工具
- 设置系统服务（OpenWrt使用procd）
- 启动交互式配置向导

安装完成后，运行 `github-sync` 进入交互式菜单，或者：

```bash
github-sync config   # 编辑配置文件
github-sync test     # 测试配置
github-sync start    # 启动服务
github-sync status   # 查看状态
```

## 详细配置

### GitHub令牌设置

1. 访问 [GitHub Settings > Personal Access Tokens](https://github.com/settings/tokens)
2. 点击 "Generate new token (classic)"
3. 选择以下权限：
   - `repo`: 完整的仓库访问权限
4. 复制生成的令牌到配置文件

### 同步路径配置

同步路径格式：`本地路径|GitHub仓库|分支|目标路径`

```bash
SYNC_PATHS="
/etc/config|username/openwrt-config|main|config
/root/scripts|username/scripts|main|
/etc/firewall.user|username/openwrt-config|main|firewall.user
"
```

### 文件过滤

```bash
# 排除不需要同步的文件
EXCLUDE_PATTERNS="*.tmp *.log *.pid *.lock .git *.swp"
```

## 命令参考

```bash
# 基本命令
./github-sync.sh start          # 启动服务
./github-sync.sh stop           # 停止服务
./github-sync.sh restart        # 重启服务
./github-sync.sh status         # 查看状态

# 配置和测试
./github-sync.sh config         # 编辑配置
./github-sync.sh test           # 测试配置
./github-sync.sh sync           # 执行一次性同步

# 维护命令
./github-sync.sh logs           # 查看日志
./github-sync.sh install        # 安装工具
./github-sync.sh help           # 显示帮助
```

## 服务管理

### OpenWrt系统

```bash
# 使用procd服务管理
/etc/init.d/github-sync start
/etc/init.d/github-sync stop
/etc/init.d/github-sync restart
/etc/init.d/github-sync enable   # 开机自启
```

### 手动管理

```bash
# 后台运行
nohup ./github-sync.sh daemon > /dev/null 2>&1 &

# 查看进程
ps | grep github-sync
```

## 故障排除

### 常见问题

1. **GitHub连接失败**
   ```bash
   # 检查网络连接
   curl -I https://api.github.com

   # 验证令牌
   curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
   ```

2. **文件同步失败**
   ```bash
   # 查看详细日志
   ./github-sync.sh logs

   # 检查文件权限
   ls -la /path/to/file
   ```

3. **服务启动失败**
   ```bash
   # 检查配置
   ./github-sync.sh test

   # 手动运行测试
   ./github-sync.sh sync
   ```

### 日志分析

日志文件位置：`./github-sync.log`

```bash
# 实时查看日志
tail -f github-sync.log

# 查看错误日志
grep ERROR github-sync.log
```

## 高级配置

### 网络代理

```bash
# 在配置文件中设置代理
HTTP_PROXY="http://proxy.example.com:8080"
HTTPS_PROXY="http://proxy.example.com:8080"
```

### 自定义提交消息

```bash
# 自定义提交消息模板
COMMIT_MESSAGE_TEMPLATE="[OpenWrt] Update %s from $(hostname)"
```

### 性能优化

```bash
# 调整轮询间隔
POLL_INTERVAL=60  # 60秒检查一次

# 限制文件大小
MAX_FILE_SIZE=2097152  # 2MB
```

## 安全建议

1. **令牌安全**
   - 定期轮换GitHub令牌
   - 使用最小权限原则
   - 不要在公共场所暴露令牌

2. **文件安全**
   - 避免同步包含密码的文件
   - 使用私有仓库存储敏感配置
   - 定期检查同步的文件内容

3. **网络安全**
   - 确保HTTPS连接
   - 在不安全网络中使用VPN

## 贡献

欢迎提交Issue和Pull Request来改进这个工具。

## 许可证

MIT License

## 更新日志

### v1.0.0
- 初始版本发布
- 支持基本的文件同步功能
- 集成procd服务管理
- 完善的日志和错误处理
