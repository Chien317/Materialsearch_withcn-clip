import logging
from config import *
from env import *

# 初始化日志配置
logging.basicConfig(
    level=LOG_LEVEL,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# 设置Flask日志级别
logging.getLogger('werkzeug').setLevel(LOG_LEVEL)

def init2():
    """初始化函数"""
    pass

def init():
    """主初始化函数"""
    init2()