#!/bin/bash

# ELEVATER分布式环境设置封装启动器
# 从本地自动部署和执行分布式环境设置到各个云服务器

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  ELEVATER分布式环境设置封装启动器"
echo "=================================================="

# 定义服务器列表（v800已有环境，重点是v801和v802）
SERVERS=("seetacloud-v801" "seetacloud-v802")
SERVER_DESCS=("Worker-1" "Worker-2 (数据源)")
SETUP_SCRIPT="setup_distributed_environment.sh"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="./distributed_setup_logs_${TIMESTAMP}"

# 创建日志目录
mkdir -p ${LOG_DIR}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_DIR}/wrapper.log
}

log "=== 分布式环境设置封装启动器开始 ==="

# 步骤0: 检查本地文件
echo ""
echo "步骤0: 检查本地环境"
echo "----------------------------------------------"

if [ ! -f "${SETUP_SCRIPT}" ]; then
    log "❌ 错误: 找不到 ${SETUP_SCRIPT} 文件"
    log "请确保在正确的目录下运行此脚本"
    exit 1
fi

log "✅ 找到环境设置脚本: ${SETUP_SCRIPT}"

# 检查SSH连通性
log "检查SSH连通性..."
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

# 步骤1: 上传环境设置脚本
echo ""
echo "步骤1: 上传环境设置脚本到目标服务器"
echo "----------------------------------------------"

for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    
    log "📤 上传 ${SETUP_SCRIPT} 到 ${server} (${desc})..."
    
    # 上传脚本
    if scp ${SETUP_SCRIPT} ${server}:/root/autodl-tmp/; then
        log "✅ ${server} 文件上传成功"
        
        # 设置执行权限
        ssh ${server} "chmod +x /root/autodl-tmp/${SETUP_SCRIPT}"
        log "✅ ${server} 执行权限设置完成"
    else
        log "❌ ${server} 文件上传失败"
        exit 1
    fi
done

# 步骤2: 远程执行环境设置
echo ""
echo "步骤2: 远程执行环境设置"
echo "----------------------------------------------"

for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    server_log="${LOG_DIR}/${server}_setup.log"
    
    log "🚀 开始在 ${server} (${desc}) 上执行环境设置..."
    log "📝 日志文件: ${server_log}"
    
    # 远程执行环境设置脚本
    if ssh ${server} << EOF | tee ${server_log}
cd /root/autodl-tmp
echo "=== 开始在 ${server} 上执行环境设置 ==="
echo "当前目录: \$(pwd)"
echo "脚本位置: \$(ls -la ${SETUP_SCRIPT})"
echo ""

# 执行环境设置脚本
./${SETUP_SCRIPT}

echo ""
echo "=== ${server} 环境设置执行完成 ==="
EOF
    then
        log "✅ ${server} (${desc}) 环境设置成功完成"
    else
        log "❌ ${server} (${desc}) 环境设置执行失败"
        log "请检查日志文件: ${server_log}"
        # 不退出，继续处理其他服务器
    fi
    
    echo ""
done

# 步骤3: 验证环境设置结果
echo ""
echo "步骤3: 验证环境设置结果"
echo "----------------------------------------------"

for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    
    log "🔍 验证 ${server} (${desc}) 环境设置结果..."
    
    verification_result=$(ssh ${server} << 'EOF'
echo "=== 环境验证报告 ==="
echo "工作目录: /root/autodl-tmp"
echo "目录结构:"
ls -la /root/autodl-tmp/ | head -10

echo ""
echo "datapath目录结构:"
if [ -d "/root/autodl-tmp/datapath" ]; then
    ls -la /root/autodl-tmp/datapath/
else
    echo "datapath目录不存在"
fi

echo ""
echo "conda环境:"
if command -v conda >/dev/null 2>&1; then
    conda info --envs | head -5
else
    echo "conda未安装或未配置"
fi

echo ""
echo "Python环境:"
if command -v python >/dev/null 2>&1; then
    python --version
else
    echo "Python未安装"
fi

echo ""
echo "Chinese-CLIP代码库:"
if [ -d "/root/autodl-tmp/Chinese-CLIP" ]; then
    echo "✅ Chinese-CLIP代码库存在"
    echo "目录大小: $(du -sh /root/autodl-tmp/Chinese-CLIP | cut -f1)"
else
    echo "❌ Chinese-CLIP代码库不存在"
fi

echo "=== 验证完成 ==="
EOF
)
    
    echo "${verification_result}" | tee ${LOG_DIR}/${server}_verification.log
    log "📋 ${server} 验证报告已保存到: ${LOG_DIR}/${server}_verification.log"
    echo ""
done

# 完成总结
echo ""
echo "=================================================="
echo "🎉 分布式环境设置封装启动完成！"
echo "=================================================="
echo ""
log "执行总结:"
echo "----------------------------------------------"
echo "📂 日志目录: ${LOG_DIR}"
echo "📝 主日志: ${LOG_DIR}/wrapper.log"
echo ""
echo "各服务器状态:"
for i in "${!SERVERS[@]}"; do
    server="${SERVERS[$i]}"
    desc="${SERVER_DESCS[$i]}"
    echo "  ${server} (${desc}):"
    echo "    📋 设置日志: ${LOG_DIR}/${server}_setup.log"
    echo "    🔍 验证日志: ${LOG_DIR}/${server}_verification.log"
done

echo ""
echo "下一步操作建议:"
echo "  1. 检查各服务器的验证日志确认环境设置成功"
echo "  2. 运行数据集分发脚本: ./smart_data_distributor.sh"
echo "  3. 运行蒸馏模型分发脚本: ./distilled_model_distributor.sh"
echo "  4. 开始分布式零样本分类测试"
echo ""
echo "=================================================="

log "=== 分布式环境设置封装启动器结束 ===" 