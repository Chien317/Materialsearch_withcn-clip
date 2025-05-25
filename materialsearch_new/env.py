import os
from dotenv import load_dotenv

# 加载 .env 文件
load_dotenv()

# 环境变量设置
HF_HOME = os.getenv('HF_HOME', '')
HF_HUB_OFFLINE = os.getenv('HF_HUB_OFFLINE', '')
TRANSFORMERS_OFFLINE = os.getenv('TRANSFORMERS_OFFLINE', '')

# 设置默认环境变量
os.environ.setdefault('HF_HOME', HF_HOME)
os.environ.setdefault('HF_HUB_OFFLINE', HF_HUB_OFFLINE)
os.environ.setdefault('TRANSFORMERS_OFFLINE', TRANSFORMERS_OFFLINE)



