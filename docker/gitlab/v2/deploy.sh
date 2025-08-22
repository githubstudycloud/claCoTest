#!/bin/bash

# GitLab v2 部署脚本
# 用于在192.168.0.127服务器上部署GitLab

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

# 检查是否在服务器上运行
check_environment() {
    log_header "检查部署环境"
    
    # 检查是否为目标服务器
    current_ip=$(hostname -I | awk '{print $1}')
    if [[ "$current_ip" == "192.168.0.127" ]]; then
        log_info "确认在目标服务器上运行 (192.168.0.127)"
    else
        log_warn "当前IP: $current_ip，非目标服务器192.168.0.127"
        read -p "是否继续部署? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "取消部署"
            exit 0
        fi
    fi
    
    # 检查用户权限
    if [[ $EUID -eq 0 ]]; then
        log_warn "当前以root用户运行"
    else
        log_info "当前用户: $(whoami)"
    fi
    
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

# 创建项目目录
setup_directories() {
    log_header "创建项目目录"
    
    PROJECT_DIR="/home/ubuntu/gitlab-v2"
    
    # 创建主目录
    if [[ ! -d "$PROJECT_DIR" ]]; then
        mkdir -p "$PROJECT_DIR"
        log_info "创建项目目录: $PROJECT_DIR"
    else
        log_info "项目目录已存在: $PROJECT_DIR"
    fi
    
    # 创建数据目录
    sudo mkdir -p "$PROJECT_DIR"/{gitlab-config,gitlab-logs,gitlab-data}
    log_info "创建数据目录: config, logs, data"
    
    # 设置目录权限
    sudo chown -R ubuntu:ubuntu "$PROJECT_DIR"
    sudo chmod -R 755 "$PROJECT_DIR"
    
    # 设置GitLab数据目录权限
    sudo chown -R 998:998 "$PROJECT_DIR"/gitlab-{config,logs,data} 2>/dev/null || {
        log_warn "无法设置GitLab用户权限，启动时可能会自动修正"
    }
    
    log_info "目录权限设置完成"
}

# 复制配置文件
deploy_config() {
    log_header "部署配置文件"
    
    PROJECT_DIR="/home/ubuntu/gitlab-v2"
    
    # 复制docker-compose.yml
    if [[ -f "docker-compose.yml" ]]; then
        # 替换占位符
        sed 's/\[server-ip\]/192.168.0.127/g' docker-compose.yml > "$PROJECT_DIR/docker-compose.yml"
        log_info "已复制并配置 docker-compose.yml"
    else
        log_error "docker-compose.yml 文件不存在"
        exit 1
    fi
    
    # 复制systemd服务文件
    if [[ -f "gitlab-v2.service" ]]; then
        sudo cp gitlab-v2.service /etc/systemd/system/
        log_info "已复制systemd服务文件"
    else
        log_warn "gitlab-v2.service 文件不存在，跳过systemd配置"
    fi
}

# 配置systemd服务
setup_systemd() {
    log_header "配置开机自启动"
    
    if [[ -f "/etc/systemd/system/gitlab-v2.service" ]]; then
        # 重载systemd配置
        sudo systemctl daemon-reload
        log_info "重载systemd配置"
        
        # 启用服务
        sudo systemctl enable gitlab-v2.service
        log_info "启用gitlab-v2服务开机自启动"
        
        # 检查服务状态
        if sudo systemctl is-enabled gitlab-v2.service &> /dev/null; then
            log_info "开机自启动配置成功"
        else
            log_error "开机自启动配置失败"
        fi
    else
        log_warn "systemd服务文件不存在，跳过开机自启动配置"
    fi
}

# 启动GitLab
start_gitlab() {
    log_header "启动GitLab服务"
    
    PROJECT_DIR="/home/ubuntu/gitlab-v2"
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

# 等待服务就绪
wait_for_gitlab() {
    log_header "等待GitLab服务就绪"
    
    log_info "GitLab正在初始化，首次启动需要5-15分钟..."
    log_info "请耐心等待..."
    
    # 等待容器启动
    sleep 30
    
    # 检查容器状态
    cd "/home/ubuntu/gitlab-v2"
    if ! $COMPOSE_CMD ps | grep -q "Up"; then
        log_error "GitLab容器未正常运行"
        log_info "检查容器状态："
        $COMPOSE_CMD ps
        log_info "检查容器日志："
        $COMPOSE_CMD logs --tail=50 gitlab
        return 1
    fi
    
    log_info "容器运行正常，等待GitLab服务就绪..."
    
    # 等待HTTP服务响应
    max_attempts=30
    attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sf http://192.168.0.127/-/readiness &> /dev/null; then
            log_info "GitLab服务已就绪！"
            return 0
        elif curl -sf http://192.168.0.127 &> /dev/null; then
            log_info "GitLab Web界面已可访问！"
            return 0
        else
            printf "."
            sleep 30
            ((attempt++))
        fi
    done
    
    log_warn "GitLab服务可能仍在初始化中"
    log_warn "请继续等待或检查日志"
    return 1
}

# 显示部署信息
show_deployment_info() {
    log_header "GitLab v2 部署完成"
    
    echo -e "${GREEN}✅ GitLab已成功部署到服务器！${NC}"
    echo ""
    echo -e "${BLUE}访问信息:${NC}"
    echo -e "  🌐 Web地址: http://192.168.0.127"
    echo -e "  👤 用户名: root"
    echo -e "  🔑 密码: GitLabAdmin2024!"
    echo -e "      ${YELLOW}(首次登录后请立即修改密码)${NC}"
    echo ""
    echo -e "${BLUE}SSH Git访问:${NC}"
    echo -e "  🔗 SSH地址: git@192.168.0.127"
    echo -e "  📂 克隆示例: git clone git@192.168.0.127:username/project.git"
    echo ""
    echo -e "${BLUE}服务管理命令:${NC}"
    echo -e "  📊 查看状态: sudo systemctl status gitlab-v2"
    echo -e "  🔄 重启服务: sudo systemctl restart gitlab-v2"
    echo -e "  ⏹️  停止服务: sudo systemctl stop gitlab-v2"
    echo -e "  📋 查看日志: docker compose logs -f gitlab"
    echo ""
    echo -e "${BLUE}项目目录:${NC}"
    echo -e "  📁 /home/ubuntu/gitlab-v2/"
    echo -e "    ├── docker-compose.yml"
    echo -e "    ├── gitlab-config/      # GitLab配置"
    echo -e "    ├── gitlab-data/        # GitLab数据"
    echo -e "    └── gitlab-logs/        # GitLab日志"
    echo ""
    echo -e "${YELLOW}重要提醒:${NC}"
    echo -e "  • 已配置开机自启动"
    echo -e "  • 首次启动需要等待10-15分钟"
    echo -e "  • 数据已持久化到外挂目录"
    echo -e "  • 内存使用限制为2GB"
    echo -e "  • 请定期备份 gitlab-data 目录"
}

# 主函数
main() {
    log_header "GitLab v2 服务器部署脚本"
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    # 执行部署流程
    check_environment
    setup_directories
    deploy_config
    setup_systemd
    start_gitlab
    wait_for_gitlab
    show_deployment_info
    
    log_info "部署脚本执行完成"
    echo ""
    echo -e "${GREEN}🎉 GitLab v2已成功部署！请访问 http://192.168.0.127${NC}"
}

# 运行主函数
main "$@"