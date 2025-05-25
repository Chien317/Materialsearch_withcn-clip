import os
import sys
import torch
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

# Chinese-CLIP模型路径
MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chinese_clip_finetuned")

if not os.path.exists(MODEL_PATH):
    logger.error(f"未找到Chinese-CLIP路径: {MODEL_PATH}")
    raise FileNotFoundError(f"模型路径不存在: {MODEL_PATH}")

sys.path.append(MODEL_PATH)
logger.info(f"添加Chinese-CLIP路径: {MODEL_PATH}")
    
try:
    from cn_clip.clip import image_transform, tokenize
    from cn_clip.clip.utils import create_model
    logger.info("成功导入Chinese-CLIP模块")
except ImportError as e:
    logger.error(f"导入Chinese-CLIP失败: {e}")
    logger.error("将使用备用方法加载模型")
    # 在这里可以添加备用的模型加载方法

def load_chinese_clip_model(model_path, 
                           vision_model="ViT-B-16", 
                           text_model="RoBERTa-wwm-ext-base-chinese", 
                           input_resolution=224,
                           device=None):
    """
    加载任何格式的Chinese-CLIP模型，处理模型格式差异
    
    参数:
        model_path (str): 模型文件路径
        vision_model (str): 视觉模型类型，默认为"ViT-B-16"
        text_model (str): 文本模型类型，默认为"RoBERTa-wwm-ext-base-chinese"
        input_resolution (int): 输入分辨率，默认为224
        device (str, optional): 设备，默认为None，会自动检测
        
    返回:
        tuple: (model, preprocess_function)
    """
    # 检查模型文件是否存在
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"模型文件不存在: {model_path}")
    
    if device is None:
        device = "cuda" if torch.cuda.is_available() else "cpu"
    
    # 创建模型结构
    model_name = f"{vision_model}@{text_model}"
    try:
        model = create_model(model_name)
    except Exception as e:
        logger.error(f"创建模型结构失败: {e}")
        raise RuntimeError(f"无法创建模型结构: {e}")
    
    # 安全加载模型权重，兼容PyTorch 2.6+
    try:
        checkpoint = torch.load(model_path, map_location="cpu", weights_only=False)
    except (TypeError, ValueError, RuntimeError) as e:
        logger.warning(f"使用weights_only=False加载失败: {e}")
        logger.info("尝试使用默认参数加载...")
        try:
            checkpoint = torch.load(model_path, map_location="cpu")
        except Exception as e:
            raise RuntimeError(f"无法加载模型 {model_path}: {e}")
    
    # 处理不同的checkpoint格式
    if isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        logger.info(f"发现state_dict键，使用state_dict中的权重")
        state_dict = checkpoint["state_dict"]
    else:
        logger.info(f"直接使用checkpoint作为state_dict")
        state_dict = checkpoint
    
    # 确保state_dict不为空
    if not state_dict:
        raise ValueError(f"模型权重为空: {model_path}")
    
    # 检查第一个键名
    first_key = list(state_dict.keys())[0]
    logger.info(f"第一个键名: {first_key}")
    
    # 处理module前缀 - 这是关键步骤
    if first_key.startswith('module.'):
        logger.info(f"检测到module前缀，正在移除...")
        state_dict = {k[len('module.'):]: v for k, v in state_dict.items()}
    
    # 加载权重到模型
    missing, unexpected = model.load_state_dict(state_dict, strict=False)
    
    # 如果有大量缺失键，记录警告但继续执行
    if len(missing) > 0:
        logger.warning(f"警告: 模型加载时有 {len(missing)} 个缺失键")
        if len(missing) < 10:
            logger.warning(f"缺失键: {missing}")
        else:
            logger.warning(f"缺失键示例: {missing[:5]}")
            
    if len(unexpected) > 0:
        logger.warning(f"警告: 模型加载时有 {len(unexpected)} 个意外键")
        if len(unexpected) < 10:
            logger.warning(f"意外键: {unexpected}")
        else:
            logger.warning(f"意外键示例: {unexpected[:5]}")
    
    # 设置模型到指定设备并设为评估模式
    model = model.to(device)
    model.eval()
    
    # 手动添加device属性以便在app.py中访问
    model.device = device
    
    # 返回模型和预处理函数
    preprocess = image_transform(input_resolution)
    return model, preprocess

def get_available_models():
    """
    获取当前项目中可用的模型文件列表
    
    返回:
        list: 模型文件路径列表
    """
    models_paths = []
    
    # 检查模型目录
    if os.path.exists(MODEL_PATH):
        for file in os.listdir(MODEL_PATH):
            if file.endswith(".pt"):
                models_paths.append(os.path.join(MODEL_PATH, file))
    
    return models_paths

# 模型选择辅助函数
def get_model_info(model_path):
    """
    获取模型的基本信息
    
    参数:
        model_path (str): 模型文件路径
        
    返回:
        dict: 模型信息
    """
    model_name = os.path.basename(model_path)
    model_size = os.path.getsize(model_path) / (1024 * 1024)  # MB
    
    info = {
        "path": model_path,
        "name": model_name,
        "size": f"{model_size:.2f} MB"
    }
    
    # 基于文件名判断模型类型
    if "muge" in model_name.lower():
        if "private" in model_name.lower():
            info["type"] = "MUGE (私有数据微调)"
        else:
            info["type"] = "MUGE 基础模型"
    elif "flickr" in model_name.lower():
        if "private" in model_name.lower():
            info["type"] = "Flickr (私有数据微调)"
        else:
            info["type"] = "Flickr 基础模型"
    else:
        info["type"] = "其他模型"
    
    return info

# 示例用法：
if __name__ == "__main__":
    # 设置日志级别
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    
    # 列出可用模型
    models = get_available_models()
    logger.info(f"找到 {len(models)} 个可用模型:")
    
    for i, model_path in enumerate(models):
        info = get_model_info(model_path)
        logger.info(f"{i+1}. {info['name']} ({info['type']}) - {info['size']}")
    
    # 尝试加载一个原始MUGE模型
    test_model_path = None
    for model_path in models:
        if "muge" in model_path.lower() and "private" not in model_path.lower() and not model_path.lower().endswith("converted.pt") and os.path.exists(model_path):
            test_model_path = model_path
            break
    
    if test_model_path:
        logger.info(f"\n尝试加载原始MUGE模型: {test_model_path}")
        try:
            model, preprocess = load_chinese_clip_model(test_model_path)
            logger.info(f"成功加载模型: {test_model_path}")
            
            # 测试模型编码功能
            if os.path.exists("examples/pokemon.jpeg"):
                from PIL import Image
                logger.info("\n测试模型功能...")
                img = preprocess(Image.open("examples/pokemon.jpeg")).unsqueeze(0).to("cpu")
                txt = tokenize(["测试文本"]).to("cpu")
                
                with torch.no_grad():
                    img_features = model.encode_image(img)
                    txt_features = model.encode_text(txt)
                    logger.info(f"图像特征形状: {img_features.shape}")
                    logger.info(f"文本特征形状: {txt_features.shape}")
                logger.info("模型功能测试成功! ✅")
        except Exception as e:
            import traceback
            logger.error(f"加载模型失败: {e}")
            logger.error(traceback.format_exc())
    else:
        logger.warning("未找到可用的原始MUGE模型") 