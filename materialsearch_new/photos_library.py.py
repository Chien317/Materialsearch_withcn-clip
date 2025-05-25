import os
import logging
from typing import List, Dict, Any, Optional
import osxphotos
from photoscript import PhotosLibrary
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)

class MacPhotosLibrary:
    def __init__(self):
        self.db = None
        self.library = None
        self.photos = []
        
    def connect(self) -> bool:
        """连接到Mac照片库"""
        try:
            # 使用osxphotos连接到照片库
            self.db = osxphotos.PhotosDB()
            # 使用photoscript连接到照片库
            self.library = PhotosLibrary()
            return True
        except Exception as e:
            logger.error(f"连接照片库失败: {e}")
            return False
            
    def get_all_photos(self) -> List[Dict[str, Any]]:
        """获取所有照片的信息"""
        try:
            if not self.db:
                if not self.connect():
                    return []
                    
            photos_info = []
            # 获取所有照片
            all_photos = self.db.photos()
            
            for photo in all_photos:
                try:
                    # 获取原始文件路径
                    original_path = photo.path
                    if not original_path:
                        continue
                        
                    # 获取照片信息
                    info = {
                        'path': original_path,
                        'filename': photo.filename,
                        'created_at': photo.date.timestamp() if photo.date else None,
                        'width': photo.width,
                        'height': photo.height,
                        'type': 'image',
                        'is_deleted': False
                    }
                    
                    photos_info.append(info)
                except Exception as e:
                    logger.warning(f"处理照片失败 {photo.filename}: {e}")
                    continue
                    
            return photos_info
            
        except Exception as e:
            logger.error(f"获取照片信息失败: {e}")
            return []
            
    def export_photo(self, photo_path: str, dest_dir: str) -> Optional[str]:
        """
        导出单张照片
        
        参数:
            photo_path: 照片路径
            dest_dir: 目标目录
        返回:
            str: 导出后的文件路径，失败返回None
        """
        try:
            if not os.path.exists(dest_dir):
                os.makedirs(dest_dir, exist_ok=True)
                
            # 获取文件名
            filename = os.path.basename(photo_path)
            # 构建目标路径
            dest_path = os.path.join(dest_dir, filename)
            
            # 如果文件已存在，添加时间戳
            if os.path.exists(dest_path):
                name, ext = os.path.splitext(filename)
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                dest_path = os.path.join(dest_dir, f"{name}_{timestamp}{ext}")
            
            # 复制文件
            import shutil
            shutil.copy2(photo_path, dest_path)
            
            return dest_path
            
        except Exception as e:
            logger.error(f"导出照片失败 {photo_path}: {e}")
            return None
            
    def export_all_photos(self, dest_dir: str) -> List[str]:
        """
        导出所有照片
        
        参数:
            dest_dir: 目标目录
        返回:
            list: 导出成功的文件路径列表
        """
        exported_paths = []
        photos_info = self.get_all_photos()
        
        for photo in photos_info:
            try:
                path = photo['path']
                exported_path = self.export_photo(path, dest_dir)
                if exported_path:
                    exported_paths.append(exported_path)
            except Exception as e:
                logger.warning(f"导出照片失败 {photo.get('filename', '')}: {e}")
                continue
                
        return exported_paths
        
    def close(self):
        """关闭连接"""
        try:
            if self.library:
                self.library.quit()
            self.db = None
            self.library = None
            self.photos = []
        except Exception as e:
            logger.error(f"关闭照片库连接失败: {e}") 