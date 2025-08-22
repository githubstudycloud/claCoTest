#!/bin/bash

# GitLab v5 自动化部署脚本
# 版本: 2.0
# 更新时间: 2024-08-22
# 用于在192.168.0.127服务器上部署完整的GitLab CE服务

set -e

# ==================== 配置部分 ====================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 系统配置
GITLAB_HOME="/opt/gitlab/v5"
DOCKER_COMPOSE_FILE="docker-compose.yml"
SERVER_IP="192.168.0.127"
CONTAINER_NAME="gitlab-v5"

# GitLab配置
GITLAB_HTTP_PORT="8929"
GITLAB_SSH_PORT="2289"
GITLAB_REGISTRY_PORT="5089"
INITIAL_PASSWORD="GitLab@V5#2024!"

# ==================== 函数定义 ====================

# 打印信息函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_title() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查Docker和Docker Compose
check_prerequisites() {
    print_title "系统依赖检查"
    
    local errors=0
    
    # 检查Docker
    if command_exists docker; then
        print_info "Docker版本: $(docker --version)"
    else
        print_error "Docker未安装，请先安装Docker"
        errors=$((errors + 1))
    fi
    
    # 检查Docker Compose
    if command_exists docker-compose; then
        print_info "Docker Compose版本: $(docker-compose --version)"
    else
        print_error "Docker Compose未安装，请先安装Docker Compose"
        errors=$((errors + 1))
    fi
    
    # 检查sudo权限
    if [ "$EUID" -ne 0 ]; then
        if ! sudo -n true 2>/dev/null; then
            print_warning "需要sudo权限来创建目录"
            print_info "请输入sudo密码..."
        fi
    fi
    
    if [ $errors -gt 0 ]; then
        print_error "依赖检查失败，请安装缺失的组件"
        exit 1
    fi
    
    print_success "所有依赖检查通过"
}

# 创建目录结构
create_directories() {
    print_title "创建数据目录"
    
    print_info "创建GitLab数据目录: ${GITLAB_HOME}"
    
    # 创建主目录和子目录
    sudo mkdir -p ${GITLAB_HOME}/{config,logs,data,backups}
    
    # 设置目录权限
    sudo chown -R $(whoami):$(whoami) ${GITLAB_HOME}
    
    print_info "目录结构创建完成："
    ls -la ${GITLAB_HOME}
    
    print_success "目录创建成功"
}

# 检查端口占用
check_ports() {
    print_title "端口占用检查"
    
    local ports=($GITLAB_HTTP_PORT $GITLAB_SSH_PORT $GITLAB_REGISTRY_PORT 8943)
    local occupied=false
    
    for port in "${ports[@]}"; do
        if sudo lsof -i:$port &>/dev/null; then
            print_warning "端口 $port 已被占用："
            sudo lsof -i:$port | head -n 2
            occupied=true
        else
            print_info "端口 $port 可用 ✓"
        fi
    done
    
    if [ "$occupied" = true ]; then
        echo ""
        read -p "发现端口占用，是否继续？(y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "部署已取消"
            exit 1
        fi
    else
        print_success "所有端口检查通过"
    fi
}

# 检查配置文件
check_config_file() {
    print_title "配置文件检查"
    
    if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
        print_error "找不到配置文件: ${DOCKER_COMPOSE_FILE}"
        print_info "请确保docker-compose.yml文件在当前目录"
        exit 1
    fi
    
    print_info "配置文件存在: ${DOCKER_COMPOSE_FILE}"
    
    # 验证配置文件语法
    if docker-compose -f ${DOCKER_COMPOSE_FILE} config > /dev/null 2>&1; then
        print_success "配置文件语法检查通过"
    else
        print_error "配置文件语法错误"
        docker-compose -f ${DOCKER_COMPOSE_FILE} config
        exit 1
    fi
}

# 停止现有服务
stop_existing_services() {
    print_title "清理现有服务"
    
    # 检查是否有运行中的GitLab容器
    if docker ps -a | grep -q ${CONTAINER_NAME}; then
        print_info "发现现有GitLab容器，正在停止..."
        docker-compose down 2>/dev/null || true
        docker stop ${CONTAINER_NAME} 2>/dev/null || true
        docker rm ${CONTAINER_NAME} 2>/dev/null || true
        print_success "现有服务已停止"
    else
        print_info "没有发现运行中的GitLab服务"
    fi
}

# 部署GitLab
deploy_gitlab() {
    print_title "启动GitLab服务"
    
    print_info "开始拉取GitLab镜像..."
    docker-compose pull
    
    print_info "启动GitLab容器..."
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "GitLab容器已启动"
    else
        print_error "GitLab容器启动失败"
        docker-compose logs --tail=50
        exit 1
    fi
}

# 等待GitLab初始化
wait_for_gitlab() {
    print_title "等待GitLab初始化"
    
    print_info "GitLab正在初始化，这可能需要5-10分钟..."
    print_info "您可以在另一个终端运行 'docker logs -f ${CONTAINER_NAME}' 查看详细日志"
    
    local max_attempts=60  # 最多等待10分钟
    local attempt=0
    local health_check_passed=false
    
    echo -n "等待服务启动 "
    while [ $attempt -lt $max_attempts ]; do
        # 检查容器是否运行
        if ! docker ps | grep -q ${CONTAINER_NAME}; then
            echo ""
            print_error "容器未运行，请检查日志"
            docker logs --tail=50 ${CONTAINER_NAME}
            exit 1
        fi
        
        # 检查健康状态
        if docker ps | grep ${CONTAINER_NAME} | grep -q "healthy"; then
            health_check_passed=true
            break
        fi
        
        echo -n "."
        sleep 10
        attempt=$((attempt + 1))
    done
    echo ""
    
    if [ "$health_check_passed" = true ]; then
        print_info "健康检查通过，验证服务状态..."
        
        # 额外等待确保所有服务完全启动
        sleep 20
        
        # 测试HTTP访问
        if curl -f -s -o /dev/null -w "%{http_code}" http://localhost:${GITLAB_HTTP_PORT} | grep -q "302"; then
            print_success "GitLab已成功启动！"
            return 0
        else
            print_warning "GitLab可能还在启动中，请稍后再试"
            return 0
        fi
    else
        print_error "GitLab启动超时"
        print_info "查看容器日志："
        docker logs --tail=50 ${CONTAINER_NAME}
        return 1
    fi
}

# 显示服务状态
show_status() {
    print_title "服务状态检查"
    
    # 容器状态
    print_info "容器状态："
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep ${CONTAINER_NAME} || true
    
    echo ""
    
    # GitLab组件状态
    print_info "GitLab组件状态："
    docker exec ${CONTAINER_NAME} gitlab-ctl status 2>/dev/null || print_warning "组件状态获取失败（可能还在初始化）"
}

# 验证部署
verify_deployment() {
    print_title "部署验证"
    
    local tests_passed=0
    local tests_total=4
    
    # 测试1: Web界面
    print_info "测试Web界面访问..."
    if curl -s -o /dev/null -w "%{http_code}" http://${SERVER_IP}:${GITLAB_HTTP_PORT} | grep -q "302"; then
        print_success "Web界面访问正常 ✓"
        tests_passed=$((tests_passed + 1))
    else
        print_error "Web界面访问失败 ✗"
    fi
    
    # 测试2: Registry
    print_info "测试Container Registry..."
    if curl -s -o /dev/null -w "%{http_code}" http://${SERVER_IP}:${GITLAB_REGISTRY_PORT}/v2/ | grep -q "401"; then
        print_success "Container Registry正常 ✓"
        tests_passed=$((tests_passed + 1))
    else
        print_error "Container Registry失败 ✗"
    fi
    
    # 测试3: SSH端口
    print_info "测试SSH端口..."
    if nc -zv ${SERVER_IP} ${GITLAB_SSH_PORT} 2>&1 | grep -q "succeeded"; then
        print_success "SSH端口正常 ✓"
        tests_passed=$((tests_passed + 1))
    else
        print_error "SSH端口失败 ✗"
    fi
    
    # 测试4: 服务健康状态
    print_info "检查服务健康状态..."
    if docker exec ${CONTAINER_NAME} /opt/gitlab/bin/gitlab-healthcheck 2>/dev/null; then
        print_success "健康检查通过 ✓"
        tests_passed=$((tests_passed + 1))
    else
        print_warning "健康检查未通过（可能还在初始化）"
    fi
    
    echo ""
    print_info "验证结果: ${tests_passed}/${tests_total} 测试通过"
    
    if [ $tests_passed -eq $tests_total ]; then
        print_success "所有测试通过！"
    elif [ $tests_passed -ge 2 ]; then
        print_warning "部分测试通过，GitLab基本可用"
    else
        print_error "多数测试失败，请检查部署"
    fi
}

# 显示访问信息
show_access_info() {
    print_title "GitLab访问信息"
    
    echo -e "${GREEN}部署成功！${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 访问地址："
    echo "  Web界面:   http://${SERVER_IP}:${GITLAB_HTTP_PORT}"
    echo "  Registry:  http://${SERVER_IP}:${GITLAB_REGISTRY_PORT}"
    echo ""
    echo "🔑 默认管理员账户："
    echo "  用户名: root"
    echo "  密码:   ${INITIAL_PASSWORD}"
    echo "  ${YELLOW}⚠️  首次登录后请立即修改密码！${NC}"
    echo ""
    echo "📦 Git使用示例："
    echo "  HTTP克隆: git clone http://${SERVER_IP}:${GITLAB_HTTP_PORT}/username/project.git"
    echo "  SSH克隆:  git clone ssh://git@${SERVER_IP}:${GITLAB_SSH_PORT}/username/project.git"
    echo ""
    echo "💾 数据存储位置："
    echo "  ${GITLAB_HOME}"
    echo ""
    echo "🔧 常用命令："
    echo "  查看日志:  docker logs -f ${CONTAINER_NAME}"
    echo "  查看状态:  docker exec ${CONTAINER_NAME} gitlab-ctl status"
    echo "  重启服务:  docker-compose restart"
    echo "  停止服务:  docker-compose down"
    echo "  创建备份:  docker exec ${CONTAINER_NAME} gitlab-backup create"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 创建快捷脚本
create_helper_scripts() {
    print_title "创建辅助脚本"
    
    # 创建备份脚本
    cat > backup.sh <<'EOF'
#!/bin/bash
# GitLab备份脚本
CONTAINER_NAME="gitlab-v5"
BACKUP_PATH="/opt/gitlab/v5/backups"

echo "开始备份GitLab..."
docker exec -t ${CONTAINER_NAME} gitlab-backup create

echo "清理旧备份（保留最近7天）..."
find ${BACKUP_PATH} -name "*.tar" -mtime +7 -delete

echo "备份完成！"
ls -lh ${BACKUP_PATH}
EOF
    chmod +x backup.sh
    print_info "创建备份脚本: ./backup.sh"
    
    # 创建状态检查脚本
    cat > status.sh <<'EOF'
#!/bin/bash
# GitLab状态检查脚本
CONTAINER_NAME="gitlab-v5"

echo "=== GitLab容器状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep ${CONTAINER_NAME}

echo ""
echo "=== GitLab服务状态 ==="
docker exec ${CONTAINER_NAME} gitlab-ctl status
EOF
    chmod +x status.sh
    print_info "创建状态脚本: ./status.sh"
    
    print_success "辅助脚本创建完成"
}

# 主函数
main() {
    clear
    print_title "GitLab v5 自动化部署脚本"
    
    echo "目标服务器: ${SERVER_IP}"
    echo "GitLab版本: 17.5.1-ce.0"
    echo "部署路径:   ${GITLAB_HOME}"
    echo ""
    
    # 执行部署步骤
    check_prerequisites
    check_config_file
    check_ports
    create_directories
    stop_existing_services
    deploy_gitlab
    
    # 等待并验证
    if wait_for_gitlab; then
        show_status
        verify_deployment
        create_helper_scripts
        show_access_info
        
        print_success "GitLab部署完成！"
        exit 0
    else
        print_error "GitLab部署失败，请查看日志排查问题"
        exit 1
    fi
}

# 错误处理
trap 'print_error "脚本执行出错，退出代码: $?"' ERR

# 运行主函数
main "$@"