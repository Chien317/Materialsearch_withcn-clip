#!/bin/bash

# 设置备份目录
BACKUP_DIR=~/materialsearch_backups
DB_PATH=/Users/chienchen/workspace/materialsearch_new/instance/assets.db

# 创建带时间戳的备份文件名
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/assets_$TIMESTAMP.db"

# 确保数据库文件存在
if [ ! -f "$DB_PATH" ]; then
    echo "数据库文件不存在: $DB_PATH"
    exit 1
fi

# 创建备份目录（如果不存在）
mkdir -p "$BACKUP_DIR"

# 使用sqlite3命令行工具创建备份
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"

# 压缩备份文件
gzip "$BACKUP_FILE"

echo "备份完成: ${BACKUP_FILE}.gz"

# 清理7天前的备份
find "$BACKUP_DIR" -name "assets_*.db.gz" -mtime +7 -delete

echo "已清理7天前的备份文件" 