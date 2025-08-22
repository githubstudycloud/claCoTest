#!/bin/bash

# 传输GitLab v2配置文件到服务器并执行部署

set -e

SERVER="ubuntu@192.168.0.127"
LOCAL_DIR="docker/gitlab/v2"
REMOTE_TEMP_DIR="/tmp/gitlab-v2-deploy"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

# 传输文件到服务器
transfer_files() {
    log_header "传输文件到服务器"
    
    # 创建远程临时目录
    ssh $SERVER "rm -rf $REMOTE_TEMP_DIR && mkdir -p $REMOTE_TEMP_DIR"
    log_info "创建远程临时目录: $REMOTE_TEMP_DIR"
    
    # 传输配置文件
    scp docker-compose.yml $SERVER:$REMOTE_TEMP_DIR/
    scp gitlab-v2.service $SERVER:$REMOTE_TEMP_DIR/
    scp deploy.sh $SERVER:$REMOTE_TEMP_DIR/
    
    log_info "配置文件传输完成"
    
    # 设置执行权限
    ssh $SERVER "chmod +x $REMOTE_TEMP_DIR/deploy.sh"
    log_info "设置脚本执行权限"
}

# 在服务器上执行部署
execute_deployment() {
    log_header "在服务器上执行部署"
    
    log_info "连接服务器并执行部署脚本..."
    
    ssh $SERVER "cd $REMOTE_TEMP_DIR && ./deploy.sh"
    
    log_info "部署脚本执行完成"
}

# 清理临时文件
cleanup() {
    log_header "清理临时文件"
    
    ssh $SERVER "rm -rf $REMOTE_TEMP_DIR"
    log_info "远程临时文件已清理"
}

# 显示部署结果
show_result() {
    log_header "部署结果检查"
    
    log_info "检查GitLab服务状态..."
    
    # 检查容器状态
    ssh $SERVER "cd /home/ubuntu/gitlab-v2 && docker compose ps" || {
        echo -e "${YELLOW}无法获取容器状态，可能仍在启动中${NC}"
    }
    
    echo ""
    log_info "检查systemd服务状态..."
    ssh $SERVER "sudo systemctl status gitlab-v2 --no-pager" || {
        echo -e "${YELLOW}systemd服务状态检查失败${NC}"
    }
    
    echo ""
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${GREEN}✅ GitLab v2部署完成！${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo -e "${BLUE}访问信息:${NC}"
    echo -e "  🌐 Web地址: http://192.168.0.127"
    echo -e "  👤 用户名: root"
    echo -e "  🔑 密码: GitLabAdmin2024!"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo -e "  • 首次启动需要等待10-15分钟"
    echo -e "  • 已配置开机自启动"
    echo -e "  • 数据保存在 /home/ubuntu/gitlab-v2/ 目录"
    echo -e "  • 内存使用限制为2GB"
}

# 主函数
main() {
    log_header "GitLab v2 远程部署脚本"
    
    # 检查本地文件
    if [[ ! -f "docker-compose.yml" ]]; then
        echo "错误: 找不到 docker-compose.yml"
        exit 1
    fi
    
    if [[ ! -f "deploy.sh" ]]; then
        echo "错误: 找不到 deploy.sh"
        exit 1
    fi
    
    # 执行部署流程
    transfer_files
    execute_deployment
    cleanup
    show_result
    
    echo ""
    echo -e "${GREEN}🎉 远程部署完成！GitLab正在初始化中，请稍候访问 http://192.168.0.127${NC}"
}

# 运行主函数
main "$@"