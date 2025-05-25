#!/bin/bash

# 服务器缓存清理脚本
# 清理pip、conda缓存以及临时文件，释放系统盘空间

echo "=================================================="
echo "  服务器缓存清理工具"
echo "=================================================="

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 显示清理前的磁盘使用情况
echo ""
echo "清理前磁盘使用情况:"
echo "----------------------------------------------"
df -h | head -1
df -h | grep -E "(/$|/root)"

echo ""
echo "内存使用情况:"
free -h

# 激活conda环境
log "激活conda环境..."
if command -v conda &> /dev/null; then
    source /root/miniconda3/bin/activate
    log "✅ Conda已激活"
else
    log "⚠️  Conda未找到，跳过conda相关清理"
fi

# 1. 清理pip缓存
echo ""
echo "1. 清理pip缓存"
echo "----------------------------------------------"
log "正在清理pip缓存..."

if command -v pip &> /dev/null; then
    # 显示pip缓存大小
    cache_dir=$(pip cache dir 2>/dev/null || echo "~/.cache/pip")
    if [ -d "$cache_dir" ]; then
        cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
        log "pip缓存目录: $cache_dir (大小: $cache_size)"
    fi
    
    # 清理pip缓存
    pip cache purge 2>/dev/null || log "pip cache purge失败，手动清理..."
    
    # 手动清理pip缓存目录
    rm -rf ~/.cache/pip/* 2>/dev/null || true
    rm -rf /tmp/pip-* 2>/dev/null || true
    
    log "✅ pip缓存清理完成"
else
    log "⚠️  pip未找到，跳过pip缓存清理"
fi

# 2. 清理conda缓存
echo ""
echo "2. 清理conda缓存"
echo "----------------------------------------------"
log "正在清理conda缓存..."

if command -v conda &> /dev/null; then
    # 显示conda缓存信息
    log "conda缓存信息:"
    conda info 2>/dev/null | grep -E "(package cache|envs directories)" || true
    
    # 清理conda缓存
    conda clean --all -y 2>/dev/null || log "conda clean失败"
    
    # 手动清理conda缓存目录
    rm -rf ~/.conda/pkgs/* 2>/dev/null || true
    rm -rf /root/miniconda3/pkgs/* 2>/dev/null || true
    rm -rf /tmp/conda-* 2>/dev/null || true
    
    log "✅ conda缓存清理完成"
else
    log "⚠️  conda未找到，跳过conda缓存清理"
fi

# 3. 清理系统临时文件
echo ""
echo "3. 清理系统临时文件"
echo "----------------------------------------------"
log "正在清理系统临时文件..."

# 清理/tmp目录
temp_size=$(du -sh /tmp 2>/dev/null | cut -f1)
log "/tmp目录大小: $temp_size"

find /tmp -type f -atime +1 -delete 2>/dev/null || true
find /tmp -type d -empty -delete 2>/dev/null || true

# 清理用户临时文件
rm -rf ~/.cache/matplotlib/* 2>/dev/null || true
rm -rf ~/.cache/fontconfig/* 2>/dev/null || true
rm -rf ~/.cache/torch/* 2>/dev/null || true

# 清理apt缓存（如果存在）
if command -v apt &> /dev/null; then
    apt clean 2>/dev/null || true
    apt autoclean 2>/dev/null || true
fi

log "✅ 系统临时文件清理完成"

# 4. 清理下载和安装残留
echo ""
echo "4. 清理下载和安装残留"
echo "----------------------------------------------"
log "正在清理下载和安装残留..."

# 清理可能的下载残留
find /root -name "*.whl" -delete 2>/dev/null || true
find /root -name "*.tar.gz" -delete 2>/dev/null || true
find /root -name "*temp*" -type d -exec rm -rf {} \; 2>/dev/null || true

# 清理Chinese-CLIP可能的下载缓存
if [ -d "/root/autodl-tmp/Chinese-CLIP" ]; then
    find /root/autodl-tmp/Chinese-CLIP -name "__pycache__" -type d -exec rm -rf {} \; 2>/dev/null || true
    find /root/autodl-tmp/Chinese-CLIP -name "*.pyc" -delete 2>/dev/null || true
fi

# 清理datapath中的临时文件
if [ -d "/root/autodl-tmp/datapath" ]; then
    find /root/autodl-tmp/datapath -name "*temp*" -type d -exec rm -rf {} \; 2>/dev/null || true
    find /root/autodl-tmp/datapath -name "._*" -delete 2>/dev/null || true
fi

log "✅ 下载和安装残留清理完成"

# 5. 清理日志文件
echo ""
echo "5. 清理日志文件"
echo "----------------------------------------------"
log "正在清理日志文件..."

# 清理系统日志（保留最近7天）
find /var/log -name "*.log" -mtime +7 -delete 2>/dev/null || true
find /var/log -name "*.log.*" -delete 2>/dev/null || true

# 清理用户目录的日志
find /root -name "*.log" -mtime +1 -delete 2>/dev/null || true

log "✅ 日志文件清理完成"

# 6. 强制同步文件系统
echo ""
echo "6. 同步文件系统"
echo "----------------------------------------------"
log "正在同步文件系统..."
sync
log "✅ 文件系统同步完成"

# 显示清理后的磁盘使用情况
echo ""
echo "清理后磁盘使用情况:"
echo "----------------------------------------------"
df -h | head -1
df -h | grep -E "(/$|/root)"

echo ""
echo "内存使用情况:"
free -h

echo ""
echo "=================================================="
echo "🎉 服务器缓存清理完成！"
echo "=================================================="

# 显示释放的空间（大概估算）
echo ""
echo "清理总结："
echo "• pip缓存已清理"
echo "• conda缓存已清理"  
echo "• 系统临时文件已清理"
echo "• 下载和安装残留已清理"
echo "• 日志文件已清理"
echo ""
echo "建议："
echo "• 检查磁盘使用情况是否有改善"
echo "• 如果空间仍然不足，可考虑删除不必要的大文件"
echo "• 定期运行此脚本保持系统清洁"
echo "==================================================" 