#!/bin/bash

# GitLab Docker 停止脚本
# 用途：安全停止GitLab服务

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

log_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

# 检测Docker Compose命令
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

main() {
    log_header "停止GitLab服务"
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    log_info "正在停止GitLab容器..."
    $COMPOSE_CMD down
    
    log_info "GitLab服务已停止"
    
    # 显示状态
    log_info "当前容器状态："
    $COMPOSE_CMD ps -a
    
    echo ""
    echo -e "${GREEN}✅ GitLab已安全停止${NC}"
    echo -e "${YELLOW}💡 数据已保存在 ./data 目录中${NC}"
    echo -e "${YELLOW}💡 要重新启动，请运行: ./start.sh${NC}"
}

main "$@"