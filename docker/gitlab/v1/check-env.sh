#!/bin/bash

# GitLab 环境检查脚本
# 检查Docker环境和系统要求

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

check_os() {
    log_header "系统环境检查"
    
    echo -e "${BLUE}操作系统:${NC} $(uname -s)"
    echo -e "${BLUE}架构:${NC} $(uname -m)"
    
    # 检查是否为Windows
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        log_warn "检测到Windows系统，请确保Docker Desktop已启动"
        echo -e "${YELLOW}Windows用户注意事项:${NC}"
        echo "  1. 启动Docker Desktop"
        echo "  2. 确保WSL2后端已启用"
        echo "  3. 确保有足够磁盘空间 (>10GB)"
    fi
}

check_docker() {
    log_header "Docker环境检查"
    
    # 检查Docker命令是否可用
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装"
        echo -e "${YELLOW}请访问 https://docs.docker.com/get-docker/ 安装Docker${NC}"
        return 1
    fi
    log_info "Docker命令可用"
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行"
        echo -e "${YELLOW}请启动Docker服务:${NC}"
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            echo "  - Windows: 启动Docker Desktop"
        else
            echo "  - Linux: sudo systemctl start docker"
            echo "  - macOS: 启动Docker Desktop"
        fi
        return 1
    fi
    log_info "Docker服务运行正常"
    
    # 显示Docker版本
    docker_version=$(docker --version)
    echo -e "${BLUE}Docker版本:${NC} $docker_version"
    
    # 检查Docker Compose
    if docker compose version &> /dev/null; then
        compose_version=$(docker compose version)
        echo -e "${BLUE}Docker Compose:${NC} $compose_version"
        log_info "Docker Compose v2 可用"
    elif command -v docker-compose &> /dev/null; then
        compose_version=$(docker-compose --version)
        echo -e "${BLUE}Docker Compose:${NC} $compose_version"
        log_info "Docker Compose v1 可用"
    else
        log_error "Docker Compose未安装"
        return 1
    fi
}

check_ports() {
    log_header "端口检查"
    
    ports=(8080 2222)
    all_ports_available=true
    
    for port in "${ports[@]}"; do
        if command -v ss &> /dev/null; then
            # 使用ss命令检查（Linux/macOS）
            if ss -tuln | grep -q ":$port "; then
                log_error "端口 $port 已被占用"
                echo -e "  ${YELLOW}占用详情:${NC} $(ss -tuln | grep ":$port ")"
                all_ports_available=false
            else
                log_info "端口 $port 可用"
            fi
        elif command -v netstat &> /dev/null; then
            # 使用netstat命令检查（Windows）
            if netstat -an | grep -q ":$port "; then
                log_error "端口 $port 已被占用"
                all_ports_available=false
            else
                log_info "端口 $port 可用"
            fi
        else
            log_warn "无法检查端口 $port（缺少ss或netstat命令）"
        fi
    done
    
    if ! $all_ports_available; then
        log_warn "部分端口被占用，可能需要修改配置文件中的端口设置"
        echo -e "${YELLOW}解决方案:${NC}"
        echo "  1. 停止占用端口的服务"
        echo "  2. 或修改 .env 文件中的端口配置"
    fi
}

check_resources() {
    log_header "系统资源检查"
    
    # 检查内存
    if command -v free &> /dev/null; then
        # Linux
        total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
        available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7/1024}')
        
        echo -e "${BLUE}总内存:${NC} ${total_mem}GB"
        echo -e "${BLUE}可用内存:${NC} ${available_mem}GB"
        
        if (( available_mem < 2 )); then
            log_error "可用内存不足2GB，GitLab可能无法正常运行"
        elif (( available_mem < 4 )); then
            log_warn "可用内存不足4GB，建议关闭其他应用程序"
        else
            log_info "内存充足"
        fi
    else
        log_warn "无法检查系统内存（非Linux系统）"
        echo -e "${YELLOW}请确保系统至少有4GB可用内存${NC}"
    fi
    
    # 检查磁盘空间
    current_dir=$(pwd)
    if command -v df &> /dev/null; then
        available_space=$(df -BG "$current_dir" | awk 'NR==2 {print $4}' | sed 's/G//')
        echo -e "${BLUE}当前目录可用空间:${NC} ${available_space}GB"
        
        if (( available_space < 10 )); then
            log_error "磁盘空间不足10GB，GitLab需要更多空间"
        elif (( available_space < 20 )); then
            log_warn "磁盘空间不足20GB，建议清理磁盘空间"
        else
            log_info "磁盘空间充足"
        fi
    else
        log_warn "无法检查磁盘空间"
    fi
}

check_network() {
    log_header "网络连通性检查"
    
    # 检查Docker Hub连通性
    if curl -s --connect-timeout 10 https://registry-1.docker.io/v2/ > /dev/null; then
        log_info "Docker Hub连接正常"
    else
        log_error "无法连接到Docker Hub"
        echo -e "${YELLOW}可能的原因:${NC}"
        echo "  1. 网络连接问题"
        echo "  2. 防火墙阻止"
        echo "  3. 需要配置代理"
    fi
    
    # 测试本地端口绑定
    if command -v python3 &> /dev/null; then
        # 使用Python测试端口绑定
        python3 -c "
import socket
try:
    s = socket.socket()
    s.bind(('localhost', 8080))
    s.close()
    print('✓ 可以绑定到端口8080')
except:
    print('✗ 无法绑定到端口8080')
" 2>/dev/null || log_warn "无法测试端口绑定"
    fi
}

check_files() {
    log_header "配置文件检查"
    
    required_files=("docker-compose.yml" ".env")
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "配置文件存在: $file"
        else
            log_error "缺少配置文件: $file"
        fi
    done
    
    # 检查.env文件内容
    if [[ -f ".env" ]]; then
        if grep -q "GITLAB_ROOT_PASSWORD" .env; then
            log_info ".env文件包含密码配置"
        else
            log_warn ".env文件缺少密码配置"
        fi
    fi
}

provide_next_steps() {
    log_header "下一步操作建议"
    
    echo -e "${GREEN}如果所有检查都通过，可以执行以下命令启动GitLab:${NC}"
    echo ""
    echo -e "${BLUE}  ./start.sh${NC}        # 自动启动GitLab"
    echo -e "${BLUE}  ./manage.sh start${NC} # 使用管理脚本启动"
    echo ""
    echo -e "${GREEN}启动后访问地址:${NC}"
    echo -e "${BLUE}  Web界面: http://localhost:8080${NC}"
    echo -e "${BLUE}  用户名: root${NC}"
    echo -e "${BLUE}  密码: ChangeMePlease123!${NC}"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo "  • 首次启动需要5-10分钟初始化"
    echo "  • 请耐心等待，不要中断启动过程"
    echo "  • 启动完成后立即修改默认密码"
}

main() {
    echo -e "${BLUE}GitLab Docker 环境检查工具${NC}"
    echo -e "${BLUE}版本: v1.0${NC}"
    echo ""
    
    # 切换到脚本目录
    cd "$(dirname "$0")"
    
    # 执行各项检查
    check_os
    echo ""
    
    check_docker
    if [ $? -ne 0 ]; then
        echo ""
        log_error "Docker环境检查失败，请解决Docker问题后重试"
        exit 1
    fi
    echo ""
    
    check_ports
    echo ""
    
    check_resources
    echo ""
    
    check_network
    echo ""
    
    check_files
    echo ""
    
    provide_next_steps
    
    echo ""
    echo -e "${GREEN}🎉 环境检查完成！${NC}"
}

main "$@"