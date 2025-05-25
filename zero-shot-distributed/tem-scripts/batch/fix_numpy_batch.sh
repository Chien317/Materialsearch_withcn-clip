#!/bin/bash

echo "=================================================="
echo "  NumPy兼容性批量修复工具"
echo "=================================================="
echo "🎯 修复目标: 所有服务器的NumPy 1.25+ 兼容性警告"
echo "🔧 修复文件: zeroshot_evaluation.py"
echo "🖥️  目标服务器: v800, v801, v802"
echo "=================================================="

# 服务器列表
SERVERS=("seetacloud-v800" "seetacloud-v801" "seetacloud-v802")
LOCAL_FILE="model_training/Chinese-CLIP/cn_clip/eval/zeroshot_evaluation.py"
REMOTE_FILE="/root/autodl-tmp/Chinese-CLIP/cn_clip/eval/zeroshot_evaluation.py"

# 检查本地文件
echo "🔍 检查本地文件..."
if [ ! -f "$LOCAL_FILE" ]; then
    echo "❌ 本地文件不存在: $LOCAL_FILE"
    exit 1
fi

echo "✅ 本地文件存在"

# 检查文件是否已经修复
if grep -q "\.numpy()\.item()" "$LOCAL_FILE"; then
    echo "✅ 本地文件已经修复过"
else
    echo "🔧 首先修复本地文件..."
    # 创建备份
    BACKUP_DIR="backup_batch_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp "$LOCAL_FILE" "$BACKUP_DIR/"
    echo "✅ 已备份原文件到: $BACKUP_DIR/"
    
    # 修复本地文件
    cat > /tmp/numpy_fix_batch.py << 'EOF'
import re
import sys

def fix_numpy_compatibility(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 修复accuracy函数中的NumPy兼容性问题
    old_pattern = r'float\(correct\[:k\]\.reshape\(-1\)\.float\(\)\.sum\(0, keepdim=True\)\.cpu\(\)\.numpy\(\)\)'
    new_pattern = r'correct[:k].reshape(-1).float().sum(0, keepdim=True).cpu().numpy().item()'
    
    if old_pattern in content:
        content = re.sub(old_pattern, new_pattern, content)
        print("✅ 已修复NumPy标量转换")
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    else:
        print("ℹ️  文件已经是修复状态")
        return False

if __name__ == "__main__":
    file_path = sys.argv[1]
    fix_numpy_compatibility(file_path)
EOF
    
    python /tmp/numpy_fix_batch.py "$LOCAL_FILE"
    rm -f /tmp/numpy_fix_batch.py
fi

echo ""
echo "📡 开始批量同步到所有服务器..."
echo ""

# 批量处理所有服务器
success_count=0
total_count=${#SERVERS[@]}

for server in "${SERVERS[@]}"; do
    echo "----------------------------------------"
    echo "🖥️  正在处理服务器: $server"
    echo "----------------------------------------"
    
    # 检查SSH连接
    echo "📡 测试SSH连接..."
    if ssh -o ConnectTimeout=10 "$server" "echo 'SSH连接成功'" 2>/dev/null; then
        echo "✅ SSH连接正常"
        
        # 上传修复文件
        echo "📤 上传修复文件..."
        if scp "$LOCAL_FILE" "$server:$REMOTE_FILE" 2>/dev/null; then
            echo "✅ 文件上传成功"
            
            # 验证远程文件
            echo "🧪 验证远程修复..."
            if ssh "$server" "grep -q '\.numpy()\.item()' '$REMOTE_FILE'" 2>/dev/null; then
                echo "✅ 远程文件修复验证成功"
                ((success_count++))
            else
                echo "⚠️  远程文件验证失败"
            fi
        else
            echo "❌ 文件上传失败"
        fi
    else
        echo "❌ SSH连接失败，跳过服务器 $server"
    fi
    echo ""
done

echo "=================================================="
echo "🎉 批量修复完成！"
echo "=================================================="
echo "📊 处理结果:"
echo "  ✅ 成功: $success_count/$total_count 个服务器"
echo "  📁 本地备份: $(ls -d backup_batch_* 2>/dev/null | tail -1 || echo '无需备份')"
echo ""
echo "🧪 建议测试:"
echo "  1. SSH到各服务器验证修复: ssh <server-name>"
echo "  2. 运行测试确认NumPy警告消失"
echo ""
echo "服务器列表:"
for server in "${SERVERS[@]}"; do
    echo "  - $server"
done
echo "==================================================" 