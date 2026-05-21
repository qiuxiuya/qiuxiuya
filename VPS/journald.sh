#!/bin/bash

> /etc/motd
cat > /etc/systemd/journald.conf <<EOF
[Journal]
Storage=volatile
RuntimeMaxUse=30M
EOF

systemctl restart systemd-journald