#!/bin/bash

# Distillation Model Evaluation Manager
# 该脚本管理不同蒸馏模型的评估流程
# 使用方法：./run_distillation_evaluation.sh [模型选项号] [评估方式] [服务器]

# 显示菜单
echo "=========================================="
echo "    蒸馏模型评估管理器"
echo "=========================================="
echo "请选择蒸馏模型："
echo "  1. TEAM 蒸馏模型"
echo "  2. Large 蒸馏模型" 
echo "  3. Huge 蒸馏模型"
echo "  4. Baseline 基准模型"
echo ""
echo "请选择评估方式："
echo "  A. 快速评估 - 分步执行 (Quick Evaluation)"
echo "     a. 仅特征提取 (Extract)"
echo "     b. 仅KNN检索 (KNN)"
echo "     c. 仅Recall计算 (Recall)"
echo "  B. 完整评估 - 一键全流程 (Full Evaluation)"
echo ""
echo "可用服务器："
echo "  v800: 4-GPU A800 server (seetacloud-v800)"
echo "  h20:  1-GPU H20 server (seetacloud-h20)"
echo "  v801: New GPU server (seetacloud-v801)"
echo "=========================================="

# 处理参数
if [ $# -eq 3 ]; then
    # 三个参数都提供了
    model_choice=$1
    eval_choice=$2
    server_choice=$3
elif [ $# -eq 2 ]; then
    # 提供了模型和评估方式，询问服务器
    model_choice=$1
    eval_choice=$2
    echo "Model $model_choice and evaluation $eval_choice selected."
    read -p "请选择服务器 (v800/h20/v801): " server_choice
elif [ $# -eq 1 ]; then
    # 只提供了模型，询问评估方式和服务器
    model_choice=$1
    echo "Model $model_choice selected."
    read -p "请选择评估方式 (A/a/b/c/B): " eval_choice
    read -p "请选择服务器 (v800/h20/v801): " server_choice
elif [ $# -eq 0 ]; then
    # 没有参数，交互式选择
    read -p "请选择模型 (1-4): " model_choice
    read -p "请选择评估方式 (A/a/b/c/B): " eval_choice
    read -p "请选择服务器 (v800/h20/v801): " server_choice
else
    echo "错误：参数过多。"
    echo "使用方法：$0 <model_type> <eval_type> <server>"
    exit 1
fi

# 验证并设置服务器
case $server_choice in
    v800|V800)
        SSH_TARGET="seetacloud-v800"
        SERVER_DESC="4-GPU A800 server"
        ;;
    h20|H20)
        SSH_TARGET="seetacloud-h20"
        SERVER_DESC="1-GPU H20 server"
        ;;
    v801|V801)
        SSH_TARGET="seetacloud-v801"
        SERVER_DESC="New GPU server"
        ;;
    *)
        echo "错误：无效的服务器选择 '$server_choice'。请选择 'v800', 'h20' 或 'v801'。"
        exit 1
        ;;
esac

# 设置数据路径和数据集（固定参数）
DATAPATH="/root/autodl-tmp/datapath"
DATASET_NAME="Flickr30k-CN"
VISION_MODEL="ViT-B-16"
TEXT_MODEL="RoBERTa-wwm-ext-base-chinese"

# 设置模型路径和描述
case $model_choice in
    1)
        MODEL_PATH="/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill/checkpoints/epoch_latest.pt"
        MODEL_DESC="TEAM 蒸馏模型"
        MODEL_NAME="team_distill"
        ;;
    2)
        MODEL_PATH="/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_large_distill/checkpoints/epoch_latest.pt"
        MODEL_DESC="Large 蒸馏模型"
        MODEL_NAME="large_distill"
        ;;
    3)
        MODEL_PATH="/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_huge_distill/checkpoints/epoch_latest.pt"
        MODEL_DESC="Huge 蒸馏模型"
        MODEL_NAME="huge_distill"
        ;;
    4)
        MODEL_PATH="/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs128_1gpu_baseline/checkpoints/epoch_latest.pt"
        MODEL_DESC="Baseline 基准模型"
        MODEL_NAME="baseline"
        ;;
    *)
        echo "Invalid model choice. Please select 1, 2, 3, or 4."
        exit 1
        ;;
esac

# 设置评估方式和命令
case $eval_choice in
    A)
        EVAL_DESC="快速评估 - 完整分步执行 (Extract + KNN + Recall)"
        EVAL_MODE="quick_full"
        ;;
    a)
        EVAL_DESC="快速评估 - 仅特征提取 (Extract)"
        EVAL_MODE="quick_extract"
        ;;
    b)
        EVAL_DESC="快速评估 - 仅KNN检索 (KNN)"
        EVAL_MODE="quick_knn"
        ;;
    c)
        EVAL_DESC="快速评估 - 仅Recall计算 (Recall)"
        EVAL_MODE="quick_recall"
        ;;
    B)
        EVAL_DESC="完整评估 - 一键全流程 (Full Evaluation)"
        EVAL_MODE="full"
        ;;
    *)
        echo "Invalid evaluation choice. Please select A, a, b, c, or B."
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "  评估配置确认"
echo "=========================================="
echo "选择的模型：$MODEL_DESC"
echo "评估方式：$EVAL_DESC"
echo "服务器：$server_choice ($SERVER_DESC)"
echo "SSH目标：$SSH_TARGET"
echo "数据集：$DATASET_NAME"
echo ""

# 确认执行
read -p "确认开始评估吗？(y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "评估已取消。"
    exit 0
fi

echo "正在启动评估..."
echo "=========================================="

# 开始时间记录
START_TIME=$(date)
echo "评估开始时间: $START_TIME"
echo ""

# 根据评估模式执行不同命令
case "$EVAL_MODE" in
    quick_extract)
        echo "=== 开始特征提取 ==="
        python quick_evaluation.py --server "$SSH_TARGET" --step extract --datapath "$DATAPATH" --dataset-name "$DATASET_NAME" --model-path "$MODEL_PATH" --vision-model "$VISION_MODEL" --text-model "$TEXT_MODEL"
        ;;
    quick_knn)
        echo "=== 开始KNN检索 ==="
        python quick_evaluation.py --server "$SSH_TARGET" --step knn --datapath "$DATAPATH" --dataset-name "$DATASET_NAME"
        ;;
    quick_recall)
        echo "=== 开始Recall计算 ==="
        python quick_evaluation.py --server "$SSH_TARGET" --step recall --datapath "$DATAPATH" --dataset-name "$DATASET_NAME"
        ;;
    quick_full)
        echo "=== 开始完整快速评估 ==="
        echo "第1步：特征提取..."
        python quick_evaluation.py --server "$SSH_TARGET" --step extract --datapath "$DATAPATH" --dataset-name "$DATASET_NAME" --model-path "$MODEL_PATH" --vision-model "$VISION_MODEL" --text-model "$TEXT_MODEL"
        echo ""
        echo "第2步：KNN检索..."
        python quick_evaluation.py --server "$SSH_TARGET" --step knn --datapath "$DATAPATH" --dataset-name "$DATASET_NAME"
        echo ""
        echo "第3步：Recall计算..."
        python quick_evaluation.py --server "$SSH_TARGET" --step recall --datapath "$DATAPATH" --dataset-name "$DATASET_NAME"
        ;;
    full)
        echo "=== 开始完整评估（直接在服务器上执行）==="
        
        # 上传评估脚本到云服务器（仅full模式需要）
        echo "正在上传评估脚本到云服务器..."
        scp distillation_model_evaluation.py ${SSH_TARGET}:~/
        
        # 连接到云服务器并执行评估
        ssh ${SSH_TARGET} << EOF
            # 激活conda环境
            source /root/miniconda3/bin/activate
            conda activate training
            
            # 进入项目目录
            cd /root/autodl-tmp/Chinese-CLIP
            
            # 移动脚本到项目目录
            mv ~/distillation_model_evaluation.py .
            
            # 显示GPU状态
            echo "=== GPU状态检查 ==="
            nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free --format=csv,noheader,nounits
            echo "==================="
            
            # 开始时间记录
            START_TIME=\$(date)
            echo "评估开始时间: \$START_TIME"
            echo ""
            
            # 根据评估模式执行不同命令
            case "$EVAL_MODE" in
                quick_extract)
                    echo "=== 开始特征提取 ==="
                    python quick_evaluation.py --server "$SSH_TARGET" --step extract --datapath "$DATAPATH" --dataset-name "$DATASET_NAME" --model-path "$MODEL_PATH" --vision-model "$VISION_MODEL" --text-model "$TEXT_MODEL"
                    ;;
                quick_knn)
                    echo "=== 开始KNN检索 ==="
                    python quick_evaluation.py --server "$SSH_TARGET" --step knn --datapath "$DATAPATH" --dataset-name "$DATASET_NAME"
                    ;;
                quick_recall)
                    echo "=== 开始Recall计算 ==="
                    python quick_evaluation.py --server "$SSH_TARGET" --step recall --datapath "$DATAPATH" --dataset-name "$DATASET_NAME"
                    ;;
                quick_full)
                    echo "=== 开始完整快速评估 ==="
                    echo "第1步：特征提取..."
                    python quick_evaluation.py --server "$SSH_TARGET" --step extract --datapath "$DATAPATH" --dataset-name "$DATASET_NAME" --model-path "$MODEL_PATH" --vision-model "$VISION_MODEL" --text-model "$TEXT_MODEL"
                    echo ""
                    echo "第2步：KNN检索..."
                    python quick_evaluation.py --server "$SSH_TARGET" --step knn --datapath "$DATAPATH" --dataset-name "$DATASET_NAME"
                    echo ""
                    echo "第3步：Recall计算..."
                    python quick_evaluation.py --server "$SSH_TARGET" --step recall --datapath "$DATAPATH" --dataset-name "$DATASET_NAME"
                    ;;
                full)
                    echo "=== 开始完整评估 ==="
                    
                    # 步骤1: 图文特征提取
                    echo "第1步：图文特征提取..."
                    export CUDA_VISIBLE_DEVICES=0
                    export PYTHONPATH=\${PYTHONPATH}:\$(pwd)/cn_clip
                    python -u cn_clip/eval/extract_features.py \\
                        --extract-image-feats \\
                        --extract-text-feats \\
                        --image-data="$DATAPATH/datasets/$DATASET_NAME/lmdb/valid/imgs" \\
                        --text-data="$DATAPATH/datasets/$DATASET_NAME/valid_texts.jsonl" \\
                        --img-batch-size=32 \\
                        --text-batch-size=32 \\
                        --context-length=52 \\
                        --resume="$MODEL_PATH" \\
                        --vision-model="$VISION_MODEL" \\
                        --text-model="$TEXT_MODEL"
                    
                    echo ""
                    echo "第2步：文到图检索 (KNN)..."
                    python -u cn_clip/eval/make_topk_predictions.py \\
                        --image-feats="$DATAPATH/datasets/$DATASET_NAME/valid_imgs.img_feat.jsonl" \\
                        --text-feats="$DATAPATH/datasets/$DATASET_NAME/valid_texts.txt_feat.jsonl" \\
                        --top-k=10 \\
                        --eval-batch-size=32768 \\
                        --output="$DATAPATH/datasets/$DATASET_NAME/valid_predictions.jsonl"
                    
                    echo ""
                    echo "第3步：文到图检索 Recall计算..."
                    python cn_clip/eval/evaluation.py \\
                        "$DATAPATH/datasets/$DATASET_NAME/valid_texts.jsonl" \\
                        "$DATAPATH/datasets/$DATASET_NAME/valid_predictions.jsonl" \\
                        "$DATAPATH/datasets/$DATASET_NAME/text_to_image_results.json"
                    
                    echo ""
                    echo "第4步：转换标注格式（图到文）..."
                    python cn_clip/eval/transform_ir_annotation_to_tr.py \\
                        --input "$DATAPATH/datasets/$DATASET_NAME/valid_texts.jsonl"
                    
                    echo ""
                    echo "第5步：图到文检索 (KNN)..."
                    python -u cn_clip/eval/make_topk_predictions_tr.py \\
                        --image-feats="$DATAPATH/datasets/$DATASET_NAME/valid_imgs.img_feat.jsonl" \\
                        --text-feats="$DATAPATH/datasets/$DATASET_NAME/valid_texts.txt_feat.jsonl" \\
                        --top-k=10 \\
                        --eval-batch-size=32768 \\
                        --output="$DATAPATH/datasets/$DATASET_NAME/valid_tr_predictions.jsonl"
                    
                    echo ""
                    echo "第6步：图到文检索 Recall计算..."
                    python cn_clip/eval/evaluation_tr.py \\
                        "$DATAPATH/datasets/$DATASET_NAME/valid_texts.tr.jsonl" \\
                        "$DATAPATH/datasets/$DATASET_NAME/valid_tr_predictions.jsonl" \\
                        "$DATAPATH/datasets/$DATASET_NAME/image_to_text_results.json"
                    ;;
            esac
            
            # 结束时间记录
            END_TIME=\$(date)
            echo ""
            echo "=========================================="
            echo "评估完成！"
            echo "开始时间: \$START_TIME"
            echo "结束时间: \$END_TIME"
            
            # 显示结果文件位置
            echo ""
            echo "=== 生成的结果文件 ==="
            EVAL_DIR="/root/autodl-tmp/datapath/datasets/$DATASET_NAME/valid_features"
            if [ -d "\$EVAL_DIR" ]; then
                echo "特征文件目录：\$EVAL_DIR"
                ls -la "\$EVAL_DIR"/*.jsonl 2>/dev/null | head -5
            fi
            
            RESULT_DIR="/root/autodl-tmp/datapath/datasets/$DATASET_NAME"
            if [ -f "\$RESULT_DIR/text_to_image_results.json" ]; then
                echo ""
                echo "=== 文到图检索结果 ==="
                cat "\$RESULT_DIR/text_to_image_results.json"
            fi
            
            if [ -f "\$RESULT_DIR/image_to_text_results.json" ]; then
                echo ""
                echo "=== 图到文检索结果 ==="
                cat "\$RESULT_DIR/image_to_text_results.json"
            fi
            
EOF
            ;;
esac

# 结束时间记录
END_TIME=$(date)
echo ""
echo "=========================================="
echo "评估完成！"
echo "开始时间: $START_TIME"
echo "结束时间: $END_TIME"

# 显示结果文件位置
echo ""
echo "=== 生成的结果文件 ==="
EVAL_DIR="/root/autodl-tmp/datapath/datasets/$DATASET_NAME/valid_features"
if [ -d "$EVAL_DIR" ]; then
    echo "特征文件目录：$EVAL_DIR"
    ls -la "$EVAL_DIR"/*.jsonl 2>/dev/null | head -5
fi

RESULT_DIR="/root/autodl-tmp/datapath/datasets/$DATASET_NAME"
if [ -f "$RESULT_DIR/text_to_image_results.json" ]; then
    echo ""
    echo "=== 文到图检索结果 ==="
    cat "$RESULT_DIR/text_to_image_results.json"
fi

if [ -f "$RESULT_DIR/image_to_text_results.json" ]; then
    echo ""
    echo "=== 图到文检索结果 ==="
    cat "$RESULT_DIR/image_to_text_results.json"
fi

echo ""
echo "=========================================="
echo "  评估执行完成！"
echo "=========================================="
echo "模型：$MODEL_DESC"
echo "评估方式：$EVAL_DESC"
echo "服务器：$server_choice ($SERVER_DESC)"
echo ""
echo "结果文件位置："
echo "  特征文件：/root/autodl-tmp/datapath/datasets/$DATASET_NAME/valid_features/"
echo "  评估结果：/root/autodl-tmp/datapath/datasets/$DATASET_NAME/*_results.json"
echo ""
echo "常用查看命令："
echo "  查看文到图结果：ssh $SSH_TARGET 'cat /root/autodl-tmp/datapath/datasets/$DATASET_NAME/text_to_image_results.json'"
echo "  查看图到文结果：ssh $SSH_TARGET 'cat /root/autodl-tmp/datapath/datasets/$DATASET_NAME/image_to_text_results.json'"
echo "  查看特征文件：ssh $SSH_TARGET 'ls -la /root/autodl-tmp/datapath/datasets/$DATASET_NAME/valid_features/'"
echo "==========================================" 