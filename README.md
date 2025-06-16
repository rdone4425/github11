# GitHub File Sync Tool for OpenWrt/Kwrt

专为OpenWrt/Kwrt系统设计的GitHub文件同步工具，使用单个Shell脚本实现本地文件到GitHub仓库的自动同步功能。

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
