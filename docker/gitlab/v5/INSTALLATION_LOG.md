# GitLab v5 完整安装日志

## 安装时间线

- **开始时间**: 2024-08-21 22:14:00 CST
- **完成时间**: 2024-08-22 07:53:00 CST
- **总耗时**: 约 9 小时（包含问题排查和优化）

## 安装环境

```bash
# 服务器信息
IP地址: 192.168.0.127
用户名: ubuntu
操作系统: Ubuntu 24.04 LTS
Docker版本: 27.5.1
Docker Compose版本: 1.29.2

# 硬件配置
CPU: 4核
内存: 8GB
存储: 100GB SSD
```

## 详细安装步骤记录

### 步骤1: 初始准备 (22:14)

```bash
# SSH连接到服务器
ssh ubuntu@192.168.0.127

# 创建v5目录
mkdir -p ~/v5
cd ~/v5

# 传输初始配置文件
scp docker-compose.yml ubuntu@192.168.0.127:~/v5/
```

### 步骤2: 创建数据目录 (22:14)

```bash
# 创建GitLab数据目录（需要sudo权限）
echo '2014' | sudo -S mkdir -p /opt/gitlab/v5/{config,logs,data,backups,lfs-objects,uploads,pages,registry}
echo '2014' | sudo -S chown -R ubuntu:ubuntu /opt/gitlab/v5

# 验证目录创建
ls -la /opt/gitlab/v5
drwxr-xr-x 10 ubuntu ubuntu 4096 Aug 21 22:14 .
drwxr-xr-x  3 root   root   4096 Aug 21 22:14 ..
drwxr-xr-x  2 ubuntu ubuntu 4096 Aug 21 22:14 backups
drwxr-xr-x  2 ubuntu ubuntu 4096 Aug 21 22:17 config
drwxr-xr-x  5 ubuntu ubuntu 4096 Aug 21 22:14 data
drwxr-xr-x  2 ubuntu ubuntu 4096 Aug 21 22:14 lfs-objects
drwxr-xr-x  4 ubuntu ubuntu 4096 Aug 21 22:14 logs
drwxr-xr-x  2 ubuntu ubuntu 4096 Aug 21 22:14 pages
drwxr-xr-x  2 ubuntu ubuntu 4096 Aug 21 22:14 registry
drwxr-xr-x  2 ubuntu ubuntu 4096 Aug 21 22:14 uploads
```

### 步骤3: 第一次启动尝试 - 失败 (22:15)

```bash
# 启动服务
cd ~/v5 && docker-compose up -d

# 错误信息
FATAL: Mixlib::Config::UnknownConfigOptionError: Reading unsupported config value gitlab.
FATAL: Mixlib::Config::UnknownConfigOptionError: Reading unsupported config value grafana.
```

**问题原因**: 配置文件包含已废弃的配置项

### 步骤4: 第一次配置修复 (22:17)

修改的配置项：
- 移除 `gitlab['time_zone']` (只保留 `gitlab_rails['time_zone']`)
- 移除 `grafana['enable'] = false`
- 修改 `nginx['gzip'] = "on"` 为 `nginx['gzip_enabled'] = true`

```bash
# 重新传输配置并启动
scp docker-compose.yml ubuntu@192.168.0.127:~/v5/docker-compose.yml
cd ~/v5 && docker-compose down && docker-compose up -d
```

### 步骤5: 第二次启动尝试 - 部分成功 (22:18)

```bash
# 检查容器状态
docker ps | grep gitlab-v5
e6b81e1e37f8   gitlab/gitlab-ce:17.5.1-ce.0   Up 58 seconds (health: starting)

# 检查服务状态
docker exec gitlab-v5 gitlab-ctl status
# 所有服务运行正常
```

### 步骤6: 端口访问问题排查 (22:30-23:00)

```bash
# 测试内部访问
docker exec gitlab-v5 curl -I http://localhost:8080
HTTP/1.0 302 Found  # 内部正常

# 测试外部访问
curl -I http://192.168.0.127:8929
curl: (7) Failed to connect  # 外部失败

# 检查端口监听
docker exec gitlab-v5 netstat -tln
tcp  0  0  127.0.0.1:8080  0.0.0.0:*  LISTEN  # 问题：只监听localhost
tcp  0  0  0.0.0.0:8929    0.0.0.0:*  LISTEN  # nginx监听了错误端口
```

**问题原因**: `external_url` 包含端口号导致nginx配置错误

### 步骤7: 关键配置修复 (23:40)

创建新的配置文件 `docker-compose-fixed.yml`：

关键修改：
```yaml
# 添加必要参数
privileged: true  # 解决权限问题
shm_size: '512m'  # 防止内存不足

# 修正URL配置
external_url 'http://192.168.0.127'  # 不包含端口
nginx['listen_port'] = 80            # 容器内监听80
nginx['listen_https'] = false        # 禁用HTTPS

# 端口映射
ports:
  - "8929:80"   # 外部8929映射到容器内80
```

### 步骤8: 最终成功启动 (23:45)

```bash
# 使用修复后的配置启动
scp docker-compose-fixed.yml ubuntu@192.168.0.127:~/v5/docker-compose.yml
cd ~/v5 && docker-compose down && docker-compose up -d

# 等待初始化
sleep 120

# 验证状态
docker ps | grep gitlab-v5
9ef8ff2d8696   gitlab/gitlab-ce:17.5.1-ce.0   Up 2 minutes (healthy)
```

### 步骤9: 运行gitlab-ctl reconfigure (07:05)

```bash
# 重新配置以应用所有设置
docker exec gitlab-v5 gitlab-ctl reconfigure

# 输出关键信息
Starting Cinc Client Run for gitlab.example.com
Recipe: gitlab::default
Recipe: gitlab::gitlab-rails
Recipe: gitlab::database_migrations
Recipe: gitlab::puma
Recipe: gitlab::sidekiq
Recipe: gitlab::gitlab-workhorse
Recipe: gitlab::nginx
Recipe: registry::enable
...
gitlab Reconfigured!
```

### 步骤10: 功能验证 (07:53)

```bash
# Web界面测试
curl -I http://192.168.0.127:8929
HTTP/1.1 302 Found
Location: http://192.168.0.127:8929/users/sign_in
✅ 成功

# Registry测试
curl -I http://192.168.0.127:5089/v2/
HTTP/1.1 401 Unauthorized
Docker-Distribution-Api-Version: registry/2.0
✅ 成功（401是预期的，需要认证）

# 服务状态确认
docker exec gitlab-v5 gitlab-ctl status
run: gitaly: (pid 327) 517s; run: log: (pid 349) 516s
run: gitlab-kas: (pid 504) 505s; run: log: (pid 524) 502s
run: gitlab-workhorse: (pid 840) 429s; run: log: (pid 604) 484s
run: logrotate: (pid 279) 529s; run: log: (pid 293) 528s
run: nginx: (pid 614) 481s; run: log: (pid 635) 478s
run: postgresql: (pid 361) 511s; run: log: (pid 372) 510s
run: puma: (pid 527) 499s; run: log: (pid 540) 498s
run: redis: (pid 303) 523s; run: log: (pid 318) 520s
run: registry: (pid 852) 428s; run: log: (pid 657) 474s
run: sidekiq: (pid 550) 493s; run: log: (pid 571) 490s
run: sshd: (pid 36) 539s; run: log: (pid 35) 539s
✅ 所有服务正常运行
```

## 遇到的问题和解决方案汇总

### 问题1: 配置项废弃错误

**错误信息**:
```
Removed configurations found in gitlab.rb. Aborting reconfigure.
nginx['gzip'] has been deprecated since 13.12 and was removed in 14.0
```

**解决方案**:
- `nginx['gzip']` → `nginx['gzip_enabled']`
- 移除 `grafana['enable']`
- 移除重复的 `gitlab['time_zone']`

### 问题2: 容器权限问题

**症状**: 某些服务无法写入文件

**解决方案**:
```yaml
privileged: true  # 在docker-compose.yml中添加
```

### 问题3: Nginx端口监听错误

**症状**: 外部无法访问，nginx监听在错误端口

**根本原因**: 当 `external_url` 包含端口时，nginx会监听该端口而不是标准的80端口

**解决方案**:
```yaml
external_url 'http://192.168.0.127'  # 不包含端口
nginx['listen_port'] = 80            # 明确指定容器内端口
```

### 问题4: Redis连接EOF警告

**日志信息**:
```
redis: discarding bad PubSub connection: EOF
keywatcher: pubsub receive: EOF
```

**影响**: 无实际影响，仅为日志噪音

**优化配置**:
```yaml
redis['tcp_keepalive'] = 60
redis['tcp_backlog'] = 511
```

### 问题5: GitLab KAS连接错误

**错误信息**:
```
Failed to get receptive agents
connection reset by peer
```

**解决方案**:
```yaml
gitlab_kas['enable'] = true
gitlab_kas['listen_address'] = '0.0.0.0:8150'
gitlab_rails['gitlab_kas_internal_url'] = 'grpc://localhost:8153'
```

## 最终工作配置总结

### 关键配置要点

1. **必须使用 `privileged: true`**
2. **设置 `shm_size: '512m'` 防止502错误**
3. **`external_url` 不能包含端口号**
4. **明确指定 `nginx['listen_port'] = 80`**
5. **通过Docker端口映射实现外部访问**

### 端口映射策略

| 用途 | 外部端口 | 容器内部 | 说明 |
|-----|---------|---------|------|
| Web | 8929 | 80 | nginx监听80，Docker映射到8929 |
| SSH | 2289 | 22 | SSH服务 |
| Registry | 5089 | 5050 | Docker Registry |

## 性能监控数据

```bash
# 容器资源使用
docker stats gitlab-v5

CONTAINER   CPU %   MEM USAGE / LIMIT   MEM %
gitlab-v5   8.32%   3.421GiB / 4GiB     85.52%

# 磁盘使用
du -sh /opt/gitlab/v5/*
156M    /opt/gitlab/v5/config
892M    /opt/gitlab/v5/data
124M    /opt/gitlab/v5/logs
4.0K    /opt/gitlab/v5/backups
```

## 安装后验证清单

- [x] Docker容器正常运行
- [x] 所有GitLab服务状态正常
- [x] Web界面可访问 (http://192.168.0.127:8929)
- [x] 管理员登录成功 (root/GitLab@V5#2024!)
- [x] Container Registry可访问 (http://192.168.0.127:5089)
- [x] SSH端口可连接 (2289)
- [x] 数据持久化目录正确挂载
- [x] 日志正常输出
- [x] 健康检查通过

## 结论

经过多次配置调整和问题修复，GitLab v5已成功部署在192.168.0.127服务器上。主要的挑战在于理解GitLab的端口配置机制和处理废弃的配置项。最终配置已优化并文档化，可作为未来部署的参考模板。