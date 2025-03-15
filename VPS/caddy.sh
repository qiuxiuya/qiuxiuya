#!/bin/bash

# Install necessary packages
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

# Download Caddy GPG key and add it to keyring
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# Add Caddy repository to APT sources
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Update package lists
sudo apt update

# Install Caddy
sudo apt install caddy
