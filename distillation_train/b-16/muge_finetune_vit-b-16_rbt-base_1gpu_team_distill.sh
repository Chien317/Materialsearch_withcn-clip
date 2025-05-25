#!/usr/bin/env bash

# Guide:
# This script supports single GPU training with Knowledge Distillation
# Teacher Model: damo/multi-modal_team-vit-large-patch14_multi-modal-similarity (TEAM)
# Optimized for 1x GPU configuration
# Command: bash run_scripts/muge_finetune_vit-b-16_rbt-base_1gpu_team_distill.sh

# Number of GPUs per GPU worker - 设置为1卡
GPUS_PER_NODE=1 
# Number of GPU workers, for single-node training with 1 GPU
WORKER_CNT=1
# The ip address of the rank-0 worker, for single-node training
export MASTER_ADDR=localhost
# The port for communication
export MASTER_PORT=29504  # H20单卡服务器专用端口，避免与4GPU服务器冲突
# The rank of this worker, should be in {0, ..., WORKER_CNT-1}
export RANK=0 

export PYTHONPATH=${PYTHONPATH}:`pwd`/cn_clip/

# 设置CUDA相关环境变量
export CUDA_VISIBLE_DEVICES=0
export NCCL_DEBUG=INFO

# data options
train_data=/root/autodl-tmp/datapath/datasets/MUGE/lmdb/train
val_data=/root/autodl-tmp/datapath/datasets/MUGE/lmdb/valid

# restore options
resume=/root/autodl-tmp/datapath/pretrained_weights/clip_cn_vit-b-16.pt
reset_data_offset="--reset-data-offset"
reset_optimizer="--reset-optimizer"

# Knowledge Distillation options
distillation="--distillation"
teacher_model_name="damo/multi-modal_team-vit-large-patch14_multi-modal-similarity"
kd_loss_weight=0.5

# output options
output_base_dir=/root/autodl-tmp/datapath/experiments/
name=muge_finetune_vit-b-16_roberta-base_bs128_1gpu_team_distill
save_step_frequency=999999 # disable step-based saving
save_epoch_frequency=1
log_interval=1
report_training_batch_acc="--report-training-batch-acc"

# training hyper-params - 1卡优化配置
context_length=52
warmup=100  # 减少warmup步数，适应较小batch size
batch_size=32  # 每卡batch size，适合单GPU
valid_batch_size=32
accum_freq=4   # 增加累积梯度，保持较大的effective batch size = 32*1*4 = 128
lr=4e-5       # 降低学习率，适应较小的batch size
wd=0.001
max_epochs=3
valid_step_interval=200  # 更频繁的验证
valid_epoch_interval=1
vision_model=ViT-B-16
text_model=RoBERTa-wwm-ext-base-chinese
use_augment="--use-augment"

# 额外的优化参数
grad_checkpointing="--grad-checkpointing"  # 启用梯度检查点，节省显存
fp16_precision="--precision=fp16"          # 使用fp16精度，提升速度
# use_flash_attention="--use-flash-attention"  # 暂时禁用flash attention

echo "=== 1-GPU Knowledge Distillation Training Configuration ==="
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
    ${distillation} \
    --teacher-model-name=${teacher_model_name} \
    --kd_loss_weight ${kd_loss_weight} 