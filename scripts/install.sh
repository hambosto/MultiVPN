#!/bin/bash

# Function to display banner
display_banner() {
    clear
    curl -sS https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/banner
}

# Function to check if the script is already installed
check_installed() {
    if [ -f "/usr/local/etc/xray/domain" ]; then
        clear
        echo "Xray Script is already installed."
        echo "To make changes, please rebuild your VPS first!"
        echo "Visit https://github.com/hambosto/MultiVPN for more documentation."
    fi
}

# Function to set up username and domain
setup_domains() {
    read -p "Domain: " domain
    echo -e ""

    if [ -z "$domain" ]; then
        echo "Domain cannot be empty or null."
    else
        echo "Domain '$domain' added successfully."
        echo "$domain" > /root/domain
    fi
    echo -e ""

}


# Function to install XRAY Defender
install_xray_defender() {
    display_banner
    echo "Installing XRAY Defender with support for SSH, Vmess, Vless, Trojan, and Trojan Go..."
    sleep 3
    wget -qO /root/install-vpn.sh "https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/setup/install-vpn.sh" 
    chmod +x /root/install-vpn.sh 
    /root/install-vpn.sh
    echo "XRAY Defender installed successfully."
    rm /root/install-vpn.sh
    clear
}

# Function to install XRAY Core
install_xray_core() {
    display_banner
    echo "Installing XRAY Core with support for SSH, Vmess, Vless, Trojan, and Trojan Go..."
    sleep 3
    wget -qO /root/install-xray.sh "https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/setup/install-xray.sh" 
    chmod +x /root/install-xray.sh 
    /root/install-xray.sh
    echo "XRAY Core installed successfully."
    rm /root/install-xray.sh
    clear
}

# Function to install XRAY Menu
install_xray_menu() {
    display_banner
    echo "Installing XRAY Menu with support for SSH, Vmess, Vless, Trojan, and Trojan Go..."
    sleep 1
    wget -qO /root/install-menu.sh "https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/setup/install-menu.sh" 
    chmod +x /root/install-menu.sh && 
    /root/install-menu.sh
    echo "XRAY Menu installed successfully."
    rm /root/install-menu.sh
    sleep 3
    clear
}


# Main script starts here
echo -e "Updating Package..."
apt update && apt upgrade -y && apt install curl wget -y

if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root"
    exit 1
fi

if [ "$(systemd-detect-virt)" == "openvz" ]; then
    echo "OpenVZ is not supported"
    exit 1
fi

check_installed
display_banner
setup_domains
install_xray_defender
install_xray_core
install_xray_menu


display_banner
echo "--------------------------------------------"
echo "           Installation complete."
echo "--------------------------------------------"
echo "IP     : $(curl -sS ipv4.icanhazip.com)"
echo "Domain : $(cat /usr/local/etc/xray/domain)"
echo "--------------------------------------------"
echo "Github : https://github.com/hambosto"
echo "--------------------------------------------"

read -rp "Do you want to reboot your system now? (yes/no): " user_input

rm -rf ~/install.sh

case $user_input in
    [Yy]|[Yy][Ee][Ss])
        clear
        echo "Rebooting your system..."
        sleep 2
        reboot
        ;;
    [Nn]|[Nn][Oo])
        clear
        echo "Exiting without reboot."
        sleep 2
        exit
        ;;
    *)
        clear
        echo "Invalid input. Rebooting your system..."
        sleep 2
        reboot
        ;;
esac
