#!/bin/bash

echo "========== 开始安装 xmrig-proxy v6.24.0 =========="

# 更新源及安装必备工具
apt update -y
apt install -y curl socat wget screen sudo iptables ufw python3

# 权限调整
chmod 777 /root

# 创建目录并进入
mkdir -p ~/xmrig-proxy-deploy
cd ~/xmrig-proxy-deploy

# 下载并解压 xmrig-proxy
wget https://github.com/xmrig/xmrig-proxy/releases/download/v6.24.0/xmrig-proxy-6.24.0-linux-static-x64.tar.gz
tar -zxvf xmrig-proxy-6.24.0-linux-static-x64.tar.gz
cd xmrig-proxy-6.24.0

# 赋予执行权限
chmod +x xmrig-proxy

# 配置防火墙
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 7777/tcp
sudo ufw allow 8181/tcp
sudo ufw allow proto icmp
sudo ufw --force enable
sudo ufw status

# 下载配置文件
rm -f config.json
wget https://raw.githubusercontent.com/zjaacmyx/xxx1/main/config.json

# 清理 JSON 注释（重要！）
python3 << 'PYEOF'
import json
import re
try:
    with open('config.json', 'r') as f:
        content = f.read()
    content = re.sub(r'//.*', '', content)
    config = json.loads(content)
    with open('config.json', 'w') as f:
        json.dump(config, f, indent=4)
    print("✓ JSON 配置文件已清理")
except Exception as e:
    print(f"✗ 配置文件处理失败: {e}")
    exit(1)
PYEOF

# 显示配置
echo "配置文件内容:"
cat config.json

# 提升文件句柄数限制
ulimit -n 65535

# 后台启动
echo "启动 xmrig-proxy..."
nohup ./xmrig-proxy > proxy.log 2>&1 &
PROXY_PID=$!

# 验证启动
sleep 3
if ps -p $PROXY_PID > /dev/null 2>&1; then
    echo ""
    echo "========== ✓ 安装成功 =========="
    echo "PID: $PROXY_PID"
    echo "日志: $(pwd)/xmrig-proxy.log"
    echo "API: http://YOUR_IP:8181"
    echo ""
    tail -n 20 xmrig-proxy.log 2>/dev/null || cat proxy.log
else
    echo ""
    echo "========== ✗ 启动失败 =========="
    cat proxy.log 2>/dev/null || cat xmrig-proxy.log 2>/dev/null
    exit 1
fi
