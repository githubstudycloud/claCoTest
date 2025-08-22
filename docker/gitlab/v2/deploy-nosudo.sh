#!/bin/bash

# GitLab v2 无sudo部署脚本
# 适用于非root用户，避免sudo密码问题

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

# 检查环境
check_environment() {
    log_header "检查部署环境"
    
    # 检查是否为目标服务器
    current_ip=$(hostname -I | awk '{print $1}')
    if [[ "$current_ip" == "192.168.0.127" ]]; then
        log_info "确认在目标服务器上运行 (192.168.0.127)"
    else
        log_warn "当前IP: $current_ip"
    fi
    
    log_info "当前用户: $(whoami)"
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行"
        exit 1
    fi
    
    # 检查Docker Compose
    if docker compose version &> /dev/null; then
        log_info "Docker Compose v2 可用"
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        log_info "Docker Compose v1 可用"
        COMPOSE_CMD="docker-compose"
    else
        log_error "Docker Compose未安装"
        exit 1
    fi
}

# 创建项目目录（无sudo版本）
setup_directories() {
    log_header "创建项目目录"
    
    PROJECT_DIR="$HOME/gitlab-v2"
    
    # 创建主目录
    if [[ ! -d "$PROJECT_DIR" ]]; then
        mkdir -p "$PROJECT_DIR"
        log_info "创建项目目录: $PROJECT_DIR"
    else
        log_info "项目目录已存在: $PROJECT_DIR"
    fi
    
    # 创建数据目录
    mkdir -p "$PROJECT_DIR"/{gitlab-config,gitlab-logs,gitlab-data}
    log_info "创建数据目录: config, logs, data"
    
    # 设置目录权限
    chmod -R 755 "$PROJECT_DIR"
    log_info "目录权限设置完成"
}

# 复制配置文件
deploy_config() {
    log_header "部署配置文件"
    
    PROJECT_DIR="$HOME/gitlab-v2"
    
    # 复制docker-compose.yml
    if [[ -f "docker-compose.yml" ]]; then
        # 替换占位符
        sed 's/\[server-ip\]/192.168.0.127/g' docker-compose.yml > "$PROJECT_DIR/docker-compose.yml"
        log_info "已复制并配置 docker-compose.yml"
    else
        log_error "docker-compose.yml 文件不存在"
        exit 1
    fi
    
    # 创建简单的管理脚本
    cat > "$PROJECT_DIR/manage.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

case "${1:-help}" in
    start)
        echo "启动GitLab..."
        docker compose up -d
        ;;
    stop)
        echo "停止GitLab..."
        docker compose down
        ;;
    restart)
        echo "重启GitLab..."
        docker compose restart
        ;;
    status)
        echo "GitLab状态:"
        docker compose ps
        ;;
    logs)
        echo "GitLab日志:"
        docker compose logs -f gitlab
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs}"
        ;;
esac
EOF
    
    chmod +x "$PROJECT_DIR/manage.sh"
    log_info "已创建管理脚本 manage.sh"
}

# 启动GitLab
start_gitlab() {
    log_header "启动GitLab服务"
    
    PROJECT_DIR="$HOME/gitlab-v2"
    cd "$PROJECT_DIR"
    
    log_info "拉取GitLab镜像..."
    $COMPOSE_CMD pull
    
    log_info "启动GitLab容器..."
    $COMPOSE_CMD up -d
    
    if [[ $? -eq 0 ]]; then
        log_info "GitLab容器启动成功"
    else
        log_error "GitLab容器启动失败"
        exit 1
    fi
}

# 等待服务就绪（简化版）
wait_for_gitlab() {
    log_header "等待GitLab服务就绪"
    
    log_info "GitLab正在初始化，首次启动需要10-15分钟..."
    
    PROJECT_DIR="$HOME/gitlab-v2"
    cd "$PROJECT_DIR"
    
    # 检查容器状态
    sleep 30
    if ! $COMPOSE_CMD ps | grep -q "Up"; then
        log_error "GitLab容器未正常运行"
        $COMPOSE_CMD ps
        return 1
    fi
    
    log_info "容器运行正常"
    log_warn "GitLab仍在初始化中，请稍后访问Web界面"
}

# 显示部署信息
show_deployment_info() {
    log_header "GitLab v2 部署完成"
    
    echo -e "${GREEN}✅ GitLab已成功部署到用户目录！${NC}"
    echo ""
    echo -e "${BLUE}访问信息:${NC}"
    echo -e "  🌐 Web地址: http://192.168.0.127"
    echo -e "  👤 用户名: root"
    echo -e "  🔑 密码: GitLabAdmin2024!"
    echo ""
    echo -e "${BLUE}管理命令:${NC}"
    echo -e "  📊 查看状态: ~/gitlab-v2/manage.sh status"
    echo -e "  🔄 重启服务: ~/gitlab-v2/manage.sh restart"
    echo -e "  ⏹️  停止服务: ~/gitlab-v2/manage.sh stop"
    echo -e "  📋 查看日志: ~/gitlab-v2/manage.sh logs"
    echo ""
    echo -e "${BLUE}项目目录:${NC}"
    echo -e "  📁 $HOME/gitlab-v2/"
    echo -e "    ├── docker-compose.yml"
    echo -e "    ├── manage.sh           # 管理脚本"
    echo -e "    ├── gitlab-config/      # GitLab配置"
    echo -e "    ├── gitlab-data/        # GitLab数据"
    echo -e "    └── gitlab-logs/        # GitLab日志"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo -e "  • 未配置开机自启动（需要sudo权限）"
    echo -e "  • 首次启动需要等待10-15分钟"
    echo -e "  • 数据已持久化到用户目录"
    echo -e "  • 内存使用限制为2GB"
    echo -e "  • 请定期备份 gitlab-data 目录"
}

# 主函数
main() {
    log_header "GitLab v2 用户目录部署脚本"
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    # 执行部署流程
    check_environment
    setup_directories
    deploy_config
    start_gitlab
    wait_for_gitlab
    show_deployment_info
    
    log_info "部署脚本执行完成"
    echo ""
    echo -e "${GREEN}🎉 GitLab v2已成功部署！请等待初始化完成后访问 http://192.168.0.127${NC}"
}

# 运行主函数
main "$@"