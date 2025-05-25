#!/bin/bash

echo "=================================================="
echo "  PyTorch分布式启动命令恢复工具"
echo "=================================================="

if [ $# -eq 0 ]; then
    echo "❌ 错误: 请提供备份目录路径"
    echo ""
    echo "用法: $0 <backup_directory>"
    echo ""
    echo "示例: $0 backup_torch_fix_20250524_030000"
    echo ""
    # 显示可用的备份目录
    echo "📁 可用的备份目录:"
    ls -d backup_torch_fix_* 2>/dev/null | head -5
    exit 1
fi

backup_dir="$1"

if [ ! -d "$backup_dir" ]; then
    echo "❌ 错误: 备份目录 '$backup_dir' 不存在"
    exit 1
fi

echo "📁 备份目录: $backup_dir"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

restored_count=0

echo "🔍 恢复备份文件..."
echo "----------------------------------------------"

# 恢复所有备份文件
for backup_file in "$backup_dir"/*.backup; do
    if [ -f "$backup_file" ]; then
        # 获取原始文件名
        original_name=$(basename "$backup_file" .backup)
        
        # 查找原始文件位置
        original_file=$(find . -name "$original_name" -type f | head -1)
        
        if [ -n "$original_file" ]; then
            echo "📝 恢复: $original_file"
            cp "$backup_file" "$original_file"
            restored_count=$((restored_count + 1))
        else
            echo "⚠️  警告: 找不到原始文件 $original_name"
        fi
    fi
done

echo ""
echo "=================================================="
echo "🎉 恢复完成！"
echo "=================================================="
echo "📊 恢复统计:"
echo "  - 恢复文件数: $restored_count"
echo ""

if [ $restored_count -gt 0 ]; then
    echo -e "${GREEN}✅ 文件已恢复到修复前状态${NC}"
    echo ""
    echo "🔄 已还原:"
    echo "  torchrun → torchrun"
else
    echo -e "${YELLOW}ℹ️  没有文件被恢复${NC}"
fi

echo ""
echo "💡 提示: 备份目录 '$backup_dir' 仍然保留，如需删除请手动操作" 