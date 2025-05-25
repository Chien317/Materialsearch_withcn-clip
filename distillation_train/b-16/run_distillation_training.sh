#!/bin/bash

# 知识蒸馏训练脚本管理器 - 单GPU版本
# 可以选择不同的teacher model进行训练比较

echo "=========================================="
echo "  CN-CLIP 知识蒸馏训练管理器 (单GPU版本)"
echo "=========================================="
echo "请选择训练类型："
echo "  1. Baseline训练 (无知识蒸馏)"
echo "  2. CLIP Huge Teacher 知识蒸馏"
echo "  3. CLIP Large Teacher 知识蒸馏" 
echo "  4. TEAM Teacher 知识蒸馏"
echo ""
echo "可用服务器："
echo "  v800: 4-GPU A800 server (seetacloud-v800)"
echo "  h20:  1-GPU H20 server (seetacloud-h20)"
echo "  v801: New GPU server (seetacloud-v801)"
echo "=========================================="

# 处理参数
if [ $# -eq 2 ]; then
    # 两个参数都提供了
    choice=$1
    server_choice=$2
elif [ $# -eq 1 ]; then
    # 只提供了训练类型，询问服务器
    choice=$1
    echo "Training type $choice selected."
    read -p "请选择服务器 (v800/h20/v801): " server_choice
elif [ $# -eq 0 ]; then
    # 没有参数，交互式选择
    read -p "请输入选择 (1-4): " choice
    read -p "请选择服务器 (v800/h20/v801): " server_choice
else
    echo "错误：参数过多。"
    echo "使用方法：$0 <training_type> <server>"
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

# 设置变量
case $choice in
    1)
        SCRIPT_NAME="muge_finetune_vit-b-16_rbt-base_1gpu_baseline.sh"
        DESCRIPTION="Baseline training (No Knowledge Distillation) - Single GPU"
        ;;
    2)
        SCRIPT_NAME="muge_finetune_vit-b-16_rbt-base_1gpu_huge_distill.sh"
        DESCRIPTION="Knowledge Distillation with CLIP Huge Teacher - Single GPU"
        ;;
    3)
        SCRIPT_NAME="muge_finetune_vit-b-16_rbt-base_1gpu_large_distill.sh"
        DESCRIPTION="Knowledge Distillation with CLIP Large Teacher - Single GPU"
        ;;
    4)
        SCRIPT_NAME="muge_finetune_vit-b-16_rbt-base_1gpu_team_distill.sh"
        DESCRIPTION="Knowledge Distillation with TEAM Teacher - Single GPU"
        ;;
    *)
        echo "Invalid choice. Please select 1, 2, 3, or 4."
        exit 1
        ;;
esac

echo "选择的训练类型：$DESCRIPTION"
echo "使用的脚本：$SCRIPT_NAME"
echo "服务器：$server_choice ($SERVER_DESC)"
echo "SSH目标：$SSH_TARGET"
echo ""

# 检查脚本是否存在
if [ ! -f "$SCRIPT_NAME" ]; then
    echo "错误：脚本 $SCRIPT_NAME 未找到！"
    exit 1
fi

# 上传训练脚本到云服务器
echo "正在上传训练脚本到云服务器..."
scp $SCRIPT_NAME ${SSH_TARGET}:~/

echo "正在启动远程训练..."
echo "=========================================="

# 连接到云服务器并执行训练
ssh ${SSH_TARGET} << EOF
    # 激活conda环境
    source /root/miniconda3/bin/activate
    conda activate training
    
    # 进入项目目录
    cd /root/autodl-tmp/Chinese-CLIP
    
    # 确保脚本有执行权限
    chmod +x ~/$SCRIPT_NAME
    
    # 移动脚本到run_scripts目录
    mv ~/$SCRIPT_NAME run_scripts/
    
    # 显示GPU状态
    echo "=== GPU状态检查 ==="
    nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free --format=csv,noheader,nounits
    echo "==================="
    
    # 执行训练脚本
    echo "开始执行训练：$DESCRIPTION"
    nohup bash run_scripts/$SCRIPT_NAME 2>&1 &
    
    # 获取进程ID
    TRAIN_PID=\$!
    echo "训练已在后台启动，进程ID: \$TRAIN_PID"
    echo "注意：实际日志文件将保存在experiments目录下"
    
    # 等待实验目录生成
    echo ""
    echo "=== 等待实验目录生成 ==="
    sleep 10
    
    # 找到最新的日志文件
    LOG_DIR="/root/autodl-tmp/datapath/experiments"
    LATEST_LOG=\$(find \$LOG_DIR -name "out_*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -n "\$LATEST_LOG" ]; then
        echo "找到日志文件: \$LATEST_LOG"
        echo ""
        echo "=== 最新日志 ==="
        tail -n 20 "\$LATEST_LOG"
    else
        echo "日志文件还未生成，请稍后在experiments目录下查看"
    fi
    
    echo ""
    echo "训练已启动！"
    echo "实际日志将保存在experiments目录下的out_*.log文件中"
    echo "结束训练命令：pkill -f $SCRIPT_NAME"
EOF

echo ""
echo "=========================================="
echo "  训练启动完成！"
echo "=========================================="
echo "训练类型：$DESCRIPTION"
echo "服务器：$server_choice ($SERVER_DESC)"
echo "日志位置：/root/autodl-tmp/datapath/experiments/[实验名]/out_*.log"
echo ""
echo "常用监控命令："
echo "  查看最新日志：ssh $SSH_TARGET \"find /root/autodl-tmp/datapath/experiments -name 'out_*.log' -type f -printf '%T@ %p\\n' | sort -n | tail -1 | cut -d' ' -f2- | xargs tail -f\""
echo "  GPU状态：ssh $SSH_TARGET 'nvidia-smi'"
echo "  查看训练进程：ssh $SSH_TARGET 'ps aux | grep muge_finetune'"
echo "  停止训练：ssh $SSH_TARGET 'pkill -f $SCRIPT_NAME'"
echo ""
echo "简化日志查看命令："
echo "  ssh $SSH_TARGET 'cd /root/autodl-tmp/datapath/experiments && ls -t */out_*.log | head -1 | xargs tail -f'"
echo "===========================================" 