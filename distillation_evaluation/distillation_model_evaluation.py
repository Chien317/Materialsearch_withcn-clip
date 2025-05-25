#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
蒸馏模型评估脚本
复刻Chinese-CLIP的完整评估流程：特征提取 + KNN检索 + Recall计算
"""

import os
import sys
import json
import argparse
import subprocess
from pathlib import Path

def run_command(cmd, description):
    """执行命令并处理错误"""
    print(f"\n{'='*60}")
    print(f"正在执行: {description}")
    print(f"命令: {cmd}")
    print(f"{'='*60}")
    
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"错误: {description} 失败")
        print(f"错误信息: {result.stderr}")
        return False
    else:
        print(f"成功完成: {description}")
        if result.stdout:
            print(f"输出: {result.stdout}")
        return True

def extract_features(args):
    """步骤1: 图文特征提取"""
    print("\n" + "="*80)
    print("步骤 1: 图文特征提取")
    print("="*80)
    
    # 特征提取命令
    extract_cmd = f"""
ssh seetacloud-v800 'cd /root/autodl-tmp/Chinese-CLIP && source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && \\
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
    --text-model={args.text_model}'
    """
    
    return run_command(extract_cmd, "图文特征提取")

def knn_retrieval_text_to_image(args):
    """步骤2a: 文到图检索 (KNN)"""
    print("\n" + "="*80)
    print("步骤 2a: 文到图检索 (KNN)")
    print("="*80)
    
    knn_cmd = f"""
ssh seetacloud-v800 'cd /root/autodl-tmp/Chinese-CLIP && source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && \\
python -u cn_clip/eval/make_topk_predictions.py \\
    --image-feats="{args.datapath}/datasets/{args.dataset_name}/{args.split}_imgs.img_feat.jsonl" \\
    --text-feats="{args.datapath}/datasets/{args.dataset_name}/{args.split}_texts.txt_feat.jsonl" \\
    --top-k=10 \\
    --eval-batch-size=32768 \\
    --output="{args.datapath}/datasets/{args.dataset_name}/{args.split}_predictions.jsonl"'
    """
    
    return run_command(knn_cmd, "文到图检索")

def knn_retrieval_image_to_text(args):
    """步骤2b: 图到文检索 (KNN)"""
    print("\n" + "="*80)
    print("步骤 2b: 图到文检索 (KNN)")
    print("="*80)
    
    # 首先转换标注格式
    transform_cmd = f"""
ssh seetacloud-v800 'cd /root/autodl-tmp/Chinese-CLIP && source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && \\
python cn_clip/eval/transform_ir_annotation_to_tr.py \\
    --input {args.datapath}/datasets/{args.dataset_name}/{args.split}_texts.jsonl'
    """
    
    if not run_command(transform_cmd, "转换标注格式（图到文）"):
        return False
    
    # 执行图到文检索
    knn_cmd = f"""
ssh seetacloud-v800 'cd /root/autodl-tmp/Chinese-CLIP && source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && \\
python -u cn_clip/eval/make_topk_predictions_tr.py \\
    --image-feats="{args.datapath}/datasets/{args.dataset_name}/{args.split}_imgs.img_feat.jsonl" \\
    --text-feats="{args.datapath}/datasets/{args.dataset_name}/{args.split}_texts.txt_feat.jsonl" \\
    --top-k=10 \\
    --eval-batch-size=32768 \\
    --output="{args.datapath}/datasets/{args.dataset_name}/{args.split}_tr_predictions.jsonl"'
    """
    
    return run_command(knn_cmd, "图到文检索")

def calculate_recall_text_to_image(args):
    """步骤3a: 文到图检索 Recall计算"""
    print("\n" + "="*80)
    print("步骤 3a: 文到图检索 Recall计算")
    print("="*80)
    
    recall_cmd = f"""
ssh seetacloud-v800 'cd /root/autodl-tmp/Chinese-CLIP && source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && \\
python cn_clip/eval/evaluation.py \\
    {args.datapath}/datasets/{args.dataset_name}/{args.split}_texts.jsonl \\
    {args.datapath}/datasets/{args.dataset_name}/{args.split}_predictions.jsonl \\
    {args.datapath}/datasets/{args.dataset_name}/text_to_image_results.json && \\
cat {args.datapath}/datasets/{args.dataset_name}/text_to_image_results.json'
    """
    
    return run_command(recall_cmd, "文到图检索Recall计算")

def calculate_recall_image_to_text(args):
    """步骤3b: 图到文检索 Recall计算"""
    print("\n" + "="*80)
    print("步骤 3b: 图到文检索 Recall计算")
    print("="*80)
    
    recall_cmd = f"""
ssh seetacloud-v800 'cd /root/autodl-tmp/Chinese-CLIP && source /root/miniconda3/etc/profile.d/conda.sh && conda activate training && \\
python cn_clip/eval/evaluation_tr.py \\
    {args.datapath}/datasets/{args.dataset_name}/{args.split}_texts.tr.jsonl \\
    {args.datapath}/datasets/{args.dataset_name}/{args.split}_tr_predictions.jsonl \\
    {args.datapath}/datasets/{args.dataset_name}/image_to_text_results.json && \\
cat {args.datapath}/datasets/{args.dataset_name}/image_to_text_results.json'
    """
    
    return run_command(recall_cmd, "图到文检索Recall计算")

def main():
    parser = argparse.ArgumentParser(description="蒸馏模型评估脚本")
    
    # 基础参数
    parser.add_argument("--datapath", type=str, required=True, help="数据路径 (DATAPATH)")
    parser.add_argument("--dataset-name", type=str, required=True, help="数据集名称")
    parser.add_argument("--split", type=str, default="valid", choices=["valid", "test"], help="数据集分割")
    parser.add_argument("--model-path", type=str, required=True, help="蒸馏模型检查点路径")
    
    # 模型参数
    parser.add_argument("--vision-model", type=str, default="ViT-B-16", 
                       choices=["ViT-B-32", "ViT-B-16", "ViT-L-14", "ViT-L-14-336", "ViT-H-14", "RN50"], 
                       help="视觉模型类型")
    parser.add_argument("--text-model", type=str, default="RoBERTa-wwm-ext-base-chinese",
                       choices=["RoBERTa-wwm-ext-base-chinese", "RoBERTa-wwm-ext-large-chinese", "RBT3-chinese"],
                       help="文本模型类型")
    
    # 执行选项
    parser.add_argument("--skip-extraction", action="store_true", help="跳过特征提取步骤")
    parser.add_argument("--skip-text-to-image", action="store_true", help="跳过文到图检索")
    parser.add_argument("--skip-image-to-text", action="store_true", help="跳过图到文检索")
    
    args = parser.parse_args()
    
    print("="*80)
    print("蒸馏模型评估脚本")
    print("="*80)
    print(f"数据路径: {args.datapath}")
    print(f"数据集: {args.dataset_name}")
    print(f"分割: {args.split}")
    print(f"模型路径: {args.model_path}")
    print(f"视觉模型: {args.vision_model}")
    print(f"文本模型: {args.text_model}")
    
    success = True
    
    # 步骤1: 特征提取
    if not args.skip_extraction:
        if not extract_features(args):
            success = False
            print("特征提取失败，停止执行")
            return
    else:
        print("\n跳过特征提取步骤")
    
    # 步骤2a & 3a: 文到图检索
    if not args.skip_text_to_image:
        if knn_retrieval_text_to_image(args):
            calculate_recall_text_to_image(args)
        else:
            success = False
            print("文到图检索失败")
    else:
        print("\n跳过文到图检索")
    
    # 步骤2b & 3b: 图到文检索
    if not args.skip_image_to_text:
        if knn_retrieval_image_to_text(args):
            calculate_recall_image_to_text(args)
        else:
            success = False
            print("图到文检索失败")
    else:
        print("\n跳过图到文检索")
    
    print("\n" + "="*80)
    if success:
        print("🎉 评估完成！")
        print("结果文件:")
        print(f"  - 文到图检索结果: {args.datapath}/datasets/{args.dataset_name}/text_to_image_results.json")
        print(f"  - 图到文检索结果: {args.datapath}/datasets/{args.dataset_name}/image_to_text_results.json")
    else:
        print("❌ 评估过程中出现错误")
    print("="*80)

if __name__ == "__main__":
    main() 