# GitLab Docker 部署指南

> 基于Docker快速部署GitLab CE（社区版）的完整解决方案

## 📋 目录结构

```
docker/gitlab/v1/
├── docker-compose.yml    # Docker Compose配置文件
├── .env                  # 环境变量配置（包含敏感信息）
├── start.sh             # 启动脚本
├── stop.sh              # 停止脚本
├── manage.sh            # 管理脚本
├── README.md            # 本文档
├── config/              # GitLab配置目录（自动创建）
├── data/                # GitLab数据目录（自动创建）
├── logs/                # GitLab日志目录（自动创建）
└── backups/             # 备份目录（自动创建）
```

## 🚀 快速开始

### 1. 前置要求

#### 系统要求
- **操作系统**: Linux (推荐)、macOS、Windows (支持Docker)
- **内存**: 最小2GB，推荐4GB+
- **磁盘空间**: 最小10GB可用空间
- **网络**: 需要访问Docker Hub

#### 软件要求
- **Docker**: 版本20.10+
- **Docker Compose**: 版本1.29+ 或 Docker Compose v2

#### 端口要求
- **8080**: GitLab Web界面 (HTTP)
- **2222**: GitLab SSH访问

### 2. 一键启动

```bash
# 进入项目目录
cd docker/gitlab/v1

# 给脚本执行权限（Linux/macOS）
chmod +x *.sh

# 启动GitLab
./start.sh
```

### 3. 首次访问

启动完成后（大约5-10分钟），通过浏览器访问：

**🌐 Web地址**: http://localhost:8080  
**👤 用户名**: root  
**🔑 密码**: ChangeMePlease123!

> ⚠️ **重要**: 首次登录后请立即修改默认密码！

## 🛠️ 管理操作

### 使用管理脚本

```bash
# 查看所有可用命令
./manage.sh help

# 常用命令
./manage.sh start          # 启动服务
./manage.sh stop           # 停止服务
./manage.sh restart        # 重启服务
./manage.sh status         # 查看状态
./manage.sh logs           # 查看实时日志
./manage.sh backup         # 创建备份
./manage.sh info           # 显示访问信息
```

### 直接使用Docker Compose

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看状态
docker compose ps

# 查看日志
docker compose logs -f gitlab

# 进入容器
docker compose exec gitlab bash
```

## ⚙️ 配置说明

### 核心配置文件

#### docker-compose.yml
主要的Docker Compose配置，包含：
- GitLab容器配置
- 端口映射
- 卷挂载
- 环境变量
- 资源限制

#### .env文件
环境变量配置文件，包含：
- 访问URL和端口配置
- 初始密码设置
- 资源限制参数
- 功能开关配置

### 重要配置项

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| GITLAB_EXTERNAL_URL | http://localhost:8080 | 外部访问URL |
| GITLAB_ROOT_PASSWORD | ChangeMePlease123! | 初始root密码 |
| GITLAB_HTTP_PORT | 8080 | Web访问端口 |
| GITLAB_SSH_PORT | 2222 | SSH访问端口 |
| GITLAB_SIGNUP_ENABLED | false | 是否允许注册 |

### 自定义配置

1. **修改访问端口**
```bash
# 编辑.env文件
GITLAB_HTTP_PORT=9090
GITLAB_SSH_PORT=2223
```

2. **修改初始密码**
```bash
# 编辑.env文件
GITLAB_ROOT_PASSWORD=YourStrongPassword123!
```

3. **启用用户注册**
```bash
# 编辑.env文件
GITLAB_SIGNUP_ENABLED=true
```

## 📊 资源使用

### 默认资源配置

- **内存限制**: 4GB
- **内存预留**: 2GB
- **Puma工作进程**: 2个
- **PostgreSQL连接**: 50个

### 性能优化建议

#### 小型部署（<100用户）
```yaml
# docker-compose.yml中的资源配置
deploy:
  resources:
    limits:
      memory: 2G
    reservations:
      memory: 1G
```

#### 中型部署（100-500用户）
```yaml
deploy:
  resources:
    limits:
      memory: 6G
    reservations:
      memory: 4G
```

## 💾 备份和恢复

### 自动备份

```bash
# 创建备份
./manage.sh backup

# 备份文件保存在 ./backups/ 目录
```

### 手动备份

```bash
# 进入GitLab容器
docker compose exec gitlab bash

# 创建备份
gitlab-backup create

# 备份文件位置
ls /var/opt/gitlab/backups/
```

### 数据恢复

```bash
# 使用管理脚本恢复
./manage.sh restore

# 或手动恢复
docker compose exec gitlab gitlab-backup restore BACKUP=备份文件名
```

### 重要备份目录

| 目录 | 内容 | 重要性 |
|------|------|--------|
| ./data | GitLab所有数据 | 🔴 极重要 |
| ./config | GitLab配置文件 | 🟡 重要 |
| ./backups | 手动创建的备份 | 🟢 建议保留 |

## 🔧 故障排除

### 常见问题

#### 1. 启动失败

**症状**: 容器启动后立即退出

**排查步骤**:
```bash
# 查看容器状态
docker compose ps

# 查看详细日志
docker compose logs gitlab

# 检查端口占用
ss -tuln | grep -E ':(8080|2222)'
```

**可能原因**:
- 端口已被占用
- 磁盘空间不足
- 内存不够
- 权限问题

#### 2. 无法访问Web界面

**症状**: 浏览器无法打开 http://localhost:8080

**排查步骤**:
```bash
# 检查容器状态
./manage.sh status

# 检查端口监听
netstat -tlnp | grep 8080

# 检查防火墙（Linux）
sudo ufw status
```

**解决方案**:
- 等待更长时间（首次启动需要5-10分钟）
- 检查防火墙设置
- 确认端口映射正确

#### 3. SSH克隆失败

**症状**: `git clone ssh://git@localhost:2222/user/repo.git` 失败

**排查步骤**:
```bash
# 测试SSH连接
ssh -T git@localhost -p 2222

# 检查SSH端口
telnet localhost 2222
```

#### 4. 内存不足

**症状**: GitLab运行缓慢或频繁重启

**解决方案**:
```bash
# 降低资源配置
# 编辑docker-compose.yml，减少内存限制
memory: 2G  # 从4G降低到2G

# 禁用不必要的服务
# 在GITLAB_OMNIBUS_CONFIG中添加：
prometheus_monitoring['enable'] = false
grafana['enable'] = false
```

### 日志查看

```bash
# 查看GitLab应用日志
./manage.sh logs

# 查看特定服务日志
docker compose exec gitlab gitlab-ctl tail nginx
docker compose exec gitlab gitlab-ctl tail postgresql
docker compose exec gitlab gitlab-ctl tail redis
```

## 🔒 安全配置

### 修改默认密码

```bash
# 方法1：使用管理脚本
./manage.sh reset-password

# 方法2：在Web界面修改
# 登录后点击用户头像 -> Settings -> Password
```

### 禁用注册功能

```bash
# 编辑.env文件
GITLAB_SIGNUP_ENABLED=false

# 重启服务
./manage.sh restart
```

### SSH密钥管理

```bash
# 用户需要在GitLab Web界面添加SSH公钥
# Profile -> SSH Keys -> Add Key
```

## 🚀 更新升级

### 更新GitLab版本

```bash
# 备份数据（强烈推荐）
./manage.sh backup

# 更新到最新版本
./manage.sh update
```

### 版本锁定

```yaml
# 在docker-compose.yml中指定具体版本
image: gitlab/gitlab-ce:15.11.0-ce.0
```

## 📝 使用示例

### 1. 创建新项目

1. 登录Web界面: http://localhost:8080
2. 点击 "New project"
3. 填写项目名称和描述
4. 选择可见性级别
5. 点击 "Create project"

### 2. 克隆项目

```bash
# HTTPS克隆
git clone http://localhost:8080/username/project-name.git

# SSH克隆
git clone ssh://git@localhost:2222/username/project-name.git
```

### 3. 推送代码

```bash
# 初始化本地仓库
git init
git add .
git commit -m "Initial commit"

# 添加远程仓库
git remote add origin http://localhost:8080/username/project-name.git

# 推送代码
git push -u origin main
```

## ⚠️ 注意事项

### 生产环境使用

1. **修改默认密码**: 必须修改默认的root密码
2. **启用HTTPS**: 配置SSL证书
3. **备份策略**: 建立定期备份机制
4. **监控**: 配置系统监控和告警
5. **资源规划**: 根据用户数量调整资源配置

### 数据安全

1. **备份**: 定期备份./data目录
2. **权限**: 确保数据目录权限正确
3. **网络**: 在生产环境中限制网络访问

### 性能考虑

1. **硬件**: SSD存储可显著提升性能
2. **内存**: 内存越大，性能越好
3. **网络**: 确保网络带宽充足

## 🆘 获取帮助

### 官方文档
- [GitLab官方文档](https://docs.gitlab.com/)
- [GitLab Docker镜像](https://docs.gitlab.com/ee/install/docker.html)

### 社区支持
- [GitLab社区论坛](https://forum.gitlab.com/)
- [GitLab Issues](https://gitlab.com/gitlab-org/gitlab/-/issues)

### 本地帮助

```bash
# 查看管理脚本帮助
./manage.sh help

# 查看GitLab版本信息
docker compose exec gitlab gitlab-rake gitlab:env:info
```

---

## 📄 许可证

本部署方案基于GitLab CE（社区版），遵循MIT许可证。

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个部署方案！

---

**🎉 现在你可以开始使用GitLab了！**

记住：首次启动需要耐心等待5-10分钟，GitLab需要时间来初始化所有服务。