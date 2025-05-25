#!/bin/bash

# ELEVATER分布式环境快速部署脚本
# 自动化完成环境搭建、数据同步、模型分发

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  ELEVATER分布式环境快速部署器"
echo "=================================================="

# 检查本地文件
if [ ! -f "setup_environment.sh" ]; then
    echo "❌ 错误: 找不到 setup_environment.sh 文件"
    echo "请确保在正确的目录下运行此脚本"
    exit 1
fi

echo "准备开始分布式环境部署..."
echo ""
echo "部署步骤："
echo "1. 环境搭建 (v801, v802)"
echo "2. 数据同步 (ELEVATER数据集)"
echo "3. 模型分发 (蒸馏模型)"
echo "4. 验证部署"
echo ""

read -p "确认开始部署？ (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "部署已取消。"
    exit 0
fi

# 定义服务器
NEW_SERVERS=("seetacloud-v801" "seetacloud-v802")
MASTER_SERVER="seetacloud-v800"

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 步骤1: 检查连通性
echo ""
echo "步骤1: 检查服务器连通性"
echo "----------------------------------------------"

for server in ${MASTER_SERVER} "${NEW_SERVERS[@]}"; do
    if ssh -o ConnectTimeout=10 ${server} "echo 'connected'" >/dev/null 2>&1; then
        log "✅ ${server} - 连接成功"
    else
        log "❌ ${server} - 连接失败"
        exit 1
    fi
done

# 步骤2: 环境搭建
echo ""
echo "步骤2: 环境搭建"
echo "----------------------------------------------"

for server in "${NEW_SERVERS[@]}"; do
    log "🚀 开始搭建 ${server} 环境..."
    
    # 上传精简版setup脚本
    log "  上传setup_distributed_environment.sh到 ${server}"
    scp setup_distributed_environment.sh ${server}:/root/autodl-tmp/
    
    # 执行环境搭建
    log "  执行环境搭建 (这可能需要10-15分钟)..."
    ssh ${server} << 'EOF'
cd /root/autodl-tmp
chmod +x setup_distributed_environment.sh
echo "开始环境搭建..."
./setup_distributed_environment.sh
echo "环境搭建完成"
EOF
    
    log "✅ ${server} 环境搭建完成"
done

# 步骤3: 智能数据分发
echo ""
echo "步骤3: 智能数据分发"
echo "----------------------------------------------"

log "使用智能分发策略分发ELEVATER数据集..."
log "数据分配策略："
log "  - v800+v801: 基础数据集 (cifar-10, cifar-100, caltech-101, oxford-flower-102, food-101, fgvc-aircraft)"
log "  - v802: 扩展数据集 (eurosat_clip, resisc45_clip, country211)"

# 运行智能数据分发脚本
chmod +x smart_data_distributor.sh
./smart_data_distributor.sh

log "✅ 智能数据分发完成"

# 步骤4: 蒸馏模型分发
echo ""
echo "步骤4: 蒸馏模型分发"
echo "----------------------------------------------"

log "从v800分发4个蒸馏模型到其他服务器..."

# 运行蒸馏模型分发脚本
chmod +x distilled_model_distributor.sh
./distilled_model_distributor.sh

log "✅ 蒸馏模型分发完成"

# 步骤6: 部署测试脚本
echo ""
echo "步骤6: 部署测试脚本"
echo "----------------------------------------------"

log "上传测试脚本到各服务器..."

for server in ${MASTER_SERVER} "${NEW_SERVERS[@]}"; do
    log "上传脚本到 ${server}..."
    scp run_zeroshot_classification.sh ${server}:/root/autodl-tmp/
    scp run_zeroshot_batch.sh ${server}:/root/autodl-tmp/
    
    # 设置执行权限
    ssh ${server} << 'EOF'
cd /root/autodl-tmp
chmod +x run_zeroshot_classification.sh
chmod +x run_zeroshot_batch.sh
EOF
    
    log "✅ ${server} 脚本部署完成"
done

# 步骤7: 验证部署
echo ""
echo "步骤7: 验证部署"
echo "----------------------------------------------"

log "验证各服务器环境..."

for server in ${MASTER_SERVER} "${NEW_SERVERS[@]}"; do
    log "验证 ${server}..."
    
    # 检查关键组件
    verification_result=$(ssh ${server} << 'EOF'
cd /root/autodl-tmp

# 检查conda环境
if conda env list | grep training >/dev/null 2>&1; then
    echo "✅ Conda环境"
else
    echo "❌ Conda环境"
fi

# 检查Chinese-CLIP
if [ -d "Chinese-CLIP" ]; then
    echo "✅ Chinese-CLIP代码库"
else
    echo "❌ Chinese-CLIP代码库"
fi

# 检查ELEVATER数据集
if [ -d "datapath/datasets/ELEVATER" ]; then
    dataset_count=$(ls datapath/datasets/ELEVATER/ | wc -l)
    echo "✅ ELEVATER数据集 (${dataset_count}个)"
else
    echo "❌ ELEVATER数据集"
fi

# 检查蒸馏模型
model_count=$(ls datapath/experiments/muge_finetune_*_distill/checkpoints/epoch_latest.pt 2>/dev/null | wc -l)
if [ "$model_count" -ge 3 ]; then
    echo "✅ 蒸馏模型 (${model_count}个)"
else
    echo "❌ 蒸馏模型 (${model_count}个)"
fi

# 检查GPU
gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
echo "✅ GPU数量: ${gpu_count}"

# 检查测试脚本
if [ -f "run_zeroshot_classification.sh" ] && [ -f "run_zeroshot_batch.sh" ]; then
    echo "✅ 测试脚本"
else
    echo "❌ 测试脚本"
fi
EOF
)
    
    echo "  ${server} 验证结果:"
    echo "$verification_result" | sed 's/^/    /'
done

# 部署完成
echo ""
echo "=================================================="
echo "🎉 分布式环境部署完成！"
echo ""
echo "部署摘要:"
echo "----------------------------------------------"
echo "✅ 环境搭建: v801, v802"
echo "✅ 数据同步: ELEVATER数据集已分发到所有服务器"
echo "✅ 模型分发: 蒸馏模型已分发到所有服务器"
echo "✅ 脚本部署: 测试脚本已部署到所有服务器"
echo "✅ 环境验证: 所有关键组件检查完成"
echo ""
echo "下一步:"
echo "----------------------------------------------"
echo "1. 运行分布式协调器:"
echo "   chmod +x distributed_coordinator.sh"
echo "   ./distributed_coordinator.sh"
echo ""
echo "2. 或者手动测试单个任务:"
echo "   ssh seetacloud-v801"
echo "   conda activate training"
echo "   cd /root/autodl-tmp"
echo "   ./run_zeroshot_classification.sh cifar-10 team"
echo ""
echo "3. 监控GPU使用情况:"
echo "   ssh seetacloud-v800 'nvidia-smi'"
echo "   ssh seetacloud-v801 'nvidia-smi'"
echo "   ssh seetacloud-v802 'nvidia-smi'"
echo "==================================================" 