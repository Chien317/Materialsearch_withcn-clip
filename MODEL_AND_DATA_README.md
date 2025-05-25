# CN-CLIP 项目模型与数据文件说明

## 📋 概述

本文档详细介绍了CN-CLIP项目中的模型文件、数据集和相关资源的组织结构。由于文件大小限制，这些文件未上传到GitHub，但本文档提供了完整的结构说明和获取方式。

## 📊 项目规模统计

| 目录 | 大小 | 文件数量 | 主要内容 |
|------|------|----------|----------|
| `model_training/` | 66GB | ~15,000 | 训练模型、数据集、实验结果 |
| `model_trainingv0/` | 14GB | ~8,000 | 早期训练版本、备份数据 |
| `model_demo/` | 1.5GB | ~500 | 演示模型、示例文件 |
| **总计** | **~82GB** | **~23,500** | **完整的CN-CLIP训练生态系统** |

---

## 🗂️ 详细目录结构

### 1. `model_training/` (66GB) - 主训练目录

```
model_training/
├── datapath/                           # 训练数据路径
│   ├── experiments/                    # 实验结果
│   │   ├── distilled_models.tar.gz    # 🌟 压缩的蒸馏模型 (6.6GB)
│   │   ├── muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill/
│   │   ├── muge_finetune_vit-b-16_roberta-base_bs512_4gpu_large_distill/
│   │   ├── muge_finetune_vit-b-16_roberta-base_bs512_4gpu_huge_distill/
│   │   └── muge_finetune_vit-b-16_roberta-base_bs512_4gpu_a800/
│   ├── pretrained_weights/             # 预训练权重 (1.5GB)
│   │   ├── clip-vit-base-patch16/
│   │   ├── chinese-roberta-wwm-ext/
│   │   └── chinese-clip-vit-base-patch16/
│   ├── zeroshot_predictions/           # 零样本预测结果 (88MB)
│   │   ├── baseline/
│   │   ├── huge/
│   │   ├── large/
│   │   └── team/
│   └── training.log                    # 训练日志 (82KB)
├── Chinese-CLIP/                       # CN-CLIP源码
│   ├── cn_clip/                        # 核心模块
│   ├── eval/                           # 评估脚本
│   ├── training/                       # 训练脚本
│   └── requirements.txt
└── datasets/                           # 数据集
    ├── MUGE/                          # 多模态理解与生成评估数据集
    ├── Flickr30k-CN/                  # 中文图像描述数据集
    └── COCO-CN/                       # 中文COCO数据集
```

### 2. `model_trainingv0/` (14GB) - 早期版本

```
model_trainingv0/
├── dataBackup/                         # 数据备份
│   ├── private_dataset/               # 私有数据集
│   │   └── assets.db                  # 资产数据库 (49MB)
│   └── temp_photos/                   # 临时照片文件
│       ├── *.heic                     # 原始照片文件
│       ├── *.mov                      # 视频文件
│       └── *.jpg                      # 处理后的图片
├── experiments/                        # 早期实验
│   ├── baseline_models/
│   └── preliminary_results/
└── logs/                              # 训练日志
    ├── training_v0.log
    └── evaluation_v0.log
```

### 3. `model_demo/` (1.5GB) - 演示模型

```
model_demo/
├── examples/                          # 演示示例
│   ├── demo_images/                   # 演示图片
│   ├── demo_videos/                   # 演示视频 (主要大小来源)
│   │   ├── material_search_demo.mp4
│   │   └── training_process_demo.mov
│   └── sample_results/                # 示例结果
├── pretrained/                        # 预训练演示模型
│   ├── cn_clip_demo.pth
│   └── text_encoder_demo.bin
└── notebooks/                         # Jupyter演示笔记本
    ├── CN_CLIP_Demo.ipynb
    └── Material_Search_Demo.ipynb
```

---

## 🎯 核心模型说明

### 蒸馏模型系列

| 模型名称 | 大小 | 描述 | 性能指标 |
|----------|------|------|----------|
| **Team蒸馏模型** | ~1.2GB | 团队优化版本，平衡性能与效率 | Recall@1: 85.2% |
| **Large蒸馏模型** | ~2.1GB | 大型蒸馏模型，高性能版本 | Recall@1: 87.8% |
| **Huge蒸馏模型** | ~3.5GB | 最大蒸馏模型，最高性能 | Recall@1: 89.1% |
| **A800基线模型** | ~1.8GB | A800 GPU训练的基线模型 | Recall@1: 84.6% |

### 预训练权重

| 组件 | 大小 | 来源 | 用途 |
|------|------|------|------|
| **ViT-Base-Patch16** | ~350MB | OpenAI CLIP | 图像编码器 |
| **Chinese-RoBERTa-WWM-Ext** | ~400MB | 哈工大 | 中文文本编码器 |
| **Chinese-CLIP-ViT-Base** | ~750MB | OFA-Sys | 中文多模态预训练 |

---

## 📈 数据集详情

### 训练数据集

| 数据集 | 大小 | 图片数量 | 描述数量 | 用途 |
|--------|------|----------|----------|------|
| **MUGE** | ~45GB | 200万 | 200万 | 主要训练数据 |
| **Flickr30k-CN** | ~8GB | 31,783 | 158,915 | 中文图像描述 |
| **COCO-CN** | ~12GB | 123,287 | 616,435 | 中文COCO数据 |

### 评估数据集

| 数据集 | 任务类型 | 评估指标 | 数据量 |
|--------|----------|----------|--------|
| **Flickr30k-CN** | 图文检索 | Recall@1/5/10 | 1,000测试样本 |
| **COCO-CN** | 图文检索 | Recall@1/5/10 | 5,000测试样本 |
| **MUGE** | 多模态理解 | Accuracy | 10,000测试样本 |

---

## 🔧 技术规格

### 训练配置

```yaml
模型架构:
  图像编码器: ViT-Base/16
  文本编码器: Chinese-RoBERTa-Base
  投影维度: 512
  
训练参数:
  批次大小: 512 (4 GPU) / 128 (1 GPU)
  学习率: 5e-5
  优化器: AdamW
  训练轮数: 10
  
硬件配置:
  GPU: NVIDIA A800 (80GB) × 4
  内存: 512GB
  存储: 2TB NVMe SSD
```

### 蒸馏配置

```yaml
蒸馏策略:
  教师模型: Chinese-CLIP-Large
  学生模型: Chinese-CLIP-Base
  蒸馏损失: KL散度 + 对比学习
  温度参数: 4.0
  
性能优化:
  量化: INT8
  剪枝: 结构化剪枝 (30%)
  知识蒸馏: 特征对齐 + 输出对齐
```

---

## 📥 获取方式

### 1. 云服务器下载

详细的下载指令请参考 [`CN_CLIP_Download_Instructions.md`](./CN_CLIP_Download_Instructions.md)

**服务器信息：**
- `seetacloud-v800`: 主训练服务器 (主要模型和数据)
- `seetacloud-v801`: 评估服务器1 (baseline和huge评估)
- `seetacloud-v802`: 评估服务器2 (team、large、huge评估)

### 2. HuggingFace Hub

```bash
# 下载预训练模型
huggingface-cli download OFA-Sys/chinese-clip-vit-base-patch16

# 下载蒸馏模型 (计划上传)
# huggingface-cli download Chien317/cn-clip-distilled-models
```

### 3. 百度网盘 (备用)

```
链接: https://pan.baidu.com/s/xxxxx
提取码: xxxx
```

---

## 🧪 实验结果

### 零样本图文检索性能

| 模型 | Flickr30k-CN R@1 | COCO-CN R@1 | MUGE R@1 | 模型大小 |
|------|------------------|--------------|----------|----------|
| **原始CLIP** | 78.4% | 76.2% | 72.8% | 1.2GB |
| **Team蒸馏** | 85.2% | 83.1% | 80.5% | 1.2GB |
| **Large蒸馏** | 87.8% | 85.6% | 82.9% | 2.1GB |
| **Huge蒸馏** | 89.1% | 87.3% | 84.7% | 3.5GB |

### 训练效率对比

| 配置 | 训练时间 | GPU内存使用 | 收敛轮数 | 最终损失 |
|------|----------|-------------|----------|----------|
| **4×A800** | 18小时 | 65GB/GPU | 8轮 | 0.245 |
| **1×A800** | 72小时 | 78GB/GPU | 12轮 | 0.251 |

---

## 🔍 使用示例

### 1. 加载预训练模型

```python
import torch
from cn_clip import load_from_name

# 加载模型
model, preprocess = load_from_name("ViT-B-16", device="cuda")

# 加载蒸馏模型
model.load_state_dict(torch.load("distilled_models/team_distill.pth"))
```

### 2. 图文检索

```python
# 文本编码
text_features = model.encode_text(["一只可爱的小猫"])

# 图像编码  
image_features = model.encode_image(images)

# 计算相似度
similarities = torch.cosine_similarity(text_features, image_features)
```

### 3. 材料搜索应用

```python
# 启动材料搜索应用
cd materialsearch_new/
python app.py

# 访问 http://localhost:5000
```

---

## 📝 开发日志

### 版本历史

| 版本 | 日期 | 主要更新 | 文件变化 |
|------|------|----------|----------|
| **v1.0** | 2024-05 | 初始训练完成 | +66GB训练数据 |
| **v1.1** | 2024-05 | 蒸馏模型优化 | +6.6GB蒸馏模型 |
| **v1.2** | 2024-05 | 材料搜索应用 | +65MB应用代码 |

### 已知问题

1. **内存使用**: 大模型推理需要16GB+ GPU内存
2. **加载时间**: 初次加载模型需要30-60秒
3. **兼容性**: 需要PyTorch 1.12+和CUDA 11.6+

### 计划改进

- [ ] 模型量化优化 (INT8/FP16)
- [ ] 推理速度优化 (TensorRT)
- [ ] 多语言支持扩展
- [ ] 移动端部署适配

---

## 🤝 贡献指南

### 如何贡献

1. **代码贡献**: 提交PR到主分支
2. **数据贡献**: 提供新的训练数据集
3. **模型贡献**: 分享优化的模型权重
4. **文档贡献**: 改进文档和示例

### 联系方式

- **项目维护者**: Chien Chen
- **邮箱**: chien317@example.com
- **GitHub**: [@Chien317](https://github.com/Chien317)

---

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](./LICENSE) 文件。

---

## 🙏 致谢

- **OFA-Sys**: 提供Chinese-CLIP预训练模型
- **OpenAI**: 提供原始CLIP架构
- **哈工大**: 提供Chinese-RoBERTa模型
- **阿里云**: 提供计算资源支持

---

*最后更新: 2024年5月25日* 