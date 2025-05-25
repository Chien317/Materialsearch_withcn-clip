#!/bin/bash

# ELEVATER分布式零样本分类环境设置脚本
# 精简版本：包含必要的依赖安装，避免重复安装大包（如PyTorch）
# 假设所有服务器都使用相同的系统镜像，PyTorch等大包已预装

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  ELEVATER分布式零样本分类环境设置 (精简版)"
echo "=================================================="

# 检查是否在正确的环境中运行
if [ ! -d "/root/autodl-tmp" ]; then
    echo "❌ 错误：此脚本需要在云服务器上运行"
    echo "请确保在seetacloud服务器上执行此脚本"
    exit 1
fi

# 设置基本路径
export WORKSPACE="/root/autodl-tmp"
export DATAPATH="${WORKSPACE}/datapath"

echo "工作空间: ${WORKSPACE}"
echo "数据路径: ${DATAPATH}"

# 步骤 1: 检查现有环境
echo ""
echo "[步骤 1/4] 检查现有环境..."
echo "----------------------------------------------"

# 检查conda环境
if command -v conda &> /dev/null; then
    echo "✅ Conda已安装: $(conda --version)"
    source /root/miniconda3/bin/activate
    if conda env list | grep -q "training"; then
        echo "✅ 'training'环境已存在"
    else
        echo "📝 创建training环境..."
        conda create -n training python=3.9 -y
    fi
    conda activate training
    echo "✅ 激活training环境: $(python --version)"
else
    echo "❌ 错误：Conda未安装"
    exit 1
fi

# 检查PyTorch
if python -c "import torch; print('PyTorch版本:', torch.__version__)" 2>/dev/null; then
    echo "✅ PyTorch已安装并可用"
else
    echo "⚠️  PyTorch检测失败，可能需要手动检查"
fi

# 步骤 2: 安装必要的Python依赖
echo ""
echo "[步骤 2/4] 安装Chinese-CLIP必要依赖..."
echo "----------------------------------------------"

# 检查并安装transformers
if python -c "import transformers" 2>/dev/null; then
    echo "✅ transformers已安装: $(python -c 'import transformers; print(transformers.__version__)')"
else
    echo "📦 安装transformers..."
    pip install transformers==4.30.0 --no-cache-dir
    echo "✅ transformers安装完成"
fi

# 检查并安装timm
if python -c "import timm" 2>/dev/null; then
    echo "✅ timm已安装: $(python -c 'import timm; print(timm.__version__)')"
else
    echo "📦 安装timm..."
    pip install timm==0.6.7 --no-cache-dir
    echo "✅ timm安装完成"
fi

# 检查并安装其他必要依赖
echo "📦 检查和安装其他必要依赖..."
missing_packages=()

# 检查ftfy
if ! python -c "import ftfy" 2>/dev/null; then
    missing_packages+=("ftfy")
fi

# 检查regex
if ! python -c "import regex" 2>/dev/null; then
    missing_packages+=("regex")
fi

# 检查tqdm
if ! python -c "import tqdm" 2>/dev/null; then
    missing_packages+=("tqdm")
fi

# 批量安装缺失的包
if [ ${#missing_packages[@]} -gt 0 ]; then
    echo "安装缺失包: ${missing_packages[*]}"
    pip install ${missing_packages[*]} --no-cache-dir
    echo "✅ 缺失包安装完成"
else
    echo "✅ 所有小依赖包都已安装"
fi

# 步骤 3: 创建目录结构
echo ""
echo "[步骤 3/4] 创建目录结构..."
echo "----------------------------------------------"

# 创建所需目录
mkdir -p ${WORKSPACE}
mkdir -p ${DATAPATH}/pretrained_weights
mkdir -p ${DATAPATH}/datasets
mkdir -p ${DATAPATH}/experiments

echo "✅ 目录结构创建完成"

# 步骤 4: 克隆Chinese-CLIP仓库
echo ""
echo "[步骤 4/4] 克隆Chinese-CLIP仓库..."
echo "----------------------------------------------"

CLIP_DIR="${WORKSPACE}/Chinese-CLIP"
if [ ! -d "${CLIP_DIR}" ]; then
    echo "正在克隆Chinese-CLIP仓库..."
    git clone https://github.com/OFA-Sys/Chinese-CLIP.git ${CLIP_DIR}
    echo "✅ Chinese-CLIP仓库克隆完成"
else
    echo "✅ Chinese-CLIP仓库已存在，保持现有版本"
    echo "   (避免覆盖本地修改，如需更新请手动执行)"
    echo "   手动更新命令: cd ${CLIP_DIR} && git pull origin master"
fi

cd ${CLIP_DIR}

# 最终验证所有依赖
echo ""
echo "最终验证环境..."
echo "----------------------------------------------"

python -c "
import sys
missing = []

try:
    import torch
    print(f'✅ PyTorch: {torch.__version__}')
    print(f'✅ CUDA可用: {torch.cuda.is_available()}')
    if torch.cuda.is_available():
        print(f'✅ GPU数量: {torch.cuda.device_count()}')
except ImportError:
    missing.append('torch')

try:
    import transformers
    print(f'✅ Transformers: {transformers.__version__}')
except ImportError:
    missing.append('transformers')

try:
    import timm
    print(f'✅ Timm: {timm.__version__}')
except ImportError:
    missing.append('timm')

try:
    import numpy
    print(f'✅ Numpy: {numpy.__version__}')
except ImportError:
    missing.append('numpy')

try:
    import ftfy
    print(f'✅ Ftfy: 可用')
except ImportError:
    missing.append('ftfy')

try:
    import regex
    print(f'✅ Regex: 可用')
except ImportError:
    missing.append('regex')

try:
    import tqdm
    print(f'✅ Tqdm: 可用')
except ImportError:
    missing.append('tqdm')

if missing:
    print(f'❌ 仍然缺失: {missing}')
    sys.exit(1)
else:
    print('🎉 所有关键依赖验证通过！')
"

if [ $? -ne 0 ]; then
    echo "❌ 依赖验证失败！"
    echo ""
    echo "建议操作："
    echo "1. 检查pip安装是否成功"
    echo "2. 手动安装缺失的依赖"
    echo "3. 重新运行此脚本"
    exit 1
fi

# 清理临时文件
echo ""
echo "清理临时文件..."
find ${DATAPATH} -name "._____temp" -type d -exec rm -rf {} \; 2>/dev/null || true
find ${DATAPATH} -name "temp" -type d -exec rm -rf {} \; 2>/dev/null || true
echo "✅ 清理完成"

# 安装完成总结
echo ""
echo "=================================================="
echo "🎉 分布式环境设置完成！"
echo "=================================================="
echo ""
echo "环境信息:"
echo "  - 工作空间: ${WORKSPACE}"
echo "  - 数据路径: ${DATAPATH}"
echo "  - Chinese-CLIP: ${CLIP_DIR}"
echo "  - Conda环境: training"
echo "  - Python版本: $(python --version)"
echo "  - PyTorch版本: $(python -c 'import torch; print(torch.__version__)')"
echo "  - GPU状态: $(python -c 'import torch; print("可用" if torch.cuda.is_available() else "不可用")')"
echo ""
echo "已完成组件:"
echo "  ✅ 目录结构"
echo "  ✅ Chinese-CLIP代码库"
echo "  ✅ 环境验证"
echo ""
echo "待完成的分布式设置:"
echo "  ⏳ 蒸馏模型同步 (从v800获取)"
echo "  ⏳ ELEVATER数据集同步 (从v802获取)"
echo "  ⏳ 测试脚本部署"
echo ""
echo "下一步："
echo "  运行分布式部署脚本来完成剩余设置"
echo "=================================================="

cd ${WORKSPACE} 