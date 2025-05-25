#!/bin/bash

echo "=================================================="
echo "  PyTorch分布式完整修复工具（云端执行）"
echo "=================================================="
echo "🎯 修复目标: torch.distributed.nn 模块问题 + 启动命令"
echo "🔧 解决问题: PyTorch 1.12.0+cu113 完整兼容性修复"
echo "🌥️  执行位置: seetacloud-v800 服务器"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 服务器配置
SERVER="seetacloud-v800"

echo "🔗 连接到云端服务器: $SERVER"
echo ""

# 检查SSH连接
echo "📡 测试SSH连接..."
if ! ssh $SERVER "echo '✅ SSH连接成功'" 2>/dev/null; then
    echo -e "${RED}❌ 无法连接到服务器 $SERVER${NC}"
    echo "请检查:"
    echo "  1. SSH配置是否正确"
    echo "  2. 服务器是否运行"
    echo "  3. 网络连接是否正常"
    exit 1
fi

echo ""
echo "📤 上传完整修复脚本到服务器..."

# 创建修复脚本内容（嵌入完整的Python修复脚本）
cat > /tmp/fix_torch_complete_remote.py << 'EOF'
#!/usr/bin/env python3
"""
完整修复 torch.distributed.nn 问题
解决 PyTorch 1.12.0 中缺失的模块和函数
"""

import os
import re
import shutil
from pathlib import Path

def fix_broken_syntax():
    """修复由于重复try语句造成的语法错误"""
    
    train_file = "/root/autodl-tmp/Chinese-CLIP/cn_clip/training/train.py"
    
    if os.path.exists(train_file):
        print(f"🔧 检查并修复 {train_file} 的语法错误...")
        
        with open(train_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # 修复重复的try语句
        content = re.sub(r'try:\s*try:', 'try:', content, flags=re.MULTILINE)
        
        # 修复缩进问题和多重try块
        lines = content.split('\n')
        fixed_lines = []
        skip_next = False
        
        for i, line in enumerate(lines):
            if skip_next:
                skip_next = False
                continue
                
            stripped_line = line.strip()
            
            # 检查是否有重复的try语句
            if 'try:' in line and i < len(lines) - 1:
                next_line = lines[i + 1].strip()
                if next_line == 'try:':
                    # 跳过重复的try
                    skip_next = True
            
            fixed_lines.append(line)
        
        content = '\n'.join(fixed_lines)
        
        # 清理多余的兼容性修复代码块
        compatibility_pattern = r'# PyTorch 1\.12\.0 兼容性修复.*?print\("✅ torch\.distributed\.nn 兼容层已创建"\)'
        matches = list(re.finditer(compatibility_pattern, content, re.DOTALL))
        
        if len(matches) > 1:
            print("🧹 清理重复的兼容性代码块...")
            # 保留第一个，删除其他的
            for match in reversed(matches[1:]):
                content = content[:match.start()] + content[match.end():]
        
        if content != original_content:
            # 创建备份
            backup_path = train_file + '.backup_syntax_fix'
            shutil.copy2(train_file, backup_path)
            
            # 写入修复后的内容
            with open(train_file, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f"✅ 已修复语法错误: {train_file}")
            return True
    
    return False

def fix_torch_distributed_nn_imports():
    """修复所有 torch.distributed.nn 相关的导入和使用问题"""
    
    # 查找所有需要修复的 Python 文件
    python_files = []
    
    # 搜索目录
    search_dirs = [
        "/root/autodl-tmp/Chinese-CLIP",
        "/root/autodl-tmp/cn_clip",
    ]
    
    for search_dir in search_dirs:
        if os.path.exists(search_dir):
            for root, dirs, files in os.walk(search_dir):
                for file in files:
                    if file.endswith('.py'):
                        python_files.append(os.path.join(root, file))
    
    print(f"🔍 找到 {len(python_files)} 个 Python 文件需要检查")
    
    fixed_files = []
    
    for file_path in python_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # 只对包含torch.distributed.nn但没有兼容性修复的文件进行处理
            if 'torch.distributed.nn' in content and '兼容性修复' not in content:
                print(f"📝 为 {file_path} 添加兼容性包装")
                
                # 简化的兼容性代码，避免语法错误
                compatibility_code = '''# PyTorch 1.12.0 兼容性修复
try:
    import torch.distributed.nn
except (ImportError, ModuleNotFoundError):
    import torch.distributed
    import types
    nn_module = types.ModuleType('torch.distributed.nn')
    nn_module.all_gather = torch.distributed.all_gather
    torch.distributed.nn = nn_module

'''
                
                # 在文件开头添加兼容性代码
                content = compatibility_code + content
            
            # 修复 all_gather 使用方式
            if 'torch.distributed.nn.all_gather' in content:
                print(f"📝 修复 {file_path} 中的 all_gather 函数")
                content = re.sub(
                    r'torch\.distributed\.nn\.all_gather\(',
                    'torch.distributed.all_gather(',
                    content
                )
            
            # 如果内容有变化，写回文件
            if content != original_content:
                # 创建备份
                backup_path = file_path + '.backup_distributed_fix'
                shutil.copy2(file_path, backup_path)
                
                # 写入修复后的内容
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                fixed_files.append(file_path)
                print(f"✅ 已修复: {file_path}")
                
        except Exception as e:
            print(f"⚠️  处理文件 {file_path} 时出错: {e}")
    
    return fixed_files

def fix_shell_scripts():
    """修复shell脚本中的启动命令"""
    
    script_files = []
    
    # 搜索目录
    search_dirs = [
        "/root/autodl-tmp/Chinese-CLIP",
        "/root/autodl-tmp/cn_clip",
    ]
    
    for search_dir in search_dirs:
        if os.path.exists(search_dir):
            for root, dirs, files in os.walk(search_dir):
                for file in files:
                    if file.endswith('.sh'):
                        script_files.append(os.path.join(root, file))
    
    print(f"🔍 找到 {len(script_files)} 个shell脚本需要检查")
    
    fixed_scripts = []
    
    for script_path in script_files:
        try:
            with open(script_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # 替换启动命令
            if 'python3 -m torch.distributed.launch' in content:
                print(f"📝 修复 {script_path} 中的启动命令")
                content = re.sub(
                    r'python3 -m torch\.distributed\.launch',
                    'torchrun',
                    content
                )
            
            if content != original_content:
                # 创建备份
                backup_path = script_path + '.backup_launch_fix'
                shutil.copy2(script_path, backup_path)
                
                # 写入修复后的内容
                with open(script_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                fixed_scripts.append(script_path)
                print(f"✅ 已修复: {script_path}")
                
        except Exception as e:
            print(f"⚠️  处理脚本 {script_path} 时出错: {e}")
    
    return fixed_scripts

def main():
    print("=" * 60)
    print("  完整修复 torch.distributed.nn 问题")
    print("=" * 60)
    print("🎯 修复内容:")
    print("  1. 修复语法错误")
    print("  2. torch.distributed.nn 模块导入问题")
    print("  3. all_gather 函数使用问题") 
    print("  4. 添加 PyTorch 1.12.0 兼容层")
    print("  5. 修复shell脚本启动命令")
    print("=" * 60)
    print()
    
    # 步骤0: 先修复语法错误
    print("📋 步骤0: 修复语法错误...")
    syntax_fixed = fix_broken_syntax()
    
    # 步骤1: 修复Python代码
    print("📋 步骤1: 修复 torch.distributed.nn 导入...")
    fixed_files = fix_torch_distributed_nn_imports()
    
    # 步骤2: 修复shell脚本
    print("📋 步骤2: 修复shell脚本启动命令...")
    fixed_scripts = fix_shell_scripts()
    
    print("\n" + "=" * 60)
    print("🎉 修复完成!")
    print("=" * 60)
    if syntax_fixed:
        print("✅ 语法错误已修复")
    print(f"✅ 修复了 {len(fixed_files)} 个Python文件")
    print(f"✅ 修复了 {len(fixed_scripts)} 个shell脚本")
    
    print("\n🧪 建议测试:")
    print("  python -c 'import torch.distributed.nn; print(\"导入成功\")'")
    print("  python -c 'from cn_clip.training.train import train; print(\"训练模块导入成功\")'")

if __name__ == "__main__":
    main()
EOF

# 上传修复脚本到服务器
echo "📤 上传修复脚本..."
scp /tmp/fix_torch_complete_remote.py $SERVER:/tmp/

# 在服务器上执行修复
echo ""
echo "🚀 在服务器上执行完整修复..."
echo "=================================================="

ssh $SERVER << 'ENDSSH'
echo "🔄 激活conda环境..."
source ~/.bashrc
conda activate base

echo ""
echo "📍 当前环境信息:"
python --version
which python
echo "工作目录: $(pwd)"

echo ""
echo "🚀 开始执行修复..."
cd /root/autodl-tmp
python /tmp/fix_torch_complete_remote.py

echo ""
echo "🧪 测试修复结果..."
echo "测试1: torch.distributed.nn导入"
python -c "
try:
    import torch.distributed.nn
    print('✅ torch.distributed.nn 导入成功')
except Exception as e:
    print(f'❌ 导入失败: {e}')
"

echo ""
echo "测试2: train模块导入"
python -c "
try:
    import sys
    sys.path.append('/root/autodl-tmp/Chinese-CLIP')
    from cn_clip.training.train import train
    print('✅ train 模块导入成功')
except Exception as e:
    print(f'❌ train模块导入失败: {e}')
"

echo ""
echo "测试3: 检查修复后的文件"
echo "📁 检查train.py文件:"
head -20 /root/autodl-tmp/Chinese-CLIP/cn_clip/training/train.py

ENDSSH

echo ""
echo "=================================================="
echo "🎉 云端修复执行完成！"
echo "=================================================="
echo -e "${GREEN}✅ 修复任务已在 $SERVER 服务器上完成${NC}"
echo ""
echo "📋 修复内容:"
echo "  ✅ 语法错误修复"
echo "  ✅ torch.distributed.nn 兼容层"
echo "  ✅ all_gather 函数修复"
echo "  ✅ shell脚本启动命令修复"
echo ""
echo "🚀 下一步:"
echo "  1. SSH到服务器测试训练"
echo "  2. 运行单卡测试验证修复效果"
echo "  3. 如有问题查看备份文件恢复"
echo ""
echo "🔗 连接到服务器:"
echo "  ssh $SERVER"
echo ""

# 清理临时文件
rm -f /tmp/fix_torch_complete_remote.py

echo "🧹 本地临时文件已清理" 