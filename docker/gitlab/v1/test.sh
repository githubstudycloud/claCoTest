#!/bin/bash

# GitLab 快速测试脚本
# 用于验证GitLab基本功能是否正常

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }

test_web_access() {
    log_test "测试Web界面访问..."
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
        log_info "Web界面可访问 (http://localhost:8080)"
    else
        log_error "Web界面无法访问"
        return 1
    fi
}

test_ssh_connection() {
    log_test "测试SSH连接..."
    
    # 测试SSH端口连通性
    if timeout 5 bash -c 'cat < /dev/null > /dev/tcp/localhost/2222' 2>/dev/null; then
        log_info "SSH端口2222可连接"
    else
        log_error "SSH端口2222无法连接"
        return 1
    fi
}

test_container_health() {
    log_test "测试容器健康状态..."
    
    # 检测Docker Compose命令
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    if $COMPOSE_CMD ps | grep -q "Up"; then
        log_info "GitLab容器运行正常"
        
        # 显示容器详细状态
        echo -e "${BLUE}容器状态详情:${NC}"
        $COMPOSE_CMD ps
        
        return 0
    else
        log_error "GitLab容器未运行"
        echo -e "${YELLOW}容器状态:${NC}"
        $COMPOSE_CMD ps -a
        return 1
    fi
}

test_gitlab_readiness() {
    log_test "测试GitLab服务就绪状态..."
    
    # 检查readiness端点
    if curl -s http://localhost:8080/-/readiness | grep -q '"status":"ok"'; then
        log_info "GitLab服务完全就绪"
        return 0
    elif curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/-/health | grep -q "200"; then
        log_warn "GitLab服务部分就绪，可能仍在初始化"
        return 0
    else
        log_warn "GitLab服务仍在启动中，请稍后重试"
        return 1
    fi
}

show_access_info() {
    echo ""
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}GitLab 访问信息${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo -e "${GREEN}🌐 Web访问:${NC}"
    echo -e "   URL: http://localhost:8080"
    echo -e "   用户名: root"
    echo -e "   密码: ChangeMePlease123!"
    echo ""
    echo -e "${GREEN}🔗 SSH访问:${NC}"
    echo -e "   测试命令: ssh -T git@localhost -p 2222"
    echo -e "   克隆示例: git clone ssh://git@localhost:2222/username/project.git"
    echo ""
    echo -e "${YELLOW}⚠️  重要提醒:${NC}"
    echo -e "   1. 首次登录后请立即修改默认密码"
    echo -e "   2. 添加SSH公钥以启用SSH Git操作"
    echo -e "   3. 如果服务仍在初始化，请耐心等待5-10分钟"
}

run_all_tests() {
    echo -e "${BLUE}GitLab 功能测试开始...${NC}"
    echo ""
    
    cd "$(dirname "$0")"
    
    tests_passed=0
    total_tests=4
    
    # 测试容器健康状态
    if test_container_health; then
        ((tests_passed++))
    fi
    echo ""
    
    # 测试Web访问
    if test_web_access; then
        ((tests_passed++))
    fi
    echo ""
    
    # 测试SSH连接
    if test_ssh_connection; then
        ((tests_passed++))
    fi  
    echo ""
    
    # 测试GitLab就绪状态
    if test_gitlab_readiness; then
        ((tests_passed++))
    fi
    echo ""
    
    # 显示测试结果
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}测试结果汇总${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "通过测试: ${GREEN}$tests_passed${NC}/$total_tests"
    
    if [ $tests_passed -eq $total_tests ]; then
        echo -e "状态: ${GREEN}✅ 所有测试通过，GitLab运行正常${NC}"
        show_access_info
        return 0
    elif [ $tests_passed -ge 2 ]; then
        echo -e "状态: ${YELLOW}⚠️  部分测试通过，GitLab可能仍在初始化${NC}"
        echo -e "${YELLOW}建议: 等待5-10分钟后重新测试${NC}"
        show_access_info
        return 0
    else
        echo -e "状态: ${RED}❌ 多项测试失败，请检查GitLab配置${NC}"
        echo ""
        echo -e "${YELLOW}排查建议:${NC}"
        echo -e "  1. 检查容器日志: ./manage.sh logs"
        echo -e "  2. 检查系统资源: docker stats"
        echo -e "  3. 重启服务: ./manage.sh restart"
        echo -e "  4. 查看环境检查: ./check-env.sh"
        return 1
    fi
}

# 主函数
case "${1:-all}" in
    web)
        test_web_access
        ;;
    ssh)
        test_ssh_connection
        ;;
    health)
        test_container_health
        ;;
    ready)
        test_gitlab_readiness
        ;;
    info)
        show_access_info
        ;;
    all)
        run_all_tests
        ;;
    *)
        echo "用法: $0 [web|ssh|health|ready|info|all]"
        echo ""
        echo "测试选项:"
        echo "  web    - 测试Web界面访问"
        echo "  ssh    - 测试SSH连接"
        echo "  health - 测试容器健康状态"  
        echo "  ready  - 测试GitLab就绪状态"
        echo "  info   - 显示访问信息"
        echo "  all    - 运行所有测试 (默认)"
        exit 1
        ;;
esac