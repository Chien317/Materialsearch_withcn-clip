#!/bin/bash

# 零样本图像分类启动脚本
# 基于Chinese-CLIP官方zeroshot_eval.sh，适配蒸馏模型评估

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "========== 零样本图像分类评估 =========="

# 显示模型选择菜单
echo ""
echo "可用模型:"
echo "  1. TEAM蒸馏模型"
echo "  2. Large蒸馏模型" 
echo "  3. Huge蒸馏模型"
echo "  4. Baseline基准模型"
echo ""

# 解析参数
if [ $# -ge 2 ]; then
    # 有足够参数，解析输入
    DATASET_NAME=$1
    
    # 检查第二个参数是数字还是字符串
    if [[ $2 =~ ^[1-4]$ ]]; then
        # 是数字，转换为模型类型
        case $2 in
            1) MODEL_TYPE="team" ;;
            2) MODEL_TYPE="large" ;;
            3) MODEL_TYPE="huge" ;;
            4) MODEL_TYPE="baseline" ;;
        esac
    else
        # 是字符串，直接使用
        MODEL_TYPE=$2
    fi
    
    GPU_ID=${3:-0}
    BATCH_SIZE=${4:-32}
    
    # 询问服务器选择
    if [ $# -ge 5 ]; then
        server_choice=$5
    else
        read -p "请选择服务器 (v800/h20/v801/v802): " server_choice
    fi
elif [ $# -eq 1 ]; then
    # 只提供了数据集名称，交互式选择其他参数
    DATASET_NAME=$1
    read -p "请选择模型 (1-4): " model_choice
    case $model_choice in
        1) MODEL_TYPE="team" ;;
        2) MODEL_TYPE="large" ;;
        3) MODEL_TYPE="huge" ;;
        4) MODEL_TYPE="baseline" ;;
        *) echo "错误：无效的模型选择"; exit 1 ;;
    esac
    read -p "GPU ID (默认: 0): " GPU_ID
    GPU_ID=${GPU_ID:-0}
    read -p "Batch Size (默认: 64): " BATCH_SIZE
    BATCH_SIZE=${BATCH_SIZE:-64}
    read -p "请选择服务器 (v800/h20/v801/v802): " server_choice
else
    # 完全交互式选择
    echo ""
    echo "数据集示例: cifar-10, cifar-100, caltech-101, oxford-flower-102, food-101, etc."
    read -p "请输入数据集名称: " DATASET_NAME
    
    read -p "请选择模型 (1-4): " model_choice
    case $model_choice in
        1) MODEL_TYPE="team" ;;
        2) MODEL_TYPE="large" ;;
        3) MODEL_TYPE="huge" ;;
        4) MODEL_TYPE="baseline" ;;
        *) echo "错误：无效的模型选择"; exit 1 ;;
    esac
    
    read -p "GPU ID (默认: 0): " GPU_ID
    GPU_ID=${GPU_ID:-0}
    read -p "Batch Size (默认: 64): " BATCH_SIZE
    BATCH_SIZE=${BATCH_SIZE:-64}
    read -p "请选择服务器 (v800/h20/v801/v802): " server_choice
fi

# 验证并设置服务器
case $server_choice in
    v800|V800)
        SSH_TARGET="seetacloud-v800"
        SERVER_DESC="4-GPU A800 server"
        ;;
    h20|H20)
        SSH_TARGET="seetacloud-h20"
        SERVER_DESC="4-GPU H20 server"
        ;;
    v801|V801)
        SSH_TARGET="seetacloud-v801"
        SERVER_DESC="4-GPU server"
        ;;
    v802|V802)
        SSH_TARGET="seetacloud-v802"
        SERVER_DESC="4-GPU server with large storage"
        ;;
    *)
        echo "错误：无效的服务器选择 '$server_choice'。请选择 'v800', 'h20', 'v801' 或 'v802'。"
        exit 1
        ;;
esac

# 验证模型类型
case ${MODEL_TYPE} in
    team|large|huge|baseline)
        echo "✓ 使用模型类型: ${MODEL_TYPE}"
        ;;
    *)
        echo "❌ 错误: 不支持的模型类型 '${MODEL_TYPE}'"
        echo "支持的模型类型: team, large, huge, baseline"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "  评估配置确认"
echo "=========================================="
echo "数据集: ${DATASET_NAME}"
echo "模型类型: ${MODEL_TYPE}"
echo "GPU设备: ${GPU_ID}"
echo "批处理大小: ${BATCH_SIZE}"
echo "服务器: $server_choice ($SERVER_DESC)"
echo "SSH目标: $SSH_TARGET"
echo ""

# 确认执行
read -p "确认开始零样本分类评估吗？(y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "评估已取消。"
    exit 0
fi

echo "正在启动远程零样本分类评估..."
echo "=========================================="

# 连接到云服务器并执行评估
ssh ${SSH_TARGET} << EOF
    # 激活conda环境
    source /root/miniconda3/bin/activate
    conda activate training
    
    # 设置基础路径和模型配置
    export DATAPATH="/root/autodl-tmp/datapath"
    export WORKSPACE="/root/autodl-tmp"
    export CUDA_VISIBLE_DEVICES=${GPU_ID}

    # 模型路径映射
    case "${MODEL_TYPE}" in
        team)
            MODEL_PATH="\${DATAPATH}/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill/checkpoints/epoch_latest.pt"
            ;;
        large)
            MODEL_PATH="\${DATAPATH}/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_large_distill/checkpoints/epoch_latest.pt"
            ;;
        huge)
            MODEL_PATH="\${DATAPATH}/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_huge_distill/checkpoints/epoch_latest.pt"
            ;;
            baseline)
        MODEL_PATH="\${DATAPATH}/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_a800/checkpoints/epoch_latest.pt"
            ;;
    esac

    # 设置数据集和保存路径
    DATASET_DIR="\${DATAPATH}/datasets/ELEVATER/${DATASET_NAME}"
    TEST_DATA_DIR="\${DATASET_DIR}/test"
    LABEL_FILE="\${DATASET_DIR}/label_cn.txt"
    SAVE_DIR="\${DATAPATH}/zeroshot_predictions/${MODEL_TYPE}"
    INDEX_FILE="\${DATASET_DIR}/index.json"

    # 设置模型配置
    VISION_MODEL="ViT-B-16"
    TEXT_MODEL="RoBERTa-wwm-ext-base-chinese"

    # 检查必要文件
    echo "[检查] 验证必要文件和路径..."

    if [ ! -d "\${TEST_DATA_DIR}" ]; then
        echo "❌ 错误: 测试数据目录不存在: \${TEST_DATA_DIR}"
        echo "请确保ELEVATER数据集已正确下载和解压"
        exit 1
    fi

    if [ ! -f "\${LABEL_FILE}" ]; then
        echo "❌ 错误: 标签文件不存在: \${LABEL_FILE}"
        exit 1
    fi

    if [ ! -f "\${MODEL_PATH}" ]; then
        echo "❌ 错误: 模型文件不存在: \${MODEL_PATH}"
        echo "请确保蒸馏模型已训练完成"
        exit 1
    fi

    # 检查Chinese-CLIP代码库
    CLIP_DIR="\${WORKSPACE}/Chinese-CLIP"
    if [ ! -d "\${CLIP_DIR}" ]; then
        echo "❌ 错误: Chinese-CLIP代码库不存在: \${CLIP_DIR}"
        echo "请先运行setup_environment.sh"
        exit 1
    fi

    echo "✓ 所有必要文件检查通过"

    # 创建保存目录
    mkdir -p \${SAVE_DIR}

    # 进入Chinese-CLIP目录
    cd \${CLIP_DIR}

    # 设置Python路径
    export PYTHONPATH=\${PYTHONPATH}:\${CLIP_DIR}/cn_clip

    echo ""
    echo "[配置] 零样本分类参数:"
    echo "  数据集: ${DATASET_NAME}"
    echo "  模型类型: ${MODEL_TYPE}"
    echo "  GPU设备: ${GPU_ID}"
    echo "  批处理大小: ${BATCH_SIZE}"
    echo "  测试数据: \${TEST_DATA_DIR}"
    echo "  标签文件: \${LABEL_FILE}"
    echo "  模型路径: \${MODEL_PATH}"
    echo "  保存目录: \${SAVE_DIR}"
    echo ""

    # 检查是否存在index.json文件（某些ELEVATER数据集需要）
    INDEX_PARAM=""
    if [ -f "\${INDEX_FILE}" ]; then
        echo "✓ 检测到index.json文件，将应用样本重排序"
        INDEX_PARAM="--index \${INDEX_FILE}"
    fi

    echo "[开始] 零样本图像分类评估..."
    echo "=========================================="

    # 运行零样本分类评估
    python -u cn_clip/eval/zeroshot_evaluation.py \
        --datapath="\${TEST_DATA_DIR}" \
        --label-file="\${LABEL_FILE}" \
        --save-dir="\${SAVE_DIR}" \
        --dataset="${DATASET_NAME}" \
        \${INDEX_PARAM} \
        --img-batch-size=${BATCH_SIZE} \
        --resume="\${MODEL_PATH}" \
        --vision-model="\${VISION_MODEL}" \
        --text-model="\${TEXT_MODEL}" \
        --precision="amp" \
        --context-length=52 \
        --num-workers=4

    echo ""
    echo "=========================================="
    echo "✅ 零样本分类评估完成！"
    echo ""
    echo "结果文件保存在: \${SAVE_DIR}/${DATASET_NAME}.json"
    echo ""
    echo "模型信息:"
    echo "  模型类型: ${MODEL_TYPE}"
    echo "  数据集: ${DATASET_NAME}"
    echo "  GPU设备: ${GPU_ID}"
    echo "  批处理大小: ${BATCH_SIZE}"

    # 显示结果文件
    if [ -f "\${SAVE_DIR}/${DATASET_NAME}.json" ]; then
        echo ""
        echo "评估结果预览:"
        echo "----------------------------------------"
        head -5 "\${SAVE_DIR}/${DATASET_NAME}.json" | jq '.' 2>/dev/null || head -5 "\${SAVE_DIR}/${DATASET_NAME}.json"
        echo "----------------------------------------"
    fi

    echo ""
    echo "🎉 零样本分类评估任务完成！"
EOF

echo ""
echo "=========================================="
echo "远程评估执行完毕"
echo "==========================================" 