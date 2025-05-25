# SSH无密钥登录自动化设置

## 概述
这个脚本可以自动为新的云服务器设置SSH无密钥登录，并添加简化的主机名配置。

## 使用方法

### 脚本语法
```bash
./ssh_setup_nokey.sh "SSH_COMMAND" "PASSWORD" "HOST_ALIAS"
```

### 参数说明
- `SSH_COMMAND`: 完整的SSH连接命令（包含端口和用户信息）
- `PASSWORD`: 服务器的root密码
- `HOST_ALIAS`: 你想要设置的简化主机名

### 使用示例

#### 为新服务器设置无密钥登录
```bash
./ssh_setup_nokey.sh "ssh -p 56850 root@connect.nma1.seetacloud.com" "c0zpnkThdvYu" "seetacloud-v801"
```

#### 设置完成后的使用方式
```bash
# 原来需要这样连接：
ssh -p 56850 root@connect.nma1.seetacloud.com

# 设置后可以这样连接：
ssh seetacloud-v801
```

## 脚本功能

1. **自动解析SSH连接信息**：从完整SSH命令中提取主机名、端口、用户名
2. **复制SSH公钥**：自动将本地公钥复制到远程服务器
3. **测试无密钥登录**：验证设置是否成功
4. **更新SSH配置**：将简化配置添加到 `~/.ssh/config`
5. **测试简化名称**：确认可以使用简化名称连接

## 前置要求

1. **SSH密钥对**：确保本地存在 `~/.ssh/id_ed25519` 和 `~/.ssh/id_ed25519.pub`
   ```bash
   # 如果没有，可以生成：
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

2. **expect工具**（可选）：用于自动输入密码
   ```bash
   # macOS安装：
   brew install expect
   
   # 如果没有expect，脚本会要求手动输入密码
   ```

## 当前配置的服务器

- **seetacloud-v800**: `ssh seetacloud-v800`
  - 主机: connect.nma1.seetacloud.com:48490
  - 状态: ✅ 已配置

## 配置文件位置

SSH配置文件位于：`~/.ssh/config`

当前配置内容：
```
Host seetacloud-v800
    HostName connect.nma1.seetacloud.com
    User root
    Port 48490
    IdentityFile ~/.ssh/id_ed25519
```

## 故障排除

### 1. 无法解析主机名
如果出现 "Could not resolve hostname" 错误：
- 检查 `~/.ssh/config` 文件格式是否正确
- 确认缩进使用空格而不是制表符
- 尝试重新创建配置文件

### 2. 连接被拒绝
如果出现 "Connection reset by peer" 错误：
- 检查服务器是否正在运行
- 确认端口号是否正确
- 验证网络连接是否正常

### 3. 密钥认证失败
如果仍然要求输入密码：
- 确认公钥已正确复制到服务器
- 检查服务器的SSH配置是否允许密钥认证
- 验证本地密钥文件权限是否正确

## 安全建议

1. **保护私钥**：确保私钥文件权限为600
   ```bash
   chmod 600 ~/.ssh/id_ed25519
   ```

2. **定期更新**：定期更换SSH密钥对

3. **备份配置**：备份SSH配置文件
   ```bash
   cp ~/.ssh/config ~/.ssh/config.backup
   ``` 