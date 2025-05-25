import shutil
import threading
import logging
import argparse
import sys
import datetime
import json
import os
import base64
from functools import wraps
from io import BytesIO

# 导入Flask和其他非自定义模块
from flask import Flask, abort, jsonify, redirect, request, send_file, session, url_for, send_from_directory
from flask_cors import CORS

# 先导入配置
from config import *
from config import get_secret_key

# 导入数据库函数
from database import (
    get_image_path_by_id, 
    is_video_exist, 
    get_pexels_video_count,
    get_image_count,
    get_video_count,
    get_video_frame_count
)

# 初始化Flask应用
logger = logging.getLogger(__name__)
app = Flask(__name__, static_folder='static', static_url_path='/static')
CORS(app)  # 启用CORS
app.secret_key = get_secret_key()

# 添加MIME类型
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
app.config['JSON_AS_ASCII'] = False

# 添加自定义MIME类型
# 静态文件会读取这部分格式说明来对文件进行处理
mimetypes = {
    '.js': 'application/javascript',
    '.css': 'text/css',
    '.html': 'text/html',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.woff': 'application/font-woff',
    '.woff2': 'application/font-woff2',
    '.ttf': 'application/font-ttf',
    '.eot': 'application/vnd.ms-fontobject',
    '.otf': 'application/font-otf',
}

# 模型当前信息
current_model = None

#初始化三步
#1.检查路径是否存在
#2.从数据库加载数据
#3.启动自动扫描线程
def init():
    """
    清理和创建临时文件夹，初始化扫描线程，根据AUTO_SCAN决定是否开启自动扫描线程
    """
    global scanner
    # 检查ASSETS_PATH是否存在
    for path in ASSETS_PATH:
        if not os.path.isdir(path):
            logger.warning(f"ASSETS_PATH检查：路径 {path} 不存在！请检查输入的路径是否正确！")
    # 删除临时目录中所有文件
    shutil.rmtree(f'{TEMP_PATH}', ignore_errors=True)
    os.makedirs(f'{TEMP_PATH}/upload')
    os.makedirs(f'{TEMP_PATH}/video_clips')
    
    # 从数据库加载现有统计信息
    with DatabaseSession() as session:
        scanner.total_images = get_image_count(session)
        scanner.total_videos = get_video_count(session)
        scanner.total_video_frames = get_video_frame_count(session)
    scanner.db_initialized = True
    
    # 启动自动扫描线程
    if AUTO_SCAN:
        auto_scan_thread = threading.Thread(target=scanner.auto_scan, args=())
        auto_scan_thread.start()


def login_required(view_func):
    """
    装饰器函数，用于控制需要登录认证的视图
    """
    #接受所有参数变成元组和字典
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        # 检查登录开关状态
        if ENABLE_LOGIN:
            # 如果开关已启用，则进行登录认证检查
            if "username" not in session:
                # 如果用户未登录，则重定向到登录页面
                return redirect(url_for("login"))
        # 调用原始的视图函数
        return view_func(*args, **kwargs)

    return wrapper

#decorator装饰器，用于装饰视图函数
#访问网页，发送htttp请求回到8085端口
@app.route("/", methods=["GET"])
@login_required
def index_page():
    """主页"""
    return send_from_directory('static', 'index.html')

#检查static文件夹内容，js文件，css文件，flask正确响应
@app.route("/static/<path:filename>")
def serve_static(filename):
    """处理静态文件请求"""
    return send_from_directory('static', filename)


@app.route("/login", methods=["GET", "POST"])
def login():
    """登录"""
    if request.method == "POST":
        # 获取用户IP地址
        ip_addr = request.environ.get("HTTP_X_FORWARDED_FOR", request.remote_addr)
        # 获取表单数据
        username = request.form["username"]
        password = request.form["password"]
        # 简单的验证逻辑
        if username == USERNAME and password == PASSWORD:
            # 登录成功，将用户名保存到会话中
            logger.info(f"用户登录成功 {ip_addr}")
            session["username"] = username
            return redirect(url_for("index_page"))
        # 登录失败，重定向到登录页面
        logger.info(f"用户登录失败 {ip_addr}")
        return redirect(url_for("login"))
    return app.send_static_file("login.html")


@app.route("/logout", methods=["GET", "POST"])
def logout():
    """登出"""
    # 清除会话数据
    session.clear()
    return redirect(url_for("login"))

#把某个URL路径和一个python处理函数绑定起来，让flask自动调用函数处理请求
@app.route("/api/scan", methods=["GET"])
@login_required
def api_scan():
    """开始扫描"""
    global scanner
    if not scanner.is_scanning:
        scan_thread = threading.Thread(target=scanner.scan, args=(False,))
        scan_thread.start()
        return jsonify({"status": "start scanning"})
    return jsonify({"status": "already scanning"})


@app.route("/api/status", methods=["GET"])
@login_required
def api_status():
    """状态"""
    global scanner, current_model
    result = scanner.get_status()
    # 添加当前模型信息
    result["current_model"] = current_model
    with DatabaseSessionPexelsVideo() as session:
        result["total_pexels_videos"] = get_pexels_video_count(session)
        #返回json格式的信息，与前端互传
    return jsonify(result)


@app.route("/api/change_model", methods=["GET"])
@login_required
def api_change_model():
    """更改当前模型"""
    global current_model
    
    model_name = request.args.get('model')
    if not model_name or model_name not in CUSTOM_MODELS:
        return jsonify({"error": "无效的模型名称"}), 400
    
    try:
        # 更新全局变量
        import config
        config.CURRENT_CUSTOM_MODEL = model_name
        current_model = model_name
        
        # 需要重新导入process_assets模块以重新加载模型，这样新的process_assets才会生效模型才会切换成功
        import importlib
        importlib.reload(sys.modules['process_assets'])
        
        # 清除搜索缓存
        clean_cache()
        
        return jsonify({"success": True, "model": model_name})
    except Exception as e:
        logger.error(f"加载模型失败: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/api/models", methods=["GET"])
@login_required
def api_get_models():
    """获取可用模型列表"""
    models = {}
    for name, path in CUSTOM_MODELS.items():
        if os.path.exists(path):
            models[name] = {
                "name": name,
                "path": path,
                "current": name == current_model
            }
    return jsonify(models)


@app.route("/api/clean_cache", methods=["GET", "POST"])
@login_required
def api_clean_cache():
    """
    清缓存
    :return: 204 No Content
    """
    clean_cache()
    return "", 204


@app.route("/api/upload", methods=["POST"])
@login_required
def api_upload():
    """
    上传文件。首先删除旧的文件，保存新文件，计算hash，重命名文件。
    :return: JSON响应
    """
    logger.debug(request.files)
    try:
        # 删除旧文件
        upload_file_path = session.get('upload_file_path', '')
        if upload_file_path and os.path.exists(upload_file_path):
            os.remove(upload_file_path)
        
        # 检查是否有文件上传
        if 'file' not in request.files:
            return jsonify({'error': 'No file uploaded'}), 400
            
        # 保存文件
        f = request.files["file"]
        filehash = get_hash(f.stream)
        upload_file_path = f"{TEMP_PATH}/upload/{filehash}"
        f.save(upload_file_path)
        session['upload_file_path'] = upload_file_path
        
        return jsonify({
            'data': 'file uploaded successfully',
            'status': 'success',
            'file_path': upload_file_path
        })
    except Exception as e:
        logger.error(f"文件上传失败: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route("/api/match", methods=["POST"])
@login_required
def api_match():
    """
    匹配文字对应的素材
    :return: json格式的素材信息列表
    """
    try:
        data = request.get_json()
        top_n = int(data["top_n"])
        search_type = data["search_type"]
        positive_threshold = data["positive_threshold"]
        negative_threshold = data["negative_threshold"]
        image_threshold = data["image_threshold"]
        img_id = data["img_id"]
        path = data["path"]
        start_time = data["start_time"]
        end_time = data["end_time"]
        
        # 获取上传的文件路径
        upload_file_path = session.get('upload_file_path', '')
        session['upload_file_path'] = ""  # 清除session中的文件路径
        
        # 检查需要上传文件的搜索类型
        if search_type in (1, 3):
            if not upload_file_path or not os.path.exists(upload_file_path):
                return jsonify({"error": "请先上传图片文件"}), 400
        
        logger.debug(f"搜索参数: {data}")
        
        # 进行匹配
        if search_type == 0:  # 文字搜图
            results = search_image_by_text_path_time(
                data["positive"], data["negative"], 
                positive_threshold, negative_threshold,
                path, start_time, end_time
            )
        elif search_type == 1:  # 以图搜图
            results = search_image_by_image(upload_file_path, image_threshold)
        elif search_type == 2:  # 文字搜视频
            results = search_video_by_text_path_time(
                data["positive"], data["negative"], 
                positive_threshold, negative_threshold,
                path, start_time, end_time
            )
        elif search_type == 3:  # 以图搜视频
            results = search_video_by_image(upload_file_path, image_threshold)
        elif search_type == 5:  # 以图搜图(图片是数据库中的)
            results = search_image_by_image(img_id, image_threshold)
        elif search_type == 6:  # 以图搜视频(图片是数据库中的)
            results = search_video_by_image(img_id, image_threshold)
        elif search_type == 9:  # 文字搜pexels视频
            results = search_pexels_video_by_text(data["positive"], positive_threshold)
        else:
            logger.warning(f"不支持的搜索类型：{search_type}")
            return jsonify({"error": "不支持的搜索类型"}), 400
            
        # 返回结果
        return jsonify(results[:top_n])
        
    except Exception as e:
        logger.error(f"搜索失败: {str(e)}")
        return jsonify({"error": str(e)}), 500


@app.route("/api/get_image/<int:image_id>", methods=["GET"])
@login_required
def api_get_image(image_id):
    """
    读取图片
    :param image_id: int, 图片在数据库中的id
    :return: 图片文件
    """
    with DatabaseSession() as session:
        path = get_image_path_by_id(session, image_id)
        logger.debug(path)
    # 静态图片压缩返回
    if request.args.get("thumbnail") and os.path.splitext(path)[-1] != "gif":
        # 这里转换成RGB然后压缩成JPEG格式返回。也可以不转换RGB，压缩成WEBP格式，这样可以保留透明通道。
        # 目前暂时使用JPEG格式，如果切换成WEBP，还需要实际测试两者的文件大小和质量。
        image = resize_image_with_aspect_ratio(path, (640, 480), convert_rgb=True)
        image_io = BytesIO()
        image.save(image_io, 'JPEG', quality=60)
        image_io.seek(0)
        return send_file(
            image_io,
            mimetype='image/jpeg',
            as_attachment=False,
            download_name=os.path.basename(path)
        )
    return send_file(
        path,
        mimetype=mimetypes.get(os.path.splitext(path)[-1], 'application/octet-stream'),
        as_attachment=False
    )


@app.route("/api/get_video/<video_path>", methods=["GET"])
@login_required
def api_get_video(video_path):
    """
    读取视频
    :param video_path: string, 经过base64.urlsafe_b64encode的字符串，解码后可以得到视频在服务器上的绝对路径
    :return: 视频文件
    """
    path = base64.urlsafe_b64decode(video_path).decode()
    logger.debug(path)
    with DatabaseSession() as session:
        if not is_video_exist(session, path):  # 如果路径不在数据库中，则返回404，防止任意文件读取攻击
            abort(404)
    return send_file(path)


@app.route(
    "/api/download_video_clip/<video_path>/<int:start_time>/<int:end_time>",
    methods=["GET"],
)
@login_required
def api_download_video_clip(video_path, start_time, end_time):
    """
    下载视频片段
    :param video_path: string, 经过base64.urlsafe_b64encode的字符串，解码后可以得到视频在服务器上的绝对路径
    :param start_time: int, 视频开始秒数
    :param end_time: int, 视频结束秒数
    :return: 视频文件
    """
    path = base64.urlsafe_b64decode(video_path).decode()
    logger.debug(path)
    with DatabaseSession() as session:
        if not is_video_exist(session, path):  # 如果路径不在数据库中，则返回404，防止任意文件读取攻击
            abort(404)
    # 根据VIDEO_EXTENSION_LENGTH调整时长
    start_time -= VIDEO_EXTENSION_LENGTH
    end_time += VIDEO_EXTENSION_LENGTH
    if start_time < 0:
        start_time = 0
    # 调用ffmpeg截取视频片段
    output_path = f"{TEMP_PATH}/video_clips/{start_time}_{end_time}_" + os.path.basename(path)
    if not os.path.exists(output_path):  # 如果存在说明已经剪过，直接返回，如果不存在则剪
        crop_video(path, output_path, start_time, end_time)
    return send_file(output_path)


if __name__ == "__main__":
    # 添加命令行参数解析
    parser = argparse.ArgumentParser(description='MaterialSearch多模态素材搜索平台')
    parser.add_argument('--model', type=str, default=CURRENT_CUSTOM_MODEL, 
                        help='要使用的模型名称，可选值: ' + ', '.join(CUSTOM_MODELS.keys()))
    parser.add_argument('--port', type=int, default=PORT, 
                        help=f'服务器端口号，默认值: {PORT}')
    parser.add_argument('--no-browser', action='store_true',
                        help='不自动打开浏览器')
    args = parser.parse_args()
    
    # 设置当前模型
    #如果命令行制定了模型就更新config
    if args.model and args.model in CUSTOM_MODELS:
        # 设置全局config变量
        import config
        config.CURRENT_CUSTOM_MODEL = args.model
        
        # 设置当前模块内的变量
        CURRENT_CUSTOM_MODEL = args.model  # 更新当前模块内的变量
        current_model = args.model
        
        logger.info(f"当前使用模型: {current_model}")
    else:
        # 使用config中的默认值
        current_model = CURRENT_CUSTOM_MODEL
    
    # 首先导入不依赖于process_assets的模块
    from database import get_image_path_by_id, is_video_exist, get_pexels_video_count
    from init import *
    from models import DatabaseSession, DatabaseSessionPexelsVideo
    from utils import crop_video, get_hash, resize_image_with_aspect_ratio
    
    # 确保process_assets模块在我们更新CURRENT_CUSTOM_MODEL后再导入
    import importlib
    if 'process_assets' in sys.modules:
        importlib.reload(sys.modules['process_assets'])
    else:
        import process_assets
    
    # 导入依赖于process_assets的模块
    from process_assets import process_image, process_text
    from scan import Scanner
    from search import (
        clean_cache,
        search_image_by_image,
        search_image_by_text_path_time,
        search_video_by_image,
        search_video_by_text_path_time,
        search_pexels_video_by_text,
    )
    
    # 初始化扫描器
    scanner = Scanner()
    
    # 初始化数据库和获取统计信息
    scanner.init()  # 确保在启动时就初始化数据库并获取统计信息
    
    # 设置日志级别
    logging.getLogger('werkzeug').setLevel(LOG_LEVEL)
    
    # 任何可能需要的额外初始化
    try:
        init2()
    except NameError:
        # 如果init2不存在，忽略错误
        pass
    
    # 添加自动打开浏览器功能
    if not args.no_browser:
        import webbrowser
        import threading
        
        def open_browser():
            """在应用启动后自动打开浏览器"""
            import time
            time.sleep(1.5)  # 等待1.5秒，让服务器有时间启动
            url = f"http://{HOST if HOST != '0.0.0.0' else '127.0.0.1'}:{args.port}"
            webbrowser.open(url)
            logger.info(f"已自动打开浏览器，访问地址: {url}")
        
        # 启动打开浏览器的线程
        browser_thread = threading.Thread(target=open_browser)
        browser_thread.daemon = True
        browser_thread.start()
    
    # 启动应用
    app.run(host=HOST, port=args.port, debug=FLASK_DEBUG)
