# GitLab v2 快速访问指南

> 🚀 GitLab已成功部署到 192.168.0.127 服务器

## 🌐 立即访问

**Web界面**: http://192.168.0.127  
**登录账户**: root / GitLabAdmin2024!

## ⏰ 当前状态

**容器状态**: ✅ 运行中  
**初始化**: ⏳ 进行中 (需要10-15分钟)  
**预计可用**: 2025-08-20 17:55

## 🔧 管理命令

```bash
# SSH连接服务器
ssh ubuntu@192.168.0.127

# 进入项目目录
cd ~/gitlab-v2

# 查看状态
docker compose ps

# 查看日志  
docker compose logs -f gitlab

# 管理服务
./manage.sh status    # 状态
./manage.sh restart   # 重启
./manage.sh stop      # 停止
```

## 📋 首次使用步骤

1. **等待初始化** - 耐心等待10-15分钟
2. **访问Web界面** - http://192.168.0.127
3. **登录** - 使用 root / GitLabAdmin2024!
4. **修改密码** - 立即修改为强密码
5. **创建项目** - 开始使用GitLab

## 🔑 SSH Git访问

```bash
# 测试SSH连接
ssh -T git@192.168.0.127 -p 2222

# 克隆项目示例
git clone ssh://git@192.168.0.127:2222/username/project.git
```

## 💡 重要提醒

- ⚠️ **必须修改默认密码**
- 🔑 **添加SSH密钥后才能使用Git SSH**
- 💾 **数据保存在 ~/gitlab-v2/gitlab-data/**
- 🔄 **内存限制2GB，适合小团队使用**

---

**🎉 现在可以开始使用GitLab了！**