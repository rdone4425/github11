# 使用说明

本文档介绍GitHub文件同步系统的日常使用和管理方法。

## 基本命令

### 查看帮助

```bash
# 显示主要帮助信息
file-sync --help

# 显示版本信息
file-sync --version
```

### 系统管理

```bash
# 初始化系统（首次使用）
file-sync init

# 验证配置
file-sync validate

# 查看系统状态
file-sync status
```

## 服务管理

### 启动和停止

```bash
# 启动监控服务
file-sync start

# 停止监控服务
file-sync stop

# 重启监控服务
file-sync restart

# 查看服务状态
file-sync status
```

### 使用systemd管理

```bash
# 启动服务
sudo systemctl start file-sync

# 停止服务
sudo systemctl stop file-sync

# 重启服务
sudo systemctl restart file-sync

# 查看服务状态
sudo systemctl status file-sync

# 启用开机自启
sudo systemctl enable file-sync

# 禁用开机自启
sudo systemctl disable file-sync
```

## 配置管理

### 查看配置

```bash
# 列出所有配置
file-sync config list

# 验证配置
file-sync config validate
```

### 编辑配置

```bash
# 交互式编辑配置
file-sync config edit

# 直接编辑配置文件
sudo nano /opt/file-sync-system/config/global.conf
sudo nano /opt/file-sync-system/config/paths.conf
```

### 重置配置

```bash
# 重置所有配置到默认值
file-sync config reset
```

## 手动同步

### 同步所有路径

```bash
# 同步所有启用的路径
file-sync sync all
```

### 同步特定路径

```bash
# 同步指定的路径
file-sync sync documents

# 强制同步（忽略缓存）
file-sync sync --force projects
```

## 日志管理

### 查看日志

```bash
# 显示最近的日志
file-sync logs show

# 实时跟踪日志
file-sync logs follow

# 显示日志统计
file-sync logs stats
```

### 清理日志

```bash
# 清理旧日志文件
file-sync logs clean
```

### 查看系统日志

```bash
# 查看systemd日志
sudo journalctl -u file-sync

# 实时跟踪systemd日志
sudo journalctl -u file-sync -f

# 查看最近的错误
sudo journalctl -u file-sync --since "1 hour ago" -p err
```

## 监控和诊断

### 检查系统健康

```bash
# 运行系统健康检查
file-sync validate

# 详细输出模式
file-sync -v validate
```

### 查看监控状态

```bash
# 查看详细状态信息
file-sync status

# 查看特定路径状态
file-sync status documents
```

### 网络连接测试

```bash
# 测试GitHub连接
curl -I https://api.github.com

# 测试GitHub API认证
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
```

## 常见使用场景

### 场景1：开发环境代码备份

1. **配置路径**
   ```ini
   [dev-projects]
   LOCAL_PATH=/home/developer/projects
   GITHUB_REPO=developer/code-backup
   TARGET_BRANCH=backup
   ENABLED=true
   EXCLUDE_PATTERNS=node_modules/ .git/ *.log build/ dist/
   ```

2. **启动监控**
   ```bash
   file-sync start
   ```

3. **验证同步**
   ```bash
   # 创建测试文件
   echo "test" > /home/developer/projects/test.txt
   
   # 查看日志确认同步
   file-sync logs follow
   ```

### 场景2：文档自动发布

1. **配置路径**
   ```ini
   [documentation]
   LOCAL_PATH=/home/writer/docs
   GITHUB_REPO=writer/documentation
   TARGET_BRANCH=gh-pages
   ENABLED=true
   EXCLUDE_PATTERNS=*.draft *.tmp
   ```

2. **手动同步现有文件**
   ```bash
   file-sync sync documentation
   ```

3. **启动自动监控**
   ```bash
   file-sync start
   ```

### 场景3：配置文件备份

1. **配置路径**
   ```ini
   [dotfiles]
   LOCAL_PATH=/home/user/.config
   GITHUB_REPO=user/dotfiles
   TARGET_BRANCH=main
   SUBDIR_MAPPING=config
   ENABLED=true
   WATCH_SUBDIRS=false
   EXCLUDE_PATTERNS=*.cache *.lock
   ```

2. **初始同步**
   ```bash
   file-sync sync --force dotfiles
   ```

## 性能优化

### 调整同步间隔

编辑 `global.conf`：
```bash
# 减少同步频率以降低API使用
SYNC_INTERVAL=30

# 增加同步频率以获得更快响应
SYNC_INTERVAL=2
```

### 优化排除模式

```bash
# 排除大文件和临时文件
EXCLUDE_PATTERNS="*.tmp *.log *.swp .git node_modules/ *.iso *.img"
```

### 限制监控深度

```ini
# 只监控顶级目录
WATCH_SUBDIRS=false
```

## 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查配置
   file-sync validate
   
   # 查看详细错误
   sudo journalctl -u file-sync -n 50
   ```

2. **文件未同步**
   ```bash
   # 检查文件是否被排除
   file-sync -v status
   
   # 手动触发同步
   file-sync sync all
   ```

3. **GitHub API限制**
   ```bash
   # 检查API使用情况
   curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/rate_limit
   ```

4. **权限错误**
   ```bash
   # 检查文件权限
   ls -la /opt/file-sync-system/
   
   # 重新设置权限
   sudo chown -R file-sync:file-sync /opt/file-sync-system/
   ```

### 调试模式

启用详细日志：

```bash
# 临时启用详细模式
file-sync -v start

# 永久启用（编辑配置文件）
LOG_LEVEL="DEBUG"
VERBOSE=true
```

### 重置系统

如果遇到严重问题，可以重置系统：

```bash
# 停止服务
file-sync stop

# 重置配置
file-sync config reset

# 清理日志
file-sync logs clean

# 重新配置
file-sync config edit

# 验证配置
file-sync validate

# 重新启动
file-sync start
```

## 最佳实践

### 1. 定期维护

```bash
# 每周检查系统状态
file-sync status

# 每月清理日志
file-sync logs clean

# 定期更新GitHub token
```

### 2. 监控设置

```bash
# 设置日志轮转
# 在 /etc/logrotate.d/file-sync 中配置

# 监控磁盘空间
df -h /opt/file-sync-system/

# 监控内存使用
ps aux | grep file-sync
```

### 3. 备份策略

```bash
# 备份配置文件
cp -r /opt/file-sync-system/config/ /backup/file-sync-config-$(date +%Y%m%d)/

# 导出路径配置
file-sync config list > /backup/file-sync-paths-$(date +%Y%m%d).txt
```

### 4. 安全实践

- 定期轮换GitHub token
- 监控异常的API使用
- 检查同步的文件内容
- 使用最小权限原则

## 集成和自动化

### 与其他工具集成

```bash
# 与cron集成进行定期检查
echo "0 */6 * * * /usr/local/bin/file-sync status" | crontab -

# 与监控系统集成
file-sync status | grep -q "运行中" || echo "File sync service down" | mail admin@example.com
```

### API和脚本

系统提供了丰富的命令行接口，可以轻松集成到其他脚本中：

```bash
#!/bin/bash
# 自动化部署脚本示例

# 检查服务状态
if ! file-sync status | grep -q "运行中"; then
    echo "启动文件同步服务..."
    file-sync start
fi

# 手动同步重要文件
file-sync sync documents
file-sync sync projects

echo "同步完成"
```
