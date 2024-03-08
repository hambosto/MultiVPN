#!/bin/bash

set -x

# Function to install essential packages and utilities
install_essentials() {
    echo "Updating and upgrading the system..."
    apt update -y && apt upgrade -y

    echo "Installing essential packages..."
    essential_packages=("socat" "python2" "curl" "wget" "sed" "nano" "python3" "jq" "cron" "bash-completion" "ntpdate" "chrony" "zip" "unzip" "pwgen" "openssl" "netcat")
    apt install "${essential_packages[@]}" -y

    echo "Configuring and starting chrony..."
    timedatectl set-ntp true
    systemctl enable --now chronyd

    echo "Setting the timezone to Asia/Jakarta..."
    timedatectl set-timezone Asia/Jakarta

    echo "Displaying chrony information..."
    chronyc sourcestats -v
    chronyc tracking -v
    date
}

# Function to install XRAY Core
install_xray_core() {
    echo "Downloading and installing the latest XRAY Core..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta
    echo "XRAY Core installation completed successfully."
}


# Function to install acme.sh and obtain SSL certificate
install_acme_and_ssl() {
    echo "Stopping Nginx for SSL certificate installation..."
    systemctl stop nginx
    acme_sh_dir="/root/.acme.sh"
    xray_config_dir="/usr/local/etc/xray"

    echo "Creating directory for acme.sh..."
    mkdir "$acme_sh_dir"
    curl https://acme-install.netlify.app/acme.sh -o "$acme_sh_dir/acme.sh"
    chmod +x "$acme_sh_dir/acme.sh"

    echo "Upgrading acme.sh and setting default CA..."
    "$acme_sh_dir/acme.sh" --upgrade --auto-upgrade
    "$acme_sh_dir/acme.sh" --set-default-ca --server letsencrypt

    echo "Issuing SSL certificate using acme.sh..."
    "$acme_sh_dir/acme.sh" --issue -d "$domain" --standalone -k ec-256
    "$acme_sh_dir/acme.sh" --installcert -d "$domain" --fullchainpath "$xray_config_dir/xray.crt" --keypath "$xray_config_dir/xray.key" --ecc
}

# Function to generate and set a UUID for XRAY configuration files
generate_and_set_uuid() {
    uuid=$(cat /proc/sys/kernel/random/uuid)
    xray_config_dir="/usr/local/etc/xray"
    echo "$uuid" > "$xray_config_dir/uuid"

    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vmess-tls.json" | jq '.inbounds[0].settings.clients[0].id = "'$uuid'"' > "$xray_config_dir/vmess-tls.json"
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vmess-nonetls.json" | jq '.inbounds[1].settings.clients[0].id = "'$uuid'"' > "$xray_config_dir/vmess-nonetls.json"
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vless-tls.json" | jq '.inbounds[0].settings.clients[0].id = "'$uuid'"' > "$xray_config_dir/vless-tls.json"
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vless-nonetls.json" | jq '.inbounds[1].settings.clients[0].id = "'$uuid'"' > "$xray_config_dir/vless-nonetls.json"
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/trojan-tls.json" | jq '.inbounds[0].settings.clients[0].password = "'$uuid'"' > "$xray_config_dir/trojan-tls.json"
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/trojan-nonetls.json" | jq '.inbounds[0].settings.clients[0].password = "'$uuid'"' > "$xray_config_dir/trojan-nonetls.json"

    echo "Creating users database for XRAY..."
    jq -n '{"vmess": [], "vless": [], "trojan": [], "trojan_tcp": [], "trojan_go": []}' > "$xray_config_dir/users.db"
}

# Function to set up services and configurations
setup_services_and_configs() {
    xray_service_dir="/etc/systemd/system/xray.service.d"
    xray_at_service_dir="/etc/systemd/system/xray@.service.d"
    nginx_conf_dir="/etc/nginx/conf.d"

    echo "Cleaning up existing service directories..."
    rm -rf "$xray_service_dir" "$xray_at_service_dir"

    echo "Downloading service and configuration files..."
    wget -qO "/etc/systemd/system/xray.service" "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/xray.service"
    wget -qO "/etc/systemd/system/xray@.service" "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/xray@.service"
    wget -qO "$nginx_conf_dir/xray.conf" "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray.conf"

    sleep 1
    echo -e "Restarting All Services..."
    systemctl daemon-reload
    sleep 1

    services=("xray.service" "xray@vmess-nonetls.service" "xray@vless-tls.service" "xray@vless-nonetls.service" "xray@trojan-tls.service" "xray@trojan-nonetls.service" "xray@trojan-tcp.service" "trojan-go.service" "nginx")

    for service in "${services[@]}"; do
        echo -e "Restarting $service..."
        systemctl enable "$service" > /dev/null 2>&1
        systemctl start "$service" > /dev/null 2>&1
        systemctl restart "$service" > /dev/null 2>&1
    done

    echo "Configuring iptables rules..."
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 442 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport 442 -j ACCEPT
    iptables-save > /etc/iptables.up.rules
    netfilter-persistent save > /dev/null
    netfilter-persistent reload > /dev/null
}

# Main execution starts here
domain=$(cat /root/domain)

sleep 1

install_essentials
install_xray_core
install_acme_and_ssl
generate_and_set_uuid
setup_services_and_configs

# Move domain file to Xray configuration directory
mv /root/domain "$xray_config_dir"

# Remove installation script
rm -f install-xray.sh

echo "Installation completed successfully!"
