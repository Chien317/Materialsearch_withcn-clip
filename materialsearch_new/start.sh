#!/bin/bash

# 设置conda环境变量
export PATH="/Users/chienchen/miniconda3/bin:$PATH"

# 激活conda环境
source ~/miniconda3/bin/activate materialsearch_new

# 检查环境是否激活成功
if [ $? -ne 0 ]; then
    echo "Error: Failed to activate conda environment"
    exit 1
fi

# 打印Python版本和环境信息
echo "Using Python: $(which python)"
echo "Python version: $(python --version)"
echo "Conda environment: $CONDA_DEFAULT_ENV"

# 创建必要的目录
mkdir -p instance tmp tmp/upload tmp/video_clips

# 设置环境变量
export PYTHONPATH="${PYTHONPATH}:${PWD}"
export DEVICE="mps"  # 为Mac设置MPS设备
export HF_HOME="./hub"  # 设置HuggingFace缓存目录

# 启动应用
echo "Starting application..."
python main.py --model muge_private --port 8085 