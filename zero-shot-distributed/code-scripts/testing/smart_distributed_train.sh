#!/bin/bash

echo "=================================================="
echo "  智能分布式训练启动器"
echo "=================================================="
echo "🎯 自动适配异构多机多卡环境"
echo ""

# 检查是否有配置文件
if [ ! -f "dynamic_gpu_config.env" ]; then
    echo "🔧 首次运行，检测GPU配置..."
    chmod +x detect_gpu_config.sh
    ./detect_gpu_config.sh
fi

# 加载配置
source dynamic_gpu_config.env

echo "📊 当前配置:"
echo "  - 总GPU数量: $TOTAL_GPUS"
echo "  - v800 GPU数量: $v800_GPUS"
echo "  - v801 GPU数量: $v801_GPUS"
echo "  - v802 GPU数量: $v802_GPUS"
echo "  - v803 GPU数量: $v803_GPUS"
echo ""

# 获取当前主机名
current_host=$(hostname)
echo "🖥️  当前运行节点: $current_host"

# 根据主机名确定GPU数量
if [[ "$current_host" == *"v800"* ]]; then
    LOCAL_GPU_COUNT=$v800_GPUS
    NODE_RANK=0
elif [[ "$current_host" == *"v801"* ]]; then
    LOCAL_GPU_COUNT=$v801_GPUS
    NODE_RANK=1
elif [[ "$current_host" == *"v802"* ]]; then
    LOCAL_GPU_COUNT=$v802_GPUS
    NODE_RANK=2

else
    echo "❌ 未知主机，尝试自动检测..."
    LOCAL_GPU_COUNT=$(python -c "import torch; print(torch.cuda.device_count())" 2>/dev/null || echo "0")
    NODE_RANK=0
fi

echo "🎮 本节点配置:"
echo "  - 本地GPU数量: $LOCAL_GPU_COUNT"
echo "  - 节点排名: $NODE_RANK"
echo ""

# 检查参数
if [ $# -eq 0 ]; then
    echo "❌ 错误: 请提供训练脚本路径"
    echo ""
    echo "用法: $0 <训练脚本> [其他参数...]"
    echo ""
    echo "示例:"
    echo "  $0 model_training/Chinese-CLIP/run_scripts/muge_finetune_vit-b-16_rbt-base.sh"
    echo "  $0 train.py --batch-size 32"
    exit 1
fi

TRAIN_SCRIPT="$1"
shift  # 移除第一个参数，剩余的作为训练参数

echo "🚀 启动分布式训练..."
echo "----------------------------------------------"
echo "训练脚本: $TRAIN_SCRIPT"
echo "额外参数: $@"
echo ""

# 根据脚本类型选择执行方式
if [[ "$TRAIN_SCRIPT" == *.sh ]]; then
    echo "📝 检测到Shell脚本，注入GPU配置..."
    
    # 创建临时包装脚本
    temp_script="/tmp/wrapped_$(basename "$TRAIN_SCRIPT")"
    
    cat > "$temp_script" << EOF
#!/bin/bash

# 自动注入的GPU配置
export CUDA_VISIBLE_DEVICES=\$(seq -s, 0 \$((${LOCAL_GPU_COUNT}-1)))
export LOCAL_GPU_COUNT=${LOCAL_GPU_COUNT}
export TOTAL_GPUS=${TOTAL_GPUS}
export NODE_RANK=${NODE_RANK}

echo "🎮 GPU配置已注入:"
echo "  CUDA_VISIBLE_DEVICES: \$CUDA_VISIBLE_DEVICES"
echo "  LOCAL_GPU_COUNT: \$LOCAL_GPU_COUNT"
echo "  TOTAL_GPUS: \$TOTAL_GPUS"
echo "  NODE_RANK: \$NODE_RANK"
echo ""

# 执行原始脚本
source "${TRAIN_SCRIPT}" $@
EOF
    
    chmod +x "$temp_script"
    
    # 执行包装后的脚本
    "$temp_script"
    
    # 清理临时文件
    rm -f "$temp_script"
    
elif [[ "$TRAIN_SCRIPT" == *.py ]]; then
    echo "🐍 检测到Python脚本，直接启动torchrun..."
    
    # 设置环境变量
    export CUDA_VISIBLE_DEVICES=$(seq -s, 0 $((LOCAL_GPU_COUNT-1)))
    export LOCAL_GPU_COUNT=$LOCAL_GPU_COUNT
    export TOTAL_GPUS=$TOTAL_GPUS
    export NODE_RANK=$NODE_RANK
    
    # 构建torchrun命令
    torchrun \
        --nnodes=4 \
        --nproc_per_node=$LOCAL_GPU_COUNT \
        --node_rank=$NODE_RANK \
        --rdzv_id=123 \
        --rdzv_backend=c10d \
        --rdzv_endpoint=seetacloud-v800:23456 \
        "$TRAIN_SCRIPT" "$@"
else
    echo "❌ 不支持的脚本类型: $TRAIN_SCRIPT"
    exit 1
fi

echo ""
echo "✅ 训练任务完成或已退出" 