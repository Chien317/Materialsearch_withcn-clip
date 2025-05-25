#!/bin/bash
# Conda环境wrapper脚本 - 解决SSH远程执行conda命令的问题

# 检测Miniconda路径
CONDA_PATHS=(
    "$HOME/miniconda3"
    "$HOME/miniconda"
    "/opt/miniconda3"
    "/root/miniconda3"
)

CONDA_PATH=""
for path in "${CONDA_PATHS[@]}"; do
    if [ -f "$path/etc/profile.d/conda.sh" ]; then
        CONDA_PATH="$path"
        break
    fi
done

if [ -z "$CONDA_PATH" ]; then
    echo "❌ 未找到Conda安装路径"
    exit 1
fi

echo "🔧 使用Conda路径: $CONDA_PATH"

# 初始化Conda环境
source "$CONDA_PATH/etc/profile.d/conda.sh"

# 激活指定环境（默认为training）
ENV_NAME=${1:-training}
conda activate "$ENV_NAME"

echo "🚀 已激活环境: $ENV_NAME"
echo "🐍 Python路径: $(which python)"
echo "📦 Conda环境列表:"
conda env list | grep '*'

# 如果有额外参数，执行命令
if [ $# -gt 1 ]; then
    shift  # 移除第一个参数（环境名）
    echo "▶️  执行命令: $@"
    exec "$@"
else
    echo "💡 使用方法: $0 [环境名] [命令...]"
    echo "💡 例如: $0 training python upload_script.py"
    # 启动交互式shell
    exec bash
fi 