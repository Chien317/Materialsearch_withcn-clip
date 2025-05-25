#!/bin/bash

echo "=================================================="
echo "  NumPy兼容性修复工具"
echo "=================================================="
echo "🎯 修复目标: NumPy 1.25+ 兼容性警告"
echo "🔧 修复文件: zeroshot_evaluation.py"
echo "⚠️  警告内容: Conversion of array to scalar deprecated"
echo "=================================================="

# 本地修复
LOCAL_FILE="model_training/Chinese-CLIP/cn_clip/eval/zeroshot_evaluation.py"
REMOTE_FILE="/root/autodl-tmp/Chinese-CLIP/cn_clip/eval/zeroshot_evaluation.py"

echo "🔍 检查本地文件..."
if [ ! -f "$LOCAL_FILE" ]; then
    echo "❌ 本地文件不存在: $LOCAL_FILE"
    exit 1
fi

echo "✅ 本地文件存在"

# 创建备份
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$LOCAL_FILE" "$BACKUP_DIR/"
echo "✅ 已备份原文件到: $BACKUP_DIR/"

echo "🔧 修复NumPy兼容性问题..."

# 修复accuracy函数
cat > /tmp/numpy_fix.py << 'EOF'
import re
import sys

def fix_numpy_compatibility(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 修复accuracy函数中的NumPy兼容性问题
    old_pattern = r'return \[float\(correct\[:k\]\.reshape\(-1\)\.float\(\)\.sum\(0, keepdim=True\)\.cpu\(\)\.numpy\(\)\) for k in topk\]'
    new_pattern = r'return [correct[:k].reshape(-1).float().sum(0, keepdim=True).cpu().numpy().item() for k in topk]'
    
    if old_pattern in content:
        content = re.sub(old_pattern, new_pattern, content)
        print("✅ 已修复accuracy函数")
    else:
        # 备用修复方案
        old_pattern2 = r'float\(correct\[:k\]\.reshape\(-1\)\.float\(\)\.sum\(0, keepdim=True\)\.cpu\(\)\.numpy\(\)\)'
        new_pattern2 = r'correct[:k].reshape(-1).float().sum(0, keepdim=True).cpu().numpy().item()'
        content = re.sub(old_pattern2, new_pattern2, content)
        print("✅ 已修复NumPy标量转换")
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return True

if __name__ == "__main__":
    file_path = sys.argv[1]
    fix_numpy_compatibility(file_path)
EOF

# 执行修复
python /tmp/numpy_fix.py "$LOCAL_FILE"

echo "📤 上传修复文件到云端服务器..."
scp "$LOCAL_FILE" "seetacloud-v800:$REMOTE_FILE"

echo "🧪 验证修复结果..."
echo "检查修复后的代码片段:"
grep -A 3 -B 3 "return \[" "$LOCAL_FILE" | grep -A 3 -B 3 "numpy"

echo "=================================================="
echo "🎉 NumPy兼容性修复完成！"
echo "=================================================="
echo "✅ 修复内容:"
echo "  - 将 float(tensor.numpy()) 改为 tensor.numpy().item()"
echo "  - 避免NumPy 1.25+的deprecation警告"
echo "  - 本地和云端文件已同步"
echo ""
echo "🧪 建议测试:"
echo "  1. SSH到服务器测试: ssh seetacloud-v800"
echo "  2. 重新运行单卡测试验证修复效果"
echo "  3. 确认警告消失"
echo "=================================================="

# 清理临时文件
rm -f /tmp/numpy_fix.py

echo "🧹 临时文件已清理" 