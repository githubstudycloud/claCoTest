# SSH 免密登录配置指南

本文档详细说明如何配置SSH免密登录，支持从不同客户端（Windows、Linux、macOS）访问Linux或macOS服务器。

## 目录
- [基本原理](#基本原理)
- [前置要求](#前置要求)
- [客户端配置](#客户端配置)
  - [Windows客户端](#windows客户端)
  - [Linux/macOS客户端](#linuxmacos客户端)
- [服务器配置](#服务器配置)
- [测试连接](#测试连接)
- [故障排除](#故障排除)
- [安全建议](#安全建议)

## 基本原理

SSH免密登录使用公钥加密技术：
1. 在客户端生成一对密钥（公钥和私钥）
2. 将公钥复制到服务器的授权文件中
3. 客户端使用私钥进行身份验证，无需输入密码

## 前置要求

### 服务器端
- Linux 或 macOS 系统
- 已安装并启动 SSH 服务
- 具有用户账户和适当权限

### 客户端
- Windows：Git Bash、WSL、PowerShell 或 PuTTY
- Linux/macOS：内置 SSH 客户端

## 客户端配置

### Windows客户端

#### 方法1：使用Git Bash或WSL
```bash
# 1. 生成SSH密钥对
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 按提示操作：
# - 文件保存位置（默认：~/.ssh/id_rsa）
# - 设置密码（可留空，但建议设置）

# 2. 查看生成的公钥
cat ~/.ssh/id_rsa.pub
```

#### 方法2：使用PowerShell（Windows 10+）
```powershell
# 1. 生成SSH密钥对
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 2. 查看公钥
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub
```

#### 方法3：使用PuTTY
```
1. 下载并安装 PuTTY 套件
2. 运行 PuTTYgen
3. 选择密钥类型：RSA，长度：4096
4. 点击 "Generate" 生成密钥
5. 保存私钥文件（.ppk格式）
6. 复制公钥内容
```

### Linux/macOS客户端

```bash
# 1. 生成SSH密钥对
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 2. 查看生成的公钥
cat ~/.ssh/id_rsa.pub
```

## 服务器配置

### 方法1：使用ssh-copy-id（推荐）
```bash
# 从客户端执行（Linux/macOS/Git Bash）
ssh-copy-id username@server_ip

# 示例
ssh-copy-id ubuntu@[server-ip]
```

### 方法2：手动复制公钥
```bash
# 1. 登录到服务器
ssh username@server_ip

# 2. 创建.ssh目录（如果不存在）
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 3. 将公钥添加到authorized_keys文件
echo "你的公钥内容" >> ~/.ssh/authorized_keys

# 4. 设置正确的权限
chmod 600 ~/.ssh/authorized_keys
```

### 方法3：一条命令完成（从客户端执行）
```bash
# 将本地公钥直接添加到服务器
cat ~/.ssh/id_rsa.pub | ssh username@server_ip "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

## 测试连接

```bash
# 测试SSH连接
ssh username@server_ip

# 第一次连接会提示验证服务器指纹，输入yes确认
# 如果配置正确，应该无需输入密码即可登录
```

## 故障排除

### 常见问题及解决方案

#### 1. 仍然提示输入密码
```bash
# 检查服务器SSH配置
sudo nano /etc/ssh/sshd_config

# 确保以下配置正确：
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication yes  # 可选，建议先保持启用

# 重启SSH服务
sudo systemctl restart sshd
```

#### 2. 权限错误
```bash
# 服务器端检查权限
ls -la ~/.ssh/
# .ssh目录应该是700权限
# authorized_keys文件应该是600权限

# 修正权限
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

#### 3. 连接被拒绝
```bash
# 检查SSH服务状态
sudo systemctl status sshd

# 检查防火墙设置
sudo ufw status

# 检查SSH端口（默认22）
sudo netstat -tlnp | grep :22
```

#### 4. 详细调试
```bash
# 客户端调试模式连接
ssh -v username@server_ip

# 查看服务器SSH日志
sudo tail -f /var/log/auth.log
```

## 高级配置

### SSH配置文件优化
客户端创建 `~/.ssh/config` 文件：
```
Host myserver
    HostName [server-ip]
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
```

使用别名连接：
```bash
ssh myserver
```

### 多密钥管理
```bash
# 为不同服务器生成不同密钥
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_server1 -C "server1_key"
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_server2 -C "server2_key"

# 在config文件中指定不同密钥
Host server1
    HostName 192.168.0.100
    User admin
    IdentityFile ~/.ssh/id_rsa_server1

Host server2
    HostName 192.168.0.200
    User root
    IdentityFile ~/.ssh/id_rsa_server2
```

## 安全建议

### 1. 密钥安全
- 为私钥设置密码保护
- 定期更换密钥对
- 备份密钥到安全位置
- 不要在不安全的网络传输私钥

### 2. 服务器安全加固
```bash
# 禁用密码登录（确保密钥登录正常后）
sudo nano /etc/ssh/sshd_config
PasswordAuthentication no

# 禁用root登录
PermitRootLogin no

# 更改默认SSH端口
Port 2222

# 重启SSH服务
sudo systemctl restart sshd
```

### 3. 防火墙配置
```bash
# Ubuntu/Debian
sudo ufw allow 22/tcp
sudo ufw enable

# CentOS/RHEL
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

### 4. 监控和日志
```bash
# 监控SSH登录
sudo tail -f /var/log/auth.log | grep ssh

# 查看最近登录用户
last

# 查看当前登录用户
who
```

## 示例：完整配置流程

### 场景：Windows客户端连接Ubuntu服务器

```bash
# 1. Windows客户端（Git Bash）生成密钥
ssh-keygen -t rsa -b 4096 -C "work@company.com"

# 2. 复制公钥到服务器
ssh-copy-id ubuntu@[server-ip]

# 3. 测试连接
ssh ubuntu@[server-ip]

# 4. 创建SSH配置文件（可选）
cat > ~/.ssh/config << EOF
Host ubuntu-server
    HostName [server-ip]
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa
EOF

# 5. 使用别名连接
ssh ubuntu-server
```

---

## 总结

SSH免密登录配置完成后，可以大大提高工作效率和安全性。记住定期检查和更新密钥，保持系统安全。

如有问题，请检查：
1. 密钥文件权限
2. SSH服务配置
3. 网络连接和防火墙
4. 系统日志信息

**最后更新：2025-08-19**