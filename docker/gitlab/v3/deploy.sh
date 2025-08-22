#!/bin/bash

# GitLab v3 完整功能部署脚本
# 基于v2优化，提供完整功能但控制内存使用

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
    
    # 检查内存
    if command -v free &> /dev/null; then
        total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
        available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7/1024}')
        
        log_info "系统内存: ${total_mem}GB 总计, ${available_mem}GB 可用"
        
        if (( available_mem < 3 )); then
            log_error "可用内存不足3GB，GitLab v3可能无法正常运行"
            log_warn "建议: 关闭其他应用程序或考虑使用v2版本"
        else
            log_info "内存充足，支持完整功能"
        fi
    fi
}

# 创建项目目录
setup_directories() {
    log_header "创建项目目录"
    
    PROJECT_DIR="$HOME/gitlab-v3"
    
    # 创建主目录
    if [[ ! -d "$PROJECT_DIR" ]]; then
        mkdir -p "$PROJECT_DIR"
        log_info "创建项目目录: $PROJECT_DIR"
    else
        log_info "项目目录已存在: $PROJECT_DIR"
    fi
    
    # 创建所有必要的数据目录
    directories=(
        "gitlab-config"
        "gitlab-logs" 
        "gitlab-data"
        "ssl"
        "redis-data"
        "postgresql-data"
        "backups"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$PROJECT_DIR/$dir"
        log_info "创建目录: $dir"
    done
    
    # 设置目录权限
    chmod -R 755 "$PROJECT_DIR"
    log_info "目录权限设置完成"
}

# 创建SSL证书 (自签名用于测试)
create_ssl_certificates() {
    log_header "创建SSL证书"
    
    PROJECT_DIR="$HOME/gitlab-v3"
    SSL_DIR="$PROJECT_DIR/ssl"
    
    if [[ ! -f "$SSL_DIR/gitlab.crt" ]]; then
        log_info "创建自签名SSL证书..."
        
        # 创建私钥
        openssl genrsa -out "$SSL_DIR/gitlab.key" 2048
        
        # 创建证书签名请求
        openssl req -new -key "$SSL_DIR/gitlab.key" -out "$SSL_DIR/gitlab.csr" \
            -subj "/C=CN/ST=Shanghai/L=Shanghai/O=GitLab/OU=IT/CN=192.168.0.127"
        
        # 创建自签名证书
        openssl x509 -req -days 365 -in "$SSL_DIR/gitlab.csr" \
            -signkey "$SSL_DIR/gitlab.key" -out "$SSL_DIR/gitlab.crt"
        
        # 设置权限
        chmod 600 "$SSL_DIR/gitlab.key"
        chmod 644 "$SSL_DIR/gitlab.crt"
        
        log_info "SSL证书创建完成"
    else
        log_info "SSL证书已存在"
    fi
}

# 复制配置文件
deploy_config() {
    log_header "部署配置文件"
    
    PROJECT_DIR="$HOME/gitlab-v3"
    
    # 复制docker-compose.yml
    if [[ -f "docker-compose.yml" ]]; then
        # 替换占位符
        sed 's/\[server-ip\]/192.168.0.127/g' docker-compose.yml > "$PROJECT_DIR/docker-compose.yml"
        log_info "已复制并配置 docker-compose.yml"
    else
        log_error "docker-compose.yml 文件不存在"
        exit 1
    fi
    
    # 创建增强的管理脚本
    cat > "$PROJECT_DIR/manage.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    echo -e "${BLUE}GitLab v3 管理脚本${NC}"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "基本命令:"
    echo "  start           - 启动GitLab服务"
    echo "  stop            - 停止GitLab服务"
    echo "  restart         - 重启GitLab服务"
    echo "  status          - 查看服务状态"
    echo "  logs            - 查看实时日志"
    echo "  logs-tail       - 查看最近日志"
    echo ""
    echo "扩展命令:"
    echo "  backup          - 创建完整备份"
    echo "  restore         - 恢复备份"
    echo "  update          - 更新GitLab版本"
    echo "  shell           - 进入容器shell"
    echo "  cleanup         - 清理系统"
    echo ""
    echo "监控命令:"
    echo "  health          - 健康检查"
    echo "  metrics         - 显示监控指标"
    echo "  resources       - 资源使用情况"
    echo ""
    echo "扩展功能:"
    echo "  enable-redis    - 启用独立Redis"
    echo "  enable-db       - 启用独立数据库"
    echo "  disable-extras  - 禁用扩展服务"
}

case "${1:-help}" in
    start)
        echo -e "${GREEN}启动GitLab v3...${NC}"
        docker compose up -d
        echo "等待服务启动..."
        sleep 10
        docker compose ps
        ;;
    stop)
        echo -e "${YELLOW}停止GitLab v3...${NC}"
        docker compose down
        ;;
    restart)
        echo -e "${YELLOW}重启GitLab v3...${NC}"
        docker compose restart
        ;;
    status)
        echo -e "${BLUE}GitLab v3 状态:${NC}"
        docker compose ps
        echo ""
        echo -e "${BLUE}容器健康状态:${NC}"
        docker compose exec gitlab gitlab-ctl status 2>/dev/null || echo "GitLab仍在启动中..."
        ;;
    logs)
        echo -e "${BLUE}GitLab v3 实时日志:${NC}"
        docker compose logs -f gitlab
        ;;
    logs-tail)
        echo -e "${BLUE}GitLab v3 最近日志:${NC}"
        docker compose logs --tail=50 gitlab
        ;;
    backup)
        echo -e "${GREEN}创建GitLab备份...${NC}"
        mkdir -p ./backups
        backup_name="gitlab-v3-backup-$(date +%Y%m%d_%H%M%S)"
        
        # GitLab应用备份
        docker compose exec gitlab gitlab-backup create BACKUP=$backup_name
        
        # 配置文件备份
        tar -czf "./backups/${backup_name}_config.tar.gz" gitlab-config/ ssl/
        
        echo "备份完成: $backup_name"
        ;;
    restore)
        echo "可用备份:"
        ls -la ./backups/ 2>/dev/null || echo "没有找到备份文件"
        ;;
    shell)
        echo -e "${BLUE}进入GitLab容器...${NC}"
        docker compose exec gitlab bash
        ;;
    health)
        echo -e "${BLUE}GitLab健康检查:${NC}"
        curl -f http://localhost:8080/-/health 2>/dev/null && echo "✅ 健康" || echo "❌ 不健康"
        curl -f http://localhost:8080/-/readiness 2>/dev/null && echo "✅ 就绪" || echo "❌ 未就绪"
        ;;
    metrics)
        echo -e "${BLUE}监控指标:${NC}"
        echo "Prometheus: http://192.168.0.127:9090"
        echo "Node Exporter: http://192.168.0.127:9100"
        ;;
    resources)
        echo -e "${BLUE}资源使用情况:${NC}"
        docker stats --no-stream gitlab-v3
        ;;
    enable-redis)
        echo -e "${GREEN}启用独立Redis服务...${NC}"
        docker compose --profile external-redis up -d gitlab-redis
        ;;
    enable-db)
        echo -e "${GREEN}启用独立PostgreSQL服务...${NC}"
        docker compose --profile external-db up -d gitlab-postgresql
        ;;
    disable-extras)
        echo -e "${YELLOW}禁用扩展服务...${NC}"
        docker compose stop gitlab-redis gitlab-postgresql 2>/dev/null || true
        ;;
    update)
        echo -e "${GREEN}更新GitLab镜像...${NC}"
        docker compose pull
        docker compose up -d --force-recreate
        ;;
    cleanup)
        echo -e "${YELLOW}清理系统...${NC}"
        docker system prune -f
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "未知命令: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
EOF
    
    chmod +x "$PROJECT_DIR/manage.sh"
    log_info "已创建增强管理脚本 manage.sh"
    
    # 创建快速配置脚本
    cat > "$PROJECT_DIR/quick-config.sh" << 'EOF'
#!/bin/bash
# GitLab v3 快速配置脚本

cd "$(dirname "$0")"

echo "GitLab v3 快速配置助手"
echo "======================="
echo ""

echo "1. 检查服务状态..."
if docker compose ps | grep -q "Up"; then
    echo "✅ GitLab服务运行中"
    
    echo ""
    echo "2. 等待GitLab完全启动 (这可能需要几分钟)..."
    
    # 等待GitLab就绪
    attempts=0
    max_attempts=30
    while [ $attempts -lt $max_attempts ]; do
        if curl -sf http://localhost:8080/-/readiness >/dev/null 2>&1; then
            echo "✅ GitLab已就绪！"
            break
        fi
        echo "等待中... ($((attempts + 1))/$max_attempts)"
        sleep 30
        ((attempts++))
    done
    
    echo ""
    echo "🎉 GitLab v3 配置完成！"
    echo ""
    echo "访问信息:"
    echo "  Web界面: http://192.168.0.127:8080"
    echo "  用户名: root"
    echo "  密码: GitLabFull2024!"
    echo ""
    echo "高级功能:"
    echo "  Container Registry: http://192.168.0.127:5050"
    echo "  SSH Git: git@192.168.0.127:3333"
    echo ""
    echo "下一步:"
    echo "  1. 访问Web界面并修改默认密码"
    echo "  2. 配置SSH密钥"
    echo "  3. 创建第一个项目"
    echo "  4. 探索GitLab Pages和CI/CD功能"
    
else
    echo "❌ GitLab服务未运行"
    echo "请先运行: ./manage.sh start"
fi
EOF
    
    chmod +x "$PROJECT_DIR/quick-config.sh"
    log_info "已创建快速配置脚本"
}

# 启动GitLab
start_gitlab() {
    log_header "启动GitLab v3服务"
    
    PROJECT_DIR="$HOME/gitlab-v3"
    cd "$PROJECT_DIR"
    
    log_info "拉取GitLab镜像 (这可能需要几分钟)..."
    $COMPOSE_CMD pull gitlab
    
    log_info "启动GitLab v3容器..."
    $COMPOSE_CMD up -d gitlab
    
    if [[ $? -eq 0 ]]; then
        log_info "GitLab v3容器启动成功"
    else
        log_error "GitLab v3容器启动失败"
        exit 1
    fi
}

# 等待服务就绪
wait_for_gitlab() {
    log_header "等待GitLab服务就绪"
    
    log_info "GitLab v3正在初始化，首次启动需要10-20分钟..."
    log_info "这比v2时间长，因为启用了更多功能"
    
    PROJECT_DIR="$HOME/gitlab-v3"
    cd "$PROJECT_DIR"
    
    # 检查容器状态
    sleep 30
    if ! $COMPOSE_CMD ps | grep -q "Up"; then
        log_error "GitLab容器未正常运行"
        $COMPOSE_CMD ps
        $COMPOSE_CMD logs --tail=50 gitlab
        return 1
    fi
    
    log_info "容器运行正常"
    log_warn "GitLab仍在初始化中，请稍后访问Web界面"
    log_info "可使用 ./quick-config.sh 检查启动状态"
}

# 显示部署信息
show_deployment_info() {
    log_header "GitLab v3 部署完成"
    
    echo -e "${GREEN}✅ GitLab v3已成功部署到用户目录！${NC}"
    echo ""
    echo -e "${BLUE}🌐 访问信息:${NC}"
    echo -e "  Web界面: http://192.168.0.127:8080"
    echo -e "  用户名: root"
    echo -e "  密码: GitLabFull2024!"
    echo ""
    echo -e "${BLUE}🚀 完整功能:${NC}"
    echo -e "  Container Registry: http://192.168.0.127:5050"
    echo -e "  SSH Git: git@192.168.0.127:3333"
    echo -e "  GitLab Pages: http://192.168.0.127:8090"
    echo -e "  监控指标: 内置Prometheus"
    echo ""
    echo -e "${BLUE}🛠️ 管理命令:${NC}"
    echo -e "  基本管理: ~/gitlab-v3/manage.sh [start|stop|status|logs]"
    echo -e "  扩展功能: ~/gitlab-v3/manage.sh [backup|health|metrics]"
    echo -e "  快速配置: ~/gitlab-v3/quick-config.sh"
    echo ""
    echo -e "${BLUE}📁 项目目录:${NC}"
    echo -e "  📁 $HOME/gitlab-v3/"
    echo -e "    ├── docker-compose.yml      # 主配置"
    echo -e "    ├── manage.sh               # 管理脚本"
    echo -e "    ├── quick-config.sh         # 快速配置"
    echo -e "    ├── gitlab-config/          # GitLab配置"
    echo -e "    ├── gitlab-data/            # GitLab数据"
    echo -e "    ├── gitlab-logs/            # GitLab日志"
    echo -e "    ├── ssl/                    # SSL证书"
    echo -e "    └── backups/                # 备份目录"
    echo ""
    echo -e "${YELLOW}⚠️ 注意事项:${NC}"
    echo -e "  • 内存使用最高3GB (比v2多1GB)"
    echo -e "  • 首次启动需要15-20分钟"
    echo -e "  • 包含完整功能: Pages、Registry、监控"
    echo -e "  • 建议定期备份数据目录"
    echo -e "  • 可选启用独立Redis/PostgreSQL服务"
}

# 主函数
main() {
    log_header "GitLab v3 完整功能部署脚本"
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    # 执行部署流程
    check_environment
    setup_directories
    create_ssl_certificates
    deploy_config
    start_gitlab
    wait_for_gitlab
    show_deployment_info
    
    log_info "部署脚本执行完成"
    echo ""
    echo -e "${GREEN}🎉 GitLab v3已成功部署！运行 ./quick-config.sh 检查状态${NC}"
}

# 运行主函数
main "$@"