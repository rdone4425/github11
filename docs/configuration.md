# 配置说明

本文档详细说明GitHub文件同步系统的配置选项和使用方法。

## 配置文件结构

系统使用两个主要配置文件：

- `config/global.conf` - 全局配置，包含GitHub凭据和系统设置
- `config/paths.conf` - 路径配置，定义要监控的目录和对应的GitHub仓库

## 全局配置 (global.conf)

### GitHub设置

```bash
# GitHub用户名
GITHUB_USERNAME="your-username"

# GitHub访问令牌 (Personal Access Token)
# 需要具有repo权限的token
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# GitHub API基础URL (通常不需要修改)
GITHUB_API_URL="https://api.github.com"
```

#### 获取GitHub Token

1. 登录GitHub，进入 Settings → Developer settings → Personal access tokens
2. 点击 "Generate new token (classic)"
3. 设置token名称和过期时间
4. 选择权限范围：
   - `repo` - 完整的仓库访问权限（必需）
   - `workflow` - 访问GitHub Actions（可选）
5. 生成并复制token

### 同步设置

```bash
# 默认分支名称
DEFAULT_BRANCH="main"

# 同步间隔（秒）- 批量处理文件变化的间隔
SYNC_INTERVAL=5

# 最大重试次数
MAX_RETRIES=3

# 最大文件大小（字节）- GitHub限制为100MB
MAX_FILE_SIZE=104857600

# 提交消息模板 (%s 会被替换为文件名)
COMMIT_MESSAGE_TEMPLATE="Auto sync: %s"

# 是否在同步前验证文件
VALIDATE_BEFORE_SYNC=true
```

### 日志设置

```bash
# 日志级别 (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL="INFO"

# 是否启用详细输出
VERBOSE=false
```

### 文件过滤

```bash
# 排除的文件模式（用空格分隔）
EXCLUDE_PATTERNS="*.tmp *.log *.swp .git .DS_Store node_modules __pycache__ *.pyc"
```

## 路径配置 (paths.conf)

路径配置文件使用INI格式，每个监控路径为一个独立的节。

### 基本格式

```ini
[路径标识符]
LOCAL_PATH=/path/to/local/directory
GITHUB_REPO=username/repository
TARGET_BRANCH=main
SUBDIR_MAPPING=optional/subdirectory
ENABLED=true
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=*.tmp *.log
```

### 配置项说明

#### LOCAL_PATH (必需)
要监控的本地目录路径。

```ini
LOCAL_PATH=/home/user/documents
```

#### GITHUB_REPO (必需)
目标GitHub仓库，格式为 `用户名/仓库名`。

```ini
GITHUB_REPO=myuser/my-documents
```

#### TARGET_BRANCH (可选)
目标分支名称。如果不指定，使用全局配置的 `DEFAULT_BRANCH`。

```ini
TARGET_BRANCH=main
```

#### SUBDIR_MAPPING (可选)
在GitHub仓库中的子目录映射。如果指定，本地文件将上传到仓库的这个子目录下。

```ini
# 本地文件 /home/user/docs/file.txt 
# 将上传到 myuser/my-repo/documents/file.txt
SUBDIR_MAPPING=documents
```

#### ENABLED (可选)
是否启用此路径的监控。默认为 `true`。

```ini
ENABLED=true
```

#### WATCH_SUBDIRS (可选)
是否递归监控子目录。默认为 `true`。

```ini
WATCH_SUBDIRS=true
```

#### EXCLUDE_PATTERNS (可选)
此路径特有的排除模式，会与全局排除模式合并。

```ini
EXCLUDE_PATTERNS=*.o *.so build/
```

## 配置示例

### 示例1：文档同步

```ini
[documents]
LOCAL_PATH=/home/user/Documents
GITHUB_REPO=myuser/personal-docs
TARGET_BRANCH=main
SUBDIR_MAPPING=
ENABLED=true
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=*.tmp
```

### 示例2：项目代码同步

```ini
[projects]
LOCAL_PATH=/home/user/projects
GITHUB_REPO=myuser/code-backup
TARGET_BRANCH=backup
SUBDIR_MAPPING=projects
ENABLED=true
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=node_modules/ *.log build/ dist/
```

### 示例3：配置文件备份

```ini
[dotfiles]
LOCAL_PATH=/home/user/.config
GITHUB_REPO=myuser/dotfiles
TARGET_BRANCH=main
SUBDIR_MAPPING=config
ENABLED=true
WATCH_SUBDIRS=false
EXCLUDE_PATTERNS=*.cache *.lock
```

### 示例4：网站内容同步

```ini
[website]
LOCAL_PATH=/var/www/html
GITHUB_REPO=myuser/website-content
TARGET_BRANCH=gh-pages
SUBDIR_MAPPING=
ENABLED=true
WATCH_SUBDIRS=true
EXCLUDE_PATTERNS=*.log access.log error.log
```

## 高级配置

### 环境变量

可以通过环境变量覆盖配置文件中的设置：

```bash
export GITHUB_USERNAME="override-user"
export LOG_LEVEL="DEBUG"
export VERBOSE="true"
```

### 配置文件路径

默认配置文件路径：
- 全局配置: `/opt/file-sync-system/config/global.conf`
- 路径配置: `/opt/file-sync-system/config/paths.conf`

可以通过 `-c` 参数指定不同的配置目录：

```bash
file-sync -c /custom/config/path start
```

### 配置验证

使用以下命令验证配置：

```bash
# 验证所有配置
file-sync validate

# 验证特定配置文件
file-sync config validate
```

### 配置管理命令

```bash
# 列出当前配置
file-sync config list

# 编辑配置文件
file-sync config edit

# 重置配置到默认值
file-sync config reset
```

## 安全考虑

### 文件权限

确保配置文件具有适当的权限：

```bash
# 设置配置文件权限（仅所有者可读写）
chmod 600 /opt/file-sync-system/config/global.conf
chmod 600 /opt/file-sync-system/config/paths.conf
```

### Token安全

- 使用具有最小必要权限的token
- 定期轮换token
- 不要在日志中记录token
- 考虑使用GitHub Apps而不是个人token

### 网络安全

- 确保系统时间正确（用于API认证）
- 使用HTTPS连接
- 考虑使用代理服务器

## 故障排除

### 配置错误

1. **GitHub凭据无效**
   ```bash
   # 测试GitHub连接
   curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
   ```

2. **路径不存在**
   ```bash
   # 检查路径是否存在
   ls -la /path/to/directory
   ```

3. **权限问题**
   ```bash
   # 检查文件权限
   ls -la /opt/file-sync-system/config/
   ```

### 配置验证失败

运行详细验证：

```bash
file-sync -v validate
```

查看详细日志：

```bash
file-sync logs follow
```

## 最佳实践

1. **备份配置文件**
   ```bash
   cp /opt/file-sync-system/config/global.conf /opt/file-sync-system/config/global.conf.backup
   ```

2. **使用版本控制**
   将配置文件（除了包含敏感信息的部分）纳入版本控制。

3. **监控日志**
   定期检查日志文件，确保同步正常运行。

4. **测试配置**
   在生产环境使用前，先在测试环境验证配置。

5. **文档化**
   记录您的配置决策和特殊设置。
