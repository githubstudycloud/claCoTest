#!/bin/bash

# GitLab Docker 启动脚本
# 用途：启动GitLab服务并进行基本的状态检查

set -e  # 遇到错误时退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查Docker是否运行
check_docker() {
    log_header "检查Docker环境"
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请启动Docker服务"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    log_info "Docker环境检查通过"
    docker --version
    
    # 尝试使用docker compose，如果失败则使用docker-compose
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        log_info "使用Docker Compose v2"
    else
        COMPOSE_CMD="docker-compose"
        log_info "使用Docker Compose v1"
    fi
    $COMPOSE_CMD --version
}

# 检查端口占用
check_ports() {
    log_header "检查端口占用情况"
    
    ports=(8080 2222)
    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            log_warn "端口 $port 已被占用，可能会导致启动失败"
            log_warn "请检查是否有其他服务使用此端口"
        else
            log_info "端口 $port 可用"
        fi
    done
}

# 创建必要的目录
create_directories() {
    log_header "创建GitLab数据目录"
    
    dirs=("config" "logs" "data" "backups")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "创建目录: $dir"
        else
            log_info "目录已存在: $dir"
        fi
    done
    
    # 设置目录权限（Linux/macOS）
    if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" ]]; then
        log_info "设置目录权限..."
        sudo chown -R 998:998 config logs data 2>/dev/null || log_warn "无法设置目录权限，可能需要手动调整"
    fi
}

# 检查配置文件
check_config() {
    log_header "检查配置文件"
    
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml 文件不存在"
        exit 1
    fi
    log_info "docker-compose.yml 文件存在"
    
    if [ ! -f ".env" ]; then
        log_warn ".env 文件不存在，将使用默认配置"
    else
        log_info ".env 文件存在"
        # 检查.env文件中的关键配置
        if grep -q "GITLAB_ROOT_PASSWORD" .env; then
            log_info "发现root密码配置"
        else
            log_warn "未在.env中发现root密码配置，将使用默认密码"
        fi
    fi
}

# 启动GitLab
start_gitlab() {
    log_header "启动GitLab容器"
    
    log_info "拉取GitLab镜像（可能需要几分钟）..."
    $COMPOSE_CMD pull
    
    log_info "启动GitLab容器..."
    $COMPOSE_CMD up -d
    
    if [ $? -eq 0 ]; then
        log_info "GitLab容器启动成功"
    else
        log_error "GitLab容器启动失败"
        exit 1
    fi
}

# 等待GitLab启动完成
wait_for_gitlab() {
    log_header "等待GitLab服务就绪"
    
    log_info "GitLab正在初始化，首次启动可能需要5-10分钟..."
    log_info "请耐心等待..."
    
    # 等待容器启动
    sleep 30
    
    # 检查容器状态
    if ! $COMPOSE_CMD ps | grep -q "Up"; then
        log_error "GitLab容器未正常运行"
        log_info "检查容器状态："
        $COMPOSE_CMD ps
        log_info "检查容器日志："
        $COMPOSE_CMD logs --tail=50 gitlab
        exit 1
    fi
    
    log_info "容器运行正常，等待GitLab服务就绪..."
    
    # 等待HTTP服务响应
    max_attempts=60
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://localhost:8080/-/readiness &> /dev/null; then
            log_info "GitLab服务已就绪！"
            break
        elif curl -sf http://localhost:8080 &> /dev/null; then
            log_info "GitLab Web界面已可访问！"
            break
        else
            printf "."
            sleep 30
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warn "GitLab服务可能仍在初始化中"
        log_warn "请继续等待或检查日志"
    fi
}

# 显示访问信息
show_access_info() {
    log_header "GitLab访问信息"
    
    echo -e "${GREEN}✅ GitLab已启动！${NC}"
    echo ""
    echo -e "${BLUE}Web访问地址:${NC}"
    echo -e "  🌐 http://localhost:8080"
    echo ""
    echo -e "${BLUE}默认登录信息:${NC}"
    echo -e "  👤 用户名: root"
    echo -e "  🔑 密码: ChangeMePlease123!"
    echo -e "      ${YELLOW}(首次登录后请立即修改密码)${NC}"
    echo ""
    echo -e "${BLUE}SSH访问信息:${NC}"
    echo -e "  🔗 SSH地址: ssh://git@localhost:2222"
    echo -e "  📂 克隆地址示例: git clone ssh://git@localhost:2222/username/project.git"
    echo ""
    echo -e "${BLUE}管理命令:${NC}"
    echo -e "  📊 查看状态: $COMPOSE_CMD ps"
    echo -e "  📋 查看日志: $COMPOSE_CMD logs -f gitlab"
    echo -e "  ⏹️  停止服务: $COMPOSE_CMD down"
    echo -e "  🔄 重启服务: $COMPOSE_CMD restart"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo -e "  • 首次启动需要5-10分钟初始化"
    echo -e "  • 如无法访问，请等待更长时间或检查防火墙设置"
    echo -e "  • 数据保存在 ./data 目录，请注意备份"
}

# 主函数
main() {
    log_header "GitLab Docker 启动脚本"
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    # 执行检查和启动流程
    check_docker
    check_ports
    create_directories
    check_config
    start_gitlab
    wait_for_gitlab
    show_access_info
    
    log_info "启动脚本执行完成"
    echo ""
    echo -e "${GREEN}🎉 GitLab已成功启动！请打开浏览器访问 http://localhost:8080${NC}"
}

# 运行主函数
main "$@"