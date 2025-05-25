# Material Search System

基于Chinese-CLIP的多模态素材搜索系统，支持图像搜索、视频搜索等功能。

## 功能特点

- 文本搜索图片：使用自然语言描述搜索相关图片
- 以图搜图：上传图片搜索相似图片
- 文本搜索视频：使用文本描述搜索视频片段
- 以图搜视频：使用图片搜索相似的视频片段
- 支持私有数据集和模型微调

## 系统架构

- 前端：Vue.js + Element Plus
- 后端：Flask + SQLite
- 模型：Chinese-CLIP (ViT-B/16 + RoBERTa-wwm-ext-Base)
- 图像处理：OpenCV + Pillow
- 视频处理：FFmpeg

## 快速开始

1. 克隆项目
```bash
git clone --recursive https://github.com/Chien317/new_material_search.git
cd new_material_search
```

2. 安装依赖
```bash
pip install -r requirements.txt
```

3. 运行
```bash
./start.sh
```

## 项目结构

```
new_material_search/
├── app.py                    # Flask应用主文件
├── config.py                 # 配置文件
├── models_loader.py          # 模型加载器
├── process_assets.py         # 资源处理
├── search.py                # 搜索功能
├── utils.py                 # 工具函数
├── static/                  # 静态文件
├── model_training/         # 子模块：模型训练相关
│   └── chinese-clip-finetune/
├── chinese_clip_finetuned/  # 模型文件目录
└── requirements.txt        # 依赖文件
```

## 子项目

- [模型训练](./model_training/chinese-clip-finetune): Chinese-CLIP模型微调项目，用于优化模型性能

## 环境要求

- Python 3.10+
- CUDA 11.7+ (可选，用于GPU加速)
- FFmpeg (用于视频处理)

## 配置说明

主要配置项在 `config.py` 中：

- `ASSETS_PATH`: 素材扫描路径
- `MODEL_NAME`: 使用的模型名称
- `DEVICE`: 运行设备 (cpu/cuda/mps)
- `PORT`: 服务端口号

## 许可证

MIT License

## 作者

[Chien Chen](https://github.com/Chien317) 