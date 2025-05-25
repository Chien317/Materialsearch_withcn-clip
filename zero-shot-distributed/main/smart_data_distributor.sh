#!/bin/bash

# ELEVATER数据集智能分发脚本
# 根据任务分配策略，选择性分发数据集子集到对应服务器

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  ELEVATER数据集智能分发器"
echo "=================================================="

# 服务器定义
SOURCE_SERVER="seetacloud-v802"  # 数据源服务器
TARGET_SERVERS=("seetacloud-v800" "seetacloud-v801")

# 根据任务分配策略定义数据集分组（使用更兼容的方式）

# v800和v801需要的前6个数据集
BASIC_DATASETS=(
    "cifar-10" 
    "cifar-100" 
    "caltech-101" 
    "oxford-flower-102" 
    "food-101" 
    "fgvc-aircraft-2013b-variants102"
)

# v802独有的后3个数据集（已经在本地）
EXTENDED_DATASETS=(
    "eurosat_clip"
    "resisc45_clip" 
    "country211"
)

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 步骤1: 检查源服务器数据集状态
echo ""
echo "步骤1: 检查源服务器数据集状态"
echo "----------------------------------------------"

log "检查 ${SOURCE_SERVER} 上的ELEVATER数据集..."
ssh ${SOURCE_SERVER} << 'EOF'
cd /root/autodl-tmp/ELEVATER/all_zip
echo "可用数据集压缩包:"
ls -la *.zip | awk '{print $9, $5}' | column -t
echo ""
echo "总压缩包数量: $(ls *.zip | wc -l)"
echo "总大小: $(du -sh . | cut -f1)"
EOF

# 步骤2: 在v802上解压需要分发的数据集
echo ""
echo "步骤2: 在源服务器解压基础数据集"
echo "----------------------------------------------"

log "在 ${SOURCE_SERVER} 上解压基础数据集..."
ssh ${SOURCE_SERVER} << 'EOF'
cd /root/autodl-tmp/ELEVATER
mkdir -p extracted

# 解压前6个基础数据集
BASIC_DATASETS=("cifar-10" "cifar-100" "caltech-101" "oxford-flower-102" "food-101" "fgvc-aircraft-2013b-variants102")

for dataset in "${BASIC_DATASETS[@]}"; do
    if [ -f "all_zip/${dataset}.zip" ]; then
        if [ ! -d "extracted/${dataset}" ]; then
            echo "解压 ${dataset}..."
            unzip -q "all_zip/${dataset}.zip" -d extracted/
        else
            echo "${dataset} 已解压，跳过"
        fi
    else
        echo "警告: ${dataset}.zip 不存在"
    fi
done

echo "基础数据集解压完成"
ls -la extracted/
EOF

# 步骤3: 分发基础数据集到v800和v801
echo ""
echo "步骤3: 分发基础数据集"
echo "----------------------------------------------"

for target_server in "${TARGET_SERVERS[@]}"; do
    log "开始向 ${target_server} 分发基础数据集..."
    
    # 创建目标目录
    ssh ${target_server} "mkdir -p /root/autodl-tmp/datapath/datasets/ELEVATER"
    
    # 使用rsync高效同步（支持断点续传和增量同步）
    log "  使用rsync同步数据集到 ${target_server}..."
    
    # 修复：将数组转换为字符串传递到远程服务器
    basic_datasets_str="${BASIC_DATASETS[*]}"
    
    ssh ${SOURCE_SERVER} << EOF
cd /root/autodl-tmp/ELEVATER/extracted
# 重新定义数组
BASIC_DATASETS_REMOTE=($basic_datasets_str)
for dataset in "\${BASIC_DATASETS_REMOTE[@]}"; do
    if [ -d "\${dataset}" ]; then
        echo "同步 \${dataset} 到 ${target_server}..."
        rsync -avz --progress "\${dataset}/" ${target_server}:/root/autodl-tmp/datapath/datasets/ELEVATER/"\${dataset}"/
        echo "✅ \${dataset} 同步完成"
    else
        echo "⚠️  \${dataset} 目录不存在，跳过同步"
    fi
done
EOF
    
    log "✅ ${target_server} 基础数据集分发完成"
done

# 步骤4: 在v802上设置扩展数据集
echo ""
echo "步骤4: 在v802设置扩展数据集"
echo "----------------------------------------------"

log "在 ${SOURCE_SERVER} 上解压扩展数据集..."
ssh ${SOURCE_SERVER} << 'EOF'
cd /root/autodl-tmp/ELEVATER

# 确保目标目录存在
mkdir -p /root/autodl-tmp/datapath/datasets/ELEVATER

# 解压扩展数据集
EXTENDED_DATASETS=("eurosat_clip" "resisc45_clip" "country211")

for dataset in "${EXTENDED_DATASETS[@]}"; do
    if [ -f "all_zip/${dataset}.zip" ]; then
        if [ ! -d "/root/autodl-tmp/datapath/datasets/ELEVATER/${dataset}" ]; then
            echo "解压 ${dataset} 到标准位置..."
            unzip -q "all_zip/${dataset}.zip" -d /root/autodl-tmp/datapath/datasets/ELEVATER/
        else
            echo "${dataset} 已在标准位置，跳过"
        fi
    else
        echo "警告: ${dataset}.zip 不存在"
    fi
done

echo "扩展数据集设置完成"
ls -la /root/autodl-tmp/datapath/datasets/ELEVATER/
EOF

# 步骤5: 验证分发结果
echo ""
echo "步骤5: 验证分发结果"
echo "----------------------------------------------"

ALL_SERVERS=("${TARGET_SERVERS[@]}" "${SOURCE_SERVER}")

for server in "${ALL_SERVERS[@]}"; do
    log "验证 ${server} 上的数据集..."
    
    dataset_info=$(ssh ${server} << 'EOF'
cd /root/autodl-tmp/datapath/datasets/ELEVATER 2>/dev/null || exit 1
echo "数据集目录: $(pwd)"
echo "数据集数量: $(ls -d */ 2>/dev/null | wc -l)"
echo "数据集列表:"
ls -la */ 2>/dev/null | head -10
echo "总大小: $(du -sh . 2>/dev/null | cut -f1)"
EOF
)
    
    if [ $? -eq 0 ]; then
        echo "  ${server} 验证结果:"
        echo "$dataset_info" | sed 's/^/    /'
        log "✅ ${server} 数据集验证通过"
    else
        log "❌ ${server} 数据集验证失败"
    fi
    echo ""
done

# 步骤6: 清理临时文件（在验证完成后）
echo ""
echo "步骤6: 清理临时文件"
echo "----------------------------------------------"

log "清理 ${SOURCE_SERVER} 上的临时解压文件..."
ssh ${SOURCE_SERVER} << 'EOF'
cd /root/autodl-tmp/ELEVATER
if [ -d "extracted" ]; then
    echo "保留extracted目录以便后续使用，如需清理请手动删除：rm -rf extracted"
    echo "当前extracted目录大小: $(du -sh extracted 2>/dev/null | cut -f1)"
else
    echo "extracted目录不存在或已被清理"
fi
EOF

# 完成总结
echo ""
echo "=================================================="
echo "🎉 ELEVATER数据集智能分发完成！"
echo "=================================================="
echo ""
echo "分发总结:"
echo "----------------------------------------------"
echo "数据集分配策略:"
echo "  📦 v800 + v801: 基础数据集 (6个)"
echo "    - cifar-10, cifar-100, caltech-101"
echo "    - oxford-flower-102, food-101, fgvc-aircraft"
echo ""
echo "  📦 v802: 扩展数据集 (3个)"
echo "    - eurosat_clip, resisc45_clip, country211"
echo ""
echo "优势:"
echo "  ✅ 避免不必要的数据传输"
echo "  ✅ 节省存储空间"
echo "  ✅ 支持增量同步"
echo "  ✅ 按需分配资源"
echo ""
echo "下一步:"
echo "  运行蒸馏模型分发脚本"
echo "==================================================" 