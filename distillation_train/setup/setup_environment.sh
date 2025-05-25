#!/bin/bash

# 设置错误处理
set -e  # 遇到错误立即退出
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "========== 开始环境设置 =========="

# 激活conda环境
echo "正在激活conda环境..."
source /root/miniconda3/etc/profile.d/conda.sh
conda activate training
echo "✓ conda环境已激活"

# 设置基础路径
export DATAPATH="/root/autodl-tmp/datapath"  # 设置DATAPATH环境变量到数据盘
export WORKSPACE="/root/autodl-tmp"  # 工作目录
cd ${WORKSPACE}

# 步骤 1: 创建必要的目录结构
echo "\n[步骤 1/5] 创建目录结构..."
mkdir -p ${DATAPATH}/pretrained_weights && echo "✓ 创建 pretrained_weights 目录: ${DATAPATH}/pretrained_weights"
mkdir -p ${DATAPATH}/datasets && echo "✓ 创建 datasets 目录: ${DATAPATH}/datasets"
mkdir -p ${DATAPATH}/experiments && echo "✓ 创建 experiments 目录: ${DATAPATH}/experiments"
echo "✓ 目录结构创建完成"

# 步骤 2: 克隆Chinese-CLIP仓库
echo "\n[步骤 2/5] 克隆Chinese-CLIP仓库..."
CLIP_DIR="${WORKSPACE}/Chinese-CLIP"
if [ ! -d "${CLIP_DIR}" ]; then
    git clone https://github.com/OFA-Sys/Chinese-CLIP.git ${CLIP_DIR}
    echo "✓ Chinese-CLIP仓库克隆完成"
else
    echo "! Chinese-CLIP仓库已存在，跳过克隆"
fi

cd ${CLIP_DIR}

# 步骤 3: 安装所需的Python依赖
echo "\n[步骤 3/5] 安装所需的Python依赖..."
pip install -r requirements.txt && echo "✓ 常规依赖安装完成"
# 安装numpy 1.24.3
pip install numpy==1.24.3
echo "正在安装额外依赖..."
pip install lmdb timm transformers addict && echo "✓ 额外依赖安装完成"

# 安装知识蒸馏训练所需的额外依赖
echo "正在安装知识蒸馏训练相关依赖..."
pip install simplejson sortedcontainers python-dateutil && echo "✓ 知识蒸馏相关依赖安装完成"

# 安装FlashAttention加速库
#echo "正在安装FlashAttention加速库..."
#pip install flash-attn && echo "✓ FlashAttention安装完成"

# 降级transformers以解决兼容性问题
echo "正在将transformers降级到4.30.0以解决兼容性问题..."
pip install transformers==4.30.0 && echo "✓ transformers降级完成"

# 步骤 4: 安装ModelScope
echo "\n[步骤 4/5] 安装ModelScope..."
pip install -U modelscope && echo "✓ ModelScope安装完成"

# 步骤 5: 下载预训练模型和MUGE数据集
echo "\n[步骤 5/5] 下载预训练模型和数据集..."

# 下载CLIP预训练模型（避免重复下载）
CLIP_MODEL_PATH="${DATAPATH}/pretrained_weights/clip_cn_vit-b-16.pt"
if [ ! -f "${CLIP_MODEL_PATH}" ]; then
    echo "正在下载Chinese-CLIP预训练模型..."
    wget https://clip-cn-beijing.oss-cn-beijing.aliyuncs.com/checkpoints/clip_cn_vit-b-16.pt -P ${DATAPATH}/pretrained_weights/
    echo "✓ Chinese-CLIP预训练模型下载完成"
else
    echo "! Chinese-CLIP预训练模型已存在，跳过下载"
fi

# 使用ModelScope下载所有teacher模型（使用默认缓存目录）
# 确保ModelScope默认缓存目录存在
mkdir -p /root/.cache/modelscope/hub/models/damo

# 定义所有teacher模型
TEACHER_MODELS=(
    "damo/multi-modal_clip-vit-large-patch14_zh"
    "damo/multi-modal_clip-vit-huge-patch14_zh" 
    "damo/multi-modal_team-vit-large-patch14_multi-modal-similarity"
)

# 下载所有teacher模型
for MODEL_NAME in "${TEACHER_MODELS[@]}"; do
    MODEL_DIR_NAME=$(echo $MODEL_NAME | sed 's/\//_/g')
    CACHE_PATH="/root/.cache/modelscope/hub/models/${MODEL_NAME}"
    
    if [ ! -d "${CACHE_PATH}" ]; then
        echo "正在下载teacher模型: ${MODEL_NAME}"
        python3 -c "
from modelscope import snapshot_download
import os

model_name = '${MODEL_NAME}'

try:
    print(f'开始下载模型: {model_name}')
    model_dir = snapshot_download(model_name)
    print(f'✓ {model_name} 下载完成，保存在: {model_dir}')
except Exception as e:
    print(f'! {model_name} 下载失败，错误信息: {str(e)}')
    print('! 请检查网络连接和modelscope配置')
"
    else
        echo "! ${MODEL_NAME} 已存在于ModelScope默认缓存目录，跳过下载"
    fi
done

# 下载MUGE数据集（如果没有）
MUGE_DIR="${DATAPATH}/datasets/MUGE"
MUGE_ZIP="${DATAPATH}/datasets/MUGE.zip"

if [ ! -d "${MUGE_DIR}" ]; then
    # 检查文件是否存在且大小正确（2.45G = 2633309970 bytes）
    if [ ! -f "${MUGE_ZIP}" ] || [ $(stat -f%z "${MUGE_ZIP}" 2>/dev/null || stat -c%s "${MUGE_ZIP}" 2>/dev/null) != "2633309970" ]; then
        echo "正在下载MUGE数据集..."
        # 删除可能存在的不完整或损坏的文件
        rm -f ${DATAPATH}/datasets/MUGE.zip*
        wget --no-check-certificate --content-disposition 'https://clip-cn-beijing.oss-cn-beijing.aliyuncs.com/datasets/MUGE.zip' -O ${DATAPATH}/datasets/MUGE.zip
        
        # 验证下载的文件大小
        DOWNLOADED_SIZE=$(stat -f%z "${MUGE_ZIP}" 2>/dev/null || stat -c%s "${MUGE_ZIP}" 2>/dev/null)
        if [ "${DOWNLOADED_SIZE}" != "2633309970" ]; then
            echo "错误：下载的文件大小不正确（期望：2633309970 bytes，实际：${DOWNLOADED_SIZE} bytes）"
            exit 1
        fi
    else
        echo "! MUGE数据集压缩包已存在，跳过下载"
    fi
    
    echo "正在解压MUGE数据集..."
    unzip ${MUGE_ZIP} -d ${DATAPATH}/datasets/
    echo "✓ MUGE数据集解压完成"
    rm -f ${DATAPATH}/datasets/MUGE.zip*
else
    echo "! MUGE数据集目录已存在，跳过下载和解压"
fi

# 下载Flickr30k-CN数据集（如果没有）
FLICKR_DIR="${DATAPATH}/datasets/Flickr30k-CN"
FLICKR_ZIP="${DATAPATH}/datasets/Flickr30k-CN.zip"

if [ ! -d "${FLICKR_DIR}" ]; then
    if [ ! -f "${FLICKR_ZIP}" ]; then
        echo "正在下载Flickr30k-CN数据集..."
        # 删除可能存在的不完整或损坏的文件
        rm -f ${DATAPATH}/datasets/Flickr30k-CN.zip*
        wget --no-check-certificate --content-disposition 'https://clip-cn-beijing.oss-cn-beijing.aliyuncs.com/datasets/Flickr30k-CN.zip' -O ${DATAPATH}/datasets/Flickr30k-CN.zip
        echo "✓ Flickr30k-CN数据集下载完成"
    else
        echo "! Flickr30k-CN数据集压缩包已存在，跳过下载"
    fi
    
    echo "正在解压Flickr30k-CN数据集..."
    unzip ${FLICKR_ZIP} -d ${DATAPATH}/datasets/
    echo "✓ Flickr30k-CN数据集解压完成"
    rm -f ${DATAPATH}/datasets/Flickr30k-CN.zip*
else
    echo "! Flickr30k-CN数据集目录已存在，跳过下载和解压"
fi

'''
# 下载ELEVATER零样本分类数据集（新增）
ELEVATER_DIR="${DATAPATH}/datasets/ELEVATER"
ELEVATER_ZIP="${DATAPATH}/datasets/ELEVATER_all.zip"

if [ ! -d "${ELEVATER_DIR}" ]; then
    if [ ! -f "${ELEVATER_ZIP}" ]; then
        echo "正在下载ELEVATER零样本分类数据集..."
        # 删除可能存在的不完整或损坏的文件
        rm -f ${DATAPATH}/datasets/ELEVATER_all.zip*
        wget --no-check-certificate --content-disposition 'https://clip-cn-beijing.oss-cn-beijing.aliyuncs.com/datasets/ELEVATER_all.zip' -O ${DATAPATH}/datasets/ELEVATER_all.zip
        echo "✓ ELEVATER数据集下载完成"
    else
        echo "! ELEVATER数据集压缩包已存在，跳过下载"
    fi
    
    echo "正在解压ELEVATER数据集..."
    mkdir -p ${ELEVATER_DIR}
    unzip ${ELEVATER_ZIP} -d ${ELEVATER_DIR}/
    echo "✓ ELEVATER数据集解压完成"
    
    # 解压各个数据集的子压缩包
    echo "正在解压各个子数据集..."
    cd ${ELEVATER_DIR}
    for zip_file in *.zip; do
        if [ -f "$zip_file" ]; then
            dataset_name=$(basename "$zip_file" .zip)
            echo "正在解压 $dataset_name ..."
            unzip -q "$zip_file" -d ./
            rm -f "$zip_file"  # 删除已解压的zip文件以节省空间
        fi
    done
    cd ${WORKSPACE}
    
    echo "✓ 所有ELEVATER子数据集解压完成"
    rm -f ${DATAPATH}/datasets/ELEVATER_all.zip*
else
    echo "! ELEVATER数据集目录已存在，跳过下载和解压"
fi
'''

# 清理任何临时文件
echo "清理临时文件..."
find ${DATAPATH}/pretrained_weights -name "._____temp" -type d -exec rm -rf {} \; 2>/dev/null || true
find ${DATAPATH}/pretrained_weights -name "temp" -type d -exec rm -rf {} \; 2>/dev/null || true
find /root/.cache/modelscope/hub -name "._____temp" -type d -exec rm -rf {} \; 2>/dev/null || true
echo "✓ 清理完成"

echo "\n========== 环境设置完成 =========="
echo "数据目录: ${DATAPATH}"
echo "Chinese-CLIP目录: ${CLIP_DIR}"
echo "student模型路径: ${CLIP_MODEL_PATH}"
echo ""
echo "所有teacher模型路径:"
echo "  Large模型: /root/.cache/modelscope/hub/models/damo/multi-modal_clip-vit-large-patch14_zh"
echo "  Huge模型: /root/.cache/modelscope/hub/models/damo/multi-modal_clip-vit-huge-patch14_zh"
echo "  TEAM模型: /root/.cache/modelscope/hub/models/damo/multi-modal_team-vit-large-patch14_multi-modal-similarity"
echo ""
echo "数据集路径:"
echo "  MUGE数据集: ${DATAPATH}/datasets/MUGE"
echo "  Flickr30k-CN数据集: ${DATAPATH}/datasets/Flickr30k-CN"
echo "  ELEVATER零样本分类数据集: ${DATAPATH}/datasets/ELEVATER"
echo ""
echo "🎉 可以开始知识蒸馏训练和零样本分类了！" 