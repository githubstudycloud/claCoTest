# GitLab Docker 安装操作记录

> **文档创建时间**: 2025-08-20  
> **GitLab版本**: CE (Community Edition) Latest  
> **部署方式**: Docker Compose  
> **目标环境**: 开发/测试环境

## 📋 安装概述

本文档记录GitLab Docker部署的完整过程，包括自动化脚本和人工操作步骤。

### 项目结构

```
docker/gitlab/v1/
├── 📄 docker-compose.yml     # Docker Compose主配置文件
├── 🔐 .env                   # 环境变量配置文件（敏感信息）
├── 🚀 start.sh              # 自动启动脚本
├── ⏹️  stop.sh               # 停止脚本
├── 🛠️  manage.sh             # 管理脚本（备份、恢复等）
├── ✅ check-env.sh           # 环境检查脚本
├── 📖 README.md              # 用户使用指南
├── 📋 INSTALLATION.md        # 本安装文档
├── 📁 config/                # GitLab配置目录（自动创建）
├── 💾 data/                  # GitLab数据目录（自动创建）
├── 📜 logs/                  # GitLab日志目录（自动创建）
└── 💼 backups/               # 备份目录（自动创建）
```

## 🔧 核心配置说明

### 1. Docker Compose配置

**文件**: `docker-compose.yml`

**关键配置项**:
```yaml
services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab-ce
    hostname: gitlab.local
    
    # 端口映射
    ports:
      - "8080:80"     # HTTP Web访问
      - "2222:22"     # SSH Git访问
      
    # 数据持久化
    volumes:
      - ./config:/etc/gitlab:Z
      - ./logs:/var/log/gitlab:Z
      - ./data:/var/opt/gitlab:Z
      
    # 资源限制
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

**重要环境变量**:
```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url 'http://localhost:8080'
    gitlab_rails['initial_root_password'] = 'ChangeMePlease123!'
    gitlab_rails['gitlab_shell_ssh_port'] = 2222
    gitlab_rails['time_zone'] = 'Asia/Shanghai'
    gitlab_rails['gitlab_signup_enabled'] = false
```

### 2. 环境变量配置

**文件**: `.env`

**核心配置**:
```bash
# 访问配置
GITLAB_EXTERNAL_URL=http://localhost:8080
GITLAB_HOSTNAME=gitlab.local

# 认证配置
GITLAB_ROOT_PASSWORD=ChangeMePlease123!

# 端口配置
GITLAB_HTTP_PORT=8080
GITLAB_SSH_PORT=2222

# 资源配置
GITLAB_MEMORY_LIMIT=4G
GITLAB_MEMORY_RESERVATION=2G

# 功能开关
GITLAB_SIGNUP_ENABLED=false
GITLAB_EMAIL_ENABLED=false
```

## 🚀 自动化安装流程

### 第一步：环境检查

```bash
# 运行环境检查脚本
./check-env.sh
```

**检查项目**:
- ✅ Docker是否安装并运行
- ✅ Docker Compose是否可用
- ✅ 端口8080和2222是否可用
- ✅ 系统内存是否充足（>=4GB推荐）
- ✅ 磁盘空间是否充足（>=10GB）
- ✅ 网络连通性（Docker Hub访问）
- ✅ 配置文件完整性

### 第二步：一键启动

```bash
# 执行自动启动脚本
./start.sh
```

**自动执行的操作**:
1. 🔍 Docker环境验证
2. 🔍 端口占用检查
3. 📁 创建必要目录（config, data, logs, backups）
4. 🔧 设置目录权限（Linux/macOS）
5. 📥 拉取GitLab镜像
6. 🚀 启动GitLab容器
7. ⏳ 等待服务就绪（最多30分钟）
8. ✅ 显示访问信息

### 第三步：访问验证

**Web界面访问**:
- 🌐 URL: http://localhost:8080
- 👤 用户名: `root`
- 🔑 密码: `ChangeMePlease123!`

**SSH访问测试**:
```bash
# 测试SSH连接
ssh -T git@localhost -p 2222
```

## 🛠️ 人工操作步骤

### 必须执行的人工操作

#### 1. 修改默认密码 🔒

**重要性**: 🔴 极重要 - 安全风险

**操作步骤**:
1. 打开 http://localhost:8080
2. 使用 `root` / `ChangeMePlease123!` 登录
3. 点击右上角头像 → **Settings**
4. 左侧菜单选择 **Password**
5. 填写当前密码和新密码
6. 点击 **Save password**

**建议新密码要求**:
- 长度至少12位
- 包含大小写字母、数字、特殊字符
- 不使用常见单词或个人信息

#### 2. 配置SSH密钥 🔑

**操作目的**: 启用SSH Git操作

**步骤**:
1. 生成SSH密钥对（如果没有）:
```bash
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"
```

2. 复制公钥内容:
```bash
cat ~/.ssh/id_rsa.pub
```

3. 在GitLab中添加SSH密钥:
   - 登录GitLab Web界面
   - 头像 → **Settings** → **SSH Keys**
   - 粘贴公钥内容
   - 添加描述（如：My Laptop）
   - 点击 **Add key**

4. 测试SSH连接:
```bash
ssh -T git@localhost -p 2222
```

#### 3. 创建第一个项目 📁

**操作步骤**:
1. 点击 **New project**
2. 选择 **Create blank project**
3. 填写项目信息:
   - **Project name**: 项目名称
   - **Project description**: 项目描述
   - **Visibility Level**: 选择可见性
     - Private: 私有项目
     - Internal: 内部项目  
     - Public: 公开项目
4. 点击 **Create project**

#### 4. 配置用户设置 👤

**建议配置项**:

**用户资料**:
- 头像 → **Settings** → **Profile**
- 设置全名、邮箱、时区

**通知设置**:
- 头像 → **Settings** → **Notifications**  
- 配置邮件通知偏好

**访问令牌**（用于API访问）:
- 头像 → **Settings** → **Access Tokens**
- 创建个人访问令牌

### 可选的人工操作

#### 1. 启用用户注册 👥

**场景**: 团队使用，需要其他用户注册

**操作**:
1. 管理员登录
2. **Admin Area** → **Settings** → **General**
3. 展开 **Sign-up restrictions**
4. 勾选 **Sign-up enabled**
5. 配置注册限制（邮箱域名白名单等）
6. 点击 **Save changes**

#### 2. 配置LDAP认证 🏢

**场景**: 企业环境，集成现有AD/LDAP

**配置文件**: 需要修改 `docker-compose.yml` 中的 `GITLAB_OMNIBUS_CONFIG`

```yaml
GITLAB_OMNIBUS_CONFIG: |
  gitlab_rails['ldap_enabled'] = true
  gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'
    main:
      label: 'LDAP'
      host: 'ldap.company.com'
      port: 389
      uid: 'sAMAccountName'
      bind_dn: 'CN=ldapuser,OU=Users,DC=company,DC=com'
      password: 'ldappassword'
      encryption: 'plain'
      base: 'OU=Users,DC=company,DC=com'
  EOS
```

#### 3. 配置邮件服务 📧

**用途**: 发送通知邮件、密码重置等

**SMTP配置示例**:
```yaml
GITLAB_OMNIBUS_CONFIG: |
  gitlab_rails['smtp_enable'] = true
  gitlab_rails['smtp_address'] = "smtp.gmail.com"
  gitlab_rails['smtp_port'] = 587
  gitlab_rails['smtp_user_name'] = "your-email@gmail.com"
  gitlab_rails['smtp_password'] = "your-password"
  gitlab_rails['smtp_domain'] = "smtp.gmail.com"
  gitlab_rails['smtp_authentication'] = "login"
  gitlab_rails['smtp_enable_starttls_auto'] = true
  gitlab_rails['smtp_tls'] = false
  gitlab_rails['gitlab_email_from'] = 'your-email@gmail.com'
```

#### 4. 设置备份策略 💾

**自动备份配置**:
```yaml
GITLAB_OMNIBUS_CONFIG: |
  gitlab_rails['backup_keep_time'] = 604800  # 7天
  gitlab_rails['backup_archive_permissions'] = 0644
```

**手动备份命令**:
```bash
# 使用管理脚本
./manage.sh backup

# 或直接执行
docker compose exec gitlab gitlab-backup create
```

## 🔧 故障处理指南

### 常见启动问题

#### 问题1: Docker未运行

**错误信息**:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**解决方案**:
```bash
# Linux
sudo systemctl start docker

# Windows
启动Docker Desktop应用程序

# macOS  
启动Docker Desktop应用程序
```

#### 问题2: 端口被占用

**错误信息**:
```
Port 8080 is already in use
```

**解决方案**:
```bash
# 查找占用进程
netstat -tlnp | grep :8080
# 或
lsof -i :8080

# 停止占用进程或修改.env中的端口配置
GITLAB_HTTP_PORT=9090
```

#### 问题3: 内存不足

**症状**: 容器频繁重启，启动缓慢

**解决方案**:
```yaml
# 降低资源限制（docker-compose.yml）
deploy:
  resources:
    limits:
      memory: 2G    # 从4G降低
    reservations:
      memory: 1G    # 从2G降低
```

#### 问题4: 权限问题

**症状**: 数据目录无法写入（Linux/macOS）

**解决方案**:
```bash
# 设置正确权限
sudo chown -R 998:998 config/ data/ logs/
chmod -R 755 config/ data/ logs/
```

### 服务启动时间

**正常启动时间表**:
- 🚀 容器启动: 30秒内
- ⚡ GitLab服务就绪: 2-5分钟
- 🌐 Web界面可访问: 5-10分钟（首次启动）
- ✅ 完全就绪: 10-15分钟（首次启动）

**如果超过30分钟仍未就绪**:
1. 检查日志: `./manage.sh logs`
2. 检查系统资源: `docker stats`
3. 重启服务: `./manage.sh restart`

## 📊 性能调优建议

### 硬件要求

| 用户规模 | CPU | 内存 | 存储 |
|---------|-----|------|------|
| < 10人 | 2核 | 4GB | 20GB SSD |
| 10-50人 | 4核 | 8GB | 50GB SSD |
| 50-100人 | 8核 | 16GB | 100GB SSD |

### 配置优化

**小规模部署优化**:
```yaml
# 禁用不必要的功能
prometheus_monitoring['enable'] = false
grafana['enable'] = false
alertmanager['enable'] = false

# 减少工作进程
puma['worker_processes'] = 2
sidekiq['max_concurrency'] = 5
```

**数据库优化**:
```yaml
postgresql['max_connections'] = 200
postgresql['shared_buffers'] = "256MB"
postgresql['work_mem'] = "16MB"
```

## 🔒 安全加固指南

### 基础安全设置

#### 1. 网络安全
```yaml
# 限制访问IP（生产环境）
# 在docker-compose.yml中配置
ports:
  - "127.0.0.1:8080:80"  # 仅本地访问
  - "127.0.0.1:2222:22"  # 仅本地SSH
```

#### 2. 用户管理
- 禁用root用户（创建管理员账户后）
- 强制2FA认证
- 定期审核用户权限

#### 3. 数据保护
```bash
# 设置备份加密
gitlab_rails['backup_encryption'] = 'aes256'
gitlab_rails['backup_encryption_key'] = 'your-encryption-key'
```

#### 4. 访问控制
```yaml
# IP白名单
gitlab_rails['rack_attack_git_basic_auth'] = {
  'enabled' => true,
  'ip_whitelist' => ["127.0.0.1", "192.168.1.0/24"],
  'maxretry' => 10,
  'findtime' => 60,
  'bantime' => 3600
}
```

## 📝 维护计划

### 日常维护任务

**每日**:
- 检查服务状态: `./manage.sh status`
- 查看错误日志: `./manage.sh logs-tail`

**每周**:
- 创建数据备份: `./manage.sh backup`
- 清理系统资源: `docker system prune`
- 检查磁盘空间使用

**每月**:
- 更新GitLab版本: `./manage.sh update`
- 审核用户权限和项目访问
- 检查安全日志

**每季度**:
- 全面安全审核
- 灾难恢复测试
- 性能优化评估

### 监控指标

**关键指标**:
- CPU使用率 < 80%
- 内存使用率 < 85%  
- 磁盘使用率 < 80%
- 响应时间 < 2秒

**监控命令**:
```bash
# 实时资源监控
docker stats gitlab-ce

# GitLab内部状态
docker compose exec gitlab gitlab-ctl status

# 健康检查
curl -f http://localhost:8080/-/health
```

## 🔄 升级指南

### 准备工作
1. **备份数据**: `./manage.sh backup`
2. **检查兼容性**: 查看官方升级文档
3. **计划停机时间**: 通知用户

### 升级步骤
```bash
# 1. 停止服务
./manage.sh stop

# 2. 备份当前版本
cp docker-compose.yml docker-compose.yml.backup

# 3. 更新镜像
./manage.sh update

# 4. 验证升级
./manage.sh status
curl -f http://localhost:8080/-/health
```

## 📞 技术支持

### 获取帮助

**内置帮助**:
```bash
./manage.sh help           # 管理脚本帮助
./check-env.sh             # 环境检查
```

**日志分析**:
```bash
./manage.sh logs           # 实时日志
./manage.sh logs-tail      # 历史日志
```

**系统信息**:
```bash
# GitLab版本信息
docker compose exec gitlab gitlab-rake gitlab:env:info

# 系统状态
docker compose exec gitlab gitlab-ctl status
```

### 社区资源

- 📖 [GitLab官方文档](https://docs.gitlab.com/)
- 💬 [GitLab社区论坛](https://forum.gitlab.com/)
- 🐛 [问题报告](https://gitlab.com/gitlab-org/gitlab/-/issues)
- 📚 [Docker镜像文档](https://docs.gitlab.com/ee/install/docker.html)

## ✅ 安装检查清单

### 环境准备 ✓
- [ ] Docker已安装并运行
- [ ] Docker Compose已安装
- [ ] 端口8080和2222可用
- [ ] 系统内存 >= 4GB
- [ ] 磁盘空间 >= 10GB
- [ ] 网络连通正常

### 配置文件 ✓  
- [ ] docker-compose.yml存在
- [ ] .env文件存在并配置正确
- [ ] 脚本文件有执行权限

### 启动验证 ✓
- [ ] 容器启动成功
- [ ] Web界面可访问
- [ ] 可以使用默认账户登录
- [ ] SSH连接测试通过

### 安全配置 ✓
- [ ] 已修改默认密码
- [ ] 已添加SSH密钥
- [ ] 已禁用用户注册（可选）
- [ ] 已配置备份策略

### 功能测试 ✓
- [ ] 可以创建项目
- [ ] 可以推送代码
- [ ] 可以克隆仓库
- [ ] Web界面功能正常

---

## 📊 安装完成报告

**安装时间**: 2025-08-20  
**GitLab版本**: CE Latest  
**部署方式**: Docker Compose  
**配置状态**: ✅ 完成  

**访问信息**:
- 🌐 Web: http://localhost:8080
- 🔐 默认账户: root / ChangeMePlease123!
- 🔗 SSH: ssh://git@localhost:2222

**重要提醒**:
1. 🔒 **立即修改默认密码**
2. 🔑 **配置SSH密钥**  
3. 💾 **设置定期备份**
4. 📊 **监控系统资源**

---

*本文档将随着GitLab版本更新和配置变更持续更新。*