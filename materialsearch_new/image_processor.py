import os
import logging
import mmap
import io
from functools import lru_cache
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Tuple, Optional

import numpy as np
from PIL import Image

from config import IMAGE_MIN_WIDTH, IMAGE_MIN_HEIGHT

logger = logging.getLogger(__name__)

@lru_cache(maxsize=1000)
def _process_image_cached(path: str) -> Optional[np.ndarray]:
    """
    缓存版的图片处理函数
    
    参数:
        path: 图片路径
    返回:
        处理后的图片数组或None（如果处理失败）
    """
    try:
        # 使用内存映射读取文件
        with open(path, 'rb') as f:
            # 创建内存映射
            with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
                # 使用BytesIO包装mmap对象
                buffer = io.BytesIO(mm)
                image = Image.open(buffer)
                
                # 转换为RGB模式
                image = image.convert('RGB')
                width, height = image.size
                target_size = 224  # CLIP模型的标准输入尺寸
                
                # 对于超大图片，使用三步降采样
                if width > 4096 or height > 4096:
                    # 第一步：极速降采样到2048
                    scale = 2048 / max(width, height)
                    new_width = int(width * scale)
                    new_height = int(height * scale)
                    image = image.resize((new_width, new_height), Image.Resampling.NEAREST)
                    width, height = image.size
                
                if width > 2048 or height > 2048:
                    # 第二步：快速降采样到1024
                    scale = 1024 / max(width, height)
                    new_width = int(width * scale)
                    new_height = int(height * scale)
                    image = image.resize((new_width, new_height), Image.Resampling.BILINEAR)
                    width, height = image.size
                
                # 计算最终目标尺寸，保持宽高比
                if width > height:
                    new_width = target_size
                    new_height = int(height * (target_size / width))
                else:
                    new_height = target_size
                    new_width = int(width * (target_size / height))
                
                # 最终resize使用BILINEAR
                image = image.resize((new_width, new_height), Image.Resampling.BILINEAR)
                
                # 创建目标尺寸的黑色背景图像
                new_image = Image.new('RGB', (target_size, target_size), (0, 0, 0))
                paste_x = (target_size - new_width) // 2
                paste_y = (target_size - new_height) // 2
                new_image.paste(image, (paste_x, paste_y))
                
                # 转换为numpy数组，使用uint8类型节省内存
                return np.array(new_image, dtype=np.uint8)
                
    except Exception as e:
        logger.warning(f"处理图片失败：{path} {repr(e)}")
        return None

def get_image_data(path: str, ignore_small_images: bool = True) -> Optional[np.ndarray]:
    """
    获取图片像素数据
    
    参数:
        path: 图片路径
        ignore_small_images: 是否忽略尺寸过小的图片
    返回:
        处理后的图片数组或None（如果处理失败）
    """
    try:
        # 快速检查图片尺寸
        with Image.open(path) as img:
            if ignore_small_images:
                width, height = img.size
                if width < IMAGE_MIN_WIDTH or height < IMAGE_MIN_HEIGHT:
                    return None
        
        # 使用缓存版本处理图片
        return _process_image_cached(path)
        
    except Exception as e:
        logger.warning(f"打开图片失败：{path} {repr(e)}")
        return None

def process_images_batch(path_list: List[str], ignore_small_images: bool = True) -> Tuple[List[str], List[np.ndarray]]:
    """
    批量处理图片
    
    参数:
        path_list: 图片路径列表
        ignore_small_images: 是否忽略尺寸过小的图片
    返回:
        (有效的图片路径列表, 处理后的图片数组列表)
    """
    images = []
    valid_paths = []
    
    # 使用线程池并行处理图片
    with ThreadPoolExecutor(max_workers=os.cpu_count() * 2) as executor:
        # 提交所有图片处理任务
        future_to_path = {executor.submit(get_image_data, path, ignore_small_images): path 
                         for path in path_list}
        
        # 收集结果
        for future in as_completed(future_to_path):
            path = future_to_path[future]
            try:
                image = future.result()
                if image is not None:
                    images.append(image)
                    valid_paths.append(path)
            except Exception as e:
                logger.warning(f"处理图片失败：{path} {repr(e)}")
    
    return valid_paths, images 