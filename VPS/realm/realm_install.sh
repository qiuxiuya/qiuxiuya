#!/bin/bash

SERVICE_NAME="realm"

while getopts ":n:" opt; do
  case $opt in
    n)
      SERVICE_NAME="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

ARCH=$(uname -m)

mkdir -p /etc/realm

if [[ "$ARCH" == "armv7l" || "$ARCH" == "aarch64" ]]; then
    wget -q -O /etc/realm/realm https://github.com/qiuxiuya/qiuxiuya/raw/refs/heads/main/VPS/realm/realm-armv7
else
    wget -q -O /etc/realm/realm https://github.com/qiuxiuya/qiuxiuya/raw/refs/heads/main/VPS/realm/realm-x86_64
fi

wget -q -O /etc/realm/config.toml https://raw.githubusercontent.com/qiuxiuya/qiuxiuya/refs/heads/main/VPS/realm/config.toml

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=realm
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/realm
ExecStart=/etc/realm/realm -c /etc/realm/config.toml
Restart=on-failure
RestartSec=5s
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

chmod +x /etc/realm/realm

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}

echo -e "realm installed successfully.\nPlease \033[33mnano /etc/realm/config.toml\033[0m to change your config.\nAnd \033[33msystemctl start ${SERVICE_NAME}\033[0m to start realm server."