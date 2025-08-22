# GitLab v2 部署操作记录

> **部署时间**: 2025-08-20  
> **部署服务器**: 192.168.0.127  
> **GitLab版本**: CE (Community Edition) Latest  
> **部署方式**: Docker Compose (简化配置)

## 📋 部署概述

GitLab v2采用简化的Docker Compose配置，专注于快速部署和低内存消耗，适合小型团队或测试环境使用。

## 🏗️ 项目结构

```
~/gitlab-v2/
├── docker-compose.yml       # 主配置文件
├── manage.sh                # 管理脚本
├── gitlab-config/           # GitLab配置目录（外挂）
├── gitlab-data/             # GitLab数据目录（外挂）
└── gitlab-logs/             # GitLab日志目录（外挂）
```

## ⚙️ 核心配置

### Docker Compose配置

**容器设置**:
- **镜像**: gitlab/gitlab-ce:latest
- **容器名**: gitlab-v2
- **主机名**: gitlab-server
- **重启策略**: unless-stopped

**端口映射**:
- **HTTP**: 80:80 (Web界面访问)
- **SSH**: 2222:22 (Git SSH访问)

**资源限制**:
```yaml
deploy:
  resources:
    limits:
      memory: 2G        # 最大内存2GB
      cpus: '2.0'       # 最大2CPU核心
    reservations:
      memory: 1G        # 预留内存1GB
      cpus: '1.0'       # 预留1CPU核心
```

### GitLab配置优化

**性能优化配置**:
```yaml
# PostgreSQL数据库优化
postgresql['shared_buffers'] = '128MB'
postgresql['max_connections'] = 100
postgresql['work_mem'] = '8MB'

# Puma应用服务器优化
puma['worker_processes'] = 2
puma['min_threads'] = 1
puma['max_threads'] = 2

# Sidekiq后台任务优化
sidekiq['max_concurrency'] = 5

# Nginx Web服务器优化
nginx['worker_processes'] = 1
nginx['worker_connections'] = 512
```

**禁用的服务** (节省内存):
- Prometheus监控
- Alertmanager告警管理
- Node/Redis/PostgreSQL导出器
- Grafana仪表盘
- GitLab Pages
- Container Registry

## 🚀 部署过程记录

### 1. 环境准备

**服务器信息**:
- **IP**: 192.168.0.127
- **系统**: Ubuntu 24.04 LTS
- **用户**: ubuntu
- **Docker**: 已安装并运行
- **Docker Compose**: v2 (可用)

### 2. 目录创建

```bash
# 创建项目目录
mkdir -p ~/gitlab-v2
cd ~/gitlab-v2

# 创建数据目录
mkdir -p gitlab-{config,logs,data}
```

### 3. 配置文件部署

**docker-compose.yml** - 主配置文件已部署
**manage.sh** - 管理脚本已创建

### 4. 容器启动过程

**第一次尝试** (失败):
```bash
docker compose up -d
# 错误: SSH端口22冲突 (系统SSH服务占用)
```

**端口冲突解决**:
```yaml
# 修改SSH端口映射
ports:
  - "80:80"
  - "2222:22"  # 改为2222端口

# 更新GitLab SSH配置
gitlab_rails['gitlab_shell_ssh_port'] = 2222
```

**第二次启动** (成功):
```bash
docker compose up -d
# 结果: Container gitlab-v2 Started
```

### 5. 部署验证

**容器状态检查**:
```bash
docker compose ps
# NAME: gitlab-v2
# STATUS: Up (health: starting)
# PORTS: 0.0.0.0:80->80/tcp, 0.0.0.0:2222->22/tcp
```

**启动日志确认**:
- GitLab正在配置中 ("Configuring GitLab...")
- 服务启动正常
- 健康检查开始执行

## 📊 当前状态

### 容器状态 ✅
- **状态**: 运行中 (Up)
- **健康检查**: 启动中 (health: starting)
- **端口绑定**: 正常

### 服务初始化 ⏳
- **配置阶段**: 进行中
- **预计完成时间**: 10-15分钟
- **首次访问**: 等待初始化完成

### 资源使用
- **内存限制**: 2GB
- **CPU限制**: 2核心
- **存储**: 外挂持久化

## 🌐 访问信息

### Web界面访问
- **URL**: http://192.168.0.127
- **用户名**: root
- **密码**: GitLabAdmin2024!

### SSH Git访问
- **SSH地址**: git@192.168.0.127:2222
- **克隆示例**: `git clone ssh://git@192.168.0.127:2222/username/project.git`

### 管理命令
```bash
# 进入项目目录
cd ~/gitlab-v2

# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f gitlab

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 使用管理脚本
./manage.sh status    # 查看状态
./manage.sh logs      # 查看日志
./manage.sh restart   # 重启服务
```

## 📝 人工操作步骤

### 必须完成的操作

#### 1. 等待初始化完成 ⏳
**操作**: 等待10-15分钟让GitLab完成首次初始化
**验证**: 访问 http://192.168.0.127 能正常显示登录页面

#### 2. 修改默认密码 🔒
**重要性**: 🔴 极高 - 必须操作
**步骤**:
1. 使用 `root` / `GitLabAdmin2024!` 登录
2. 点击右上角头像 → Settings
3. 左侧菜单选择 Password
4. 修改为强密码
5. 保存更改

#### 3. 配置SSH密钥 🔑
**目的**: 启用SSH Git操作
**步骤**:
1. 生成SSH密钥 (如果没有):
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your.email@example.com"
   ```
2. 复制公钥: `cat ~/.ssh/id_rsa.pub`
3. GitLab中添加: Settings → SSH Keys → Add key
4. 测试连接: `ssh -T git@192.168.0.127 -p 2222`

#### 4. 创建第一个项目 📁
**步骤**:
1. 点击 "New project"
2. 选择 "Create blank project"
3. 填写项目名称和描述
4. 设置可见性级别
5. 创建项目

### 可选操作

#### 1. 配置开机自启动
由于使用了用户目录部署，需要手动配置开机启动:
```bash
# 编辑crontab
crontab -e

# 添加开机启动任务
@reboot cd /home/ubuntu/gitlab-v2 && docker compose up -d
```

#### 2. 配置邮件服务
编辑 `docker-compose.yml` 添加SMTP配置:
```yaml
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.example.com"
gitlab_rails['smtp_port'] = 587
# ... 其他SMTP配置
```

## 🔧 故障排除

### 常见问题

#### 1. 端口冲突
**症状**: "bind: address already in use"
**解决**: 修改端口映射，避免与系统服务冲突

#### 2. 内存不足
**症状**: 容器频繁重启
**解决**: 
- 检查系统内存: `free -h`
- 调整资源限制: 减少memory限制到1G
- 关闭不必要的系统服务

#### 3. 初始化超时
**症状**: 长时间无法访问Web界面
**解决**:
- 查看日志: `docker compose logs -f gitlab`
- 等待更长时间 (首次可能需要20分钟)
- 检查磁盘空间是否充足

### 日志查看

```bash
# 实时日志
docker compose logs -f gitlab

# 最近日志
docker compose logs --tail=100 gitlab

# 特定时间范围日志
docker compose logs --since="2024-08-20T09:00:00" gitlab
```

## 📈 性能监控

### 资源使用监控
```bash
# 查看容器资源使用
docker stats gitlab-v2

# 查看系统资源
htop
free -h
df -h
```

### 健康检查
```bash
# GitLab健康检查
curl http://192.168.0.127/-/health

# 就绪状态检查
curl http://192.168.0.127/-/readiness
```

## 💾 备份策略

### 数据备份
```bash
# 备份数据目录
tar -czf gitlab-backup-$(date +%Y%m%d).tar.gz ~/gitlab-v2/gitlab-data/

# GitLab内置备份
docker compose exec gitlab gitlab-backup create
```

### 配置备份
```bash
# 备份docker-compose.yml
cp ~/gitlab-v2/docker-compose.yml ~/gitlab-v2/docker-compose.yml.backup
```

## 🔄 更新升级

### 更新GitLab版本
```bash
cd ~/gitlab-v2

# 备份数据
./manage.sh stop
tar -czf backup-before-update.tar.gz gitlab-data/

# 拉取新镜像
docker compose pull

# 启动新版本
docker compose up -d
```

## 📋 部署检查清单

### 部署完成 ✅
- [x] 容器成功启动
- [x] 端口映射正确 (80, 2222)
- [x] 数据目录外挂配置
- [x] 资源限制设置 (2GB内存)
- [x] 健康检查配置
- [x] 管理脚本创建

### 待完成操作 ⏳
- [ ] 等待初始化完成 (10-15分钟)
- [ ] 修改默认密码
- [ ] 配置SSH密钥
- [ ] 创建第一个项目
- [ ] 配置开机自启动 (可选)

### 验证项目 🔍
- [ ] Web界面可正常访问
- [ ] SSH连接测试通过
- [ ] 可以创建和克隆项目
- [ ] 备份功能正常

## 📞 支持信息

### 管理命令快速参考
```bash
# 基本操作
cd ~/gitlab-v2
docker compose ps              # 查看状态
docker compose logs -f gitlab  # 查看日志
docker compose restart         # 重启服务
docker compose down            # 停止服务

# 管理脚本
./manage.sh status            # 状态检查
./manage.sh logs              # 日志查看
./manage.sh restart           # 重启服务
```

### 访问信息总结
- **Web**: http://192.168.0.127 (root / GitLabAdmin2024!)
- **SSH**: git@192.168.0.127:2222
- **项目目录**: /home/ubuntu/gitlab-v2
- **数据目录**: /home/ubuntu/gitlab-v2/gitlab-data

---

## ✅ 部署状态总结

**🎉 GitLab v2 已成功部署到 192.168.0.127 服务器！**

**当前状态**:
- ✅ 容器运行正常
- ⏳ 正在初始化 (预计10-15分钟完成)
- ✅ 端口映射正确
- ✅ 数据持久化配置
- ✅ 内存优化设置

**下一步操作**:
1. 等待初始化完成
2. 访问 http://192.168.0.127 进行首次登录
3. 修改默认密码
4. 开始使用GitLab！

---

**文档最后更新**: 2025-08-20 17:40  
**部署状态**: ✅ 成功  
**预计可用时间**: 2025-08-20 17:55