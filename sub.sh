#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 权限运行此脚本！(例如: sudo bash ...)"
  exit 1
fi

LOG_FILE="/etc/sing-box/sub_links.txt"
SUB_FILE="/etc/sing-box/sub_b64.txt"
CLIENT_JSON="/etc/sing-box/client_#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 权限运行此脚本！(例如: sudo bash ...)"
  exit 1
fi

LOG_FILE="/etc/sing-box/sub_links.txt"
SUB_FILE="/etc/sing-box/sub_b64.txt"
CLIENT_JSON="/etc/sing-box/client_config.json"
CLASH_YAML="/etc/sing-box/clash_config.yaml"
SUB_PORT=2082

# 显示当前已保存节点及 3 大专属订阅信息的函数
show_nodes() {
    if [ -f "$LOG_FILE" ]; then
        IP_ADDR=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || echo "你的IP")

        echo "============================================================"
        echo "✨ 当前服务器已生成的 8 大协议节点信息如下："
        echo "============================================================"
        cat "$LOG_FILE"
        echo ""
        echo "============================================================"
        echo "🔗 3 大专属订阅链接汇总："
        echo "============================================================"
        echo "  1. 通用节点订阅 (V2rayN / 小火箭 / v2rayNG 等):"
        echo "     http://$IP_ADDR:$SUB_PORT/sub"
        echo ""
        echo "  2. SFI / SFA / SFM 专属订阅 (Sing-box JSON):"
        echo "     http://$IP_ADDR:$SUB_PORT/sing-box"
        echo ""
        echo "  3. Clash 专属订阅 (Clash Verge / MetaCubeX YAML):"
        echo "     http://$IP_ADDR:$SUB_PORT/clash"
        echo "============================================================"
    else
        echo "❌ 未找到已保存的节点信息！请先运行全新部署。"
    fi
}

# 部署并启动轻量级 3 路由订阅托管服务
setup_sub_service() {
    echo "==> 配置 HTTP 3 路由订阅托管服务 (端口: $SUB_PORT)..."
    
    if ! command -v python3 &> /dev/null; then
        apt-get update -y && apt-get install -y python3 2>/dev/null || yum install -y python3 2>/dev/null
    fi

    # 编写后台轻量 HTTP 订阅服务脚本
    cat > /etc/sing-box/sub_server.py << 'PYEOF'
import http.server
import socketserver
import os

PORT = 2082
SUB_B64 = "/etc/sing-box/sub_b64.txt"
CLIENT_JSON = "/etc/sing-box/client_config.json"
CLASH_YAML = "/etc/sing-box/clash_config.yaml"

class SubHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/sub':
            self.send_file(SUB_B64, 'text/plain; charset=utf-8')
        elif self.path == '/sing-box':
            self.send_file(CLIENT_JSON, 'application/json; charset=utf-8')
        elif self.path == '/clash':
            self.send_file(CLASH_YAML, 'text/yaml; charset=utf-8')
        else:
            self.send_error(403, "Access Denied")

    def send_file(self, filepath, content_type):
        if os.path.exists(filepath):
            self.send_response(200)
            self.send_header('Content-type', content_type)
            self.end_headers()
            with open(filepath, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_error(404, "Subscription File Not Found")

    def log_message(self, format, *args):
        return

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), SubHandler) as httpd:
        httpd.serve_forever()
PYEOF

    cat > /etc/systemd/system/hugo-sub.service << SERVICEOF
[Unit]
Description=Hugo Sub HTTP Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/sing-box/sub_server.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SERVICEOF

    systemctl daemon-reload
    systemctl enable hugo-sub
    systemctl restart hugo-sub
    echo "✅ 3 路由订阅托管服务已启动！"
}

# 完全卸载/清理函数
uninstall_nodes() {
    echo "============================================================"
    echo "⚠️  警告：此操作将彻底卸载 sing-box、订阅服务并删除所有配置！"
    read -p "确定要彻底卸载吗？(y/N): " CONFIRM
    case "$CONFIRM" in
        [yY][eE][sS]|[yY])
            echo "==> 1. 停止并禁用服务..."
            systemctl stop sing-box 2>/dev/null
            systemctl disable sing-box 2>/dev/null
            systemctl stop hugo-sub 2>/dev/null
            systemctl disable hugo-sub 2>/dev/null

            echo "==> 2. 清理配置文件与订阅开机项..."
            rm -rf /etc/sing-box
            rm -f /etc/systemd/system/hugo-sub.service
            systemctl daemon-reload

            echo "==> 3. 卸载 sing-box 软件包..."
            if command -v apt-get &> /dev/null; then
                apt-get purge -y sing-box 2>/dev/null
                apt-get autoremove -y 2>/dev/null
            elif command -v yum &> /dev/null; then
                yum remove -y sing-box 2>/dev/null
            fi

            echo "==> 4. 清理 sub 全局快捷键..."
            rm -f /usr/local/bin/sub

            echo "============================================================"
            echo "✅ 卸载完成！所有节点、订阅服务及残留文件已彻底清理。"
            echo "============================================================"
            exit 0
            ;;
        *)
            echo "❌ 操作已取消。"
            ;;
    esac
}

# 全新部署/重置节点的函数
install_nodes() {
    echo "==> 0. 检查并自动安装 sing-box 核心..."
    if ! command -v sing-box &> /dev/null; then
        echo "检测到系统未安装 sing-box，正在自动安装..."
        apt-get update -y && apt-get install -y curl wget jq openssl python3
        bash <(curl -fsSL https://sing-box.app/deb-install.sh)
        echo "✅ sing-box 安装完成！"
    else
        echo "✅ 检测到 sing-box 已存在，跳过安装。"
    fi

    echo "==> 1. 清理并停止旧服务..."
    systemctl stop sing-box 2>/dev/null

    echo "==> 2. 生成全新 8 协议凭证..."
    mkdir -p /etc/sing-box

    KEYPAIR=$(sing-box generate reality-keypair)
    PRIV_KEY=$(echo "$KEYPAIR" | grep "PrivateKey" | awk '{print $2}')
    PUB_KEY=$(echo "$KEYPAIR" | grep "PublicKey" | awk '{print $2}')

    UUID=$(cat /proc/sys/kernel/random/uuid)
    HY2_PASS=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
    TUIC_PASS=$(cat /proc/sys/kernel/random/uuid)
    SS_PASS=$(openssl rand -base64 16)
    TROJAN_PASS=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
    PROXY_USER="hugo"
    PROXY_PASS=$(openssl rand -hex 6)

    SHORT_ID="0123456789abcdef"
    SNI="gateway.icloud.com"

    IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || curl -s https://icanhazip.com)
    if [ -z "$IP" ]; then
        IP="3.141.65.96"
    fi

    echo "==> 3. 写入服务端 8 大协议配置文件..."
    cat > /etc/sing-box/config.json << CONFIG
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "vless", "tag": "vless-tcp", "listen": "0.0.0.0", "listen_port": 443,
      "users": [{ "name": "hugo-tcp", "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": { "enabled": true, "server_name": "$SNI", "reality": { "enabled": true, "handshake": { "server": "$SNI", "server_port": 443 }, "private_key": "$PRIV_KEY", "short_id": ["$SHORT_ID"] } }
    },
    {
      "type": "vless", "tag": "vless-grpc", "listen": "0.0.0.0", "listen_port": 444,
      "users": [{ "name": "hugo-grpc", "uuid": "$UUID" }],
      "tls": { "enabled": true, "server_name": "$SNI", "reality": { "enabled": true, "handshake": { "server": "$SNI", "server_port": 443 }, "private_key": "$PRIV_KEY", "short_id": ["$SHORT_ID"] } },
      "transport": { "type": "grpc", "service_name": "hugogrpc" }
    },
    {
      "type": "vless", "tag": "xtls-reality-extra", "listen": "0.0.0.0", "listen_port": 8881,
      "users": [{ "name": "hugo-xtls-8881", "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": { "enabled": true, "server_name": "$SNI", "reality": { "enabled": true, "handshake": { "server": "$SNI", "server_port": 443 }, "private_key": "$PRIV_KEY", "short_id": ["$SHORT_ID"] } }
    },
    {
      "type": "hysteria2", "tag": "hy2-in", "listen": "0.0.0.0", "listen_port": 8443,
      "users": [{ "password": "$HY2_PASS" }],
      "masquerade": "https://bing.com",
      "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "/etc/sing-box/hy2.crt", "key_path": "/etc/sing-box/hy2.key" }
    },
    {
      "type": "tuic", "tag": "tuic-in", "listen": "0.0.0.0", "listen_port": 9443,
      "users": [{ "uuid": "$UUID", "password": "$TUIC_PASS" }],
      "congestion_control": "bbr",
      "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "/etc/sing-box/hy2.crt", "key_path": "/etc/sing-box/hy2.key" }
    },
    {
      "type": "shadowsocks", "tag": "ss-in", "listen": "0.0.0.0", "listen_port": 6443,
      "method": "2022-blake3-aes-128-gcm", "password": "$SS_PASS"
    },
    {
      "type": "trojan", "tag": "trojan-in", "listen": "0.0.0.0", "listen_port": 7443,
      "users": [{ "name": "hugo-trojan", "password": "$TROJAN_PASS" }],
      "tls": { "enabled": true, "certificate_path": "/etc/sing-box/hy2.crt", "key_path": "/etc/sing-box/hy2.key" }
    },
    {
      "type": "mixed", "tag": "mixed-in", "listen": "0.0.0.0", "listen_port": 5443,
      "users": [{ "username": "$PROXY_USER", "password": "$PROXY_PASS" }]
    }
  ],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
CONFIG

    openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/sing-box/hy2.key -out /etc/sing-box/hy2.crt -days 3650 -subj "/CN=bing.com" 2>/dev/null

    echo "==> 4. 重启 sing-box 服务..."
    systemctl enable sing-box
    systemctl restart sing-box

    VLESS_TCP="vless://$UUID@$IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID&type=tcp#Hugo-Reality-TCP"
    VLESS_GP="vless://$UUID@$IP:444?encryption=none&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID&type=grpc&serviceName=hugogrpc#Hugo-Reality-gRPC"
    XTLS_EXTRA="vless://$UUID@$IP:8881?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID&type=tcp#Hugo-XTLS-Reality-8881"
    HY2_LINK="hysteria2://$HY2_PASS@$IP:8443?insecure=1&sni=bing.com#Hugo-Hysteria2"
    TUIC_LINK="tuic://$UUID:$TUIC_PASS@$IP:9443?congestion_control=bbr&alpn=h3&allow_insecure=1#Hugo-TuicV5"
    TROJAN_LINK="trojan://$TROJAN_PASS@$IP:7443?security=tls&allowInsecure=1#Hugo-Trojan"
    SOCKS_LINK="socks5://$PROXY_USER:$PROXY_PASS@$IP:5443#Hugo-Socks5"

    SS_RAW="2022-blake3-aes-128-gcm:$SS_PASS"
    SS_ENCODED=$(echo -n "$SS_RAW" | base64 | tr -d '\n')
    SS_LINK="ss://$SS_ENCODED@$IP:6443#Hugo-Shadowsocks"

    cat > "$LOG_FILE" << LINKS
[1] VLESS-Reality-TCP (443):
$VLESS_TCP
------------------------------------------------------------
[2] VLESS-Reality-gRPC (444):
$VLESS_GP
------------------------------------------------------------
[3] XTLS-Reality-Extra (8881):
$XTLS_EXTRA
------------------------------------------------------------
[4] Hysteria 2 (8443):
$HY2_LINK
------------------------------------------------------------
[5] TUIC v5 (9443):
$TUIC_LINK
------------------------------------------------------------
[6] Shadowsocks 2022 (6443):
$SS_LINK
------------------------------------------------------------
[7] Trojan (7443):
$TROJAN_LINK
------------------------------------------------------------
[8] SOCKS5/HTTP Mixed (5443):
$SOCKS_LINK
============================================================
LINKS

    RAW_SUBS="$VLESS_TCP
$VLESS_GP
$XTLS_EXTRA
$HY2_LINK
$TUIC_LINK
$SS_LINK
$TROJAN_LINK
$SOCKS_LINK"
    echo -n "$RAW_SUBS" | base64 | tr -d '\n' > "$SUB_FILE"

    cat > "$CLIENT_JSON" << CLIEOF
{
  "log": { "level": "info" },
  "outbounds": [
    {
      "type": "vless", "tag": "Hugo-Reality-TCP", "server": "$IP", "server_port": 443, "uuid": "$UUID", "flow": "xtls-rprx-vision", "packet_encoding": "xudp",
      "tls": { "enabled": true, "server_name": "$SNI", "utls": { "enabled": true, "fingerprint": "chrome" }, "reality": { "enabled": true, "public_key": "$PUB_KEY", "short_id": "$SHORT_ID" } }
    },
    {
      "type": "vless", "tag": "Hugo-Reality-gRPC", "server": "$IP", "server_port": 444, "uuid": "$UUID", "packet_encoding": "xudp",
      "tls": { "enabled": true, "server_name": "$SNI", "utls": { "enabled": true, "fingerprint": "chrome" }, "reality": { "enabled": true, "public_key": "$PUB_KEY", "short_id": "$SHORT_ID" } },
      "transport": { "type": "grpc", "service_name": "hugogrpc" }
    },
    {
      "type": "vless", "tag": "Hugo-XTLS-Reality-8881", "server": "$IP", "server_port": 8881, "uuid": "$UUID", "flow": "xtls-rprx-vision", "packet_encoding": "xudp",
      "tls": { "enabled": true, "server_name": "$SNI", "utls": { "enabled": true, "fingerprint": "chrome" }, "reality": { "enabled": true, "public_key": "$PUB_KEY", "short_id": "$SHORT_ID" } }
    },
    {
      "type": "hysteria2", "tag": "Hugo-Hysteria2", "server": "$IP", "server_port": 8443, "up": "100 Mbps", "down": "100 Mbps", "password": "$HY2_PASS",
      "tls": { "enabled": true, "insecure": true, "alpn": ["h3"] }
    },
    {
      "type": "tuic", "tag": "Hugo-TuicV5", "server": "$IP", "server_port": 9443, "uuid": "$UUID", "password": "$TUIC_PASS", "congestion_control": "bbr",
      "tls": { "enabled": true, "insecure": true, "alpn": ["h3"] }
    },
    {
      "type": "shadowsocks", "tag": "Hugo-Shadowsocks", "server": "$IP", "server_port": 6443, "method": "2022-blake3-aes-128-gcm", "password": "$SS_PASS"
    },
    {
      "type": "trojan", "tag": "Hugo-Trojan", "server": "$IP", "server_port": 7443, "password": "$TROJAN_PASS",
      "tls": { "enabled": true, "insecure": true }
    },
    { "type": "direct", "tag": "direct" }
  ]
}
CLIEOF

    cat > "$CLASH_YAML" << CLASHEOF
proxies:
  - name: "Hugo-Reality-TCP"
    type: vless
    server: $IP
    port: 443
    uuid: $UUID
    flow: xtls-rprx-vision
    packet-encoding: xudp
    tls: true
    servername: $SNI
    client-fingerprint: chrome
    reality-opts:
      public-key: $PUB_KEY
      short-id: $SHORT_ID

  - name: "Hugo-Reality-gRPC"
    type: vless
    server: $IP
    port: 444
    uuid: $UUID
    packet-encoding: xudp
    tls: true
    servername: $SNI
    client-fingerprint: chrome
    network: grpc
    grpc-opts:
      grpc-service-name: hugogrpc
    reality-opts:
      public-key: $PUB_KEY
      short-id: $SHORT_ID

  - name: "Hugo-XTLS-Reality-8881"
    type: vless
    server: $IP
    port: 8881
    uuid: $UUID
    flow: xtls-rprx-vision
    packet-encoding: xudp
    tls: true
    servername: $SNI
    client-fingerprint: chrome
    reality-opts:
      public-key: $PUB_KEY
      short-id: $SHORT_ID

  - name: "Hugo-Hysteria2"
    type: hysteria2
    server: $IP
    port: 8443
    password: $HY2_PASS
    sni: bing.com
    skip-cert-verify: true
    up: 100
    down: 100

  - name: "Hugo-TuicV5"
    type: tuic
    server: $IP
    port: 9443
    uuid: $UUID
    password: $TUIC_PASS
    congestion_control: bbr
    sni: bing.com
    skip-cert-verify: true

  - name: "Hugo-Shadowsocks"
    type: shadowsocks
    server: $IP
    port: 6443
    cipher: 2022-blake3-aes-128-gcm
    password: $SS_PASS

  - name: "Hugo-Trojan"
    type: trojan
    server: $IP
    port: 7443
    password: $TROJAN_PASS
    sni: bing.com
    skip-cert-verify: true
CLASHEOF

    setup_sub_service

    echo "✅ 部署完成！"
    echo ""
    show_nodes
}

# --- 核心逻辑判断 ---
if [ "$1" == "install" ] || [ "$1" == "2" ]; then
    install_nodes
    exit 0
fi

if [ "$1" == "uninstall" ] || [ "$1" == "3" ]; then
    uninstall_nodes
    exit 0
fi

# 交互菜单
echo "============================================================"
echo "          Hugo sing-box 多协议一键管理脚本                  "
echo "============================================================"
echo "  1. 查看当前节点信息及 3 大专属订阅链接"
echo "  2. 全新部署 / 重置 8 大协议节点（生成新配置及订阅）"
echo "  3. 彻底卸载 sing-box 及清除所有服务"
echo "  0. 退出"
echo "============================================================"
read -p "请输入数字选择 [0-3]: " CHOICE

case "$CHOICE" in
    1)
        show_nodes
        ;;
    2)
        install_nodes
        ;;
    3)
        uninstall_nodes
        ;;
    0)
        exit 0
        ;;
    *)
        echo "❌ 无效输入，脚本已退出。"
        exit 1
        ;;
esacconfig.json"
CLASH_YAML="/etc/sing-box/clash_config.yaml"
SUB_PORT=2082

# 显示当前已保存节点及 3 大专属订阅信息的函数
show_nodes() {
    if [ -f "$LOG_FILE" ]; then
        IP_ADDR=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || echo "你的IP")

        echo "============================================================"
        echo "✨ 当前服务器已生成的 8 大协议节点信息如下："
        echo "============================================================"
        cat "$LOG_FILE"
        echo ""
        echo "============================================================"
        echo "🔗 3 大专属订阅链接汇总："
        echo "============================================================"
        echo "  1. 通用节点订阅 (V2rayN / 小火箭 / v2rayNG 等):"
        echo "     http://$IP_ADDR:$SUB_PORT/sub"
        echo ""
        echo "  2. SFI / SFA / SFM 专属订阅 (Sing-box JSON):"
        echo "     http://$IP_ADDR:$SUB_PORT/sing-box"
        echo ""
        echo "  3. Clash 专属订阅 (Clash Verge / MetaCubeX YAML):"
        echo "     http://$IP_ADDR:$SUB_PORT/clash"
        echo "============================================================"
    else
        echo "❌ 未找到已保存的节点信息！请先运行全新部署。"
    fi
}

# 部署并启动轻量级 3 路由订阅托管服务
setup_sub_service() {
    echo "==> 配置 HTTP 3 路由订阅托管服务 (端口: $SUB_PORT)..."
    
    if ! command -v python3 &> /dev/null; then
        apt-get update -y && apt-get install -y python3 2>/dev/null || yum install -y python3 2>/dev/null
    fi

    # 编写后台轻量 HTTP 订阅服务脚本（严格分离 /sub, /sing-box, /clash）
    cat > /etc/sing-box/sub_server.py << 'PYEOF'
import http.server
import socketserver
import os

PORT = 2082
SUB_B64 = "/etc/sing-box/sub_b64.txt"
CLIENT_JSON = "/etc/sing-box/client_config.json"
CLASH_YAML = "/etc/sing-box/clash_config.yaml"

class SubHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/sub':
            self.send_file(SUB_B64, 'text/plain; charset=utf-8')
        elif self.path == '/sing-box':
            self.send_file(CLIENT_JSON, 'application/json; charset=utf-8')
        elif self.path == '/clash':
            self.send_file(CLASH_YAML, 'text/yaml; charset=utf-8')
        else:
            self.send_error(403, "Access Denied")

    def send_file(self, filepath, content_type):
        if os.path.exists(filepath):
            self.send_response(200)
            self.send_header('Content-type', content_type)
            self.end_headers()
            with open(filepath, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_error(404, "Subscription File Not Found")

    def log_message(self, format, *args):
        return

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), SubHandler) as httpd:
        httpd.serve_forever()
PYEOF

    cat > /etc/systemd/system/hugo-sub.service << SERVICEOF
[Unit]
Description=Hugo Sub HTTP Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/sing-box/sub_server.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SERVICEOF

    systemctl daemon-reload
    systemctl enable hugo-sub
    systemctl restart hugo-sub
    echo "✅ 3 路由订阅托管服务已启动！"
}

# 完全卸载/清理函数
uninstall_nodes() {
    echo "============================================================"
    echo "⚠️  警告：此操作将彻底卸载 sing-box、订阅服务并删除所有配置！"
    read -p "确定要彻底卸载吗？(y/N): " CONFIRM
    case "$CONFIRM" in
        [yY][eE][sS]|[yY])
            echo "==> 1. 停止并禁用服务..."
            systemctl stop sing-box 2>/dev/null
            systemctl disable sing-box 2>/dev/null
            systemctl stop hugo-sub 2>/dev/null
            systemctl disable hugo-sub 2>/dev/null

            echo "==> 2. 清理配置文件与订阅开机项..."
            rm -rf /etc/sing-box
            rm -f /etc/systemd/system/hugo-sub.service
            systemctl daemon-reload

            echo "==> 3. 卸载 sing-box 软件包..."
            if command -v apt-get &> /dev/null; then
                apt-get purge -y sing-box 2>/dev/null
                apt-get autoremove -y 2>/dev/null
            elif command -v yum &> /dev/null; then
                yum remove -y sing-box 2>/dev/null
            fi

            echo "==> 4. 清理 sub 全局快捷键..."
            rm -f /usr/local/bin/sub

            echo "============================================================"
            echo "✅ 卸载完成！所有节点、订阅服务及残留文件已彻底清理。"
            echo "============================================================"
            exit 0
            ;;
        *)
            echo "❌ 操作已取消。"
            ;;
    esac
}

# 全新部署/重置节点的函数
install_nodes() {
    echo "==> 0. 检查并自动安装 sing-box 核心..."
    if ! command -v sing-box &> /dev/null; then
        echo "检测到系统未安装 sing-box，正在自动安装..."
        apt-get update -y && apt-get install -y curl wget jq openssl python3
        bash <(curl -fsSL https://sing-box.app/deb-install.sh)
        echo "✅ sing-box 安装完成！"
    else
        echo "✅ 检测到 sing-box 已存在，跳过安装。"
    fi

    echo "==> 1. 清理并停止旧服务..."
    systemctl stop sing-box 2>/dev/null

    echo "==> 2. 生成全新 8 协议凭证..."
    mkdir -p /etc/sing-box

    KEYPAIR=$(sing-box generate reality-keypair)
    PRIV_KEY=$(echo "$KEYPAIR" | grep "PrivateKey" | awk '{print $2}')
    PUB_KEY=$(echo "$KEYPAIR" | grep "PublicKey" | awk '{print $2}')

    UUID=$(cat /proc/sys/kernel/random/uuid)
    HY2_PASS=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
    TUIC_PASS=$(cat /proc/sys/kernel/random/uuid)
    SS_PASS=$(openssl rand -base64 16)
    TROJAN_PASS=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
    PROXY_USER="hugo"
    PROXY_PASS=$(openssl rand -hex 6)

    SHORT_ID="0123456789abcdef"
    SNI="gateway.icloud.com"

    # 多接口获取公网 IP
    IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || curl -s https://icanhazip.com)
    if [ -z "$IP" ]; then
        IP="3.141.65.96"
    fi

    echo "==> 3. 写入服务端 8 大协议配置文件..."
    cat > /etc/sing-box/config.json << CONFIG
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "vless", "tag": "vless-tcp", "listen": "0.0.0.0", "listen_port": 443,
      "users": [{ "name": "hugo-tcp", "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": { "enabled": true, "server_name": "$SNI", "reality": { "enabled": true, "handshake": { "server": "$SNI", "server_port": 443 }, "private_key": "$PRIV_KEY", "short_id": ["$SHORT_ID"] } }
    },
    {
      "type": "vless", "tag": "vless-grpc", "listen": "0.0.0.0", "listen_port": 444,
      "users": [{ "name": "hugo-grpc", "uuid": "$UUID" }],
      "tls": { "enabled": true, "server_name": "$SNI", "reality": { "enabled": true, "handshake": { "server": "$SNI", "server_port": 443 }, "private_key": "$PRIV_KEY", "short_id": ["$SHORT_ID"] } },
      "transport": { "type": "grpc", "service_name": "hugogrpc" }
    },
    {
      "type": "vless", "tag": "xtls-reality-extra", "listen": "0.0.0.0", "listen_port": 8881,
      "users": [{ "name": "hugo-xtls-8881", "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": { "enabled": true, "server_name": "$SNI", "reality": { "enabled": true, "handshake": { "server": "$SNI", "server_port": 443 }, "private_key": "$PRIV_KEY", "short_id": ["$SHORT_ID"] } }
    },
    {
      "type": "hysteria2", "tag": "hy2-in", "listen": "0.0.0.0", "listen_port": 8443,
      "users": [{ "password": "$HY2_PASS" }],
      "masquerade": "https://bing.com",
      "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "/etc/sing-box/hy2.crt", "key_path": "/etc/sing-box/hy2.key" }
    },
    {
      "type": "tuic", "tag": "tuic-in", "listen": "0.0.0.0", "listen_port": 9443,
      "users": [{ "uuid": "$UUID", "password": "$TUIC_PASS" }],
      "congestion_control": "bbr",
      "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "/etc/sing-box/hy2.crt", "key_path": "/etc/sing-box/hy2.key" }
    },
    {
      "type": "shadowsocks", "tag": "ss-in", "listen": "0.0.0.0", "listen_port": 6443,
      "method": "2022-blake3-aes-128-gcm", "password": "$SS_PASS"
    },
    {
      "type": "trojan", "tag": "trojan-in", "listen": "0.0.0.0", "listen_port": 7443,
      "users": [{ "name": "hugo-trojan", "password": "$TROJAN_PASS" }],
      "tls": { "enabled": true, "certificate_path": "/etc/sing-box/hy2.crt", "key_path": "/etc/sing-box/hy2.key" }
    },
    {
      "type": "mixed", "tag": "mixed-in", "listen": "0.0.0.0", "listen_port": 5443,
      "users": [{ "username": "$PROXY_USER", "password": "$PROXY_PASS" }]
    }
  ],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
CONFIG

    openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/sing-box/hy2.key -out /etc/sing-box/hy2.crt -days 3650 -subj "/CN=bing.com" 2>/dev/null

    echo "==> 4. 重启 sing-box 服务..."
    systemctl enable sing-box
    systemctl restart sing-box

    VLESS_TCP="vless://$UUID@$IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID&type=tcp#Hugo-Reality-TCP"
    VLESS_GP="vless://$UUID@$IP:444?encryption=none&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID&type=grpc&serviceName=hugogrpc#Hugo-Reality-gRPC"
    XTLS_EXTRA="vless://$UUID@$IP:8881?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID&type=tcp#Hugo-XTLS-Reality-8881"
    HY2_LINK="hysteria2://$HY2_PASS@$IP:8443?insecure=1&sni=bing.com#Hugo-Hysteria2"
    TUIC_LINK="tuic://$UUID:$TUIC_PASS@$IP:9443?congestion_control=bbr&alpn=h3&allow_insecure=1#Hugo-TuicV5"
    TROJAN_LINK="trojan://$TROJAN_PASS@$IP:7443?security=tls&allowInsecure=1#Hugo-Trojan"
    SOCKS_LINK="socks5://$PROXY_USER:$PROXY_PASS@$IP:5443#Hugo-Socks5"

    SS_RAW="2022-blake3-aes-128-gcm:$SS_PASS"
    SS_ENCODED=$(echo -n "$SS_RAW" | base64 | tr -d '\n')
    SS_LINK="ss://$SS_ENCODED@$IP:6443#Hugo-Shadowsocks"

    cat > "$LOG_FILE" << LINKS
[1] VLESS-Reality-TCP (443):
$VLESS_TCP
------------------------------------------------------------
[2] VLESS-Reality-gRPC (444):
$VLESS_GP
------------------------------------------------------------
[3] XTLS-Reality-Extra (8881):
$XTLS_EXTRA
------------------------------------------------------------
[4] Hysteria 2 (8443):
$HY2_LINK
------------------------------------------------------------
[5] TUIC v5 (9443):
$TUIC_LINK
------------------------------------------------------------
[6] Shadowsocks 2022 (6443):
$SS_LINK
------------------------------------------------------------
[7] Trojan (7443):
$TROJAN_LINK
------------------------------------------------------------
[8] SOCKS5/HTTP Mixed (5443):
$SOCKS_LINK
============================================================
LINKS

    RAW_SUBS="$VLESS_TCP
$VLESS_GP
$XTLS_EXTRA
$HY2_LINK
$TUIC_LINK
$SS_LINK
$TROJAN_LINK
$SOCKS_LINK"
    echo -n "$RAW_SUBS" | base64 | tr -d '\n' > "$SUB_FILE"

    cat > "$CLIENT_JSON" << CLIEOF
{
  "log": { "level": "info" },
  "outbounds": [
    {
      "type": "vless", "tag": "Hugo-Reality-TCP", "server": "$IP", "server_port": 443, "uuid": "$UUID", "flow": "xtls-rprx-vision", "packet_encoding": "xudp",
      "tls": { "enabled": true, "server_name": "$SNI", "utls": { "enabled": true, "fingerprint": "chrome" }, "reality": { "enabled": true, "public_key": "$PUB_KEY", "short_id": "$SHORT_ID" } }
    },
    {
      "type": "vless", "tag": "Hugo-Reality-gRPC", "server": "$IP", "server_port": 444, "uuid": "$UUID", "packet_encoding": "xudp",
      "tls": { "enabled": true, "server_name": "$SNI", "utls": { "enabled": true, "fingerprint": "chrome" }, "reality": { "enabled": true, "public_key": "$PUB_KEY", "short_id": "$SHORT_ID" } },
      "transport": { "type": "grpc", "service_name": "hugogrpc" }
    },
    {
      "type": "vless", "tag": "Hugo-XTLS-Reality-8881", "server": "$IP", "server_port": 8881, "uuid": "$UUID", "flow": "xtls-rprx-vision", "packet_encoding": "xudp",
      "tls": { "enabled": true, "server_name": "$SNI", "utls": { "enabled": true, "fingerprint": "chrome" }, "reality": { "enabled": true, "public_key": "$PUB_KEY", "short_id": "$SHORT_ID" } }
    },
    {
      "type": "hysteria2", "tag": "Hugo-Hysteria2", "server": "$IP", "server_port": 8443, "up": "100 Mbps", "down": "100 Mbps", "password": "$HY2_PASS",
      "tls": { "enabled": true, "insecure": true, "alpn": ["h3"] }
    },
    {
      "type": "tuic", "tag": "Hugo-TuicV5", "server": "$IP", "server_port": 9443, "uuid": "$UUID", "password": "$TUIC_PASS", "congestion_control": "bbr",
      "tls": { "enabled": true, "insecure": true, "alpn": ["h3"] }
    },
    {
      "type": "shadowsocks", "tag": "Hugo-Shadowsocks", "server": "$IP", "server_port": 6443, "method": "2022-blake3-aes-128-gcm", "password": "$SS_PASS"
    },
    {
      "type": "trojan", "tag": "Hugo-Trojan", "server": "$IP", "server_port": 7443, "password": "$TROJAN_PASS",
      "tls": { "enabled": true, "insecure": true }
    },
    { "type": "direct", "tag": "direct" }
  ]
}
CLIEOF

    cat > "$CLASH_YAML" << CLASHEOF
proxies:
  - name: "Hugo-Reality-TCP"
    type: vless
    server: $IP
    port: 443
    uuid: $UUID
    flow: xtls-rprx-vision
    packet-encoding: xudp
    tls: true
    servername: $SNI
    client-fingerprint: chrome
    reality-opts:
      public-key: $PUB_KEY
      short-id: $SHORT_ID

  - name: "Hugo-Reality-gRPC"
    type: vless
    server: $IP
    port: 444
    uuid: $UUID
    packet-encoding: xudp
    tls: true
    servername: $SNI
    client-fingerprint: chrome
    network: grpc
    grpc-opts:
      grpc-service-name: hugogrpc
    reality-opts:
      public-key: $PUB_KEY
      short-id: $SHORT_ID

  - name: "Hugo-XTLS-Reality-8881"
    type: vless
    server: $IP
    port: 8881
    uuid: $UUID
    flow: xtls-rprx-vision
    packet-encoding: xudp
    tls: true
    servername: $SNI
    client-fingerprint: chrome
    reality-opts:
      public-key: $PUB_KEY
      short-id: $SHORT_ID

  - name: "Hugo-Hysteria2"
    type: hysteria2
    server: $IP
    port: 8443
    password: $HY2_PASS
    sni: bing.com
    skip-cert-verify: true
    up: 100
    down: 100

  - name: "Hugo-TuicV5"
    type: tuic
    server: $IP
    port: 9443
    uuid: $UUID
    password: $TUIC_PASS
    congestion_control: bbr
    sni: bing.com
    skip-cert-verify: true

  - name: "Hugo-Shadowsocks"
    type: shadowsocks
    server: $IP
    port: 6443
    cipher: 2022-blake3-aes-128-gcm
    password: $SS_PASS

  - name: "Hugo-Trojan"
    type: trojan
    server: $IP
    port: 7443
    password: $TROJAN_PASS
    sni: bing.com
    skip-cert-verify: true
CLASHEOF

    setup_sub_service

    echo "✅ 部署完成！"
    echo ""
    show_nodes
}

# --- 核心逻辑判断 ---
if [ "$1" == "install" ] || [ "$1" == "2" ]; then
    install_nodes
    exit 0
fi

if [ "$1" == "uninstall" ] || [ "$1" == "3" ]; then
    uninstall_nodes
    exit 0
fi

# 交互菜单
echo "============================================================"
echo "          Hugo sing-box 多协议一键管理脚本                  "
echo "============================================================"
echo "  1. 查看当前节点信息及 3 大专属订阅链接"
echo "  2. 全新部署 / 重置 8 大协议节点（生成新配置及订阅）"
echo "  3. 彻底卸载 sing-box 及清除所有服务"
echo "  0. 退出"
echo "============================================================"
read -p "请输入数字选择 [0-3]: " CHOICE

case "$CHOICE" in
    1)
        show_nodes
        ;;
    2)
        install_nodes
        ;;
    3)
        uninstall_nodes
        ;;
    0)
        exit 0
        ;;
    *)
        echo "❌ 无效输入，脚本已退出。"
        exit 1
        ;;
es:
