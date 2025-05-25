#!/usr/bin/env bash

# Guide:
# This script supports distributed training on 4 GPU A800 workers with Knowledge Distillation
# Teacher Model: damo/multi-modal_team-vit-large-patch14_multi-modal-similarity (TEAM model)
# Optimized for 4x A800-80GB configuration
# Command: bash run_scripts/muge_finetune_vit-b-16_rbt-base_4gpu_team_distill.sh

# Number of GPUs per GPU worker - 设置为4卡
GPUS_PER_NODE=4 
# Number of GPU workers, for single-node training with 4 GPUs
WORKER_CNT=1
# The ip address of the rank-0 worker, for single-node training
export MASTER_ADDR=localhost
# The port for communication
export MASTER_PORT=29502  # 使用不同端口避免冲突
# The rank of this worker, should be in {0, ..., WORKER_CNT-1}
export RANK=0 

export PYTHONPATH=${PYTHONPATH}:`pwd`/cn_clip/

# 设置CUDA相关环境变量
export CUDA_VISIBLE_DEVICES=0,1,2,3
export NCCL_DEBUG=INFO

# data options
train_data=/root/autodl-tmp/datapath/datasets/MUGE/lmdb/train
val_data=/root/autodl-tmp/datapath/datasets/MUGE/lmdb/valid

# restore options - 智能checkpoint恢复
checkpoint_dir=/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill/checkpoints
checkpoint_path="${checkpoint_dir}/epoch_latest.pt"
pretrained_path=/root/autodl-tmp/datapath/pretrained_weights/clip_cn_vit-b-16.pt

# 检查是否存在checkpoint，如果存在则从checkpoint恢复，否则从预训练模型开始
if [ -f "${checkpoint_path}" ]; then
    echo "Found existing checkpoint: ${checkpoint_path}"
    echo "Resuming training from checkpoint..."
    resume=${checkpoint_path}
    reset_data_offset=""  # 从checkpoint恢复时不重置数据偏移
    reset_optimizer=""    # 从checkpoint恢复时不重置优化器
else
    echo "No checkpoint found, starting from pretrained model: ${pretrained_path}"
    resume=${pretrained_path}
    reset_data_offset="--reset-data-offset"  # 从预训练模型开始时重置数据偏移
    reset_optimizer="--reset-optimizer"      # 从预训练模型开始时重置优化器
fi

# Knowledge Distillation options
distillation="--distillation"
teacher_model_name="damo/multi-modal_team-vit-large-patch14_multi-modal-similarity"
kd_loss_weight=0.5

# output options
output_base_dir=/root/autodl-tmp/datapath/experiments/
name=muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill
save_step_frequency=800 # 每800步保存一次checkpoint，大约每8-10分钟
save_epoch_frequency=1  # 每个epoch也保存一次
log_interval=1
report_training_batch_acc="--report-training-batch-acc"

# training hyper-params - 4卡A800优化配置
context_length=52
warmup=200  # 增加warmup步数，适应更大batch size
batch_size=64  # 每卡batch size，总的effective batch size = 64*4*2 = 512
valid_batch_size=64
accum_freq=2   # 累积梯度，进一步增加effective batch size
lr=8e-5       # 略微增加学习率，适应更大的batch size
wd=0.001
max_epochs=3
valid_step_interval=100  # 更频繁的验证
valid_epoch_interval=1
vision_model=ViT-B-16
text_model=RoBERTa-wwm-ext-base-chinese
use_augment="--use-augment"

# 额外的优化参数
grad_checkpointing="--grad-checkpointing"  # 启用梯度检查点，节省显存
fp16_precision="--precision=fp16"          # 使用fp16精度，提升速度
#use_flash_attention="--use-flash-attention"  # 如果支持的话启用flash attention

echo "=== 4-GPU A800 Knowledge Distillation Training Configuration ==="
echo "Teacher Model: ${teacher_model_name}"
echo "KD Loss Weight: ${kd_loss_weight}"
echo "Total GPUs: ${GPUS_PER_NODE}"
echo "Per-GPU Batch Size: ${batch_size}"
echo "Accumulation Frequency: ${accum_freq}"
echo "Effective Batch Size: $((${batch_size} * ${GPUS_PER_NODE} * ${accum_freq}))"
echo "Learning Rate: ${lr}"
echo "==========================================="

# 确保在正确环境下运行
source /root/miniconda3/bin/activate
conda activate training

# 安装必要的包（包括ModelScope）
pip install numpy==1.24.3
pip install modelscope

# 开始训练
torchrun --nnodes=${WORKER_CNT} --nproc_per_node=${GPUS_PER_NODE} \
    --master_addr=${MASTER_ADDR} --master_port=${MASTER_PORT} --node_rank=${RANK} \
    cn_clip/training/main.py \
    --train-data=${train_data} \
    --val-data=${val_data} \
    --resume=${resume} \
    ${reset_data_offset} \
    ${reset_optimizer} \
    --logs=${output_base_dir} \
    --name=${name} \
    --save-step-frequency=${save_step_frequency} \
    --save-epoch-frequency=${save_epoch_frequency} \
    --log-interval=${log_interval} \
    ${report_training_batch_acc} \
    --context-length=${context_length} \
    --warmup=${warmup} \
    --batch-size=${batch_size} \
    --valid-batch-size=${valid_batch_size} \
    --accum-freq=${accum_freq} \
    --lr=${lr} \
    --wd=${wd} \
    --max-epochs=${max_epochs} \
    --valid-step-interval=${valid_step_interval} \
    --valid-epoch-interval=${valid_epoch_interval} \
    --vision-model=${vision_model} \
    --text-model=${text_model} \
    ${use_augment} \
    ${grad_checkpointing} \
    ${fp16_precision} \
    #${use_flash_attention} \
    ${distillation} \
    --teacher-model-name=${teacher_model_name} \
    --kd-loss-weight=${kd_loss_weight} 