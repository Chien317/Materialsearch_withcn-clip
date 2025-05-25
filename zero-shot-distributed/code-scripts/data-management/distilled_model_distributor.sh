#!/bin/bash

# 蒸馏模型分发脚本
# 从v800向其他服务器分发4个蒸馏模型

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  蒸馏模型分发器"
echo "=================================================="

# 服务器定义
SOURCE_SERVER="seetacloud-v800"  # 模型源服务器
TARGET_SERVERS=("seetacloud-v801" "seetacloud-v802")

# 蒸馏模型定义（4个模型）
DISTILLED_MODELS=(
    "muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill"
    "muge_finetune_vit-b-16_roberta-base_bs512_4gpu_large_distill"
    "muge_finetune_vit-b-16_roberta-base_bs512_4gpu_huge_distill"
    "muge_finetune_vit-b-16_roberta-base_bs512_4gpu_baseline_distill"
)

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 步骤1: 检查v800上的蒸馏模型
echo ""
echo "步骤1: 检查v800上的蒸馏模型"
echo "----------------------------------------------"

log "检查v800上的蒸馏模型..."

# 检查实际可用的蒸馏模型（4GPU版本，有完整checkpoints的）
AVAILABLE_MODELS=$(ssh ${SOURCE_SERVER} "find /root/autodl-tmp/datapath/experiments -name 'muge_finetune_*_4gpu_*_distill' -type d | grep -E '(team|large|huge)_distill$' | xargs -I {} sh -c 'if [ -f {}/checkpoints/epoch_latest.pt ]; then echo {}; fi'")

if [ -z "$AVAILABLE_MODELS" ]; then
    log "❌ 在v800上未找到任何完整的蒸馏模型"
    exit 1
fi

MODEL_COUNT=$(echo "$AVAILABLE_MODELS" | wc -l)
log "✅ 找到 ${MODEL_COUNT} 个完整的蒸馏模型："

echo "$AVAILABLE_MODELS" | while read model_path; do
    model_name=$(basename "$model_path")
    log "  - ${model_name}"
done

echo "总模型数量: ${MODEL_COUNT}"

# 步骤2: 创建模型压缩包
echo ""
echo "步骤2: 创建模型压缩包"
echo "----------------------------------------------"

log "在 ${SOURCE_SERVER} 上创建蒸馏模型压缩包..."
ssh ${SOURCE_SERVER} << 'EOF'
cd /root/autodl-tmp/datapath/experiments

# 只压缩实际存在且完整的模型
COMPLETE_MODELS=""
for model_dir in muge_finetune_vit-b-16_roberta-base_bs512_4gpu_*_distill; do
    if [ -d "$model_dir" ] && [ -f "$model_dir/checkpoints/epoch_latest.pt" ]; then
        COMPLETE_MODELS="$COMPLETE_MODELS $model_dir"
    fi
done

if [ -z "$COMPLETE_MODELS" ]; then
    echo "❌ 未找到完整的蒸馏模型"
    exit 1
fi

# 检查是否已有压缩包
if [ -f "distilled_models.tar.gz" ]; then
    echo "发现已存在的压缩包，检查是否需要更新..."
    
    # 检查压缩包是否比模型文件更新
    newest_model=$(find $COMPLETE_MODELS -name "epoch_latest.pt" -newer distilled_models.tar.gz 2>/dev/null | head -1)
    
    if [ -n "$newest_model" ]; then
        echo "检测到模型文件更新，重新创建压缩包..."
        rm -f distilled_models.tar.gz
    else
        echo "压缩包是最新的，跳过创建"
        exit 0
    fi
fi

echo "创建蒸馏模型压缩包..."
echo "压缩中的模型:"
for model_dir in $COMPLETE_MODELS; do
    echo "  - $model_dir"
done

# 使用tar创建压缩包，只压缩完整的模型
tar -czf distilled_models.tar.gz $COMPLETE_MODELS

if [ -f "distilled_models.tar.gz" ]; then
    size=$(du -sh distilled_models.tar.gz | cut -f1)
    echo "✅ 压缩包创建完成: distilled_models.tar.gz (${size})"
else
    echo "❌ 压缩包创建失败"
    exit 1
fi
EOF

# 步骤3: 分发模型到目标服务器
echo ""
echo "步骤3: 分发模型到目标服务器"
echo "----------------------------------------------"

for target_server in "${TARGET_SERVERS[@]}"; do
    log "开始向 ${target_server} 分发蒸馏模型..."
    
    # 创建目标目录
    ssh ${target_server} "mkdir -p /root/autodl-tmp/datapath/experiments"
    
    # 检查目标服务器是否已有相同的压缩包
    log "  检查 ${target_server} 上的现有模型..."
    existing_models=$(ssh ${target_server} "ls /root/autodl-tmp/datapath/experiments/muge_finetune_*_4gpu_*_distill/checkpoints/epoch_latest.pt 2>/dev/null | wc -l" || echo "0")
    
    if [ "$existing_models" -eq "$MODEL_COUNT" ]; then
        log "  ${target_server} 已有${MODEL_COUNT}个模型，检查是否需要更新..."
        
        # 比较时间戳（简单检查）
        source_timestamp=$(ssh ${SOURCE_SERVER} "stat -c %Y /root/autodl-tmp/datapath/experiments/distilled_models.tar.gz")
        target_timestamp=$(ssh ${target_server} "stat -c %Y /root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill/checkpoints/epoch_latest.pt 2>/dev/null || echo 0")
        
        if [ "$source_timestamp" -le "$target_timestamp" ]; then
            log "  ${target_server} 上的模型已是最新，跳过传输"
            continue
        fi
    fi
    
    # 传输压缩包
    log "  传输模型压缩包到 ${target_server}..."
    ssh ${SOURCE_SERVER} "scp /root/autodl-tmp/datapath/experiments/distilled_models.tar.gz ${target_server}:/root/autodl-tmp/datapath/experiments/"
    
    # 在目标服务器解压
    log "  在 ${target_server} 上解压模型..."
    ssh ${target_server} << 'EOF'
cd /root/autodl-tmp/datapath/experiments

if [ -f "distilled_models.tar.gz" ]; then
    echo "解压蒸馏模型..."
    tar -xzf distilled_models.tar.gz
    
    # 验证解压结果
    extracted_models=$(ls -d muge_finetune_*_distill 2>/dev/null | wc -l)
    echo "解压完成，共 ${extracted_models} 个模型目录"
    
    # 验证模型文件
    echo "验证模型文件:"
    for model_dir in muge_finetune_*_distill; do
        if [ -f "$model_dir/checkpoints/epoch_latest.pt" ]; then
            size=$(du -sh "$model_dir/checkpoints/epoch_latest.pt" | cut -f1)
            echo "  ✅ $model_dir: $size"
        else
            echo "  ❌ $model_dir: 模型文件缺失"
        fi
    done
    
    # 清理压缩包
    rm -f distilled_models.tar.gz
    echo "清理压缩包完成"
else
    echo "❌ 压缩包不存在，解压失败"
    exit 1
fi
EOF
    
    log "✅ ${target_server} 蒸馏模型分发完成"
done

# 步骤4: 验证分发结果
echo ""
echo "步骤4: 验证分发结果"
echo "----------------------------------------------"

ALL_SERVERS=("${SOURCE_SERVER}" "${TARGET_SERVERS[@]}")

for server in "${ALL_SERVERS[@]}"; do
    log "验证 ${server} 上的蒸馏模型..."
    
    model_info=$(ssh ${server} << 'EOF'
cd /root/autodl-tmp/datapath/experiments
echo "模型目录: $(pwd)"
echo "蒸馏模型数量: $(ls -d muge_finetune_*_distill 2>/dev/null | wc -l)"
echo "模型详情:"
for model_dir in muge_finetune_*_distill; do
    if [ -d "$model_dir" ] && [ -f "$model_dir/checkpoints/epoch_latest.pt" ]; then
        size=$(du -sh "$model_dir/checkpoints/epoch_latest.pt" | cut -f1)
        echo "  ✅ $model_dir: $size"
    elif [ -d "$model_dir" ]; then
        echo "  ❌ $model_dir: 模型文件缺失"
    fi
done
echo "总占用空间: $(du -sh muge_finetune_*_distill 2>/dev/null | tail -1 | cut -f1)"
EOF
)
    
    if [ $? -eq 0 ]; then
        echo "  ${server} 验证结果:"
        echo "$model_info" | sed 's/^/    /'
        
        # 检查模型数量是否正确
        model_count=$(ssh ${server} "ls -d /root/autodl-tmp/datapath/experiments/muge_finetune_*_4gpu_*_distill 2>/dev/null | wc -l")
        if [ "$model_count" -eq "$MODEL_COUNT" ]; then
            log "✅ ${server} 蒸馏模型验证通过 (${model_count}/${MODEL_COUNT})"
        else
            log "⚠️  ${server} 模型数量不正确 (${model_count}/${MODEL_COUNT})"
        fi
    else
        log "❌ ${server} 蒸馏模型验证失败"
    fi
    echo ""
done

# 步骤5: 清理源服务器压缩包
echo ""
echo "步骤5: 清理临时文件"
echo "----------------------------------------------"

log "清理 ${SOURCE_SERVER} 上的临时压缩包..."
ssh ${SOURCE_SERVER} << 'EOF'
cd /root/autodl-tmp/datapath/experiments
if [ -f "distilled_models.tar.gz" ]; then
    rm -f distilled_models.tar.gz
    echo "临时压缩包已清理"
fi
EOF

# 完成总结
echo ""
echo "=================================================="
echo "🎉 蒸馏模型分发完成！"
echo "=================================================="
echo ""
echo "分发总结:"
echo "----------------------------------------------"
echo "已分发的蒸馏模型 (${MODEL_COUNT}个):"
echo "$AVAILABLE_MODELS" | while read model_path; do
    model_name=$(basename "$model_path")
    echo "  📦 ${model_name}"
done
echo ""
echo "分发目标:"
echo "  ✅ ${SOURCE_SERVER} (源服务器)"
for target in "${TARGET_SERVERS[@]}"; do
    echo "  ✅ ${target}"
done
echo ""
echo "下一步:"
echo "  运行分布式协调器开始零样本分类测试"
echo "==================================================" 