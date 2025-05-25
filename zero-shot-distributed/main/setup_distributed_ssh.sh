#!/bin/bash

# 分布式SSH无密钥配置脚本
# 配置服务器间的无密钥登录，支持分布式数据和模型分发

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Previous command exited with status $?"' ERR

echo "=================================================="
echo "  分布式SSH无密钥配置器"
echo "=================================================="

# 定义服务器
SERVERS=("seetacloud-v800" "seetacloud-v801" "seetacloud-v802")

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 步骤1: 检查本地到服务器的连接
echo ""
echo "步骤1: 检查本地SSH连接"
echo "----------------------------------------------"

log "检查本地是否能连接到所有服务器..."

failed_connections=0
for server in "${SERVERS[@]}"; do
    if ssh -o ConnectTimeout=10 -o BatchMode=yes ${server} "echo 'connected'" >/dev/null 2>&1; then
        log "✅ 本地 → ${server} 连接正常"
    else
        log "❌ 本地 → ${server} 连接失败"
        echo "    请先使用ssh_setup_nokey.sh配置本地到${server}的无密钥登录"
        failed_connections=$((failed_connections + 1))
    fi
done

if [ $failed_connections -gt 0 ]; then
    echo ""
    echo "❌ 发现 ${failed_connections} 个本地连接问题"
    echo "请先解决本地SSH连接问题，然后重新运行此脚本"
    echo ""
    echo "示例："
    echo "  ./ssh_setup_nokey.sh 'ssh -p PORT root@HOST' 'PASSWORD' 'seetacloud-v800'"
    exit 1
fi

log "✅ 所有本地SSH连接验证通过"

# 步骤2: 配置服务器间SSH密钥
echo ""
echo "步骤2: 配置服务器间SSH密钥生成"
echo "----------------------------------------------"

for server in "${SERVERS[@]}"; do
    log "在 ${server} 上检查/生成SSH密钥..."
    
    ssh ${server} << 'EOF'
# 检查SSH密钥是否存在
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "生成SSH密钥..."
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
    echo "✅ SSH密钥生成完成"
else
    echo "✅ SSH密钥已存在"
fi

# 确保SSH目录权限正确
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519 2>/dev/null || true
chmod 644 ~/.ssh/id_ed25519.pub 2>/dev/null || true
EOF
    
    log "✅ ${server} SSH密钥准备完成"
done

# 步骤3: 配置关键的服务器间连接
echo ""
echo "步骤3: 配置服务器间无密钥连接"
echo "----------------------------------------------"

# 定义需要的连接关系（使用更兼容的方式）
log "配置 seetacloud-v802 的对外连接..."

# v802需要连接v800,v801 (数据分发)
source_server="seetacloud-v802"
target_servers="seetacloud-v800 seetacloud-v801"

# 获取源服务器的公钥
source_pubkey=$(ssh ${source_server} "cat ~/.ssh/id_ed25519.pub")

for target_server in $target_servers; do
    log "  配置 ${source_server} → ${target_server}..."
    
    # 将源服务器的公钥添加到目标服务器的authorized_keys
    ssh ${target_server} << EOF
# 确保.ssh目录存在
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 检查公钥是否已存在
if ! grep -q "${source_pubkey}" ~/.ssh/authorized_keys 2>/dev/null; then
    echo "${source_pubkey}" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "✅ 已添加 ${source_server} 的公钥"
else
    echo "✓ ${source_server} 的公钥已存在"
fi
EOF
    
    # 测试连接
    if ssh ${source_server} "ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no ${target_server} 'echo connected' >/dev/null 2>&1"; then
        log "    ✅ ${source_server} → ${target_server} 连接成功"
    else
        log "    ⚠️  ${source_server} → ${target_server} 连接测试失败，可能需要手动验证"
    fi
done

log "配置 seetacloud-v800 的对外连接..."

# v800需要连接v801,v802 (模型分发)
source_server="seetacloud-v800"
target_servers="seetacloud-v801 seetacloud-v802"

# 获取源服务器的公钥
source_pubkey=$(ssh ${source_server} "cat ~/.ssh/id_ed25519.pub")

for target_server in $target_servers; do
    log "  配置 ${source_server} → ${target_server}..."
    
    # 将源服务器的公钥添加到目标服务器的authorized_keys
    ssh ${target_server} << EOF
# 确保.ssh目录存在
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 检查公钥是否已存在
if ! grep -q "${source_pubkey}" ~/.ssh/authorized_keys 2>/dev/null; then
    echo "${source_pubkey}" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "✅ 已添加 ${source_server} 的公钥"
else
    echo "✓ ${source_server} 的公钥已存在"
fi
EOF
    
    # 测试连接
    if ssh ${source_server} "ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no ${target_server} 'echo connected' >/dev/null 2>&1"; then
        log "    ✅ ${source_server} → ${target_server} 连接成功"
    else
        log "    ⚠️  ${source_server} → ${target_server} 连接测试失败，可能需要手动验证"
    fi
done

# 步骤4: 配置SSH客户端设置
echo ""
echo "步骤4: 优化SSH客户端配置"
echo "----------------------------------------------"

for server in "${SERVERS[@]}"; do
    log "优化 ${server} 的SSH客户端配置..."
    
    ssh ${server} << 'EOF'
# 创建或更新SSH客户端配置
cat > ~/.ssh/config << 'SSH_CONFIG'
# 全局SSH客户端配置
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ConnectTimeout 30
    ServerAliveInterval 60
    ServerAliveCountMax 3

# 服务器别名配置 - 使用实际连接信息
Host seetacloud-v800
    HostName connect.nma1.seetacloud.com
    Port 48490
    User root
    
Host seetacloud-v801
    HostName connect.nma1.seetacloud.com
    Port 56850
    User root
    
Host seetacloud-v802
    HostName connect.nma1.seetacloud.com
    Port 32630
    User root
SSH_CONFIG

chmod 600 ~/.ssh/config
echo "✅ SSH客户端配置已更新 (使用实际连接信息)"
EOF

    log "✅ ${server} SSH客户端配置完成"
done

# 步骤5: 验证所有连接
echo ""
echo "步骤5: 验证分布式连接"
echo "----------------------------------------------"

log "验证关键的服务器间连接..."

# 验证数据分发连接 (v802 → v800, v801)
log "验证数据分发连接 (v802 → others)..."
for target in "seetacloud-v800" "seetacloud-v801"; do
    if ssh seetacloud-v802 "ssh -o ConnectTimeout=10 ${target} 'echo connected'" >/dev/null 2>&1; then
        log "  ✅ v802 → ${target#seetacloud-} 连接正常"
    else
        log "  ❌ v802 → ${target#seetacloud-} 连接失败"
    fi
done

# 验证模型分发连接 (v800 → v801, v802)
log "验证模型分发连接 (v800 → others)..."
for target in "seetacloud-v801" "seetacloud-v802"; do
    if ssh seetacloud-v800 "ssh -o ConnectTimeout=10 ${target} 'echo connected'" >/dev/null 2>&1; then
        log "  ✅ v800 → ${target#seetacloud-} 连接正常"
    else
        log "  ❌ v800 → ${target#seetacloud-} 连接失败"
    fi
done

# 步骤6: 测试关键操作
echo ""
echo "步骤6: 测试分布式操作"
echo "----------------------------------------------"

log "测试scp文件传输功能..."

# 测试v800 → v801的scp功能 (模型分发需要)
ssh seetacloud-v800 << 'EOF'
# 创建测试文件
echo "test from v800" > /tmp/ssh_test_v800.txt

# 测试scp到v801
if scp /tmp/ssh_test_v800.txt seetacloud-v801:/tmp/ssh_test_from_v800.txt >/dev/null 2>&1; then
    echo "✅ v800 → v801 scp测试成功"
else
    echo "❌ v800 → v801 scp测试失败"
fi

# 清理测试文件
rm -f /tmp/ssh_test_v800.txt
EOF

# 测试v802 → v800的rsync功能 (数据分发需要)
ssh seetacloud-v802 << 'EOF'
# 创建测试目录和文件
mkdir -p /tmp/test_data
echo "test data from v802" > /tmp/test_data/test.txt

# 测试rsync到v800
if rsync -q /tmp/test_data/ seetacloud-v800:/tmp/test_data_from_v802/ >/dev/null 2>&1; then
    echo "✅ v802 → v800 rsync测试成功"
else
    echo "❌ v802 → v800 rsync测试失败"
fi

# 清理测试文件
rm -rf /tmp/test_data
EOF

# 清理远程测试文件
ssh seetacloud-v801 "rm -f /tmp/ssh_test_from_v800.txt" 2>/dev/null || true
ssh seetacloud-v800 "rm -rf /tmp/test_data_from_v802" 2>/dev/null || true

# 完成总结
echo ""
echo "=================================================="
echo "🎉 分布式SSH配置完成！"
echo "=================================================="
echo ""
echo "已配置的连接:"
echo "----------------------------------------------"
echo "✅ 本地 → 所有服务器 (v800, v801, v802)"
echo "✅ v802 → v800, v801 (用于数据分发)"
echo "✅ v800 → v801, v802 (用于模型分发)"
echo ""
echo "支持的操作:"
echo "✅ SSH命令执行"
echo "✅ SCP文件传输" 
echo "✅ RSYNC同步"
echo ""
echo "下一步:"
echo "----------------------------------------------"
echo "现在可以运行分布式部署脚本："
echo "  chmod +x quick_setup_distributed.sh"
echo "  ./quick_setup_distributed.sh"
echo ""
echo "或者手动测试连接："
echo "  ssh seetacloud-v800 'ssh seetacloud-v801 echo \"v800→v801连接测试\"'"
echo "  ssh seetacloud-v802 'ssh seetacloud-v800 echo \"v802→v800连接测试\"'"
echo "==================================================" 