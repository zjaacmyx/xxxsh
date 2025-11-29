#!/bin/bash

# XMRig Proxy 一键安装脚本 v6.24.0
# 使用方法: bash <(curl -fsSL https://raw.githubusercontent.com/zjaacmyx/xxxsh/main/xxx1.sh)

set -e

echo "=========================================="
echo "  XMRig Proxy 一键安装脚本"
echo "=========================================="

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本必须以 root 用户运行"
   exit 1
fi

# 更新源及安装必备工具
echo "[1/8] 更新系统并安装依赖..."
apt update -y > /dev/null 2>&1
apt install -y curl socat wget screen sudo iptables ufw net-tools > /dev/null 2>&1
echo "✓ 依赖安装完成"

# 权限调整
chmod 777 /root

# 创建目录并进入
echo "[2/8] 创建工作目录..."
cd ~
rm -rf xmrig-proxy-deploy
mkdir -p xmrig-proxy-deploy
cd xmrig-proxy-deploy
echo "✓ 工作目录已创建"

# 下载并解压 xmrig-proxy
echo "[3/8] 下载 xmrig-proxy v6.24.0..."
wget -q --show-progress https://github.com/xmrig/xmrig-proxy/releases/download/v6.24.0/xmrig-proxy-6.24.0-linux-static-x64.tar.gz
echo "✓ 下载完成"

echo "[4/8] 解压文件..."
tar -zxf xmrig-proxy-6.24.0-linux-static-x64.tar.gz
cd xmrig-proxy-6.24.0
chmod +x xmrig-proxy
echo "✓ 解压完成"

# 验证版本
VERSION=$(./xmrig-proxy --version | head -n 1)
echo "✓ $VERSION"

# 配置防火墙
echo "[5/8] 配置防火墙..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 7777/tcp > /dev/null 2>&1
ufw allow 8181/tcp > /dev/null 2>&1
ufw allow proto icmp > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
echo "✓ 防火墙配置完成"

# 创建配置文件（直接内嵌，不从外部下载）
echo "[6/8] 创建配置文件..."
rm -f config.json

cat > config.json << 'CONFIGEOF'
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
            "url": "auto.c3pool.org:19999",
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
CONFIGEOF

echo "✓ 配置文件已创建"

# 验证 JSON 格式
echo "[7/8] 验证配置文件..."
if command -v python3 &> /dev/null; then
    if python3 -m json.tool config.json > /dev/null 2>&1; then
        echo "✓ JSON 格式验证通过"
    else
        echo "✗ JSON 格式错误"
        exit 1
    fi
fi

# 提升文件句柄数限制
ulimit -n 65535

# 停止旧进程
pkill -9 xmrig-proxy 2>/dev/null || true
sleep 1

# 启动 xmrig-proxy
echo "[8/8] 启动 xmrig-proxy..."
nohup ./xmrig-proxy > proxy.log 2>&1 &
PROXY_PID=$!

# 等待启动
sleep 3

# 检查进程
if ps -p $PROXY_PID > /dev/null 2>&1; then
    echo ""
    echo "=========================================="
    echo "  ✓ 安装成功！"
    echo "=========================================="
    echo ""
    echo "进程 PID: $PROXY_PID"
    echo "工作目录: $(pwd)"
    echo "配置文件: $(pwd)/config.json"
    echo "日志文件: $(pwd)/xmrig-proxy.log"
    echo ""
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "矿机连接: $SERVER_IP:7777"
    echo "API 地址: http://$SERVER_IP:8181"
    echo ""
    echo "管理命令:"
    echo "  查看日志: tail -f $(pwd)/xmrig-proxy.log"
    echo "  查看进程: ps aux | grep xmrig-proxy | grep -v grep"
    echo "  停止服务: pkill xmrig-proxy"
    echo ""
    echo "最新日志:"
    echo "----------------------------------------"
    tail -n 20 xmrig-proxy.log 2>/dev/null || cat proxy.log 2>/dev/null || echo "日志尚未生成"
    echo "----------------------------------------"
else
    echo ""
    echo "=========================================="
    echo "  ✗ 启动失败"
    echo "=========================================="
    echo ""
    echo "错误日志:"
    cat proxy.log 2>/dev/null || cat xmrig-proxy.log 2>/dev/null || echo "无日志文件"
    exit 1
fi

# 创建 systemd 服务
echo ""
echo "创建 systemd 服务..."
cat > /etc/systemd/system/xmrig-proxy.service << SERVICEEOF
[Unit]
Description=XMRig Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/xmrig-proxy
Restart=always
RestartSec=10
StandardOutput=append:$(pwd)/xmrig-proxy.log
StandardError=append:$(pwd)/xmrig-proxy.log
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable xmrig-proxy > /dev/null 2>&1

echo "✓ Systemd 服务已创建"
echo ""
echo "Systemd 管理命令:"
echo "  启动: systemctl start xmrig-proxy"
echo "  停止: systemctl stop xmrig-proxy"
echo "  重启: systemctl restart xmrig-proxy"
echo "  状态: systemctl status xmrig-proxy"
echo "  日志: journalctl -u xmrig-proxy -f"
echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
