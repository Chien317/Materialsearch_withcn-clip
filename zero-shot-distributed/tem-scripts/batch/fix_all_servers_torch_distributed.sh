#!/bin/bash

echo "=================================================="
echo "  批量修复所有服务器的PyTorch分布式问题"
echo "=================================================="
echo "🎯 修复内容:"
echo "  1. python3 -m torch.distributed.launch → torchrun"
echo "  2. torch.distributed.nn 导入问题修复"
echo "=================================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 服务器列表
servers=(
    "seetacloud-v800"
    "seetacloud-v801"
    "seetacloud-v802"
)

echo "🚀 开始批量修复..."
echo ""

# 检查本地修复脚本是否存在
if [ ! -f "fix_torch_distributed.sh" ] || [ ! -f "fix_torch_distributed_imports.py" ]; then
    echo -e "${RED}❌ 错误: 缺少必要的修复脚本${NC}"
    echo "   需要: fix_torch_distributed.sh, fix_torch_distributed_imports.py"
    exit 1
fi

# 对每个服务器执行修复
for server in "${servers[@]}"; do
    echo -e "${BLUE}📡 正在处理服务器: $server${NC}"
    echo "----------------------------------------------"
    
    # 检查服务器连接
    if ! ssh "$server" "echo '连接测试成功'" >/dev/null 2>&1; then
        echo -e "${RED}❌ 无法连接到 $server${NC}"
        continue
    fi
    
    # 1. 上传修复脚本
    echo "📤 上传修复脚本..."
    scp fix_torch_distributed.sh "$server:/root/autodl-tmp/"
    scp fix_torch_distributed_imports.py "$server:/root/autodl-tmp/"
    
    # 2. 执行Shell脚本修复(torchrun替换)
    echo "🔧 执行Shell脚本修复..."
    ssh "$server" "cd /root/autodl-tmp && chmod +x fix_torch_distributed.sh && ./fix_torch_distributed.sh"
    
    # 3. 执行Python脚本修复(导入问题)
    echo "🐍 执行Python脚本修复..."
    ssh "$server" "cd /root/autodl-tmp && source /root/miniconda3/etc/profile.d/conda.sh && conda activate base && python fix_torch_distributed_imports.py"
    
    # 4. 测试修复结果
    echo "🧪 测试修复结果..."
    ssh "$server" "cd /root/autodl-tmp && source /root/miniconda3/etc/profile.d/conda.sh && conda activate base && python -c 'import torch; print(f\"PyTorch版本: {torch.__version__}\"); import torch.distributed; print(\"✅ torch.distributed 导入成功\")'" 2>/dev/null && echo -e "${GREEN}✅ $server 修复成功${NC}" || echo -e "${RED}❌ $server 修复可能有问题${NC}"
    
    echo ""
done

echo "=================================================="
echo "🎉 批量修复完成！"
echo "=================================================="
echo ""
echo "📋 下一步建议:"
echo "  1. 测试分布式训练脚本"
echo "  2. 验证所有服务器间的通信"
echo "  3. 运行完整的分布式测试"
echo ""
echo "🧪 测试命令:"
echo "  ./start_distributed_setup.sh"
echo "  ./smart_distributed_train.sh [训练脚本]"
echo "" 