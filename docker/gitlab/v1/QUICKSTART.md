# GitLab Docker 快速开始

> 🚀 一分钟快速部署GitLab CE

## 🏃‍♂️ 快速启动

```bash
# 1. 进入目录
cd docker/gitlab/v1

# 2. 检查环境（推荐）
./check-env.sh

# 3. 一键启动
./start.sh

# 4. 测试功能
./test.sh
```

## 🌐 访问GitLab

**Web界面**: http://localhost:8080  
**默认账户**: root / ChangeMePlease123!

## 🛠️ 常用命令

```bash
./manage.sh status    # 查看状态
./manage.sh logs      # 查看日志  
./manage.sh stop      # 停止服务
./manage.sh restart   # 重启服务
./manage.sh backup    # 创建备份
```

## ⚠️ 重要提醒

1. **修改默认密码** - 首次登录后立即修改
2. **等待初始化** - 首次启动需5-10分钟
3. **配置SSH密钥** - 用于Git操作
4. **定期备份** - 保护重要数据

## 📚 完整文档

- 详细安装指南: [INSTALLATION.md](INSTALLATION.md)
- 用户使用手册: [README.md](README.md)

---

**🎉 现在可以开始使用GitLab了！**