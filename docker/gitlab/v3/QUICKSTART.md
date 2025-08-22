# GitLab v3 快速使用指南

> 🎯 **v3.5 最新版本** - 6GB内存配置，完整功能启用，企业级DevOps平台

## 🚀 立即使用

### 访问地址
**Web界面**: http://192.168.0.127:8080  
**默认账户**: root / GitLabFull2024!

### v3.5 最新状态 ⏰
- **容器**: ✅ 稳定运行 (6GB内存配置)
- **初始化**: ⏳ 进行中 (10-15分钟)
- **端口**: ✅ 8080 (HTTP), 3333 (SSH), 5050 (Registry), 8092 (Pages)
- **功能**: ✅ 用户注册、邮件、Pages、监控全部启用

## 🔧 管理命令

```bash
# SSH连接服务器
ssh ubuntu@192.168.0.127

# 进入项目目录
cd ~/gitlab-v3

# 基本管理
./manage.sh status    # 查看状态
./manage.sh logs      # 查看日志  
./manage.sh health    # 健康检查
./manage.sh info      # 访问信息
./manage.sh backup    # 创建备份
```

## 🌟 完整功能特性

| 功能 | v2 | v3 | 说明 |
|------|----|----|------|
| **Git仓库** | ✅ | ✅ | 代码管理 |
| **CI/CD** | ✅ | ✅ | 自动化流水线 |
| **Container Registry** | ❌ | ✅ | Docker镜像仓库 |
| **GitLab Pages** | ❌ | ✅ | 静态网站托管 |
| **Git LFS** | 基础 | ✅ | 大文件支持 |
| **监控系统** | ❌ | ✅ | Prometheus监控 |
| **SSL支持** | 基础 | ✅ | 自签名证书 |
| **内存使用** | 2GB | 6GB | 性能大幅提升 |
| **用户注册** | ❓ | ✅ | 支持新用户注册 |
| **邮件服务** | ❌ | ✅ | 完整邮件功能 |

## 🐳 Container Registry

```bash
# 登录Registry
docker login 192.168.0.127:5050

# 推送镜像
docker tag myapp:latest 192.168.0.127:5050/group/project/myapp:latest
docker push 192.168.0.127:5050/group/project/myapp:latest

# 拉取镜像
docker pull 192.168.0.127:5050/group/project/myapp:latest
```

## 🔑 SSH Git访问

```bash
# 测试连接
ssh -T git@192.168.0.127 -p 3333

# 克隆仓库
git clone ssh://git@192.168.0.127:3333/username/project.git

# 添加远程仓库
git remote add origin ssh://git@192.168.0.127:3333/username/project.git
```

## 📋 首次使用清单

### 必须操作 🔒
1. **等待初始化** (15-20分钟)
2. **修改默认密码** - 访问Web界面立即修改
3. **添加SSH密钥** - Settings → SSH Keys
4. **创建第一个项目** - New Project

### 推荐操作 🌟
5. **配置Registry** - 启用容器镜像仓库
6. **设置Pages** - 部署静态网站
7. **创建CI/CD** - 添加 `.gitlab-ci.yml`
8. **配置监控** - 查看内置指标

## 🎯 高级功能

### GitLab Pages
1. 在项目中创建 `public/` 目录
2. 配置 `.gitlab-ci.yml` 部署任务
3. 推送代码自动部署
4. 访问: http://192.168.0.127:8092 (新端口)

### CI/CD流水线
```yaml
# .gitlab-ci.yml 示例
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

## 📊 监控指标

GitLab v3内置监控功能:
- **Prometheus**: 指标收集
- **Node Exporter**: 系统监控
- **PostgreSQL Exporter**: 数据库监控
- **Redis Exporter**: 缓存监控

## ⚡ 性能对比 (v3.5更新)

| 指标 | v2 (简化版) | v3.5 (完整版) |
|------|-------------|---------------|
| 启动时间 | 10-15分钟 | 10-15分钟 |
| 内存使用 | ~1.5GB | ~4GB |
| CPU使用 | 2核 | 4核 |
| 功能数量 | 基础功能 | 全功能企业级 |
| 适用团队 | 5-20人 | 10-100人 |
| 并发性能 | 标准 | 高性能 |

## 🔄 版本切换

如果需要回到v2版本:
```bash
# 停止v3
cd ~/gitlab-v3
./manage.sh stop

# 启动v2
cd ~/gitlab-v2  
./manage.sh start
```

## 📞 获取帮助

### 故障排除
```bash
# 查看详细状态
./manage.sh status

# 查看启动日志
./manage.sh logs

# 健康检查
./manage.sh health

# 重启服务
./manage.sh restart
```

### v3.5 常见问题
- **无法访问**: 等待Puma服务初始化完成 (10-15分钟)
- **内存不足**: 需要至少6GB可用内存，否则使用v2
- **端口冲突**: 检查8080/3333/5050/8092端口占用
- **Pages无法访问**: 使用新端口8092而非8090

---

## 🎉 开始使用

**现在就可以开始体验GitLab v3的强大功能！**

1. 🌐 **访问**: http://192.168.0.127:8080
2. 🔐 **登录**: root / GitLabFull2024!
3. 🚀 **开始**: 创建你的第一个项目

**完整功能等你探索！**