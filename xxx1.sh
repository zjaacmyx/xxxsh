#!/bin/bash

set -e  # 遇到错误立即退出

echo "=========================================="
echo "  XMRig Proxy 一键安装脚本 v6.24.0"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印函数
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}➜${NC} $1"
}

# 检查是否为 root
if [[ $EUID -ne 0 ]]; then
   print_error "此脚本必须以 root 用户运行"
   exit 1
fi

# 步骤 1: 安装依赖
print_info "[1/8] 更新系统并安装依赖..."
apt update -y > /dev/null 2>&1
apt install -y curl wget screen sudo iptables ufw net-tools > /dev/null 2>&1
print_success "依赖安装完成"

# 步骤 2: 创建工作目录
print_info "[2/8] 创建工作目录..."
cd ~
rm -rf xmrig-proxy-deploy
mkdir -p xmrig-proxy-deploy
cd xmrig-proxy-deploy
print_success "工作目录已创建"

# 步骤 3: 下载 XMRig Proxy
print_info "[3/8] 下载 XMRig Proxy v6.24.0..."
wget -q --show-progress https://github.com/xmrig/xmrig-proxy/releases/download/v6.24.0/xmrig-proxy-6.24.0-linux-static-x64.tar.gz
print_success "下载完成"

# 步骤 4: 解压文件
print_info "[4/8] 解压文件..."
tar -zxf xmrig-proxy-6.24.0-linux-static-x64.tar.gz > /dev/null 2>&1
cd xmrig-proxy-6.24.0
chmod +x xmrig-proxy
print_success "解压完成"

# 验证二进制文件
VERSION=$(./xmrig-proxy --version | head -n 1)
print_success "二进制文件验证: $VERSION"

# 步骤 5: 配置防火墙
print_info "[5/8] 配置防火墙..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
ufw allow 7777/tcp comment 'XMRig Proxy' > /dev/null 2>&1
ufw allow 8181/tcp comment 'XMRig API' > /dev/null 2>&1
ufw allow proto icmp comment 'Allow Ping' > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
print_success "防火墙配置完成"

# 步骤 6: 创建配置文件（直接内嵌，不从 GitHub 下载）
print_info "[6/8] 创建配置文件..."
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

print_success "配置文件已创建"

# 步骤 7: 验证配置文件
print_info "[7/8] 验证配置文件..."
if command -v python3 &> /dev/null; then
    if python3 -m json.tool config.json > /dev/null 2>&1; then
        print_success "JSON 格式验证通过"
    else
        print_error "JSON 格式错误"
        cat config.json
        exit 1
    fi
else
    print_info "跳过 JSON 验证（未安装 python3）"
fi

# 步骤 8: 启动服务
print_info "[8/8] 启动 XMRig Proxy..."

# 提升文件句柄限制
ulimit -n 65535

# 停止可能存在的旧进程
pkill -9 xmrig-proxy 2>/dev/null || true
sleep 1

# 启动服务
nohup ./xmrig-proxy > proxy.log 2>&1 &
PROXY_PID=$!

# 等待启动
sleep 3

# 验证进程
if ps -p $PROXY_PID > /dev/null 2>&1; then
    print_success "XMRig Proxy 启动成功！"
    echo ""
    echo "=========================================="
    echo "  安装完成！"
    echo "=========================================="
    echo ""
    echo "进程 PID: $PROXY_PID"
    echo "工作目录: $(pwd)"
    echo "配置文件: $(pwd)/config.json"
    echo "日志文件: $(pwd)/xmrig-proxy.log"
    echo ""
    echo "矿机连接地址: $(hostname -I | awk '{print $1}'):7777"
    echo "API 访问地址: http://$(hostname -I | awk '{print $1}'):8181"
    echo ""
    echo "常用命令:"
    echo "  查看日志: tail -f $(pwd)/xmrig-proxy.log"
    echo "  查看进程: ps aux | grep xmrig-proxy | grep -v grep"
    echo "  重启服务: systemctl restart xmrig-proxy"
    echo "  查看状态: systemctl status xmrig-proxy"
    echo ""
    
    # 显示最新日志
    echo "最新日志:"
    echo "----------------------------------------"
    tail -n 15 xmrig-proxy.log 2>/dev/null || cat proxy.log 2>/dev/null
    echo "----------------------------------------"
    
else
    print_error "XMRig Proxy 启动失败"
    echo ""
    echo "错误日志:"
    echo "----------------------------------------"
    cat proxy.log 2>/dev/null || cat xmrig-proxy.log 2>/dev/null
    echo "----------------------------------------"
    exit 1
fi

# 创建 systemd 服务（可选）
print_info "创建 systemd 服务..."
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
print_success "Systemd 服务已创建并启用"

echo ""
print_success "安装完成！服务正在运行中..."
echo ""
