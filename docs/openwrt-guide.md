# OpenWrt使用指南

本文档专门介绍在OpenWrt/LEDE/Kwrt系统上安装和使用GitHub文件同步系统。

## OpenWrt系统特点

OpenWrt是一个基于Linux的嵌入式操作系统，主要用于路由器等网络设备：

- **轻量级**: 系统资源有限，需要优化的软件
- **procd**: 使用procd作为init系统，而非systemd
- **opkg**: 使用opkg作为包管理器
- **存储限制**: 通常存储空间较小
- **内存限制**: RAM通常在64MB-512MB之间

## 系统要求

### 硬件要求
- **存储空间**: 至少10MB可用空间
- **内存**: 建议64MB以上RAM
- **网络**: 稳定的互联网连接

### 软件要求
- OpenWrt 19.07+ / LEDE / Kwrt
- curl（通常已预装）
- tar（通常已预装）
- **注意**: 不需要inotify-tools，系统会自动使用轮询模式

## 安装方法

### 🚀 一键安装

```bash
# 通用安装脚本（自动适配OpenWrt）
bash <(curl -Ls https://raw.githubusercontent.com/rdone4425/github11/main/install.sh)

# 如果curl不可用，使用wget
wget -O- https://raw.githubusercontent.com/rdone4425/github11/main/install.sh | bash
```

### 📦 手动安装

如果一键安装失败，可以手动安装：

```bash
# 1. 安装基础依赖
opkg update
opkg install wget tar

# 2. 下载源码
cd /tmp
wget https://github.com/rdone4425/github11/archive/main.tar.gz -O github11.tar.gz
tar -xzf github11.tar.gz
cd github11-main

# 3. 运行安装脚本
./openwrt-simple-install.sh
```

### 🔧 依赖问题解决

如果遇到包安装失败的问题：

```bash
# 1. 检查系统信息
cat /etc/os-release
uname -m

# 2. 更新包列表
opkg update

# 3. 尝试安装基础包
opkg install wget
opkg install tar
opkg install ca-certificates

# 4. 如果curl安装失败，可以只用wget
# 系统会自动创建curl兼容包装器

# 5. 运行依赖检查脚本
wget -O- https://raw.githubusercontent.com/rdone4425/github11/main/openwrt-deps.sh | bash
```

## 配置说明

### 1. GitHub凭据配置

```bash
# 编辑全局配置文件
vi /file-sync-system/config/global.conf
```

设置以下参数：
```bash
GITHUB_USERNAME="your-username"
GITHUB_TOKEN="your-personal-access-token"
```

### 2. 监控路径配置

```bash
# 编辑路径配置文件
vi /file-sync-system/config/paths.conf
```

OpenWrt常用路径示例：
```ini
[config-backup]
LOCAL_PATH=/etc/config
GITHUB_REPO=your-username/router-config
TARGET_BRANCH=main
ENABLED=true
EXCLUDE_PATTERNS=*.tmp

[scripts]
LOCAL_PATH=/root/scripts
GITHUB_REPO=your-username/router-scripts
TARGET_BRANCH=main
ENABLED=true
```

## 服务管理

### 启动和停止服务

```bash
# 启动服务
/etc/init.d/file-sync start

# 停止服务
/etc/init.d/file-sync stop

# 重启服务
/etc/init.d/file-sync restart

# 查看状态
/etc/init.d/file-sync status
```

### 开机自启

```bash
# 启用开机自启
/etc/init.d/file-sync enable

# 禁用开机自启
/etc/init.d/file-sync disable
```

### 查看服务状态

```bash
# 使用file-sync命令
file-sync status

# 查看procd状态
ps | grep file-sync

# 查看系统日志
logread | grep file-sync
```

## 日志管理

### 查看日志

```bash
# 查看应用日志
file-sync logs show

# 实时跟踪日志
file-sync logs follow

# 查看系统日志
logread -f | grep file-sync

# 查看最近的错误
logread | grep -i error | grep file-sync
```

### 日志位置

- 应用日志: `/file-sync-system/logs/file-sync.log`
- 错误日志: `/file-sync-system/logs/error.log`
- 系统日志: 通过`logread`命令查看

## OpenWrt特殊配置

### 监控模式说明

OpenWrt系统通常没有inotify-tools，系统会自动使用**轮询监控模式**：

- **轮询间隔**: 默认10秒检查一次文件变化
- **资源占用**: 比inotify模式稍高，但仍然很轻量
- **响应时间**: 最多延迟一个轮询间隔
- **可靠性**: 与inotify模式同样可靠

```bash
# 调整轮询间隔（秒）
vi /file-sync-system/config/global.conf

# 添加或修改以下配置
POLLING_INTERVAL=30    # 30秒检查一次（默认10秒）
```

### 存储优化

由于OpenWrt存储空间有限，建议：

```bash
# 设置较小的日志文件大小
echo "MAX_LOG_SIZE=1048576" >> /file-sync-system/config/global.conf

# 设置较短的日志保留时间
echo "LOG_RETENTION_DAYS=3" >> /file-sync-system/config/global.conf
```

### 内存优化

```bash
# 增加同步间隔以减少CPU使用
echo "SYNC_INTERVAL=30" >> /file-sync-system/config/global.conf

# 减少并发处理
echo "MAX_CONCURRENT_SYNCS=1" >> /file-sync-system/config/global.conf
```

### 网络优化

```bash
# 设置较长的网络超时
echo "NETWORK_TIMEOUT=30" >> /file-sync-system/config/global.conf

# 启用重试机制
echo "MAX_RETRIES=5" >> /file-sync-system/config/global.conf
```

## 常见使用场景

### 1. 路由器配置备份

```ini
[router-config]
LOCAL_PATH=/etc/config
GITHUB_REPO=username/router-backup
TARGET_BRANCH=main
ENABLED=true
EXCLUDE_PATTERNS=*.tmp *.lock
```

### 2. 自定义脚本同步

```ini
[custom-scripts]
LOCAL_PATH=/root/scripts
GITHUB_REPO=username/router-scripts
TARGET_BRANCH=main
ENABLED=true
```

### 3. 网络配置监控

```ini
[network-config]
LOCAL_PATH=/etc/config/network
GITHUB_REPO=username/network-config
TARGET_BRANCH=main
ENABLED=true
```

## 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查配置
   file-sync validate
   
   # 查看详细错误
   logread | grep file-sync
   ```

2. **网络连接问题**
   ```bash
   # 测试GitHub连接
   curl -I https://api.github.com
   
   # 检查DNS解析
   nslookup github.com
   ```

3. **存储空间不足**
   ```bash
   # 检查磁盘空间
   df -h
   
   # 清理日志
   file-sync logs clean
   ```

4. **内存不足**
   ```bash
   # 检查内存使用
   free -m
   
   # 重启服务
   /etc/init.d/file-sync restart
   ```

### 性能调优

```bash
# 编辑配置文件进行性能调优
vi /file-sync-system/config/global.conf

# 添加以下配置
SYNC_INTERVAL=60          # 增加同步间隔
MAX_FILE_SIZE=1048576     # 限制文件大小为1MB
LOG_LEVEL=WARN           # 减少日志输出
VERBOSE=false            # 禁用详细输出
```

## 卸载

如果需要卸载系统：

```bash
# 停止并禁用服务
/etc/init.d/file-sync stop
/etc/init.d/file-sync disable

# 删除服务文件
rm /etc/init.d/file-sync

# 删除程序文件
rm -rf /file-sync-system

# 删除命令链接
rm /usr/bin/file-sync
```

## 注意事项

1. **备份重要配置**: 安装前请备份重要的路由器配置
2. **网络稳定性**: 确保路由器有稳定的互联网连接
3. **存储监控**: 定期检查存储空间使用情况
4. **内存监控**: 监控内存使用，避免系统卡顿
5. **安全考虑**: 妥善保管GitHub Token，避免泄露

## 技术支持

如果遇到问题，请：

1. 查看日志文件获取详细错误信息
2. 检查网络连接和GitHub API访问
3. 确认配置文件格式正确
4. 在GitHub项目页面提交Issue

项目地址: https://github.com/rdone4425/github11
