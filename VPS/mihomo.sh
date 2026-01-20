#!/usr/bin/env bash
set -e

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) KEY="amd64" ;;
    aarch64) KEY="arm64" ;;
    armv7l) KEY="armv7" ;;
    *) exit 1 ;;
esac

FILE="mihomo-linux-$KEY.gz"
RAW_BASE="https://raw.githubusercontent.com/qiuxiuya/Backup/main/mihomo"
URL="$RAW_BASE/$FILE"

TMPDIR=$(mktemp -d)

curl -s -f -L "$URL" -o "$TMPDIR/$FILE"

gunzip -c "$TMPDIR/$FILE" > /usr/bin/mihomo
chmod +x /usr/bin/mihomo

mkdir -p /etc/mihomo
touch /etc/mihomo/config.yaml

cat > /etc/systemd/system/mihomo.service <<'EOF'
[Unit]
Description=mihomo Daemon, Another Clash Kernel.
Documentation=https://wiki.metacubex.one
After=network.target nss-lookup.target network-online.target

[Service]
Type=simple
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
ExecStart=/usr/bin/mihomo -d /etc/mihomo
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mihomo

rm -rf "$TMPDIR"