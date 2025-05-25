#!/bin/bash

echo "=================================================="
echo "  全功能GPU配置检测工具 (增强版)"
echo "=================================================="
echo "🎯 目标: 自动适配异构多机多卡环境 + 详细硬件检测"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 服务器列表
servers="seetacloud-v800 seetacloud-v801 seetacloud-v802"

# 详细检测函数
detailed_gpu_check() {
    local server=$1
    echo "  🔍 详细检测 $server GPU环境..."
    
    ssh "$server" << 'EOF'
        echo "    📊 GPU硬件信息:"
        nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free --format=csv,noheader,nounits | while read line; do
            echo "      GPU $line"
        done
        
        echo ""
        echo "    🔧 CUDA环境:"
        nvcc_version=$(nvcc --version 2>/dev/null | grep "release" | sed 's/.*release \([0-9.]*\).*/\1/' || echo "未安装")
        echo "      CUDA版本: $nvcc_version"
        
        echo ""
        echo "    🐍 PyTorch环境:"
        python -c "
import torch
print(f'      PyTorch版本: {torch.__version__}')
print(f'      CUDA可用: {torch.cuda.is_available()}')
print(f'      cuDNN版本: {torch.backends.cudnn.version() if torch.backends.cudnn.is_available() else \"未安装\"}')

# 检查分布式支持
try:
    import torch.distributed as dist
    print(f'      NCCL可用: {dist.is_nccl_available()}')
    print(f'      MPI可用: {dist.is_mpi_available()}')
except ImportError:
    print('      分布式支持: 未安装')

# 测试多GPU通信
if torch.cuda.device_count() >= 2:
    try:
        device_0 = torch.device('cuda:0')
        device_1 = torch.device('cuda:1')
        x = torch.randn(2, 2, device=device_0)
        y = x.to(device_1)
        print('      多GPU通信: ✅ 正常')
    except Exception as e:
        print(f'      多GPU通信: ❌ 失败 ({str(e)[:50]}...)')
else:
    print('      多GPU通信: ⚠️ GPU数量不足')
" 2>/dev/null || echo "      Python环境检测失败"
EOF
}

echo "🔍 检测各服务器GPU数量和详细信息..."
echo "----------------------------------------------"

total_gpus=0

# 使用普通变量代替关联数组
v800_gpus=0
v801_gpus=0
v802_gpus=0

for server in $servers; do
    echo "📡 检测 $server..."
    
    # 检测GPU数量
    gpu_count=$(ssh "$server" "source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && python -c 'import torch; print(torch.cuda.device_count())'" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$gpu_count" ] && [ "$gpu_count" -gt 0 ]; then
        # 根据服务器名设置对应变量
        case "$server" in
            "seetacloud-v800")
                v800_gpus=$gpu_count
                ;;
            "seetacloud-v801")
                v801_gpus=$gpu_count
                ;;
            "seetacloud-v802")
                v802_gpus=$gpu_count
                ;;
        esac
        
        total_gpus=$((total_gpus + gpu_count))
        echo "  ✅ $server: $gpu_count GPU(s)"
        
        # 执行详细检测
        detailed_gpu_check "$server"
        
    else
        echo "  ❌ $server: 无法连接或检测失败"
    fi
    echo ""
done

echo ""
echo "📊 **GPU配置总结**"
echo "----------------------------------------------"

# 显示每个服务器的状态
if [ "$v800_gpus" -gt 0 ]; then
    echo -e "  ${GREEN}seetacloud-v800: $v800_gpus GPU(s)${NC}"
else
    echo -e "  ${RED}seetacloud-v800: 不可用${NC}"
fi

if [ "$v801_gpus" -gt 0 ]; then
    echo -e "  ${GREEN}seetacloud-v801: $v801_gpus GPU(s)${NC}"
else
    echo -e "  ${RED}seetacloud-v801: 不可用${NC}"
fi

if [ "$v802_gpus" -gt 0 ]; then
    echo -e "  ${GREEN}seetacloud-v802: $v802_gpus GPU(s)${NC}"
else
    echo -e "  ${RED}seetacloud-v802: 不可用${NC}"
fi

echo ""
echo -e "${BLUE}总GPU数量: $total_gpus${NC}"

# 生成动态配置
cat > dynamic_gpu_config.env << EOF
# 动态GPU配置 - $(date)
TOTAL_GPUS=$total_gpus
v800_GPUS=$v800_gpus
v801_GPUS=$v801_gpus
v802_GPUS=$v802_gpus
EOF

echo ""
echo "📝 **分布式训练配置建议**"
echo "----------------------------------------------"

if [ "$total_gpus" -gt 0 ]; then
    echo -e "${GREEN}✅ 可以启动分布式训练${NC}"
    echo ""
    echo "🚀 **torchrun命令示例**:"
    echo "torchrun \\"
    echo "  --nnodes=3 \\"
    echo "  --nproc_per_node=\$LOCAL_GPU_COUNT \\"
    echo "  --rdzv_id=123 \\"
    echo "  --rdzv_backend=c10d \\"
    echo "  --rdzv_endpoint=seetacloud-v800:23456 \\"
    echo "  train.py"
    echo ""
    echo "💡 **异构配置说明**:"
    echo "  - v800节点: $v800_gpus GPU(s) (主节点)"
    echo "  - v801节点: $v801_gpus GPU(s)"
    echo "  - v802节点: $v802_gpus GPU(s)"
    echo "  - 总计算能力: $total_gpus GPU(s)"
    echo ""
    echo "⚖️ **负载分配**:"
    
    if [ "$v800_gpus" -gt 0 ]; then
        percentage=$(echo "scale=1; $v800_gpus * 100 / $total_gpus" | bc -l 2>/dev/null || echo "未知")
        echo "  - seetacloud-v800: ${percentage}% 计算负载"
    fi
    
    if [ "$v801_gpus" -gt 0 ]; then
        percentage=$(echo "scale=1; $v801_gpus * 100 / $total_gpus" | bc -l 2>/dev/null || echo "未知")
        echo "  - seetacloud-v801: ${percentage}% 计算负载"
    fi
    
    if [ "$v802_gpus" -gt 0 ]; then
        percentage=$(echo "scale=1; $v802_gpus * 100 / $total_gpus" | bc -l 2>/dev/null || echo "未知")
        echo "  - seetacloud-v802: ${percentage}% 计算负载"
    fi
    
    echo ""
    echo "🎯 **配置建议**:"
    if [ "$v800_gpus" -eq 2 ]; then
        echo "  💡 建议v800升级到3卡以获得更好的负载均衡"
        echo "     - 当前: 2+4+4=10 GPU (20%不均衡)"
        echo "     - 建议: 3+4+4=11 GPU (9.1%不均衡)"
        echo "     - 性能提升: ~10%"
    elif [ "$v800_gpus" -eq 3 ]; then
        echo "  ✅ 当前3卡配置已经很好！负载相对均衡"
    fi
    
    echo ""
    echo "🔧 **零样本分类测试建议**:"
    echo "  - 单服务器测试: ./run_zeroshot_classification.sh"
    echo "  - 分布式测试: ./distributed_coordinator.sh"
    echo "  - 性能监控: watch -n 1 'nvidia-smi'"
    
else
    echo -e "${RED}❌ 没有可用的GPU节点${NC}"
fi

echo ""
echo "📁 配置已保存至: dynamic_gpu_config.env"
echo "📚 建议删除旧的 check_gpu_setup.sh，使用此增强版脚本" 