#!/bin/bash

# 分布式数据同步脚本
# 用于在多个服务器节点间同步数据集

set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

# 配置
SOURCE_NODE="seetacloud-v802"  # 数据源节点（有完整ELEVATER数据集）
TARGET_NODES=("seetacloud-v800" "seetacloud-v801")  # 目标节点
DATAPATH="/root/autodl-tmp/datapath"

echo "========== 分布式数据同步开始 =========="
echo "源节点: ${SOURCE_NODE}"
echo "目标节点: ${TARGET_NODES[@]}"
echo "时间: $(date)"

# 函数：检查节点连接
check_node_connection() {
    local node=$1
    echo "检查 ${node} 连接..."
    if ssh ${node} "echo 'Connection OK'" > /dev/null 2>&1; then
        echo "✓ ${node} 连接正常"
        return 0
    else
        echo "✗ ${node} 连接失败"
        return 1
    fi
}

# 函数：同步数据集到目标节点
sync_to_node() {
    local target_node=$1
    echo "\n=== 同步数据到 ${target_node} ==="
    
    # 检查连接
    if ! check_node_connection ${target_node}; then
        echo "跳过 ${target_node}，连接失败"
        return 1
    fi
    
    # 检查目标节点目录
    ssh ${target_node} "mkdir -p ${DATAPATH}/datasets"
    
    # 同步ELEVATER数据集（使用rsync增量同步）
    echo "正在同步ELEVATER数据集到 ${target_node}..."
    ssh ${SOURCE_NODE} "rsync -avz --progress ${DATAPATH}/datasets/ELEVATER/ ${target_node}:${DATAPATH}/datasets/ELEVATER/"
    
    if [ $? -eq 0 ]; then
        echo "✓ ELEVATER数据集同步到 ${target_node} 完成"
    else
        echo "✗ ELEVATER数据集同步到 ${target_node} 失败"
        return 1
    fi
    
    # 检查同步结果
    echo "检查 ${target_node} 上的数据集..."
    ssh ${target_node} "ls -la ${DATAPATH}/datasets/ELEVATER/ && du -sh ${DATAPATH}/datasets/ELEVATER/"
}

# 函数：快速同步（只同步必要的小数据集）
quick_sync_to_node() {
    local target_node=$1
    echo "\n=== 快速同步基础数据到 ${target_node} ==="
    
    if ! check_node_connection ${target_node}; then
        echo "跳过 ${target_node}，连接失败"
        return 1
    fi
    
    # 创建目录
    ssh ${target_node} "mkdir -p ${DATAPATH}/{datasets,pretrained_weights,experiments}"
    
    # 同步预训练模型和配置文件
    echo "同步预训练模型..."
    ssh ${SOURCE_NODE} "rsync -avz ${DATAPATH}/pretrained_weights/ ${target_node}:${DATAPATH}/pretrained_weights/"
    
    # 同步小数据集（MUGE, Flickr30k-CN）
    for dataset in MUGE Flickr30k-CN; do
        if ssh ${SOURCE_NODE} "[ -d ${DATAPATH}/datasets/${dataset} ]"; then
            echo "同步 ${dataset} 数据集..."
            ssh ${SOURCE_NODE} "rsync -avz ${DATAPATH}/datasets/${dataset}/ ${target_node}:${DATAPATH}/datasets/${dataset}/"
        fi
    done
    
    echo "✓ 快速同步到 ${target_node} 完成"
}

# 主菜单
echo "\n请选择同步模式："
echo "1. 完整同步（包含ELEVATER大数据集）"
echo "2. 快速同步（只同步必要的小文件）"
echo "3. 只检查节点连接状态"
echo "4. 自定义同步特定数据集"

read -p "请输入选择 (1-4): " choice

case $choice in
    1)
        echo "\n开始完整同步..."
        # 检查源节点ELEVATER数据集
        if ssh ${SOURCE_NODE} "[ -d ${DATAPATH}/datasets/ELEVATER ]"; then
            echo "✓ 源节点 ${SOURCE_NODE} 上的ELEVATER数据集存在"
            for node in "${TARGET_NODES[@]}"; do
                sync_to_node ${node}
            done
        else
            echo "✗ 源节点 ${SOURCE_NODE} 上缺少ELEVATER数据集"
            exit 1
        fi
        ;;
    2)
        echo "\n开始快速同步..."
        for node in "${TARGET_NODES[@]}"; do
            quick_sync_to_node ${node}
        done
        ;;
    3)
        echo "\n检查所有节点连接状态..."
        check_node_connection ${SOURCE_NODE}
        for node in "${TARGET_NODES[@]}"; do
            check_node_connection ${node}
        done
        ;;
    4)
        echo "\n可用数据集："
        ssh ${SOURCE_NODE} "ls -la ${DATAPATH}/datasets/"
        read -p "请输入要同步的数据集名称: " dataset_name
        read -p "请输入目标节点 (${TARGET_NODES[@]}): " target_node
        
        if ssh ${SOURCE_NODE} "[ -d ${DATAPATH}/datasets/${dataset_name} ]"; then
            echo "同步 ${dataset_name} 到 ${target_node}..."
            ssh ${SOURCE_NODE} "rsync -avz ${DATAPATH}/datasets/${dataset_name}/ ${target_node}:${DATAPATH}/datasets/${dataset_name}/"
            echo "✓ 自定义同步完成"
        else
            echo "✗ 数据集 ${dataset_name} 不存在"
        fi
        ;;
    *)
        echo "无效选择"
        exit 1
        ;;
esac

echo "\n========== 数据同步完成 =========="
echo "时间: $(date)"

# 显示所有节点的存储状况
echo "\n各节点存储状况："
for node in ${SOURCE_NODE} "${TARGET_NODES[@]}"; do
    if check_node_connection ${node}; then
        echo "=== ${node} ==="
        ssh ${node} "df -h ${DATAPATH} | tail -1"
        ssh ${node} "du -sh ${DATAPATH}/datasets/* 2>/dev/null || echo '暂无数据集'"
    fi
done 