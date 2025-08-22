#!/bin/bash

# GitLab 管理脚本
# 提供常用的GitLab管理操作

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检测Docker Compose命令
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

show_usage() {
    echo -e "${BLUE}GitLab 管理脚本${NC}"
    echo ""
    echo -e "${GREEN}用法:${NC}"
    echo "  $0 [命令]"
    echo ""
    echo -e "${GREEN}可用命令:${NC}"
    echo "  start          - 启动GitLab服务"
    echo "  stop           - 停止GitLab服务"
    echo "  restart        - 重启GitLab服务"
    echo "  status         - 查看服务状态"
    echo "  logs           - 查看实时日志"
    echo "  logs-tail      - 查看最近日志"
    echo "  shell          - 进入GitLab容器"
    echo "  backup         - 创建数据备份"
    echo "  restore        - 恢复数据备份"
    echo "  update         - 更新GitLab版本"
    echo "  reset-password - 重置root密码"
    echo "  cleanup        - 清理无用数据"
    echo "  info           - 显示访问信息"
    echo "  help           - 显示此帮助信息"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  $0 start       # 启动GitLab"
    echo "  $0 logs        # 查看实时日志"
    echo "  $0 backup      # 创建备份"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查GitLab是否运行
check_gitlab_running() {
    if ! $COMPOSE_CMD ps | grep -q "Up"; then
        log_error "GitLab容器未运行"
        return 1
    fi
    return 0
}

# 启动服务
start_service() {
    log_info "启动GitLab服务..."
    ./start.sh
}

# 停止服务
stop_service() {
    log_info "停止GitLab服务..."
    ./stop.sh
}

# 重启服务
restart_service() {
    log_info "重启GitLab服务..."
    $COMPOSE_CMD restart
    log_info "GitLab服务已重启"
}

# 查看状态
show_status() {
    echo -e "${BLUE}GitLab容器状态:${NC}"
    $COMPOSE_CMD ps
    echo ""
    
    if check_gitlab_running; then
        echo -e "${BLUE}GitLab服务信息:${NC}"
        $COMPOSE_CMD exec gitlab gitlab-ctl status 2>/dev/null || log_warn "无法获取GitLab内部服务状态"
    fi
}

# 查看日志
show_logs() {
    log_info "显示GitLab实时日志 (按Ctrl+C退出)..."
    $COMPOSE_CMD logs -f gitlab
}

# 查看最近日志
show_logs_tail() {
    log_info "显示最近50行日志..."
    $COMPOSE_CMD logs --tail=50 gitlab
}

# 进入容器
enter_shell() {
    if ! check_gitlab_running; then
        exit 1
    fi
    
    log_info "进入GitLab容器shell..."
    $COMPOSE_CMD exec gitlab /bin/bash
}

# 创建备份
create_backup() {
    if ! check_gitlab_running; then
        exit 1
    fi
    
    log_info "创建GitLab数据备份..."
    mkdir -p ./backups
    
    backup_name="gitlab_backup_$(date +%Y%m%d_%H%M%S)"
    log_info "备份名称: $backup_name"
    
    # 创建GitLab应用备份
    $COMPOSE_CMD exec gitlab gitlab-backup create BACKUP=$backup_name
    
    # 备份配置文件
    log_info "备份配置文件..."
    cp -r ./config "./backups/${backup_name}_config" 2>/dev/null || log_warn "配置文件备份失败"
    
    log_info "备份完成: ./backups/$backup_name"
}

# 恢复备份
restore_backup() {
    if ! check_gitlab_running; then
        exit 1
    fi
    
    echo -e "${YELLOW}可用的备份文件:${NC}"
    ls -la ./backups/ 2>/dev/null || {
        log_error "未找到备份文件"
        exit 1
    }
    
    echo ""
    read -p "请输入要恢复的备份名称: " backup_name
    
    if [ -z "$backup_name" ]; then
        log_error "备份名称不能为空"
        exit 1
    fi
    
    log_warn "恢复备份将覆盖当前数据，请确认操作"
    read -p "确认恢复备份 $backup_name? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        log_info "恢复备份: $backup_name"
        $COMPOSE_CMD exec gitlab gitlab-backup restore BACKUP=$backup_name
        log_info "备份恢复完成，建议重启服务"
    else
        log_info "取消备份恢复"
    fi
}

# 更新GitLab
update_gitlab() {
    log_warn "更新GitLab可能需要较长时间，建议先创建备份"
    read -p "是否先创建备份? (Y/n): " create_backup_confirm
    
    if [[ ! $create_backup_confirm =~ ^[Nn]$ ]]; then
        create_backup
    fi
    
    log_info "更新GitLab镜像..."
    $COMPOSE_CMD pull gitlab
    
    log_info "重新创建容器..."
    $COMPOSE_CMD up -d --force-recreate gitlab
    
    log_info "GitLab更新完成"
}

# 重置root密码
reset_root_password() {
    if ! check_gitlab_running; then
        exit 1
    fi
    
    read -s -p "请输入新的root密码: " new_password
    echo ""
    
    if [ -z "$new_password" ]; then
        log_error "密码不能为空"
        exit 1
    fi
    
    log_info "重置root用户密码..."
    $COMPOSE_CMD exec gitlab gitlab-rails runner "
        user = User.find_by(username: 'root')
        user.password = '$new_password'
        user.password_confirmation = '$new_password'
        user.save!
        puts 'Root password updated successfully'
    "
    
    log_info "root密码重置完成"
}

# 清理数据
cleanup_data() {
    log_warn "此操作将清理GitLab无用数据，可能需要较长时间"
    read -p "确认执行清理操作? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if check_gitlab_running; then
            log_info "清理GitLab数据..."
            # 清理老的日志
            $COMPOSE_CMD exec gitlab find /var/log/gitlab -name "*.log" -mtime +30 -delete 2>/dev/null || true
            # 清理临时文件
            $COMPOSE_CMD exec gitlab gitlab-rails runner "Gitlab::Cleanup::OrphanJobArtifactFiles.new.run"
            log_info "数据清理完成"
        fi
        
        # 清理Docker数据
        log_info "清理Docker数据..."
        docker system prune -f
        log_info "Docker数据清理完成"
    else
        log_info "取消清理操作"
    fi
}

# 显示访问信息
show_info() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}GitLab 访问信息${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo -e "${GREEN}Web访问地址:${NC}"
    echo -e "  🌐 http://localhost:8080"
    echo ""
    echo -e "${GREEN}默认登录信息:${NC}"
    echo -e "  👤 用户名: root"
    echo -e "  🔑 密码: ChangeMePlease123!"
    echo ""
    echo -e "${GREEN}SSH访问信息:${NC}"
    echo -e "  🔗 SSH地址: ssh://git@localhost:2222"
    echo ""
    echo -e "${GREEN}常用目录:${NC}"
    echo -e "  📂 数据目录: ./data"
    echo -e "  ⚙️  配置目录: ./config"
    echo -e "  📋 日志目录: ./logs"
    echo -e "  💾 备份目录: ./backups"
    echo ""
    
    if check_gitlab_running; then
        echo -e "${GREEN}服务状态: ✅ 运行中${NC}"
    else
        echo -e "${YELLOW}服务状态: ⏸️ 已停止${NC}"
    fi
}

# 主函数
main() {
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    case "${1:-help}" in
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        logs-tail)
            show_logs_tail
            ;;
        shell)
            enter_shell
            ;;
        backup)
            create_backup
            ;;
        restore)
            restore_backup
            ;;
        update)
            update_gitlab
            ;;
        reset-password)
            reset_root_password
            ;;
        cleanup)
            cleanup_data
            ;;
        info)
            show_info
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo -e "${RED}未知命令: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"