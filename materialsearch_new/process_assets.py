# 预处理图片和视频，建立索引，加快搜索速度
import concurrent.futures
import logging
import traceback
import time
from pathlib import Path
import os

import cv2
import numpy as np
import requests
import torch
from PIL import Image
from tqdm import trange
from transformers import ChineseCLIPModel, ChineseCLIPProcessor
from huggingface_hub import snapshot_download
from concurrent.futures import ThreadPoolExecutor, as_completed

from config import *

logger = logging.getLogger(__name__)

def load_model_with_retry(model_name=None, max_retries=3):
    """
    加载模型和处理器，支持重试机制
    :param model_name: 模型名称，如果为None则使用配置文件中的当前模型
    :param max_retries: 最大重试次数
    :return: tuple (model, processor) 或在失败时返回 (None, None)
    """
    try:
        # 优先使用自定义模型
        if CURRENT_CUSTOM_MODEL and CURRENT_CUSTOM_MODEL in CUSTOM_MODELS:
            logger.info(f"使用自定义模型: {CURRENT_CUSTOM_MODEL}")
            model_path = CUSTOM_MODELS[CURRENT_CUSTOM_MODEL]
            
            # 根据自定义模型类型选择基础模型名称
            base_model_name = "OFA-Sys/chinese-clip-vit-base-patch16"  # 默认基础模型
            if VISION_MODEL == "ViT-H-14":
                base_model_name = "OFA-Sys/chinese-clip-vit-huge-patch14"
            elif VISION_MODEL == "ViT-L-14":
                base_model_name = "OFA-Sys/chinese-clip-vit-large-patch14"
            
            # 设置HuggingFace缓存目录
            cache_dir = Path.home() / '.cache' / 'huggingface' / 'hub'
            
            try:
                # 先尝试从本地加载
                logger.info("尝试从本地加载基础模型和处理器...")
                base_model = ChineseCLIPModel.from_pretrained(
                    base_model_name,
                    cache_dir=cache_dir,
                    local_files_only=True
                )
                processor = ChineseCLIPProcessor.from_pretrained(
                    base_model_name,
                    cache_dir=cache_dir,
                    local_files_only=True
                )
            except Exception as e:
                logger.info(f"本地加载失败 ({str(e)})，从HuggingFace下载...")
                # 如果本地没有，则从HuggingFace下载
                base_model = ChineseCLIPModel.from_pretrained(
                    base_model_name,
                    cache_dir=cache_dir,
                    local_files_only=False
                )
                processor = ChineseCLIPProcessor.from_pretrained(
                    base_model_name,
                    cache_dir=cache_dir,
                    local_files_only=False
                )
            
            # 加载自定义权重
            logger.info(f"加载自定义模型权重: {model_path}")
            try:
                # 先尝试使用 weights_only=True
                state_dict = torch.load(model_path, map_location=torch.device(DEVICE), weights_only=True)
            except Exception as e:
                logger.info("使用 weights_only=True 加载失败，尝试 weights_only=False...")
                # 如果失败，使用 weights_only=False
                state_dict = torch.load(model_path, map_location=torch.device(DEVICE), weights_only=False)
            
            # 处理可能的封装格式
            if isinstance(state_dict, dict) and "state_dict" in state_dict:
                state_dict = state_dict["state_dict"]
            
            # 处理module.前缀
            if list(state_dict.keys())[0].startswith('module.'):
                logger.info("检测到module.前缀，正在移除...")
                state_dict = {k[len('module.'):]: v for k, v in state_dict.items()}
            
            # 加载权重到模型
            base_model.load_state_dict(state_dict, strict=False)
            model = base_model.to(torch.device(DEVICE))
            
            logger.info("模型加载完成")
            return model, processor
        else:
            logger.error(f"未找到自定义模型: {CURRENT_CUSTOM_MODEL}")
            return None, None
                
    except Exception as e:
        if max_retries > 0:
            logger.warning(f"加载模型失败，将在1秒后重试: {str(e)}")
            time.sleep(1)
            return load_model_with_retry(model_name, max_retries - 1)
        else:
            logger.error(f"加载模型失败，已达到最大重试次数: {str(e)}")
            return None, None

logger.info("Loading model...")
model, processor = load_model_with_retry(MODEL_NAME)
if model is None or processor is None:
    logger.error("Failed to load model or processor")
    raise RuntimeError("Model initialization failed")
logger.info("Model loaded.")


def get_image_feature(images):
    """
    获取图片特征
    :param images: 图片数据，可以是单张图片或图片列表
    :return: 图片特征向量
    """
    feature = None
    try:
        # 确保images是列表
        if not isinstance(images, list):
            images = [images]
            
        # 使用processor处理图片
        inputs = processor(images=images, return_tensors="pt")["pixel_values"].to(torch.device(DEVICE))
        
        # 根据输入类型选择不同的特征提取方法
        if hasattr(model, 'get_image_features'):
            # 使用标准方法
            features = model.get_image_features(inputs)
        elif hasattr(model, 'encode_image'):
            # 使用encode_image方法（某些模型使用这个方法名）
            features = model.encode_image(inputs)
        else:
            # 如果都没有，尝试直接使用vision_model
            features = model.vision_model(inputs)[1]
            
        # 归一化特征
        features = features / features.norm(dim=-1, keepdim=True)
        
        # 转换为numpy数组
        feature = features.detach().cpu().numpy()
        
    except Exception as e:
        logger.warning(f"处理图片报错：{repr(e)}")
        traceback.print_stack()
    return feature


def get_image_data(path: str, ignore_small_images: bool = True):
    """
    获取图片像素数据，如果出错返回 None
    :param path: string, 图片路径
    :param ignore_small_images: bool, 是否忽略尺寸过小的图片
    :return: <class 'numpy.nparray'>, 图片数据，如果出错返回 None
    """
    try:
        image = Image.open(path)
        if ignore_small_images:
            width, height = image.size
            if width < IMAGE_MIN_WIDTH or height < IMAGE_MIN_HEIGHT:
                return None
                # processor 中也会这样预处理 Image
        # 在这里提前转为 np.array 避免到时候抛出异常
        image = image.convert('RGB')
        image = np.array(image)
        return image
    except Exception as e:
        logger.warning(f"打开图片报错：{path} {repr(e)}")
        return None


def process_image(path, ignore_small_images=True):
    """
    处理图片，返回图片特征
    :param path: string, 图片路径
    :param ignore_small_images: bool, 是否忽略尺寸过小的图片
    :return: <class 'numpy.nparray'>, 图片特征
    """
    try:
        image = get_image_data(path, ignore_small_images)
        if image is None:
            return None
            
        # 转换为RGB格式
        if isinstance(image, np.ndarray):
            image = Image.fromarray(image)
        if image.mode != 'RGB':
            image = image.convert('RGB')
            
        # 提取特征
        feature = get_image_feature(image)
        return feature
        
    except Exception as e:
        logger.error(f"处理图片失败: {path} - {str(e)}")
        return None


def process_images(path_list, ignore_small_images=True):
    """
    处理图片，返回图片特征
    :param path_list: string, 图片路径列表
    :param ignore_small_images: bool, 是否忽略尺寸过小的图片
    :return: <class 'numpy.nparray'>, 图片特征
    """
    images = []
    valid_paths = []
    
    try:
        # 使用线程池并行处理图片
        with ThreadPoolExecutor(max_workers=os.cpu_count() * 2) as executor:
            # 提交所有图片处理任务
            futures = []
            for path in path_list:
                future = executor.submit(get_image_data, path, ignore_small_images)
                futures.append((future, path))
            
            # 收集结果
            for future, path in futures:
                try:
                    image = future.result(timeout=30)  # 添加超时限制
                    if image is not None:
                        # 转换为RGB格式
                        if isinstance(image, np.ndarray):
                            image = Image.fromarray(image)
                        if image.mode != 'RGB':
                            image = image.convert('RGB')
                        images.append(image)
                        valid_paths.append(path)
                except Exception as e:
                    logger.warning(f"处理图片失败：{path} {repr(e)}")
                    continue
        
        if not images:
            return None, None
        
        # 批量处理特征提取
        feature = get_image_feature(images)
        return valid_paths, feature
        
    except Exception as e:
        logger.error(f"批量处理图片失败: {str(e)}")
        return None, None

#只是一个方法没有被调用
def process_web_image(url):
    """
    处理网络图片，返回图片特征
    :param url: string, 图片URL
    :return: <class 'numpy.nparray'>, 图片特征
    """
    try:
        image = Image.open(requests.get(url, stream=True).raw)
    except Exception as e:
        logger.warning("获取图片报错：%s %s" % (url, repr(e)))
        return None
    feature = get_image_feature(image)
    return feature


def get_frames(video: cv2.VideoCapture):
    """ 
    获取视频的帧数据
    :return: (list[int], list[array]) (帧编号列表, 帧像素数据列表) 元组
    """
    frame_rate = round(video.get(cv2.CAP_PROP_FPS))
    total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT))
    logger.debug(f"fps: {frame_rate} total: {total_frames}")
    ids, frames = [], []
    for current_frame in trange(
            0, total_frames, FRAME_INTERVAL * frame_rate, desc="当前进度", unit="frame"
    ):
        # 在 FRAME_INTERVAL 为 2（默认值），frame_rate 为 24
        # 即 FRAME_INTERVAL * frame_rate == 48 时测试
        # 直接设置当前帧的运行效率低于使用 grab 跳帧
        # 如果需要跳的帧足够多，也许直接设置效率更高
        # video.set(cv2.CAP_PROP_POS_FRAMES, current_frame)
        ret, frame = video.read()
        if not ret:
            break
        ids.append(current_frame // frame_rate)
        frames.append(frame)
        if len(frames) == SCAN_PROCESS_BATCH_SIZE:
            yield ids, frames
            ids = []
            frames = []
        for _ in range(FRAME_INTERVAL * frame_rate - 1):
            video.grab()  # 跳帧
    yield ids, frames


def process_video(path):
    """
    处理视频并返回处理完成的数据
    返回一个生成器，每调用一次则返回视频下一个帧的数据
    :param path: string, 视频路径
    :return: [int, <class 'numpy.nparray'>], [当前是第几帧（被采集的才算），图片特征]
    """
    logger.info(f"处理视频中：{path}")
    try:
        video = cv2.VideoCapture(path)
        if not video.isOpened():
            logger.error(f"无法打开视频文件: {path}")
            return
            
        for ids, frames in get_frames(video):
            # 转换BGR到RGB
            rgb_frames = [cv2.cvtColor(frame, cv2.COLOR_BGR2RGB) for frame in frames]
            # 转换为PIL图像
            pil_frames = [Image.fromarray(frame) for frame in rgb_frames]
            # 提取特征
            features = get_image_feature(pil_frames)
            
            if features is None:
                logger.warning("特征提取失败")
                continue
                
            for id, feature in zip(ids, features):
                yield id, feature
                
        video.release()
        
    except Exception as e:
        logger.error(f"处理视频出错：{path} {repr(e)}")
        return


def process_text(input_text):
    """
    预处理文字，返回文字特征
    :param input_text: string, 被处理的字符串
    :return: <class 'numpy.nparray'>,  文字特征
    """
    feature = None
    if not input_text:
        return None
    try:
        text = processor(text=input_text, return_tensors="pt", padding=True)["input_ids"].to(torch.device(DEVICE))
        feature = model.get_text_features(text).detach().cpu().numpy()
    except Exception as e:
        logger.warning(f"处理文字报错：{repr(e)}")
        traceback.print_stack()
    return feature

#对输出的向量特征进行归一化
def normalize_features(features):
    """
    归一化
    :param features: [<class 'numpy.nparray'>], 特征
    :return: <class 'numpy.nparray'>, 归一化后的特征
    """
    return features / np.linalg.norm(features, axis=1, keepdims=True)


def multithread_normalize(features):
    """
    多线程执行归一化，只有对大矩阵效果才好
    :param features:  [<class 'numpy.nparray'>], 特征
    :return: <class 'numpy.nparray'>, 归一化后的特征
    """
    num_threads = os.cpu_count()
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_threads) as executor:
        # 将图像特征分成等分，每个线程处理一部分
        chunk_size = len(features) // num_threads
        chunks = [
            features[i: i + chunk_size] for i in range(0, len(features), chunk_size)
        ]
        # 并发执行特征归一化
        normalized_chunks = executor.map(normalize_features, chunks)
    # 将处理后的特征重新合并
    return np.concatenate(list(normalized_chunks))

#匹配image_feature列表并返回余弦相似度
def match_batch(
        positive_feature,
        negative_feature,
        image_features,
        positive_threshold,
        negative_threshold,
):
    """
    匹配image_feature列表并返回余弦相似度
    :param positive_feature: <class 'numpy.ndarray'>, 正向提示词特征
    :param negative_feature: <class 'numpy.ndarray'>, 反向提示词特征
    :param image_features: [<class 'numpy.ndarray'>], 图片特征列表
    :param positive_threshold: int/float, 正向提示分数阈值，高于此分数才显示
    :param negative_threshold: int/float, 反向提示分数阈值，低于此分数才显示
    :return: <class 'numpy.nparray'>, 提示词和每个图片余弦相似度列表，shape=(n, )，如果小于正向提示分数阈值或大于反向提示分数阈值则会置0
    """
    # 计算余弦相似度
    if len(image_features) > 1024:  # 多线程只对大矩阵效果好
        new_features = multithread_normalize(image_features)
    else:
        new_features = normalize_features(image_features)
    if positive_feature is None: # 没有正向feature就把分数全部设成1
        positive_scores = np.ones(len(new_features))
    else:
        new_text_positive_feature = positive_feature / np.linalg.norm(positive_feature)
        positive_scores = (new_features @ new_text_positive_feature.T).squeeze(-1)
    if negative_feature is not None:
        new_text_negative_feature = negative_feature / np.linalg.norm(negative_feature)
        negative_scores = (new_features @ new_text_negative_feature.T).squeeze(-1)
    # 根据阈值进行过滤
    scores = np.where(positive_scores < positive_threshold / 100, 0, positive_scores)
    if negative_feature is not None:
        scores = np.where(negative_scores > negative_threshold / 100, 0, scores)
    return scores
