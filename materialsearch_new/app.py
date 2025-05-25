import os
import sys
import base64
import io
from PIL import Image
import numpy as np
import torch
from flask import Flask, request, jsonify, render_template_string

# 导入模型加载器
from models_loader import load_chinese_clip_model, tokenize, get_available_models, get_model_info

app = Flask(__name__)

# 全局变量存储模型和预处理函数
model = None
preprocess = None
model_info = None

# 简单的HTML模板
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Chinese-CLIP 搜索演示</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; }
        .container { margin-top: 20px; }
        .section { background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .result { margin-top: 20px; }
        input[type="file"], input[type="text"] { margin-bottom: 10px; }
        button { background-color: #4CAF50; color: white; padding: 10px 15px; border: none; cursor: pointer; }
        .model-info { margin-top: 20px; font-size: 0.9em; color: #666; }
    </style>
</head>
<body>
    <h1>Chinese-CLIP 搜索演示</h1>
    
    <div class="model-info">
        <h3>当前加载的模型</h3>
        <p>名称: {{ model_info.name }}</p>
        <p>类型: {{ model_info.type }}</p>
        <p>大小: {{ model_info.size }}</p>
    </div>
</body>
</html>
"""

def load_model():
    """加载Chinese-CLIP模型"""
    global model, preprocess, model_info
    
    # 获取可用模型
    models = get_available_models()
    if not models:
        raise RuntimeError("未找到可用的模型")
    
    # 选择第一个可用的MUGE模型
    selected_model = None
    for model_path in models:
        if "muge" in model_path.lower():
            selected_model = model_path
            break
    
    if not selected_model:
        # 如果没有MUGE模型，使用第一个可用模型
        selected_model = models[0]
    
    # 记录模型信息
    model_info = get_model_info(selected_model)
    print(f"加载模型: {selected_model}")
    
    # 加载模型
    model, preprocess = load_chinese_clip_model(selected_model)
    
    print("模型加载完成")
    return model, preprocess

@app.route('/')
def home():
    """主页"""
    return render_template_string(HTML_TEMPLATE, model_info=model_info)

if __name__ == '__main__':
    # 设置设备
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"使用设备: {device}")
    
    # 加载模型
    load_model()
    
    # 启动Flask应用，使用8085端口
    print("启动Web服务，访问 http://127.0.0.1:8085 查看演示")
    app.run(debug=True, port=8085) 