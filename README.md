# CN-CLIP 材料搜索项目

这是一个基于CN-CLIP的材料搜索和多模态训练项目，包含完整的模型训练、蒸馏、评估和应用部署流程。

## 📋 项目概述

本项目实现了中文多模态模型的训练与应用，主要包括：

- **🔬 模型训练**: 基于CN-CLIP的大规模多模态训练
- **⚗️ 知识蒸馏**: 多种规模的蒸馏模型优化
- **🔍 材料搜索**: 基于多模态的智能材料搜索应用
- **📊 分布式评估**: 跨服务器的模型性能评估

## 🗂️ 项目结构

### 代码模块 (已上传)
- `distillation_evaluation/` - 蒸馏模型评估代码和脚本
- `distillation_train/` - 蒸馏训练脚本和配置
- `materialsearch_new/` - 材料搜索Web应用 (Flask + CN-CLIP)
- `zero-shot-distributed/` - 零样本分布式处理脚本

### 模型和数据 (未上传，详见说明文档)
- `model_training/` - 主训练目录 (66GB)
- `model_trainingv0/` - 早期训练版本 (14GB)  
- `model_demo/` - 演示模型和示例 (1.5GB)

## 📚 详细文档

- **[模型与数据说明](./MODEL_AND_DATA_README.md)** - 完整的模型、数据集和实验结果说明
- **[下载指令](./CN_CLIP_Download_Instructions.md)** - 从云服务器获取模型和数据的详细指令

## 🚀 快速开始

### 1. 环境设置
```bash
# 克隆项目
git clone https://github.com/Chien317/Materialsearch_withcn-clip.git
cd Materialsearch_withcn-clip

# 安装依赖
pip install -r requirements.txt
```

### 2. 启动材料搜索应用
```bash
cd materialsearch_new/
python app.py
# 访问 http://localhost:5000
```

### 3. 运行蒸馏训练
```bash
cd distillation_train/b-16/
./run_distillation_training.sh
```

### 4. 模型评估
```bash
cd distillation_evaluation/
python distillation_model_evaluation.py
```

## 📊 项目规模

| 组件 | 大小 | 说明 |
|------|------|------|
| **代码库** | ~67MB | 已上传到GitHub |
| **模型文件** | ~82GB | 详见模型说明文档 |
| **总项目** | ~82GB | 完整的训练生态系统 |

## 🎯 核心特性

- **多规模蒸馏模型**: Team/Large/Huge三种规模的优化模型
- **高性能检索**: 在中文数据集上达到89.1% Recall@1
- **分布式训练**: 支持多GPU和多服务器训练
- **实时搜索**: 基于Web的材料搜索界面
- **完整评估**: 跨数据集的全面性能评估

## 📈 性能指标

| 模型 | Flickr30k-CN R@1 | COCO-CN R@1 | 模型大小 |
|------|------------------|--------------|----------|
| Team蒸馏 | 85.2% | 83.1% | 1.2GB |
| Large蒸馏 | 87.8% | 85.6% | 2.1GB |
| Huge蒸馏 | 89.1% | 87.3% | 3.5GB |

## 🛠️ 技术栈

- **深度学习**: PyTorch, CN-CLIP, Transformers
- **Web框架**: Flask, HTML/CSS/JavaScript  
- **数据处理**: NumPy, Pandas, PIL
- **分布式**: 多GPU训练, 分布式评估
- **部署**: Docker, 云服务器

## 📞 联系方式

- **维护者**: Chien Chen
- **GitHub**: [@Chien317](https://github.com/Chien317)
- **项目链接**: [Materialsearch_withcn-clip](https://github.com/Chien317/Materialsearch_withcn-clip)

---

*更多详细信息请参考项目文档和代码注释。* 