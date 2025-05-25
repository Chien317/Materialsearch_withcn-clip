#!/bin/bash

# 批量零样本图像分类测试脚本
# 可以同时测试多个数据集和多个模型类型
# 支持本地运行，通过SSH连接到云服务器执行

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

# 显示菜单
echo "=========================================="
echo "  批量零样本图像分类测试管理器"
echo "=========================================="
echo "请选择测试模式："
echo "  1. 单个模型，多个数据集"
echo "  2. 多个模型，单个数据集"
echo "  3. 多个模型，多个数据集（全组合）"
echo "  4. 自定义选择"
echo ""
echo "蒸馏模型选项："
echo "  1. TEAM 蒸馏模型"
echo "  2. Large 蒸馏模型"
echo "  3. Huge 蒸馏模型"
echo "  4. Baseline 基准模型"
echo ""
echo "可用服务器："
echo "  v800: 4-GPU A800 server (seetacloud-v800)"
echo "  h20:  4-GPU H20 server (seetacloud-h20)"
echo "  v801: 4-GPU server (seetacloud-v801)"
echo "  v802: 4-GPU server with large storage (seetacloud-v802)"
echo "=========================================="

# 处理参数
if [ $# -ge 2 ]; then
    # 提供了参数，直接使用
    test_mode=$1
    server_choice=$2
    GPU_ID=${3:-0}
    BATCH_SIZE=${4:-64}
else
    # 交互式选择
    read -p "请选择测试模式 (1-4): " test_mode
    read -p "请选择服务器 (v800/h20/v801/v802): " server_choice
    read -p "GPU ID (默认: 0): " GPU_ID
    GPU_ID=${GPU_ID:-0}
    read -p "Batch Size (默认: 64): " BATCH_SIZE
    BATCH_SIZE=${BATCH_SIZE:-64}
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

# 定义要测试的数据集（根据ELEVATER数据集）
ALL_DATASETS=(
    "cifar-10"
    "cifar-100"
    "caltech-101"
    "oxford-flower-102"
    "food-101"
    "fgvc-aircraft-2013b-variants102"
    "eurosat_clip"
    "resisc45_clip"
    "country211"
)

# 定义模型类型映射
MODEL_NAMES=("team" "large" "huge" "baseline")
MODEL_DESCS=("TEAM蒸馏模型" "Large蒸馏模型" "Huge蒸馏模型" "Baseline基准模型")

# 根据测试模式选择数据集和模型
case $test_mode in
    1)
        echo ""
        echo "=== 单个模型，多个数据集模式 ==="
        read -p "请选择模型 (1-4): " model_choice
        if [[ ! "$model_choice" =~ ^[1-4]$ ]]; then
            echo "错误：无效的模型选择"
            exit 1
        fi
        MODELS=(${MODEL_NAMES[$((model_choice-1))]})
        
        echo "可用数据集："
        for i in "${!ALL_DATASETS[@]}"; do
            echo "  $((i+1)). ${ALL_DATASETS[i]}"
        done
        echo "请选择要测试的数据集（用空格分隔数字，如: 1 2 3）："
        read -a dataset_choices
        DATASETS=()
        for choice in "${dataset_choices[@]}"; do
            if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#ALL_DATASETS[@]}" ]; then
                DATASETS+=(${ALL_DATASETS[$((choice-1))]})
            fi
        done
        ;;
    2)
        echo ""
        echo "=== 多个模型，单个数据集模式 ==="
        echo "可用数据集："
        for i in "${!ALL_DATASETS[@]}"; do
            echo "  $((i+1)). ${ALL_DATASETS[i]}"
        done
        read -p "请选择数据集: " dataset_choice
        if [[ ! "$dataset_choice" =~ ^[1-9][0-9]*$ ]] || [ "$dataset_choice" -gt "${#ALL_DATASETS[@]}" ]; then
            echo "错误：无效的数据集选择"
            exit 1
        fi
        DATASETS=(${ALL_DATASETS[$((dataset_choice-1))]})
        
        echo "请选择要测试的模型（用空格分隔数字，如: 1 2 3）："
        read -a model_choices
        MODELS=()
        for choice in "${model_choices[@]}"; do
            if [[ "$choice" =~ ^[1-4]$ ]]; then
                MODELS+=(${MODEL_NAMES[$((choice-1))]})
            fi
        done
        ;;
    3)
        echo ""
        echo "=== 多个模型，多个数据集（全组合）模式 ==="
        DATASETS=("${ALL_DATASETS[@]}")
        MODELS=("${MODEL_NAMES[@]}")
        ;;
    4)
        echo ""
        echo "=== 自定义选择模式 ==="
        echo "可用数据集："
        for i in "${!ALL_DATASETS[@]}"; do
            echo "  $((i+1)). ${ALL_DATASETS[i]}"
        done
        echo "请选择要测试的数据集（用空格分隔数字）："
        read -a dataset_choices
        DATASETS=()
        for choice in "${dataset_choices[@]}"; do
            if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#ALL_DATASETS[@]}" ]; then
                DATASETS+=(${ALL_DATASETS[$((choice-1))]})
            fi
        done
        
        echo "请选择要测试的模型（用空格分隔数字）："
        read -a model_choices
        MODELS=()
        for choice in "${model_choices[@]}"; do
            if [[ "$choice" =~ ^[1-4]$ ]]; then
                MODELS+=(${MODEL_NAMES[$((choice-1))]})
            fi
        done
        ;;
    *)
        echo "错误：无效的测试模式选择"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "  批量测试配置确认"
echo "=========================================="
echo "测试模式: $test_mode"
echo "服务器: $server_choice ($SERVER_DESC)"
echo "GPU设备: ${GPU_ID}"
echo "批处理大小: ${BATCH_SIZE}"
echo ""
echo "将测试的数据集 (${#DATASETS[@]}个):"
for dataset in "${DATASETS[@]}"; do
    echo "  - $dataset"
done
echo ""
echo "将测试的模型 (${#MODELS[@]}个):"
for i in "${!MODELS[@]}"; do
    # 找到模型在原数组中的索引
    for j in "${!MODEL_NAMES[@]}"; do
        if [ "${MODELS[i]}" = "${MODEL_NAMES[j]}" ]; then
            echo "  - ${MODELS[i]} (${MODEL_DESCS[j]})"
            break
        fi
    done
done
echo ""
echo "总共测试组合数: $((${#DATASETS[@]} * ${#MODELS[@]}))"
echo ""

# 确认执行
read -p "确认开始批量测试吗？(y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "批量测试已取消。"
    exit 0
fi

# 创建结果汇总文件
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SUMMARY_FILE="/tmp/zeroshot_batch_results_${TIMESTAMP}.csv"

echo "数据集,模型类型,Top-1准确率,参数数量,状态" > ${SUMMARY_FILE}

echo ""
echo "=========================================="
echo "正在启动批量零样本分类测试..."
echo "结果将保存到: ${SUMMARY_FILE}"
echo "=========================================="

# 循环测试所有组合
total_tests=$((${#DATASETS[@]} * ${#MODELS[@]}))
current_test=0

for dataset in "${DATASETS[@]}"; do
    for model in "${MODELS[@]}"; do
        current_test=$((current_test + 1))
        echo ""
        echo "=========================================="
        echo "进度: ${current_test}/${total_tests}"
        echo "测试: ${dataset} + ${model}模型"
        echo "=========================================="
        
        # 通过SSH运行单个测试
        echo "正在连接云服务器执行测试..."
        
        if ssh ${SSH_TARGET} << EOF
            # 激活conda环境
            source /root/miniconda3/bin/activate
            conda activate training
            
            # 设置基础路径和模型配置
            export DATAPATH="/root/autodl-tmp/datapath"
            export WORKSPACE="/root/autodl-tmp"
            export CUDA_VISIBLE_DEVICES=${GPU_ID}

            # 模型路径映射
            case "${model}" in
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
                    MODEL_PATH="\${DATAPATH}/experiments/muge_finetune_vit-b-16_roberta-base_bs128_1gpu_baseline/checkpoints/epoch_latest.pt"
                    ;;
            esac

            # 设置数据集和保存路径
            DATASET_DIR="\${DATAPATH}/datasets/ELEVATER/${dataset}"
            TEST_DATA_DIR="\${DATASET_DIR}/test"
            LABEL_FILE="\${DATASET_DIR}/label_cn.txt"
            SAVE_DIR="\${DATAPATH}/zeroshot_predictions/${model}"
            INDEX_FILE="\${DATASET_DIR}/index.json"

            # 设置模型配置
            VISION_MODEL="ViT-B-16"
            TEXT_MODEL="RoBERTa-wwm-ext-base-chinese"

            # 快速检查必要文件
            if [ ! -d "\${TEST_DATA_DIR}" ] || [ ! -f "\${LABEL_FILE}" ] || [ ! -f "\${MODEL_PATH}" ]; then
                echo "❌ 错误: 必要文件缺失，跳过此测试"
                exit 1
            fi

            # 创建保存目录
            mkdir -p \${SAVE_DIR}

            # 进入Chinese-CLIP目录
            cd \${WORKSPACE}/Chinese-CLIP

            # 设置Python路径
            export PYTHONPATH=\${PYTHONPATH}:\${WORKSPACE}/Chinese-CLIP/cn_clip

            echo "开始执行: ${dataset} + ${model}"

            # 检查是否存在index.json文件
            INDEX_PARAM=""
            if [ -f "\${INDEX_FILE}" ]; then
                INDEX_PARAM="--index \${INDEX_FILE}"
            fi

            # 运行零样本分类评估
            python -u cn_clip/eval/zeroshot_evaluation.py \\
                --datapath="\${TEST_DATA_DIR}" \\
                --label-file="\${LABEL_FILE}" \\
                --save-dir="\${SAVE_DIR}" \\
                --dataset="${dataset}" \\
                \${INDEX_PARAM} \\
                --img-batch-size=${BATCH_SIZE} \\
                --resume="\${MODEL_PATH}" \\
                --vision-model="\${VISION_MODEL}" \\
                --text-model="\${TEXT_MODEL}" \\
                --precision="amp" \\
                --context-length=52 \\
                --num-workers=4

            echo "测试完成: ${dataset} + ${model}"
EOF
        then
            echo "✅ ${dataset} + ${model} 测试成功"
            
            # 尝试从云服务器获取结果
            result_file="/root/autodl-tmp/datapath/zeroshot_predictions/${model}/${dataset}.json"
            if ssh ${SSH_TARGET} "[ -f '${result_file}' ]"; then
                # 提取结果（这里可能需要根据实际输出格式调整）
                top1_acc=$(ssh ${SSH_TARGET} "grep -o '\"zeroshot-top1\": [0-9.]*' '${result_file}' | head -1 | cut -d':' -f2 | tr -d ' '" 2>/dev/null || echo "N/A")
                echo "${dataset},${model},${top1_acc},N/A,成功" >> ${SUMMARY_FILE}
            else
                echo "${dataset},${model},N/A,N/A,文件未找到" >> ${SUMMARY_FILE}
            fi
        else
            echo "❌ ${dataset} + ${model} 测试失败"
            echo "${dataset},${model},N/A,N/A,失败" >> ${SUMMARY_FILE}
        fi
        
        sleep 2  # 短暂休息，避免GPU过热
    done
done

echo ""
echo "=========================================="
echo "🎉 批量测试完成！"
echo ""
echo "结果汇总:"
echo "----------------------------------------"
cat ${SUMMARY_FILE}
echo "----------------------------------------"
echo ""
echo "详细结果文件: ${SUMMARY_FILE}"
echo ""

# 显示最佳性能模型
echo "性能分析:"
echo "----------------------------------------"
best_line=$(tail -n +2 ${SUMMARY_FILE} | sort -t',' -k3 -nr | head -1)
if [ ! -z "${best_line}" ]; then
    dataset=$(echo ${best_line} | cut -d',' -f1)
    model=$(echo ${best_line} | cut -d',' -f2)
    acc=$(echo ${best_line} | cut -d',' -f3)
    echo "最佳性能: ${model}模型在${dataset}上达到${acc}准确率"
fi
echo "----------------------------------------"
echo ""
echo "常用监控命令："
echo "  查看云服务器结果：ssh $SSH_TARGET 'ls -la /root/autodl-tmp/datapath/zeroshot_predictions/*/'"
echo "  GPU状态：ssh $SSH_TARGET 'nvidia-smi'"
echo "==========================================" 