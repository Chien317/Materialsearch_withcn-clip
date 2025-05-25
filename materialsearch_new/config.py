import os
import logging
from dotenv import load_dotenv
import torch
import secrets

# 检查是否跳过配置加载
if os.environ.get('SKIP_MATERIALSEARCH_CONFIG') == '1':
    # 只提供必要的配置
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    logging.basicConfig(level=LOG_LEVEL, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logging.getLogger('werkzeug').setLevel(logging.ERROR)
else:
    # 加载 .env 文件
    load_dotenv()

    # *****服务器配置*****
    HOST = os.getenv('HOST', '0.0.0.0')  # 监听IP，如果只想本地访问，把这个改成127.0.0.1
    PORT = int(os.getenv('PORT', 8085))  # 监听端口

    # *****扫描配置*****
    # Windows系统的路径写法例子：'D:/照片'
    # 忽略的路径和文件模式
    IGNORE_STRINGS = (
        'thumb',
        'avatar',
        '__macosx',
        'icons',
        'cache',
        'derivatives',  # 忽略Photos Library的衍生文件
        'resources',    # 忽略Photos Library的资源文件
        'previews',     # 忽略预览文件
        'thumbnails',   # 忽略缩略图
        'edited',       # 忽略编辑版本
        '.ipynb_checkpoints',
        '@2x',          # 忽略高分辨率版本
        '@3x'          # 忽略高分辨率版本
    )

    # 只扫描原始文件目录
    ASSETS_PATH = (
        os.path.join(os.path.expanduser('~'), 'Pictures/Photos Library.photoslibrary/originals'),
        os.path.join(os.path.expanduser('~'), 'Desktop')
    )

    SKIP_PATH = tuple(os.getenv('SKIP_PATH', '/tmp').split(','))  # 跳过扫描的目录，绝对路径，逗号分隔
    IMAGE_EXTENSIONS = tuple(os.getenv('IMAGE_EXTENSIONS', '.jpg,.jpeg,.png,.gif,.heic,.webp,.bmp').split(','))  # 支持的图片拓展名，逗号分隔，请填小写
    VIDEO_EXTENSIONS = tuple(os.getenv('VIDEO_EXTENSIONS', '.mp4,.flv,.mov,.mkv,.webm,.avi').split(','))  # 支持的视频拓展名，逗号分隔，请填小写
    FRAME_INTERVAL = int(os.getenv('FRAME_INTERVAL', 2))  # 视频每隔多少秒取一帧
    SCAN_PROCESS_BATCH_SIZE = int(os.getenv('SCAN_PROCESS_BATCH_SIZE', 512))  # 批处理大小，默认值调整为512以更好地利用内存
    IMAGE_MIN_WIDTH = int(os.getenv('IMAGE_MIN_WIDTH', 64))  # 图片最小宽度，小于此宽度则忽略
    IMAGE_MIN_HEIGHT = int(os.getenv('IMAGE_MIN_HEIGHT', 64))  # 图片最小高度，小于此高度则忽略
    AUTO_SCAN = os.getenv('AUTO_SCAN', 'False').lower() == 'true'  # 是否自动扫描
    AUTO_SCAN_START_TIME = tuple(map(int, os.getenv('AUTO_SCAN_START_TIME', '22:30').split(':')))  # 自动扫描开始时间
    AUTO_SCAN_END_TIME = tuple(map(int, os.getenv('AUTO_SCAN_END_TIME', '8:00').split(':')))  # 自动扫描结束时间
    AUTO_SAVE_INTERVAL = int(os.getenv('AUTO_SAVE_INTERVAL', 100))  # 扫描自动保存间隔

    # *****模型配置*****
    # 更换模型需要删库重新扫描！否则搜索会报错。数据库路径见下面SQLALCHEMY_DATABASE_URL参数。模型越大，扫描速度越慢，且占用的内存和显存越大。
    # 如果显存较小且用了较大的模型，并在扫描的时候出现了"CUDA out of memory"，请换成较小的模型。如果显存充足，可以调大上面的SCAN_PROCESS_BATCH_SIZE来提高扫描速度。
    # 4G显存推荐参数：小模型，SCAN_PROCESS_BATCH_SIZE=6
    # 8G显存推荐参数：小模型，SCAN_PROCESS_BATCH_SIZE=12
    # 超大模型最低显存要求是6G，且SCAN_PROCESS_BATCH_SIZE=1
    # 其余显存大小请自行摸索搭配。
    # 中文小模型： "OFA-Sys/chinese-clip-vit-base-patch16"
    # 中文大模型："OFA-Sys/chinese-clip-vit-large-patch14-336px"
    # 中文超大模型："OFA-Sys/chinese-clip-vit-huge-patch14"
    # 英文小模型： "openai/clip-vit-base-patch16"
    # 英文大模型："openai/clip-vit-large-patch14-336"
    MODEL_NAME = os.getenv('MODEL_NAME', "OFA-Sys/chinese-clip-vit-base-patch16")  # CLIP模型
    DEVICE = os.getenv('DEVICE', 'mps' if torch.backends.mps.is_available() else 'cpu')  # 使用MPS加速
    USE_FINETUNED_MODEL = os.getenv('USE_FINETUNED_MODEL', 'True').lower() == 'true'  # 是否使用微调后的模型

    # *****自定义微调模型配置*****
    # 可选择的微调模型类型，修改为需要使用的模型路径
    MODEL_BASE_PATH = "/Users/chienchen/workspace/model_trainingv0/chinese_clip_finetuned"
    CUSTOM_MODELS = {
        # 基础模型
        "clip_cn_vit-b-16": f"{MODEL_BASE_PATH}/clip_cn_vit-b-16.pt",  # 基础ViT-B-16模型
        "clip_cn_vit-h-14": f"{MODEL_BASE_PATH}/clip_cn_vit-h-14.pt",  # 基础ViT-H-14模型
        
        # MUGE模型
        "muge_finetune": f"{MODEL_BASE_PATH}/muge_finetune.pt",  # MUGE微调模型
        "muge_private": f"{MODEL_BASE_PATH}/muge_private_finetuned.pt",  # MUGE私有数据微调模型
        
        # Flickr模型
        "flickr_base": f"{MODEL_BASE_PATH}/flickr30k_epoch3.pt",  # Flickr30k基础模型
        "flickr_private": f"{MODEL_BASE_PATH}/flickr_epoch3_private_finetuned.pt",  # Flickr私有数据微调模型
    }

    # 当前使用的自定义模型，设置为None则使用默认的HuggingFace模型
    CURRENT_CUSTOM_MODEL = os.getenv('CURRENT_CUSTOM_MODEL', "muge_private")  # 当前使用的自定义模型

    # 模型结构配置 - 只在使用自定义模型时生效
    VISION_MODEL = os.getenv('VISION_MODEL', "ViT-B-16")  # 视觉模型类型
    TEXT_MODEL = os.getenv('TEXT_MODEL', "RoBERTa-wwm-ext-base-chinese")  # 文本模型类型
    INPUT_RESOLUTION = int(os.getenv('INPUT_RESOLUTION', 224))  # 输入分辨率

    # *****搜索配置*****
    CACHE_SIZE = int(os.getenv('CACHE_SIZE', 1000))  # LRU缓存大小
    POSITIVE_THRESHOLD = int(os.getenv('POSITIVE_THRESHOLD', 36))  # 正向搜索词阈值
    NEGATIVE_THRESHOLD = int(os.getenv('NEGATIVE_THRESHOLD', 36))  # 反向搜索词阈值
    IMAGE_THRESHOLD = int(os.getenv('IMAGE_THRESHOLD', 85))  # 图片搜索阈值

    # *****日志配置*****
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'DEBUG')  # 日志等级：NOTSET/DEBUG/INFO/WARNING/ERROR/CRITICAL

    # *****其它配置*****
    SQLALCHEMY_DATABASE_URL = os.getenv('SQLALCHEMY_DATABASE_URL', 'sqlite:///./instance/assets.db')  # 数据库保存路径
    TEMP_PATH = os.getenv('TEMP_PATH', './tmp')  # 临时目录路径
    VIDEO_EXTENSION_LENGTH = int(os.getenv('VIDEO_EXTENSION_LENGTH', 0))  # 下载视频片段时，视频前后增加的时长，单位为秒
    ENABLE_LOGIN = os.getenv('ENABLE_LOGIN', 'False').lower() == 'true'  # 是否启用登录
    USERNAME = os.getenv('USERNAME', 'admin')  # 登录用户名
    PASSWORD = os.getenv('PASSWORD', 'MaterialSearch')  # 登录密码
    FLASK_DEBUG = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'  # flask 调试开关
    ENABLE_CHECKSUM = os.getenv('ENABLE_CHECKSUM', 'False').lower() == 'true'  # 是否启用文件校验

    # 配置日志
    logging.basicConfig(
        level=LOG_LEVEL,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    # 禁用werkzeug的日志输出
    logging.getLogger('werkzeug').setLevel(logging.ERROR)

    # *****打印配置内容*****
    print("********** 运行配置 / RUNNING CONFIGURATIONS **********")
    global_vars = globals().copy()
    for var_name, var_value in global_vars.items():
        if "i" in var_name and "I" in var_name: continue
        if var_name[0].isupper():
            print(f"{var_name}: {var_value!r}")
    print(f"HF_HOME: {os.getenv('HF_HOME')}")
    print(f"HF_HUB_OFFLINE: {os.getenv('HF_HUB_OFFLINE')}")
    print(f"TRANSFORMERS_OFFLINE: {os.getenv('TRANSFORMERS_OFFLINE')}")
    print(f"CWD: {os.getcwd()}")
    print("**************************************************")

    # 性能调优配置
    BULK_INSERT_SIZE = int(os.getenv('BULK_INSERT_SIZE', 1000))  # 数据库批量插入大小

def get_secret_key():
    # 尝试从环境变量获取secret key
    secret_key = os.environ.get('FLASK_SECRET_KEY')
    
    # 如果环境变量中没有，尝试从文件读取
    if not secret_key:
        secret_key_file = os.path.join(os.path.dirname(__file__), 'secret_key')
        try:
            if os.path.exists(secret_key_file):
                with open(secret_key_file, 'r') as f:
                    secret_key = f.read().strip()
            else:
                # 如果文件不存在，生成新的secret key
                secret_key = secrets.token_hex(32)  # 生成一个32字节（256位）的随机密钥
                with open(secret_key_file, 'w') as f:
                    f.write(secret_key)
        except Exception as e:
            print(f"Warning: Could not handle secret key file: {e}")
            # 如果出现任何错误，生成一个临时的secret key
            secret_key = secrets.token_hex(32)
    
    return secret_key
