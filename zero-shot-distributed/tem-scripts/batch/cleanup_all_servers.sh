#!/bin/bash

# 批量清理所有服务器缓存脚本
# 在所有云服务器上执行缓存清理操作

set -e

echo "=================================================="
echo "  批量服务器缓存清理工具"
echo "=================================================="

# 定义服务器列表
SERVERS=("seetacloud-v800" "seetacloud-v801" "seetacloud-v802")
SERVER_DESCS=("Master" "Worker-1" "Worker-2")
CLEANUP_SCRIPT="cleanup_server_cache.sh"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="./cleanup_logs_${TIMESTAMP}"

# 创建日志目录
mkdir -p ${LOG_DIR}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_DIR}/batch_cleanup.log
}

log "=== 批量服务器缓存清理开始 ==="

# 检查清理脚本是否存在
if [ ! -f "${CLEANUP_SCRIPT}" ]; then
    log "❌ 错误: 找不到 ${CLEANUP_SCRIPT} 文件"
    exit 1
fi

# 设置脚本执行权限
chmod +x ${CLEANUP_SCRIPT}
log "✅ 清理脚本检查完成"

# 检查SSH连通性
echo ""
echo "检查SSH连通性"
echo "----------------------------------------------"
for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    
    if ssh -o ConnectTimeout=10 ${server} "echo 'connected'" >/dev/null 2>&1; then
        log "✅ ${server} (${desc}) SSH连接正常"
    else
        log "❌ ${server} (${desc}) SSH连接失败"
        echo "请检查SSH配置或网络连接"
        exit 1
    fi
done

# 上传清理脚本到各服务器
echo ""
echo "上传清理脚本到各服务器"
echo "----------------------------------------------"
for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    
    log "📤 上传清理脚本到 ${server} (${desc})..."
    if scp ${CLEANUP_SCRIPT} ${server}:/root/autodl-tmp/; then
        ssh ${server} "chmod +x /root/autodl-tmp/${CLEANUP_SCRIPT}"
        log "✅ ${server} 脚本上传成功"
    else
        log "❌ ${server} 脚本上传失败"
        exit 1
    fi
done

# 在各服务器上执行清理
echo ""
echo "在各服务器上执行缓存清理"
echo "----------------------------------------------"

for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    server_log="${LOG_DIR}/${server}_cleanup.log"
    
    log "🧹 开始在 ${server} (${desc}) 上执行缓存清理..."
    log "📝 日志文件: ${server_log}"
    
    # 远程执行清理脚本
    if ssh ${server} << EOF | tee ${server_log}
cd /root/autodl-tmp
echo "=== 开始在 ${server} 上执行缓存清理 ==="
echo "当前目录: \$(pwd)"
echo "清理脚本: \$(ls -la ${CLEANUP_SCRIPT})"
echo ""

# 执行清理脚本
./${CLEANUP_SCRIPT}

echo ""
echo "=== ${server} 缓存清理执行完成 ==="
EOF
    then
        log "✅ ${server} (${desc}) 缓存清理成功完成"
    else
        log "❌ ${server} (${desc}) 缓存清理执行失败"
        log "请检查日志文件: ${server_log}"
    fi
    
    echo ""
done

# 收集清理后的磁盘使用情况
echo ""
echo "收集各服务器磁盘使用情况"
echo "----------------------------------------------"

for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    
    log "📊 收集 ${server} (${desc}) 磁盘使用情况..."
    
    disk_info=$(ssh ${server} << 'EOF'
echo "=== 服务器磁盘使用情况 ==="
echo "日期: $(date)"
echo ""
echo "磁盘使用情况:"
df -h | head -1
df -h | grep -E "(/$|/root)" || df -h | grep "/"
echo ""
echo "内存使用情况:"
free -h
echo ""
echo "最大的目录 (前10个):"
du -sh /root/* 2>/dev/null | sort -hr | head -10 || echo "无法获取目录大小信息"
echo "=== 报告结束 ==="
EOF
)
    
    echo "${disk_info}" | tee ${LOG_DIR}/${server}_disk_usage.log
    echo ""
done

# 完成总结
echo ""
echo "=================================================="
echo "🎉 批量服务器缓存清理完成！"
echo "=================================================="
echo ""
log "批量清理总结:"
echo "----------------------------------------------"
echo "📂 日志目录: ${LOG_DIR}"
echo "📝 批量日志: ${LOG_DIR}/batch_cleanup.log"
echo ""
echo "各服务器清理状态:"
for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    echo "  ${server} (${desc}):"
    echo "    🧹 清理日志: ${LOG_DIR}/${server}_cleanup.log"
    echo "    📊 磁盘状态: ${LOG_DIR}/${server}_disk_usage.log"
done

echo ""
echo "清理效果检查："
echo "  1. 检查各服务器磁盘使用情况日志"
echo "  2. 确认系统盘使用率是否降低"
echo "  3. 如有必要可重复运行清理脚本"
echo ""
echo "下一步建议："
echo "  • 运行精简版环境设置: ./setup_distributed_wrapper.sh"
echo "  • 现在安装过程应该会快很多"
echo ""
echo "=================================================="

log "=== 批量服务器缓存清理结束 ===" 