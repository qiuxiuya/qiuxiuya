#!/bin/bash
set -e

apt update
apt install -y curl git build-essential
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs
npm install -g npm@latest
npm install -g pm2
pm2 startup systemd