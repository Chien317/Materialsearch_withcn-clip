#!/bin/bash

# 单卡测试模式配置脚本
# 修改分布式脚本支持单GPU测试，降低资源消耗

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  单卡测试模式配置器"
echo "=================================================="

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 检查脚本文件是否存在
SCRIPTS_TO_MODIFY=(
    "run_zeroshot_classification.sh"
    "run_zeroshot_batch.sh"
    "distributed_coordinator.sh"
)

echo ""
echo "步骤1: 检查脚本文件"
echo "----------------------------------------------"

missing_files=0
for script in "${SCRIPTS_TO_MODIFY[@]}"; do
    if [ -f "$script" ]; then
        log "✅ 找到脚本: $script"
    else
        log "❌ 脚本不存在: $script"
        missing_files=$((missing_files + 1))
    fi
done

if [ $missing_files -gt 0 ]; then
    echo "❌ 发现 $missing_files 个脚本文件缺失"
    echo "请确保在正确的目录下运行此脚本"
    exit 1
fi

# 创建备份
echo ""
echo "步骤2: 创建脚本备份"
echo "----------------------------------------------"

BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

for script in "${SCRIPTS_TO_MODIFY[@]}"; do
    cp "$script" "$BACKUP_DIR/"
    log "✅ 已备份: $script → $BACKUP_DIR/"
done

# 修改脚本以支持单卡模式
echo ""
echo "步骤3: 配置单卡测试模式"
echo "----------------------------------------------"

log "修改GPU配置..."

# 1. 修改 run_zeroshot_classification.sh
log "  修改 run_zeroshot_classification.sh..."
sed -i.bak '
# 将CUDA_VISIBLE_DEVICES设为单卡
s/export CUDA_VISIBLE_DEVICES="0,1,2,3"/export CUDA_VISIBLE_DEVICES="0"/g
# 减少batch size
s/BATCH_SIZE=${4:-64}/BATCH_SIZE=${4:-32}/g
# 添加单卡模式提示
/echo "开始零样本分类评估"/i\
echo "🧪 单卡测试模式：使用GPU 0，batch_size=32"
' run_zeroshot_classification.sh

# 2. 修改 run_zeroshot_batch.sh  
log "  修改 run_zeroshot_batch.sh..."
sed -i.bak '
# 将GPU配置改为单卡
s/export CUDA_VISIBLE_DEVICES="0,1,2,3"/export CUDA_VISIBLE_DEVICES="0"/g
# 减少并发任务数
s/MAX_PARALLEL_JOBS=4/MAX_PARALLEL_JOBS=1/g
# 添加单卡模式标识
/echo "开始批量零样本分类"/i\
echo "🧪 单卡测试模式：顺序执行任务，使用GPU 0"
' run_zeroshot_batch.sh

# 3. 修改 distributed_coordinator.sh
log "  修改 distributed_coordinator.sh..."
sed -i.bak '
# 减少每个服务器的任务数
s/TASKS_PER_SERVER=12/TASKS_PER_SERVER=3/g
# 添加测试模式说明
/echo "=== 分布式测试协调器启动 ==="/a\
log "🧪 单卡测试模式：每服务器运行3个任务进行验证"
' distributed_coordinator.sh

# 创建单卡模式的快速测试脚本
echo ""
echo "步骤4: 创建快速测试脚本"
echo "----------------------------------------------"

cat > single_gpu_quick_test.sh << 'EOF'
#!/bin/bash

# 单卡快速测试脚本
# 快速验证分布式环境是否正常工作

echo "=================================================="
echo "  单卡模式快速测试"
echo "=================================================="

# 测试参数
TEST_DATASET="cifar-10"
TEST_MODEL="1"  # team模型
TEST_SERVER="v800"
TEST_BATCH_SIZE="16"

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

echo ""
echo "测试配置:"
echo "----------------------------------------------"
echo "📊 数据集: $TEST_DATASET"
echo "🤖 模型: $TEST_MODEL (team)"
echo "🖥️  服务器: $TEST_SERVER"
echo "📦 批次大小: $TEST_BATCH_SIZE"
echo "🎯 GPU: 单卡模式 (GPU 0)"
echo ""

read -p "开始单卡快速测试？ (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "测试已取消。"
    exit 0
fi

log "🚀 开始单卡测试..."

# 运行测试
./run_zeroshot_classification.sh "$TEST_DATASET" "$TEST_MODEL" 0 "$TEST_BATCH_SIZE" "$TEST_SERVER"

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 单卡测试成功完成！"
    echo "分布式环境基础功能验证通过"
    echo ""
    echo "下一步建议："
    echo "1. 运行 ./restore_multi_gpu_mode.sh 恢复多卡模式"
    echo "2. 或继续进行完整的分布式测试"
else
    echo ""
    echo "❌ 单卡测试失败"
    echo "请检查环境配置和错误日志"
fi
EOF

chmod +x single_gpu_quick_test.sh
log "✅ 已创建单卡快速测试脚本"

# 创建恢复多卡模式的脚本
cat > restore_multi_gpu_mode.sh << 'EOF'
#!/bin/bash

# 恢复多卡模式脚本
# 将脚本配置恢复到4-GPU分布式模式

echo "=================================================="
echo "  恢复多卡分布式模式"
echo "=================================================="

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 找到最新的备份目录
LATEST_BACKUP=$(ls -dt backup_* 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "❌ 未找到备份文件"
    echo "无法恢复多卡模式，请手动检查脚本配置"
    exit 1
fi

log "从备份恢复: $LATEST_BACKUP"

# 恢复脚本
SCRIPTS=("run_zeroshot_classification.sh" "run_zeroshot_batch.sh" "distributed_coordinator.sh")

for script in "${SCRIPTS[@]}"; do
    if [ -f "$LATEST_BACKUP/$script" ]; then
        cp "$LATEST_BACKUP/$script" "./"
        log "✅ 已恢复: $script"
    else
        log "⚠️  备份中未找到: $script"
    fi
done

echo ""
echo "🎉 多卡模式恢复完成！"
echo "现在可以运行完整的4-GPU分布式测试"
EOF

chmod +x restore_multi_gpu_mode.sh
log "✅ 已创建多卡模式恢复脚本"

# 完成总结
echo ""
echo "=================================================="
echo "🎉 单卡测试模式配置完成！"
echo "=================================================="
echo ""
echo "已修改的脚本:"
echo "----------------------------------------------"
echo "✅ run_zeroshot_classification.sh → 单GPU + 小batch"
echo "✅ run_zeroshot_batch.sh → 顺序执行 + 单GPU"
echo "✅ distributed_coordinator.sh → 减少任务数"
echo ""
echo "新创建的脚本:"
echo "----------------------------------------------"
echo "✅ single_gpu_quick_test.sh → 快速测试"
echo "✅ restore_multi_gpu_mode.sh → 恢复多卡"
echo ""
echo "备份位置:"
echo "----------------------------------------------"
echo "📁 $BACKUP_DIR/"
echo ""
echo "快速开始:"
echo "----------------------------------------------"
echo "1. 配置SSH连接: ./setup_distributed_ssh.sh"
echo "2. 快速测试:     ./single_gpu_quick_test.sh"
echo "3. 恢复多卡:     ./restore_multi_gpu_mode.sh"
echo "==================================================" 