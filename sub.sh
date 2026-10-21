#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 权限运行此脚本！(例如: sudo bash ...)"
  exit 1
fi

LOG_FILE="/etc/sing-box/sub_links.txt"

# 显示当前已保存节点的函数
show_nodes() {
    if [ -f "$LOG_FILE" ]; then
        echo "============================================================"
        echo "✨ 当前服务器已生成的 8 大协议节点信息如下："
        echo "============================================================"
        cat "$LOG_FILE"
    else
        echo "❌ 未找到已保存的节点信息！请先运行全新部署。"
    fi
}

# 完全卸载/清理函数
uninstall_nodes() {
    echo "============================================================"
    echo "⚠️  警告：此操作将彻底卸载 sing-box 并删除所有节点配置！"
    read -p "确定要彻底卸载吗？(y/N): " CONFIRM
    case "$CONFIRM" in
        [yY][eE][sS]|[yY])
            echo "==> 1. 停止并禁用 sing-box 服务..."
            systemctl stop sing-box 2>/dev/null
            systemctl disable sing-box 2>/dev/null

            echo "==> 2. 清理配置文件、秘钥与保存的节点链接..."
            rm -rf /etc/sing-box

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
            echo "✅ 卸载完成！所有服务、配置、快捷键及残留文件已全部彻底清理。"
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
        apt-get update -y && apt-get install -y curl wget jq openssl
        bash <(curl -fsSL https://sing-box.app/deb-install.sh)
        echo "✅ sing-box 安装完成！"
    else
        echo "✅ 检测到 sing-box 已存在，跳过安装。"
    fi

    echo "==> 1. 清理并停止旧服务..."
    systemctl stop sing-box 2>/dev/null

    echo "==> 2. 生成全新 8 协议凭证..."
    mkdir -p /etc/sing-box

    # 生成 Reality 密钥
    KEYPAIR=$(sing-box generate reality-keypair)
    PRIV_KEY=$(echo "$KEYPAIR" | grep "PrivateKey" | awk '{print $2}')
    PUB_KEY=$(echo "$KEYPAIR" | grep "PublicKey" | awk '{print $2}')

    # 生成通用凭证
    UUID=$(cat /proc/sys/kernel/random/uuid)
    HY2_PASS=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
    TUIC_PASS=$(cat /proc/sys/kernel/random/uuid)
    SS_PASS=$(openssl rand -base64 16)
    TROJAN_PASS=$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)
    PROXY_USER="hugo"
    PROXY_PASS=$(openssl rand -hex 6)

    SHORT_ID="0123456789abcdef"
    SNI="gateway.icloud.com"

    # 获取公网 IP
    IP=$(curl -s https://api.ipify.org)
    if [ -z "$IP" ]; then
        IP="3.141.65.96"
    fi

    echo "==> 3. 写入 8 大协议配置文件..."
    cat > /etc/sing-box/config.json << CONFIG
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-tcp",
      "listen": "0.0.0.0",
      "listen_port": 443,
      "users": [
        {
          "name": "hugo-tcp",
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$SNI",
            "server_port": 443
          },
          "private_key": "$PRIV_KEY",
          "short_id": [
            "$SHORT_ID"
          ]
        }
      }
    },
    {
      "type": "vless",
      "tag": "vless-grpc",
      "listen": "0.0.0.0",
      "listen_port": 444,
      "users": [
        {
          "name": "hugo-grpc",
          "uuid": "$UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$SNI",
            "server_port": 443
          },
          "private_key": "$PRIV_KEY",
          "short_id": [
            "$SHORT_ID"
          ]
        }
      },
      "transport": {
        "type": "grpc",
        "service_name": "hugogrpc"
      }
    },
    {
      "type": "vless",
      "tag": "xtls-reality-extra",
      "listen": "0.0.0.0",
      "listen_port": 8881,
      "users": [
        {
          "name": "hugo-xtls-8881",
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$SNI",
            "server_port": 443
          },
          "private_key": "$PRIV_KEY",
          "short_id": [
            "$SHORT_ID"
          ]
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "0.0.0.0",
      "listen_port": 8443,
      "users": [
        {
          "password": "$HY2_PASS"
        }
      ],
      "masquerade": "https://bing.com",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "/etc/sing-box/hy2.crt",
        "key_path": "/etc/sing-box/hy2.key"
      }
    },
    {
      "type": "tuic",
      "tag": "tuic-in",
      "listen": "0.0.0.0",
      "listen_port": 9443,
      "users": [
        {
          "uuid": "$UUID",
          "password": "$TUIC_PASS"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "/etc/sing-box/hy2.crt",
        "key_path": "/etc/sing-box/hy2.key"
      }
    },
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "0.0.0.0",
      "listen_port": 6443,
      "method": "2022-blake3-aes-128-gcm",
      "password": "$SS_PASS"
    },
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "0.0.0.0",
      "listen_port": 7443,
      "users": [
        {
          "name": "hugo-trojan",
          "password": "$TROJAN_PASS"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "/etc/sing-box/hy2.crt",
        "key_path": "/etc/sing-box/hy2.key"
      }
    },
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "0.0.0.0",
      "listen_port": 5443,
      "users": [
        {
          "username": "$PROXY_USER",
          "password": "$PROXY_PASS"
        }
      ]
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
CONFIG

    # 生成 TLS 自签名证书
    openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/sing-box/hy2.key -out /etc/sing-box/hy2.crt -days 3650 -subj "/CN=bing.com" 2>/dev/null

    echo "==> 4. 重启 sing-box 服务..."
    systemctl enable sing-box
    systemctl restart sing-box

    # 拼接节点链接
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

    # 持久化存储到本地文本
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

    echo "✅ 部署完成！节点已保存至 $LOG_FILE"
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
echo "  1. 查看当前节点信息（不清除/不更新现有节点）"
echo "  2. 全新部署 / 重置 8 大协议节点（生成新配置）"
echo "  3. 彻底卸载 sing-box 及清除所有节点配置"
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
esac
