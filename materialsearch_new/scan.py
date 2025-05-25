import datetime
import logging
import pickle
import time
import os
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from queue import Queue
from threading import Thread

import osxphotos

from config import *
from database import (
    get_image_count,
    get_video_count,
    get_video_frame_count,
    delete_record_if_not_exist,
    delete_image_if_outdated,
    delete_video_if_outdated,
    add_video,
    add_image,
)
from models import create_tables, DatabaseSession
from process_assets import process_images, process_video
from search import clean_cache
from utils import get_file_hash

# 获取CPU核心数，用于线程池大小
CPU_COUNT = os.cpu_count()
THREAD_POOL_SIZE = int(CPU_COUNT * 1.5)  # 动态调整线程池大小，根据CPU核心数计算
PREFETCH_QUEUE_SIZE = 3  # 预读取队列大小

class Scanner:
    """
    扫描类
    """

    def __init__(self) -> None:
        # 全局变量
        self.scanned = False
        self.is_scanning = False
        self.scan_start_time = 0
        self.scanning_files = 0
        self.total_images = 0
        self.total_videos = 0
        self.total_video_frames = 0
        self.scanned_files = 0
        self.is_continue_scan = False
        self.logger = logging.getLogger(__name__)
        self.temp_file = f"{TEMP_PATH}/assets.pickle"
        self.assets = set()
        self.thread_pool = ThreadPoolExecutor(max_workers=THREAD_POOL_SIZE)
        self.logger.info(f"Initialized thread pool with {THREAD_POOL_SIZE} workers")
        self.db_initialized = False
        self.prefetch_queue = Queue(maxsize=PREFETCH_QUEUE_SIZE)
        self.prefetch_thread = None

        # 自动扫描时间
        self.start_time = datetime.time(*AUTO_SCAN_START_TIME)
        self.end_time = datetime.time(*AUTO_SCAN_END_TIME)
        self.is_cross_day = self.start_time > self.end_time

        # 处理跳过路径
        self.skip_paths = [Path(i) for i in SKIP_PATH if i]
        self.ignore_keywords = [i for i in IGNORE_STRINGS if i]
        self.extensions = IMAGE_EXTENSIONS + VIDEO_EXTENSIONS

    def __del__(self):
        """清理线程池和预读取队列"""
        if hasattr(self, 'thread_pool'):
            self.thread_pool.shutdown(wait=True)
        if hasattr(self, 'prefetch_thread') and self.prefetch_thread:
            self.prefetch_queue.put(None)  # 发送停止信号
            self.prefetch_thread.join()

    def init(self):
        """初始化数据库和表"""
        self.logger.info("Initializing database tables...")
        create_tables()
        #用SQL查询当前数据库中的信息
        with DatabaseSession() as session:
            self.total_images = get_image_count(session)
            self.total_videos = get_video_count(session)
            self.total_video_frames = get_video_frame_count(session)
        self.db_initialized = True
        self.logger.info("Database initialization completed.")

    def get_status(self):
        """
        获取扫描状态信息
        :return: dict, 状态信息字典
        """
        if self.scanned_files:
            remain_time = (
                    (time.time() - self.scan_start_time)
                    / self.scanned_files
                    * self.scanning_files
            )
        else:
            remain_time = 0
        if self.is_scanning and self.scanning_files != 0:
            progress = self.scanned_files / self.scanning_files
        else:
            progress = 0
        return {
            "status": self.is_scanning,
            "total_images": self.total_images,
            "total_videos": self.total_videos,
            "total_video_frames": self.total_video_frames,
            "scanning_files": self.scanning_files,
            "remain_files": self.scanning_files - self.scanned_files,
            "progress": progress,
            "remain_time": int(remain_time),
            "enable_login": ENABLE_LOGIN,
        }

    def save_assets(self):
        #保存assets到临时文件
        with open(self.temp_file, "wb") as f:
            pickle.dump(self.assets, f)

    def filter_path(self, path) -> bool:
        """
        过滤跳过的路径
        """
        if type(path) == str:
            path = Path(path)
        wrong_ext = path.suffix.lower() not in self.extensions
        skip = any((path.is_relative_to(p) for p in self.skip_paths))
        ignore = any((keyword in str(path).lower() for keyword in self.ignore_keywords))
        self.logger.debug(f"{path} 不匹配后缀：{wrong_ext} 跳过：{skip} 忽略：{ignore}")
        return not any((wrong_ext, skip, ignore))

    def generate_or_load_assets(self):
        """
        若无缓存文件，扫描目录到self.assets, 并生成新的缓存文件；
        否则加载缓存文件到self.assets
        :return: None
        """
        if os.path.isfile(self.temp_file):
            self.logger.info("读取上次的目录缓存")
            self.is_continue_scan = True
            with open(self.temp_file, "rb") as f:
                self.assets = pickle.load(f)
            self.assets = set((i for i in filter(self.filter_path, self.assets)))
        else:
            self.is_continue_scan = False
            self.scan_dir()
            self.save_assets()
        self.scanning_files = len(self.assets)

    def is_current_auto_scan_time(self) -> bool:
        """
        判断当前时间是否在自动扫描时间段内
        :return: 当前时间是否在自动扫描时间段内时返回True，否则返回False
        """
        current_time = datetime.datetime.now().time()
        is_in_range = (
                self.start_time <= current_time < self.end_time
        )  # 当前时间是否在 start_time 与 end_time 区间内
        return self.is_cross_day ^ is_in_range  # 跨日期与在区间内异或时，在自动扫描时间内

    def auto_scan(self):
        """
        自动扫描，每5秒判断一次时间，如果在目标时间段内则开始扫描。
        :return: None
        """
        while True:
            time.sleep(5)
            if self.is_scanning:
                self.scanned = True  # 设置扫描标记，这样如果手动扫描在自动扫描时间段内结束，也不会重新扫描
            elif not self.is_current_auto_scan_time():
                self.scanned = False  # 已经过了自动扫描时间段，重置扫描标记
            elif not self.scanned and self.is_current_auto_scan_time():
                self.logger.info("触发自动扫描")
                self.scanned = True  # 表示本目标时间段内已进行扫描，防止同个时间段内扫描多次
                self.scan(True)

    def scan_dir(self):
        """
        遍历文件并将符合条件的文件加入 assets 集合，包括照片库
        """
        self.assets = set()
        #ASSETS_PATH是照片库路径
        paths = [Path(i) for i in ASSETS_PATH if i]
        #遍历路径
        for path in paths:
            if str(path).endswith('.photoslibrary'):
                #如果路径是照片库
                self.logger.info(f"Found Photos library: {path}")
                try:
                    db = osxphotos.PhotosDB(dbfile=str(path))
                    #获取所有照片
                    all_photos = db.photos()
                    #打印照片数量
                    self.logger.info(f"Found {len(all_photos)} photos in library")
                    #遍历所有照片
                    for photo in all_photos:
                        #如果照片路径存在，并且符合过滤条件
                        if photo.path and self.filter_path(photo.path):
                            #添加照片路径到assets
                            self.assets.add(str(photo.path))
                            #打印添加的照片路径
                            self.logger.debug(f"Added photo: {photo.path}")
                except PermissionError as e:
                    self.logger.warning(f"Permission denied when accessing Photos library: {str(e)}")
                    self.logger.warning("Please grant full disk access to Terminal or your IDE in System Settings > Privacy & Security > Full Disk Access")
                except Exception as e:
                    self.logger.error(f"Error accessing Photos library: {str(e)}")
                    self.logger.exception("Detailed error:")
                continue  # 处理完照片库后跳过后续普通文件扫描
            # 普通文件夹递归扫描
            for file in filter(self.filter_path, path.rglob("*")):
                self.assets.add(str(file))

    def prefetch_images(self, image_paths):
        """预读取图片数据的线程函数"""
        try:
            for i in range(0, len(image_paths), SCAN_PROCESS_BATCH_SIZE):
                if not self.is_scanning:  # 如果扫描停止，退出预读取
                    break
                #获取图片路径
                batch = image_paths[i:i + SCAN_PROCESS_BATCH_SIZE]
                #创建一个字典，用于存储图片路径和修改时间、校验和
                batch_dict = {}
                #遍历图片路径
                for path in batch:
                    try:
                        modify_time = os.path.getmtime(path)

                        checksum = None
                        if ENABLE_CHECKSUM:
                            checksum = get_file_hash(path)
                        try:
                            modify_time = datetime.datetime.fromtimestamp(modify_time)
                        except Exception as e:
                            self.logger.warning(f"文件修改日期有问题：{path} {modify_time} 导致datetime转换报错 {repr(e)}")
                            modify_time = None
                            if not checksum:
                                checksum = get_file_hash(path)
                        batch_dict[path] = (modify_time, checksum)
                        #打印图片路径和修改时间、校验和
                    except Exception as e:
                        self.logger.error(f"预读取图片失败：{path} {repr(e)}")
                if batch_dict:
                    self.prefetch_queue.put(batch_dict)
                    #打印预读取的图片路径和修改时间、校验和
        except Exception as e:
            self.logger.error(f"预读取线程异常：{repr(e)}")
        finally:
            self.prefetch_queue.put(None)  # 发送结束信号

    def handle_image_batch(self, session, image_batch_dict):
        """使用线程池处理图片批量"""
        path_list = list(image_batch_dict.keys())
        if not path_list:
            return

        # 使用线程池处理图片
        future_to_path = {
            self.thread_pool.submit(process_images, [path]): path 
            for path in path_list
        }

        # 收集处理结果
        batch_images = []  # 用于批量写入的图片列表
        for future in as_completed(future_to_path):
            path = future_to_path[future]
            try:
                path_list, features_list = future.result()
                if path_list and features_list is not None:
                    for p, features in zip(path_list, features_list):
                        # 准备批量写入的数据
                        modify_time, checksum = image_batch_dict[p]
                        batch_images.append({
                            'path': p,
                            'modify_time': modify_time,
                            'checksum': checksum,
                            'features': features.tobytes()
                        })
                        if p in self.assets:  # 确保文件还在assets中
                            self.assets.remove(p)
            except Exception as e:
                self.logger.error(f"Error processing image {path}: {e}")
                self.logger.exception("Detailed error:")
            finally:
                if path in self.assets:  # 确保文件还在assets中
                    self.assets.remove(path)

        # 批量写入数据库
        if batch_images:
            try:
                from database import Image
                session.bulk_insert_mappings(Image, batch_images)
                session.commit()
                self.logger.info(f"批量写入 {len(batch_images)} 张图片到数据库")
            except Exception as e:
                self.logger.error(f"批量写入数据库失败: {e}")
                session.rollback()

        self.total_images = get_image_count(session)

    def scan(self, auto=False):
        """
        扫描资源。使用预读取队列优化性能。
        """
        if not self.db_initialized:
            self.logger.error("Database not initialized! Running init() first...")
            self.init()
            
        self.logger.info("开始扫描")
        self.is_scanning = True
        self.scan_start_time = time.time()
        self.generate_or_load_assets()
        
        with DatabaseSession() as session:
            # 删除不存在的文件记录
            if not self.is_continue_scan:
                delete_record_if_not_exist(session, self.assets)
            
            # 获取所有图片路径
            image_paths = [p for p in self.assets if p.lower().endswith(IMAGE_EXTENSIONS)]
            
            # 启动预读取线程
            self.prefetch_thread = Thread(target=self.prefetch_images, args=(image_paths,))
            self.prefetch_thread.start()
            
            skipped_files = 0
            processed_files = 0
            
            # 处理预读取的批次
            while True:
                batch_dict = self.prefetch_queue.get()
                if batch_dict is None:  # 收到结束信号
                    break
                    
                # 处理当前批次
                not_modified_paths = []
                for path, (modify_time, checksum) in batch_dict.items():
                    if delete_image_if_outdated(session, path, modify_time, checksum):
                        not_modified_paths.append(path)
                        skipped_files += 1
                    else:
                        processed_files += 1
                
                # 移除未修改的文件
                for path in not_modified_paths:
                    batch_dict.pop(path)
                    if path in self.assets:
                        self.assets.remove(path)
                
                # 处理修改过的文件
                if batch_dict:
                    self.handle_image_batch(session, batch_dict)
                
                self.scanned_files = processed_files + skipped_files
                
                # 自动保存
                if self.scanned_files % AUTO_SAVE_INTERVAL == 0:
                    self.save_assets()
                
                # 检查是否需要停止扫描
                if auto and not self.is_current_auto_scan_time():
                    self.logger.info("超出自动扫描时间，停止扫描")
                    break
            
            # 处理视频文件
            # 一个视频通常会有多个帧特征，写入视频表和帧特征表
            for path in list(self.assets):
                if path.lower().endswith(VIDEO_EXTENSIONS):
                    try:
                        modify_time = os.path.getmtime(path)
                        checksum = None
                        if ENABLE_CHECKSUM:
                            checksum = get_file_hash(path)
                        try:
                            modify_time = datetime.datetime.fromtimestamp(modify_time)
                        except Exception as e:
                            self.logger.warning(f"文件修改日期有问题：{path} {modify_time} 导致datetime转换报错 {repr(e)}")
                            modify_time = None
                            if not checksum:
                                checksum = get_file_hash(path)
                        
                        if delete_video_if_outdated(session, path, modify_time, checksum):
                            skipped_files += 1
                        else:
                            add_video(session, path, modify_time, checksum, process_video(path))
                            processed_files += 1
                            self.total_video_frames = get_video_frame_count(session)
                            self.total_videos = get_video_count(session)
                    except Exception as e:
                        self.logger.error(f"Error processing video {path}: {e}")
                        self.logger.exception("Detailed error:")
                    finally:
                        if path in self.assets:
                            self.assets.remove(path)
            
            # 最后重新统计一下数量
            self.total_images = get_image_count(session)
            self.total_videos = get_video_count(session)
            self.total_video_frames = get_video_frame_count(session)
            
            # 输出扫描统计信息
            self.logger.info(f"扫描完成，用时{int(time.time() - self.scan_start_time)}秒")
            self.logger.info(f"处理文件数: {processed_files}")
            self.logger.info(f"跳过文件数: {skipped_files}")
            self.logger.info(f"总文件数: {processed_files + skipped_files}")
        
        self.scanning_files = 0
        self.scanned_files = 0
        os.remove(self.temp_file)
        clean_cache()
        self.is_scanning = False


if __name__ == '__main__':
    scanner = Scanner()
    scanner.init()
    scanner.scan(False)
