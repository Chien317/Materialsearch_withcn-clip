#!/bin/bash

# SSH无密钥登录自动化设置脚本
# 使用方法: ./ssh_setup_nokey.sh "ssh -p 56850 root@connect.nma1.seetacloud.com" "c0zpnkThdvYu" "seetacloud-v801"

if [ $# -ne 3 ]; then
    echo "使用方法: $0 'ssh_command' 'password' 'host_alias'"
    echo "示例: $0 'ssh -p 56850 root@connect.nma1.seetacloud.com' 'c0zpnkThdvYu' 'seetacloud-v801'"
    exit 1
fi

SSH_COMMAND="$1"
PASSWORD="$2"
HOST_ALIAS="$3"

# 从SSH命令中提取信息
HOSTNAME=$(echo "$SSH_COMMAND" | sed -n 's/.*@\([^[:space:]]*\).*/\1/p')
PORT=$(echo "$SSH_COMMAND" | sed -n 's/.*-p \([0-9]*\).*/\1/p')
USER=$(echo "$SSH_COMMAND" | sed -n 's/.*ssh[[:space:]]*.*[[:space:]]\([^@]*\)@.*/\1/p')

echo "正在设置SSH无密钥登录..."
echo "主机名: $HOSTNAME"
echo "端口: $PORT"
echo "用户: $USER"
echo "别名: $HOST_ALIAS"

# 检查SSH密钥是否存在
if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    echo "错误: SSH公钥 ~/.ssh/id_ed25519.pub 不存在"
    echo "请先生成SSH密钥: ssh-keygen -t ed25519"
    exit 1
fi

# 使用expect自动输入密码进行ssh-copy-id
echo "正在复制SSH公钥到服务器..."
if command -v expect >/dev/null 2>&1; then
    expect << EOF
spawn ssh-copy-id -p $PORT $USER@$HOSTNAME
expect "password:"
send "$PASSWORD\r"
expect eof
EOF
else
    echo "注意: 系统没有安装expect，需要手动输入密码"
    ssh-copy-id -p $PORT $USER@$HOSTNAME
fi

# 测试无密钥登录
echo "测试无密钥登录..."
if ssh -p $PORT $USER@$HOSTNAME "echo '无密钥登录测试成功'" 2>/dev/null; then
    echo "✓ 无密钥登录设置成功！"
    
    # 添加到SSH配置文件
    echo "正在添加SSH配置..."
    
    # 检查配置是否已存在
    if grep -q "Host $HOST_ALIAS" ~/.ssh/config 2>/dev/null; then
        echo "配置 $HOST_ALIAS 已存在，正在更新..."
        # 这里可以添加更新逻辑，目前简单跳过
    else
        echo "" >> ~/.ssh/config
        echo "Host $HOST_ALIAS" >> ~/.ssh/config
        echo "    HostName $HOSTNAME" >> ~/.ssh/config
        echo "    User $USER" >> ~/.ssh/config
        echo "    Port $PORT" >> ~/.ssh/config
        echo "    IdentityFile ~/.ssh/id_ed25519" >> ~/.ssh/config
        echo "✓ SSH配置已添加到 ~/.ssh/config"
    fi
    
    # 测试简化名称连接
    echo "测试简化名称连接..."
    if ssh $HOST_ALIAS "echo '简化名称连接成功'" 2>/dev/null; then
        echo "✓ 可以使用 'ssh $HOST_ALIAS' 连接服务器了！"
    else
        echo "⚠ 简化名称连接失败，可能需要重新加载SSH配置"
    fi
    
else
    echo "✗ 无密钥登录设置失败，请检查网络连接和密码"
    exit 1
fi

echo "设置完成！" 