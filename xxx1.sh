#!/bin/bash

echo "========== 开始安装 xmrig-proxy v6.24.0 =========="

# 安装依赖
apt update -y
apt install -y curl wget screen sudo iptables ufw python3

# 创建目录
mkdir -p ~/xmrig-proxy-deploy
cd ~/xmrig-proxy-deploy

# 下载解压
wget https://github.com/xmrig/xmrig-proxy/releases/download/v6.24.0/xmrig-proxy-6.24.0-linux-static-x64.tar.gz
tar -zxvf xmrig-proxy-6.24.0-linux-static-x64.tar.gz
cd xmrig-proxy-6.24.0

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

# 下载并清理配置文件
rm -f config.json
wget https://raw.githubusercontent.com/zjaacmyx/xxx1/main/config.json

# 重要：清理 JSON 注释
echo "清理配置文件注释..."
python3 << 'PYEOF'
import json
import re

try:
    with open('config.json', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 移除单行注释
    content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)
    
    # 移除多行注释
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    
    # 解析并格式化
    config = json.loads(content)
    
    with open('config.json', 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=4, ensure_ascii=False)
    
    print("✓ 配置文件已清理")
except Exception as e:
    print(f"✗ 错误: {e}")
    exit(1)
PYEOF

# 验证 JSON
python3 -m json.tool config.json > /dev/null || exit 1

echo "配置文件内容:"
cat config.json

# 启动
ulimit -n 65535
nohup ./xmrig-proxy > proxy.log 2>&1 &
PID=$!

sleep 3

if ps -p $PID > /dev/null 2>&1; then
    echo ""
    echo "✓ 安装成功！"
    echo "PID: $PID"
    echo "日志: tail -f $(pwd)/xmrig-proxy.log"
    tail -20 xmrig-proxy.log
else
    echo ""
    echo "✗ 启动失败"
    cat proxy.log
    exit 1
fi
