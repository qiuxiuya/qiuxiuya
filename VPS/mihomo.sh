#!/usr/bin/env bash
set -e

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) KEY="amd64" ;;
    aarch64) KEY="arm64" ;;
    armv7l) KEY="armv7" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

FILE="mihomo-linux-$KEY.deb"
URL="https://raw.githubusercontent.com/qiuxiuya/Backup/main/mihomo/$FILE"

TMPDIR=$(mktemp -d)

curl -s -f -L "$URL" -o "$TMPDIR/$FILE"

apt install -y "$TMPDIR/$FILE"

rm -rf "$TMPDIR"