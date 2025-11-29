#!/bin/bash

set -e  # 遇到错误立即退出

echo "========== 开始安装 xmrig-proxy v6.24.0 =========="

# 更新源及安装必备工具
echo "[1/8] 更新系统并安装依赖..."
apt update -y
apt install -y curl socat wget screen sudo iptables ufw net-tools

# 权限调整
chmod 777 /root

# 创建目录并进入
echo "[2/8] 创建工作目录..."
mkdir -p ~/xmrig-proxy-deploy
cd ~/xmrig-proxy-deploy

# 下载并解压 xmrig-proxy
echo "[3/8] 下载 xmrig-proxy v6.24.0..."
wget https://github.com/xmrig/xmrig-proxy/releases/download/v6.24.0/xmrig-proxy-6.24.0-linux-static-x64.tar.gz

echo "[4/8] 解压文件..."
tar -zxvf xmrig-proxy-6.24.0-linux-static-x64.tar.gz
cd xmrig-proxy-6.24.0

# 赋予执行权限
chmod +x xmrig-proxy

# 验证二进制文件
echo "验证 xmrig-proxy 版本..."
./xmrig-proxy --version

# 配置防火墙放行端口
echo "[5/8] 配置防火墙..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 7777/tcp comment 'XMRig Proxy'
sudo ufw allow 8181/tcp comment 'XMRig API'
sudo ufw allow proto icmp comment 'Allow Ping'
sudo ufw --force enable

echo "防火墙状态:"
sudo ufw status verbose

# 下载配置文件，替换旧配置
echo "[6/8] 下载配置文件..."
rm -f config.json

if wget https://raw.githubusercontent.com/zjaacmyx/xxx1/main/config.json; then
    echo "✓ 配置文件下载成功"
    
    # 清理配置文件中的注释（JSON 不支持注释）
    echo "清理配置文件中的注释..."
    sed -i 's|//.*||g' config.json  # 删除 // 注释
    sed -i '/^[[:space:]]*$/d' config.json  # 删除空行
    
    # 修复可能的逗号问题
    python3 << 'PYTHON_END'
import json
import re

# 读取配置文件
with open('config.json', 'r') as f:
    content = f.read()

# 移除注释
content = re.sub(r'//.*', '', content)

# 尝试解析并重新格式化
try:
    config = json.loads(content)
    with open('config.json', 'w') as f:
        json.dump(config, f, indent=4)
    print("✓ JSON 格式已修复")
except Exception as e:
    print(f"✗ JSON 格式错误: {e}")
    exit(1)
PYTHON_END

else
    echo "✗ 配置文件下载失败，使用默认配置"
    cat > config.json << 'EOF'
{
    "api": {
        "id": null,
        "worker-id": null
    },
    "http": {
        "enabled": true,
        "host": "0.0.0.0",
        "port": 8181,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "colors": true,
    "title": true,
    "version": 1,
    "bind": [
        "0.0.0.0:7777"
    ],
    "pools": [
        {
            "algo": "rx/0",
            "coin": "monero",
            "url": "pool.supportxmr.com:3333",
            "user": "45nWzCSzmEvaX3dDibHm8shVBxxDKJLKqAULquDB9cW1jfrVZ13SFHPEZ61kV7cfaL47DowomUDzFY4JVfLCySRcNiaYohh.xxx1",
            "pass": "x",
            "rig-id": null,
            "keepalive": true,
            "enabled": true,
            "tls": false,
            "tls-fingerprint": null,
            "daemon": false,
            "daemon-poll-interval": 1000
        }
    ],
    "retries": 5,
    "retry-pause": 30,
    "verbose": false,
    "log-file": "xmrig-proxy.log",
    "syslog": false,
    "custom-diff": 0,
    "custom-diff-stats": false,
    "mode": "simple",
    "connections": 20000
}
EOF
fi

echo "配置文件内容:"
cat config.json

# 验证 JSON 格式
echo "[7/8] 验证配置文件..."
python3 -m json.tool config.json > /dev/null && echo "✓ JSON 格式正确" || {
    echo "✗ JSON 格式错误"
    exit 1
}

# 提升文件句柄数限制
ulimit -n 65535

# 测试启动
echo "[8/8] 测试启动..."
timeout 3s ./xmrig-proxy || true

sleep 1

# 后台启动xmrig-proxy，日志写入proxy.log
echo "后台启动 xmrig-proxy..."
nohup ./xmrig-proxy > proxy.log 2>&1 &
PROXY_PID=$!

echo "xmrig-proxy 已启动，PID: $PROXY_PID"
echo "工作目录: $(pwd)"
echo "日志文件: $(pwd)/proxy.log"

# 等待3秒后检查进程
sleep 3

if ps -p $PROXY_PID > /dev/null 2>&1; then
    echo ""
    echo "========== ✓ 安装成功 =========="
    echo "进程状态: 运行中 (PID: $PROXY_PID)"
    echo ""
    echo "查看日志: tail -f $(pwd)/xmrig-proxy.log"
    echo "查看进程: ps aux | grep xmrig-proxy | grep -v grep"
    echo "API 访问: http://$(hostname -I | awk '{print $1}'):8181"
    echo ""
    echo "前20行日志:"
    head -n 20 xmrig-proxy.log 2>/dev/null || cat proxy.log 2>/dev/null || echo "日志尚未生成"
else
    echo ""
    echo "========== ✗ 启动失败 =========="
    echo "查看日志:"
    cat proxy.log 2>/dev/null || cat xmrig-proxy.log 2>/dev/null || echo "无日志文件"
    exit 1
fi
