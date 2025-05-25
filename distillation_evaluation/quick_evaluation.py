#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
快速评估脚本 - 用于测试单个评估步骤
"""

import os
import subprocess
import argparse
import sys

def run_ssh_command(server, command, description):
    """在指定服务器上运行SSH命令"""
    print(f"\n{'='*60}")
    print(f"正在执行: {description}")
    print(f"服务器: {server}")
    print(f"命令: {command}")
    print(f"{'='*60}")
    
    # 构建完整的SSH命令
    ssh_cmd = f"ssh {server} '{command}'"
    
    result = subprocess.run(ssh_cmd, shell=True, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"错误: {description} 失败")
        print(f"错误信息: {result.stderr}")
        return False
    else:
        print(f"成功完成: {description}")
        if result.stdout:
            print(f"输出:\n{result.stdout}")
        return True

def extract_features(args):
    """步骤1: 图文特征提取"""
    print("\n" + "="*80)
    print("步骤 1: 图文特征提取")
    print("="*80)
    
    # 构建特征提取命令
    extract_cmd = f"""cd /root/autodl-tmp/Chinese-CLIP && \\
source /root/miniconda3/etc/profile.d/conda.sh && \\
conda activate training && \\
export CUDA_VISIBLE_DEVICES=0 && \\
export PYTHONPATH=${{PYTHONPATH}}:`pwd`/cn_clip && \\
python -u cn_clip/eval/extract_features.py \\
    --extract-image-feats \\
    --extract-text-feats \\
    --image-data="{args.datapath}/datasets/{args.dataset_name}/lmdb/{args.split}/imgs" \\
    --text-data="{args.datapath}/datasets/{args.dataset_name}/{args.split}_texts.jsonl" \\
    --img-batch-size=32 \\
    --text-batch-size=32 \\
    --context-length=52 \\
    --resume={args.model_path} \\
    --vision-model={args.vision_model} \\
    --text-model={args.text_model}"""
    
    return run_ssh_command(args.server, extract_cmd, "图文特征提取")

def knn_retrieval(args):
    """步骤2: KNN检索 (文到图)"""
    print("\n" + "="*80)
    print("步骤 2: KNN检索 (文到图)")
    print("="*80)
    
    knn_cmd = f"""cd /root/autodl-tmp/Chinese-CLIP && \\
source /root/miniconda3/etc/profile.d/conda.sh && \\
conda activate training && \\
python -u cn_clip/eval/make_topk_predictions.py \\
    --image-feats="{args.datapath}/datasets/{args.dataset_name}/{args.split}_imgs.img_feat.jsonl" \\
    --text-feats="{args.datapath}/datasets/{args.dataset_name}/{args.split}_texts.txt_feat.jsonl" \\
    --top-k=10 \\
    --eval-batch-size=32768 \\
    --output="{args.datapath}/datasets/{args.dataset_name}/{args.split}_predictions.jsonl" """
    
    return run_ssh_command(args.server, knn_cmd, "KNN检索")

def calculate_recall(args):
    """步骤3: Recall计算"""
    print("\n" + "="*80)
    print("步骤 3: Recall计算")
    print("="*80)
    
    recall_cmd = f"""cd /root/autodl-tmp/Chinese-CLIP && \\
source /root/miniconda3/etc/profile.d/conda.sh && \\
conda activate training && \\
python cn_clip/eval/evaluation.py \\
    {args.datapath}/datasets/{args.dataset_name}/{args.split}_texts.jsonl \\
    {args.datapath}/datasets/{args.dataset_name}/{args.split}_predictions.jsonl \\
    {args.datapath}/datasets/{args.dataset_name}/text_to_image_results.json && \\
echo "=== 文到图检索结果 ===" && \\
cat {args.datapath}/datasets/{args.dataset_name}/text_to_image_results.json"""
    
    return run_ssh_command(args.server, recall_cmd, "Recall计算")

def main():
    parser = argparse.ArgumentParser(description="Chinese-CLIP 快速评估脚本")
    
    # 服务器参数
    parser.add_argument("--server", type=str, required=True, 
                       help="SSH服务器名称 (如: seetacloud-v800, seetacloud-h20)")
    
    # 执行步骤
    parser.add_argument("--step", type=str, required=True, 
                       choices=["extract", "knn", "recall"], 
                       help="执行步骤: extract(特征提取), knn(KNN检索), recall(Recall计算)")
    
    # 数据路径参数
    parser.add_argument("--datapath", type=str, required=True, help="数据路径 (DATAPATH)")
    parser.add_argument("--dataset-name", type=str, required=True, help="数据集名称")
    parser.add_argument("--split", type=str, default="valid", help="数据集分割 (默认: valid)")
    
    # 模型参数 (仅对extract步骤必需)
    parser.add_argument("--model-path", type=str, help="模型检查点路径")
    parser.add_argument("--vision-model", type=str, default="ViT-B-16", help="视觉模型类型")
    parser.add_argument("--text-model", type=str, default="RoBERTa-wwm-ext-base-chinese", help="文本模型类型")
    
    args = parser.parse_args()
    
    # 对于extract步骤，模型路径是必需的
    if args.step == "extract" and not args.model_path:
        print("错误：extract步骤需要提供--model-path参数")
        sys.exit(1)
    
    print("="*80)
    print("Chinese-CLIP 快速评估脚本")
    print("="*80)
    print(f"服务器: {args.server}")
    print(f"执行步骤: {args.step}")
    print(f"数据路径: {args.datapath}")
    print(f"数据集: {args.dataset_name}")
    print(f"分割: {args.split}")
    if args.model_path:
        print(f"模型路径: {args.model_path}")
        print(f"视觉模型: {args.vision_model}")
        print(f"文本模型: {args.text_model}")
    
    # 根据步骤执行相应函数
    if args.step == "extract":
        success = extract_features(args)
    elif args.step == "knn":
        success = knn_retrieval(args)
    elif args.step == "recall":
        success = calculate_recall(args)
    
    print("\n" + "="*80)
    if success:
        print(f"✅ {args.step} 步骤执行成功！")
    else:
        print(f"❌ {args.step} 步骤执行失败！")
        sys.exit(1)
    print("="*80)

if __name__ == "__main__":
    main() 