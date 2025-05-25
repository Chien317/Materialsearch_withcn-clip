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
