#!/bin/bash

# Function to install XanMod kernel
install_xanmod() {
    echo "Installing XanMod kernel..."
    wget -qO - https://dl.xanmod.org/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-release.list
    sudo apt update && sudo apt install linux-xanmod-x64v3
    echo "Installation complete. Please restart your system to apply changes."
}

# Function to import optimization configurations
import_optimization() {
    echo "Importing optimization configurations..."
    declare -A optimizations=(
        ["net.ipv4.tcp_rmem"]="8192 262144 536870912"
        ["net.ipv4.tcp_wmem"]="8192 262144 536870912"
        ["net.ipv4.tcp_collapse_max_bytes"]="6291456"
        ["net.ipv4.tcp_notsent_lowat"]="131072"
        ["net.ipv4.tcp_adv_win_scale"]="1"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.conf.all.route_localnet"]="1"
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv4.conf.all.forwarding"]="1"
        ["net.ipv4.conf.default.forwarding"]="1"
        ["net.ipv4.udp_rmem_min"]="16384"
        ["net.ipv4.udp_wmem_min"]="16384"
        ["net.core.rmem_default"]="26214400"
        ["net.core.rmem_max"]="26214400"
        ["net.core.optmem_max"]="65535"
        ["net.ipv4.udp_mem"]="8192 262144 536870912"
        ["net.core.netdev_max_backlog"]="30000"
    )
    for key in "${!optimizations[@]}"; do
        echo "$key=${optimizations[$key]}" | sudo tee -a /etc/sysctl.conf
    done
    sudo sysctl -p
    echo "Optimization configurations imported successfully."
}

# Main script
echo "Welcome to the XanMod installer and optimization tool!"
echo "Please select an option:"
echo "1. Install XanMod kernel"
echo "2. Import optimization configurations"

read -p "Enter your choice (1 or 2): " choice

case $choice in
    1) install_xanmod ;;
    2) import_optimization ;;
    *) echo "Invalid choice. Please enter 1 or 2." ;;
esac
