#!/bin/bash

# 更新源及安装必备工具
apt update -y
apt install -y curl socat wget screen sudo iptables ufw

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

# 配置防火墙放行端口
sudo ufw allow ssh
sudo ufw allow 22/tcp
sudo ufw allow 7777/tcp
sudo ufw allow 8181/tcp

# 启用并查看防火墙状态
sudo ufw --force enable
sudo ufw status

# 下载配置文件，替换旧配置
rm -f config.json
wget https://raw.githubusercontent.com/zjaacmyx/xxx1/main/config.json

# 提升文件句柄数限制
ulimit -n 65535

# 后台启动xmrig-proxy，日志写入proxy.log
nohup ./xmrig-proxy > proxy.log 2>&1 &

echo "xmrig-proxy 已启动，日志文件 proxy.log"
