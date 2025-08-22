# GitLab v5 详细部署指南

## 目录
1. [环境准备](#环境准备)
2. [部署流程](#部署流程)
3. [配置详解](#配置详解)
4. [验证测试](#验证测试)
5. [问题解决](#问题解决)

## 环境准备

### 1. 系统要求检查

```bash
# 检查系统版本
lsb_release -a

# 检查内核版本
uname -r

# 检查可用资源
free -h
df -h
nproc
```

### 2. Docker环境安装

```bash
# 更新系统包
sudo apt-get update
sudo apt-get upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 将当前用户加入docker组
sudo usermod -aG docker $USER
newgrp docker

# 验证安装
docker --version
docker-compose --version
```

### 3. 系统优化

```bash
# 优化内核参数
sudo tee -a /etc/sysctl.conf <<EOF
# GitLab优化参数
vm.swappiness = 10
vm.max_map_count = 262144
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
EOF

# 应用参数
sudo sysctl -p
```

## 部署流程

### 步骤1: 传输文件到服务器

**从本地传输:**
```bash
# 创建本地压缩包
tar -czf gitlab-v5.tar.gz docker-compose.yml deploy.sh README.md DEPLOYMENT_GUIDE.md

# 传输到服务器
scp gitlab-v5.tar.gz ubuntu@192.168.0.127:~/

# 在服务器上解压
ssh ubuntu@192.168.0.127
tar -xzf gitlab-v5.tar.gz -C ~/gitlab-v5/
cd ~/gitlab-v5
```

### 步骤2: 创建数据目录

```bash
# 创建GitLab数据根目录
sudo mkdir -p /opt/gitlab/v5

# 创建子目录
sudo mkdir -p /opt/gitlab/v5/{config,logs,data,backups,lfs-objects,uploads,pages,registry}

# 设置权限
sudo chown -R $USER:$USER /opt/gitlab/v5
chmod -R 755 /opt/gitlab/v5
```

### 步骤3: 配置环境变量

```bash
# 创建环境变量文件
cat > .env <<EOF
# GitLab环境变量
GITLAB_HOME=/opt/gitlab/v5
GITLAB_HOSTNAME=192.168.0.127
GITLAB_HTTP_PORT=8929
GITLAB_SSH_PORT=2289
GITLAB_REGISTRY_PORT=5089
GITLAB_PAGES_PORT=8939
EOF

# 加载环境变量
source .env
```

### 步骤4: 启动GitLab

```bash
# 拉取镜像
docker-compose pull

# 启动服务
docker-compose up -d

# 查看启动日志
docker-compose logs -f
```

### 步骤5: 等待初始化

GitLab初始化需要5-10分钟，可通过以下方式监控：

```bash
# 方法1: 查看健康状态
watch -n 5 'docker ps | grep gitlab-v5'

# 方法2: 测试健康检查端点
while ! curl -f http://localhost/-/health 2>/dev/null; do
    echo "等待GitLab启动..."
    sleep 10
done
echo "GitLab已启动！"

# 方法3: 查看组件状态
docker exec gitlab-v5 gitlab-ctl status
```

## 配置详解

### 核心配置参数说明

#### 1. 性能配置

```yaml
# Puma配置（Web服务器）
puma['worker_processes'] = 2      # 工作进程数，建议CPU核心数的50%
puma['min_threads'] = 4           # 最小线程数
puma['max_threads'] = 8           # 最大线程数
puma['per_worker_max_memory_mb'] = 1024  # 每个工作进程最大内存

# Sidekiq配置（后台任务）
sidekiq['concurrency'] = 15       # 并发数，影响后台任务处理速度
sidekiq['max_concurrency'] = 25   # 最大并发数
sidekiq['min_concurrency'] = 5    # 最小并发数

# PostgreSQL配置
postgresql['shared_buffers'] = "512MB"     # 共享缓冲区，建议为总内存的25%
postgresql['max_connections'] = 200        # 最大连接数
postgresql['effective_cache_size'] = "2GB" # 有效缓存大小
```

#### 2. 存储配置

```yaml
volumes:
  - /opt/gitlab/v5/config:/etc/gitlab       # 配置文件
  - /opt/gitlab/v5/logs:/var/log/gitlab     # 日志文件
  - /opt/gitlab/v5/data:/var/opt/gitlab     # 核心数据
  - /opt/gitlab/v5/backups:/var/opt/gitlab/backups  # 备份
```

#### 3. 网络配置

```yaml
ports:
  - "8929:80"    # HTTP
  - "8943:443"   # HTTPS
  - "2289:22"    # SSH
  - "5089:5050"  # Registry
  - "8939:8090"  # Pages
```

### 高级配置选项

#### 启用HTTPS

1. **准备SSL证书:**
```bash
mkdir -p /opt/gitlab/v5/config/ssl
cp your-cert.crt /opt/gitlab/v5/config/ssl/gitlab.crt
cp your-cert.key /opt/gitlab/v5/config/ssl/gitlab.key
chmod 400 /opt/gitlab/v5/config/ssl/gitlab.key
```

2. **修改docker-compose.yml:**
```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url 'https://192.168.0.127:8943'
    nginx['redirect_http_to_https'] = true
    nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.crt"
    nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.key"
```

#### 配置SMTP邮件

```yaml
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.gmail.com"
gitlab_rails['smtp_port'] = 587
gitlab_rails['smtp_user_name'] = "your-email@gmail.com"
gitlab_rails['smtp_password'] = "your-app-password"
gitlab_rails['smtp_domain'] = "gmail.com"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = false
gitlab_rails['gitlab_email_from'] = 'gitlab@yourdomain.com'
gitlab_rails['gitlab_email_reply_to'] = 'noreply@yourdomain.com'
```

#### 配置LDAP认证

```yaml
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = {
  'main' => {
    'label' => 'Company LDAP',
    'host' => 'ldap.company.com',
    'port' => 389,
    'uid' => 'sAMAccountName',
    'bind_dn' => 'CN=gitlab,CN=Users,DC=company,DC=com',
    'password' => 'password',
    'encryption' => 'plain',
    'base' => 'DC=company,DC=com'
  }
}
```

## 验证测试

### 1. 基础功能测试

```bash
# 测试Web访问
curl -I http://192.168.0.127:8929

# 测试Registry
curl -I http://192.168.0.127:5089/v2/

# 测试SSH连接
ssh -T git@192.168.0.127 -p 2289
```

### 2. 创建测试项目

```bash
# 1. 登录GitLab Web界面
# 2. 创建新项目 "test-project"
# 3. 克隆测试

# HTTP克隆
git clone http://192.168.0.127:8929/root/test-project.git

# SSH克隆
git clone ssh://git@192.168.0.127:2289/root/test-project.git

# 推送测试
cd test-project
echo "# Test Project" > README.md
git add README.md
git commit -m "Initial commit"
git push origin main
```

### 3. Registry测试

```bash
# 登录Registry
docker login 192.168.0.127:5089
Username: root
Password: GitLab@V5#2024!

# 推送测试镜像
docker pull hello-world
docker tag hello-world 192.168.0.127:5089/root/test-project/hello:latest
docker push 192.168.0.127:5089/root/test-project/hello:latest
```

### 4. CI/CD测试

创建`.gitlab-ci.yml`:
```yaml
stages:
  - test

test-job:
  stage: test
  script:
    - echo "Running test..."
    - date
  tags:
    - docker
```

## 问题解决

### 常见问题及解决方案

#### 1. 端口被占用
```bash
# 查找占用端口的进程
sudo lsof -i:8929
sudo netstat -tulpn | grep 8929

# 停止占用的服务或修改GitLab端口
```

#### 2. 内存不足错误
```bash
# 增加swap空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

#### 3. 磁盘空间不足
```bash
# 清理Docker缓存
docker system prune -a

# 清理GitLab日志
docker exec gitlab-v5 find /var/log/gitlab -name "*.log" -mtime +7 -delete

# 清理旧备份
find /opt/gitlab/v5/backups -name "*.tar" -mtime +7 -delete
```

#### 4. GitLab启动缓慢
```bash
# 检查资源使用
docker stats gitlab-v5

# 调整配置参数（减少工作进程）
# 编辑docker-compose.yml，减少worker_processes和concurrency
```

#### 5. 502错误
```bash
# 重启GitLab
docker-compose restart

# 如果问题持续，检查日志
docker exec gitlab-v5 gitlab-ctl tail nginx
docker exec gitlab-v5 gitlab-ctl tail gitlab-workhorse
```

### 日志位置

| 组件 | 容器内路径 | 主机路径 |
|-----|-----------|---------|
| Nginx | /var/log/gitlab/nginx/ | /opt/gitlab/v5/logs/nginx/ |
| GitLab Rails | /var/log/gitlab/gitlab-rails/ | /opt/gitlab/v5/logs/gitlab-rails/ |
| Sidekiq | /var/log/gitlab/sidekiq/ | /opt/gitlab/v5/logs/sidekiq/ |
| PostgreSQL | /var/log/gitlab/postgresql/ | /opt/gitlab/v5/logs/postgresql/ |
| Redis | /var/log/gitlab/redis/ | /opt/gitlab/v5/logs/redis/ |
| Gitaly | /var/log/gitlab/gitaly/ | /opt/gitlab/v5/logs/gitaly/ |

### 性能调优建议

1. **根据服务器配置调整参数：**
   - 4GB内存: worker_processes=2, sidekiq_concurrency=10
   - 8GB内存: worker_processes=3, sidekiq_concurrency=20
   - 16GB内存: worker_processes=4, sidekiq_concurrency=30

2. **监控资源使用：**
```bash
# 实时监控
docker stats gitlab-v5

# 查看详细指标
docker exec gitlab-v5 gitlab-ctl status
```

3. **定期维护：**
```bash
# 每周执行
docker exec gitlab-v5 gitlab-rake gitlab:cleanup:repos
docker exec gitlab-v5 gitlab-rake cache:clear

# 每月执行
docker exec gitlab-v5 gitlab-ctl registry-garbage-collect
```

## 下一步

- 配置自动备份
- 设置监控告警
- 配置CI/CD Runner
- 集成外部服务（Jira、Slack等）
- 性能优化和扩展