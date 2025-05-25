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
