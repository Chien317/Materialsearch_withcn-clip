# CN-CLIP 蒸馏训练数据下载指令

## ⚠️ 重要说明
**这是分布式评估设置：三个服务器分别负责不同的评估任务和数据集。**
**虽然实验目录中的模型文件相同（评估需要加载同样的训练模型），但每个服务器的零样本预测结果包含不同数据集的评估，都需要收集。**
- **v800**: 主训练服务器 + 部分评估结果
- **v801**: 专门负责baseline和huge模型在特定数据集上的评估
- **v802**: 专门负责team、large、huge模型在其他数据集上的评估

## 概述
此文档包含从三个云服务器（v800, v801, v802）下载所有CN-CLIP蒸馏训练相关数据的详细指令。
**目标路径**: `/Users/chienchen/workspace/model_training/datapath` (保持与云端一致的目录结构)

## 数据分布情况

### seetacloud-v800 (主服务器)
- **训练日志**: training.log (82K)
- **预训练权重**: pretrained_weights/ (1.5G)
- **零样本预测**: zeroshot_predictions/ (88M)
- **压缩模型包**: experiments/distilled_models.tar.gz (6.6GB)
- **实验目录**: 包含4个主要模型实验

### seetacloud-v801 (评估服务器1)
- **零样本预测**: zeroshot_predictions/baseline/ 和 huge/
- **实验目录**: 同样的4个模型实验

### seetacloud-v802 (评估服务器2) 
- **零样本预测**: zeroshot_predictions/huge/, large/, team/
- **实验目录**: 同样的4个模型实验

---

## 下载指令

### 🚀 第一步：创建本地目录结构

```bash
mkdir -p /Users/chienchen/workspace/model_training/datapath/{experiments,zeroshot_predictions,pretrained_weights}
cd /Users/chienchen/workspace/model_training/datapath
```

---

## 📁 seetacloud-v800 下载指令

### 1. 下载训练日志 (82K - 快速)
```bash
scp seetacloud-v800:/root/autodl-tmp/datapath/training.log /Users/chienchen/workspace/model_training/datapath/training.log
```

### 2. 下载预训练权重 (1.5G - 约15秒)
```bash
scp -r seetacloud-v800:/root/autodl-tmp/datapath/pretrained_weights /Users/chienchen/workspace/model_training/datapath/
```

### 3. 下载零样本预测结果 (88M - 约1秒)
```bash
scp -r seetacloud-v800:/root/autodl-tmp/datapath/zeroshot_predictions /Users/chienchen/workspace/model_training/datapath/
```

### 4. 下载压缩模型包 (6.6GB - 约1分钟) ⭐️ 重要
```bash
scp seetacloud-v800:/root/autodl-tmp/datapath/experiments/distilled_models.tar.gz /Users/chienchen/workspace/model_training/datapath/experiments/distilled_models.tar.gz
```

### 5. 下载各个实验目录的日志和评估结果

#### Team蒸馏模型
```bash
scp -r seetacloud-v800:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill /Users/chienchen/workspace/model_training/datapath/experiments/
```

#### Large蒸馏模型
```bash
scp -r seetacloud-v800:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_large_distill /Users/chienchen/workspace/model_training/datapath/experiments/
```

#### Huge蒸馏模型
```bash
scp -r seetacloud-v800:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_huge_distill /Users/chienchen/workspace/model_training/datapath/experiments/
```

#### A800基线模型
```bash
scp -r seetacloud-v800:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_a800 /Users/chienchen/workspace/model_training/datapath/experiments/
```

---

## 📁 seetacloud-v801 下载指令

### 1. 下载零样本预测结果 (补充v800的评估数据)
```bash
# 方案1: 分别下载各个子目录 (推荐)
scp -r seetacloud-v801:/root/autodl-tmp/datapath/zeroshot_predictions/baseline /Users/chienchen/workspace/model_training/datapath/zeroshot_predictions/
scp -r seetacloud-v801:/root/autodl-tmp/datapath/zeroshot_predictions/huge /Users/chienchen/workspace/model_training/datapath/zeroshot_predictions/

# 方案2: 使用rsync (如果scp失败)
# rsync -avz seetacloud-v801:/root/autodl-tmp/datapath/zeroshot_predictions/ /Users/chienchen/workspace/model_training/datapath/zeroshot_predictions/
```

### 2. 下载实验目录的补充评估结果

#### Team蒸馏模型评估结果
```bash
scp -r seetacloud-v801:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill /Users/chienchen/workspace/model_training/datapath/experiments/v801_team_distill
```

#### Large蒸馏模型评估结果
```bash
scp -r seetacloud-v801:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_large_distill /Users/chienchen/workspace/model_training/datapath/experiments/v801_large_distill
```

#### Huge蒸馏模型评估结果
```bash
scp -r seetacloud-v801:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_huge_distill /Users/chienchen/workspace/model_training/datapath/experiments/v801_huge_distill
```

#### A800基线模型评估结果
```bash
scp -r seetacloud-v801:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_a800 /Users/chienchen/workspace/model_training/datapath/experiments/v801_a800
```

---

## 📁 seetacloud-v802 下载指令

### 1. 下载零样本预测结果 (补充评估数据)
```bash
# 方案1: 分别下载各个子目录 (推荐)
scp -r seetacloud-v802:/root/autodl-tmp/datapath/zeroshot_predictions/huge /Users/chienchen/workspace/model_training/datapath/zeroshot_predictions/
scp -r seetacloud-v802:/root/autodl-tmp/datapath/zeroshot_predictions/large /Users/chienchen/workspace/model_training/datapath/zeroshot_predictions/
scp -r seetacloud-v802:/root/autodl-tmp/datapath/zeroshot_predictions/team /Users/chienchen/workspace/model_training/datapath/zeroshot_predictions/

# 方案2: 使用rsync (如果scp失败)
# rsync -avz seetacloud-v802:/root/autodl-tmp/datapath/zeroshot_predictions/ /Users/chienchen/workspace/model_training/datapath/zeroshot_predictions/
```

### 2. 下载实验目录的补充评估结果

#### Team蒸馏模型评估结果
```bash
scp -r seetacloud-v802:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill /Users/chienchen/workspace/model_training/datapath/experiments/v802_team_distill
```

#### Large蒸馏模型评估结果
```bash
scp -r seetacloud-v802:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_large_distill /Users/chienchen/workspace/model_training/datapath/experiments/v802_large_distill
```

#### Huge蒸馏模型评估结果
```bash
scp -r seetacloud-v802:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_huge_distill /Users/chienchen/workspace/model_training/datapath/experiments/v802_huge_distill
```

#### A800基线模型评估结果
```bash
scp -r seetacloud-v802:/root/autodl-tmp/datapath/experiments/muge_finetune_vit-b-16_roberta-base_bs512_4gpu_a800 /Users/chienchen/workspace/model_training/datapath/experiments/v802_a800
```

---

## 📋 执行顺序建议

1. **创建目录结构**:
   ```bash
   mkdir -p /Users/chienchen/workspace/model_training/datapath/{experiments,zeroshot_predictions,pretrained_weights}
   cd /Users/chienchen/workspace/model_training/datapath
   ```

2. **快速验证连接** (下载小文件):
   ```bash
   scp seetacloud-v800:/root/autodl-tmp/datapath/training.log /Users/chienchen/workspace/model_training/datapath/training.log
   ```

3. **下载主要模型包** (最重要):
   ```bash
   scp seetacloud-v800:/root/autodl-tmp/datapath/experiments/distilled_models.tar.gz /Users/chienchen/workspace/model_training/datapath/experiments/distilled_models.tar.gz
   ```

4. **下载v800的其他主要文件**

5. **下载v801和v802的补充评估数据**

---

## 📂 最终目录结构

下载完成后，本地目录结构将如下：

```
/Users/chienchen/workspace/model_training/datapath/
├── training.log                           # 训练日志
├── pretrained_weights/                    # 预训练权重
├── zeroshot_predictions/                  # 合并的零样本预测结果
│   ├── baseline/                         # v801的基线评估
│   ├── huge/                            # huge模型评估 (v801+v802)
│   ├── large/                           # large模型评估 (v802)
│   └── team/                            # team模型评估 (v802)
└── experiments/
    ├── distilled_models.tar.gz          # 🌟 主要模型压缩包
    ├── muge_finetune_vit-b-16_roberta-base_bs512_4gpu_team_distill/    # v800主要实验
    ├── muge_finetune_vit-b-16_roberta-base_bs512_4gpu_large_distill/   # v800主要实验
    ├── muge_finetune_vit-b-16_roberta-base_bs512_4gpu_huge_distill/    # v800主要实验
    ├── muge_finetune_vit-b-16_roberta-base_bs512_4gpu_a800/            # v800主要实验
    ├── v801_team_distill/                # v801补充评估
    ├── v801_large_distill/               # v801补充评估
    ├── v801_huge_distill/                # v801补充评估
    ├── v801_a800/                        # v801补充评估
    ├── v802_team_distill/                # v802补充评估
    ├── v802_large_distill/               # v802补充评估
    ├── v802_huge_distill/                # v802补充评估
    └── v802_a800/                        # v802补充评估
```

---

## 🚀 上传到HuggingFace

下载完成后，使用本地脚本上传：

```bash
cd /Users/chienchen/workspace/huggingface_upload
python upload_to_huggingface.py --token YOUR_HF_TOKEN_HERE --data-path /Users/chienchen/workspace/model_training/datapath
```

---

## 📊 预估时间和大小

| 服务器 | 内容 | 大小 | 预估时间 (105MB/s) |
|--------|------|------|-------------------|
| v800 | distilled_models.tar.gz | 6.6GB | ~1分钟 |
| v800 | pretrained_weights | 1.5GB | ~15秒 |
| v800 | zeroshot_predictions | 88MB | ~1秒 |
| v800 | training.log | 82KB | <1秒 |
| v800 | experiments (4个目录) | ~500MB | ~5秒 |
| v801 | 评估数据 | ~200MB | ~2秒 |
| v802 | 评估数据 | ~200MB | ~2秒 |
| **总计** | | **~9GB** | **~2分钟** |

---

## ⚠️ 注意事项

1. 确保本地有足够的磁盘空间 (至少10GB)
2. 如果某个命令失败，可以重复执行
3. `distilled_models.tar.gz` 是最重要的文件，包含所有训练好的模型
4. v801和v802的实验目录会以前缀区分，避免覆盖v800的主要实验
5. 零样本预测结果会自动合并到同一目录下
6. 下载完成后记得验证文件完整性

---

## 🔧 故障排除

如果下载中断，可以使用 `rsync` 代替 `scp` 来断点续传：

```bash
rsync -avz --progress seetacloud-v800:/root/autodl-tmp/datapath/experiments/distilled_models.tar.gz /Users/chienchen/workspace/model_training/datapath/experiments/
``` 