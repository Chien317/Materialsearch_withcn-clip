#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
环境测试脚本 - 验证蒸馏模型评估环境是否配置正确
"""

import subprocess
import sys

def test_ssh_connection():
    """测试SSH连接"""
    print("1. 测试SSH连接...")
    try:
        result = subprocess.run(['ssh', 'seetacloud-v800', 'echo "SSH连接成功"'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ SSH连接正常")
            return True
        else:
            print(f"❌ SSH连接失败: {result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        print("❌ SSH连接超时")
        return False
    except Exception as e:
        print(f"❌ SSH连接错误: {e}")
        return False

def test_conda_environment():
    """测试conda环境"""
    print("\n2. 测试conda环境...")
    try:
        result = subprocess.run('ssh seetacloud-v800 "source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && echo Conda环境激活成功"', 
                              capture_output=True, text=True, timeout=10, shell=True)
        if result.returncode == 0:
            print("✅ conda training环境可用")
            return True
        else:
            print(f"❌ conda环境测试失败: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ conda环境测试错误: {e}")
        return False

def test_chinese_clip_installation():
    """测试Chinese-CLIP安装"""
    print("\n3. 测试Chinese-CLIP安装...")
    try:
        result = subprocess.run(['ssh', 'seetacloud-v800', 'ls -la /root/autodl-tmp/Chinese-CLIP'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ Chinese-CLIP目录存在")
            # 检查评估脚本
            result2 = subprocess.run(['ssh', 'seetacloud-v800', 'ls /root/autodl-tmp/Chinese-CLIP/cn_clip/eval/extract_features.py'], 
                                   capture_output=True, text=True, timeout=10)
            if result2.returncode == 0:
                print("✅ 评估脚本存在")
                return True
            else:
                print("❌ 评估脚本不存在")
                return False
        else:
            print(f"❌ Chinese-CLIP目录不存在: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Chinese-CLIP检查错误: {e}")
        return False

def test_gpu_availability():
    """测试GPU可用性"""
    print("\n4. 测试GPU可用性...")
    try:
        result = subprocess.run(['ssh', 'seetacloud-v800', 'nvidia-smi'], 
                              capture_output=True, text=True, timeout=15)
        if result.returncode == 0:
            print("✅ GPU可用")
            print("GPU信息:")
            lines = result.stdout.split('\n')
            for line in lines:
                if 'NVIDIA' in line or 'GPU' in line or 'GeForce' in line or 'Tesla' in line:
                    print(f"   {line.strip()}")
            return True
        else:
            print(f"❌ GPU不可用: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ GPU检查错误: {e}")
        return False

def test_python_environment():
    """测试Python环境"""
    print("\n5. 测试Python环境...")
    try:
        cmd = 'ssh seetacloud-v800 "source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && python -c \'import torch; print(f\\\"PyTorch版本: {torch.__version__}\\\"); print(f\\\"CUDA可用: {torch.cuda.is_available()}\\\"); print(f\\\"GPU数量: {torch.cuda.device_count()}\\\")\'\"'
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15, shell=True)
        if result.returncode == 0:
            print("✅ Python环境正常")
            print(f"环境信息: {result.stdout.strip()}")
            return True
        else:
            print(f"❌ Python环境测试失败: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Python环境测试错误: {e}")
        return False

def main():
    print("="*60)
    print("蒸馏模型评估环境测试")
    print("="*60)
    
    tests = [
        test_ssh_connection,
        test_conda_environment,
        test_chinese_clip_installation,
        test_gpu_availability,
        test_python_environment
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        else:
            print("   建议检查配置后重新测试")
    
    print("\n" + "="*60)
    print(f"测试结果: {passed}/{total} 项通过")
    
    if passed == total:
        print("🎉 环境配置完成，可以开始评估蒸馏模型！")
        print("\n下一步:")
        print("1. 准备数据集（按Chinese-CLIP格式）")
        print("2. 运行 python distillation_model_evaluation.py --help 查看使用方法")
    else:
        print("❌ 请先解决环境配置问题")
        print("\n常见解决方案:")
        print("- 检查SSH密钥配置")
        print("- 确认conda环境已创建")
        print("- 检查Chinese-CLIP是否正确安装")
        print("- 验证GPU驱动和CUDA版本")
    
    print("="*60)

if __name__ == "__main__":
    main() 