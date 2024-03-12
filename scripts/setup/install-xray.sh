#!/bin/bash

# Function to install essential packages and utilities
install_essentials() {
    echo "Updating and upgrading the system..."
    apt update -y && apt upgrade -y

    echo "Installing essential packages..."
    apt install socat -y
    apt install curl -y
    apt install jq -y
    apt install ntpdate -y
    apt install chrony -y
    apt install zip -y
    apt install unzip -y
    apt install netcat -y

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
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" - install --beta
    echo "XRAY Core installation completed successfully."
}

# Function to install acme.sh and obtain SSL certificate
install_acme_and_ssl() {
    echo "Stopping Nginx for SSL certificate installation..."
    systemctl stop nginx
    acme_sh_dir="/root/.acme.sh"
    xray_config_dir="/usr/local/etc/xray"

    echo "Creating directory for acme.sh..."
    mkdir -p "$acme_sh_dir"
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

    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/config.json" | jq --arg uuid "$uuid" '.inbounds[1].settings.clients[0].id = $uuid | .inbounds[2].settings.clients[0].id = $uuid | .inbounds[3].settings.clients[0].id = $uuid | .inbounds[4].settings.clients[0].id = $uuid | .inbounds[5].settings.clients[0].password = $uuid | .inbounds[6].settings.clients[0].password = $uuid' > "$xray_config_dir/config.json"

    

    # wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vmess-tls.json" | jq '.inbounds[0].settings.clients[0].id = "'$uuid'"' > "$xray_config_dir/config.json"
    # wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vmess-nonetls.json" | jq '.inbounds[1].settings.clients[0].id = "'$uuid'"' > "$xray_config_dir/vmess-nonetls.json"
    # wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vless-tls.json" | jq '.inbounds[0].settings.clients[0].id = "'$uuid'"' > "$xray_config_dir/vless-tls.json"
    # wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vless-nonetls.json" | jq '.inbounds[1].settings.clients[0].id = "'$uuid'"' > "$xray_config_dir/vless-nonetls.json"
    # wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/trojan-tls.json" | jq '.inbounds[0].settings.clients[0].password = "'$uuid'"' > "$xray_config_dir/trojan-tls.json"
    # wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/trojan-nonetls.json" | jq '.inbounds[0].settings.clients[0].password = "'$uuid'"' > "$xray_config_dir/trojan-nonetls.json"



    # echo "$(jq --arg uuid "$uuid" '.inbounds[1].settings.clients[0].id = $uuid' "config.json")" > config.json
    # echo "$(jq --arg uuid "$uuid" '.inbounds[2].settings.clients[0].id = $uuid' "config.json")" > config.json
    # echo "$(jq --arg uuid "$uuid" '.inbounds[3].settings.clients[0].id = $uuid' "config.json")" > config.json
    # echo "$(jq --arg uuid "$uuid" '.inbounds[4].settings.clients[0].id = $uuid' "config.json")" > config.json
    # echo "$(jq --arg uuid "$uuid" '.inbounds[5].settings.clients[0].password = $uuid' "config.json")" > config.json
    # echo "$(jq --arg uuid "$uuid" '.inbounds[6].settings.clients[0].password = $uuid' "config.json")" > config.json

    
    echo "Creating users database for XRAY..."
    jq -n '{"vmess": [], "vless": [], "trojan": [], "trojan_tcp": [], "trojan_go": []}' > "$xray_config_dir/users.db"
}

# Function to set up services and configurations
setup_services_and_configs() {
    nginx_conf_dir="/etc/nginx/conf.d"

    echo "Downloading service and configuration files..."
    wget -qO "$nginx_conf_dir/xray.conf" "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray.conf"

    sleep 1
    echo -e "Restarting All Services..."
    systemctl daemon-reload
    sleep 1

    systemctl enable xray > /dev/null 2>&1
    systemctl start xray > /dev/null 2>&1
    systemctl restart xray > /dev/null 2>&1

    systemctl enable nginx > /dev/null 2>&1
    systemctl start nginx > /dev/null 2>&1
    systemctl restart nginx > /dev/null 2>&1

    # services=("xray.service" "xray@vmess-nonetls.service" "xray@vless-tls.service" "xray@vless-nonetls.service" "xray@trojan-tls.service" "xray@trojan-nonetls.service" "nginx")

    # for service in "${services[@]}"; do
    #     echo -e "Restarting $service..."
    #     systemctl enable "$service" > /dev/null 2>&1
    #     systemctl start "$service" > /dev/null 2>&1
    #     systemctl restart "$service" > /dev/null 2>&1
    # done

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
