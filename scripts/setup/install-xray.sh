#!/bin/bash

# Function to install essential packages and utilities
install_essentials() {
    apt update -y
    apt upgrade -y
    apt install socat jq apt-transport-https dnsutils -y
    apt install cron ntpdate -y
    ntpdate pool.ntp.org
    apt install chrony -y
    timedatectl set-ntp true
    systemctl enable chronyd && systemctl restart chronyd
    timedatectl set-timezone Asia/Jakarta
    chronyc sourcestats -v
    chronyc tracking -v
    apt install zip -y
}

# Function to install XRAY Core
install_xray_core() {
    echo -e "=== Installing XRAY Core ==="
    mkdir -p /var/log/xray
    chmod +x /var/log/xray
    mkdir -p /usr/local/etc/xray
    latest_version=$(curl -sI "https://github.com/XTLS/Xray-core/releases/latest" | grep -i location | awk -F '/' '{print $NF}' | tr -d '\r\n[:space:]')
    xraycore_link="https://github.com/XTLS/Xray-core/releases/download/$latest_version/xray-linux-64.zip"
    cd "$(mktemp -d)"
    curl -sL "$xraycore_link" -o xray.zip
    unzip -q xray.zip && rm -rf xray.zip
    mv xray /usr/local/bin/xray
    chmod +x /usr/local/bin/xray
}

# Function to install Trojan Go
install_trojan_go() {
    echo -e "=== Installing Trojan Go ==="
    latest_version=$(curl -s "https://api.github.com/repos/p4gefau1t/trojan-go/releases" | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)
    trojan_go_link="https://github.com/p4gefau1t/trojan-go/releases/download/v${latest_version}/trojan-go-linux-amd64.zip"
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    curl -sL "$trojan_go_link" -o trojan-go.zip
    unzip -q trojan-go.zip && rm -rf trojan-go.zip
    mv trojan-go /usr/local/bin/trojan-go
    chmod +x /usr/local/bin/trojan-go
    rm -rf "$temp_dir"
}

# Function to install acme.sh and obtain SSL certificate
install_acme_and_ssl() {
    echo -e "=== Installing acme.sh and Obtaining SSL Certificate ==="
    mkdir /root/.acme.sh
    curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --server https://api.buypass.com/acme/directory --register-account --accountemail $email
    /root/.acme.sh/acme.sh --server https://api.buypass.com/acme/directory --issue -d $domain --standalone -k ec-256			   
    ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /usr/local/etc/xray/xray.crt --keypath /usr/local/etc/xray/xray.key --ecc
}

# Function to generate and set a UUID for XRAY configuration files
generate_and_set_uuid() {
    echo -e "=== Generating and Setting a UUID for XRAY Configuration Files ==="
    uuid=$(cat /proc/sys/kernel/random/uuid)
    echo "$uuid" > /usr/local/etc/xray/uuid

    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vmess-tls.json" | jq '.inbounds[0].settings.clients[0].id = "'$uuid'"' > /usr/local/etc/xray/vmess-tls.json
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vmess-nontls.json" | jq '.inbounds[1].settings.clients[0].id = "'$uuid'"' > /usr/local/etc/xray/vmess-nontls.json
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vless-tls.json" | jq '.inbounds[0].settings.clients[0].id = "'$uuid'"' > /usr/local/etc/xray/vless-tls.json
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/vless-nontls.json" | jq '.inbounds[1].settings.clients[0].id = "'$uuid'"' > /usr/local/etc/xray/vless-nontls.json
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/trojan-tls.json" | jq '.inbounds[0].settings.clients[0].password = "'$uuid'"' > /usr/local/etc/xray/trojan-tls.json
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/trojan-nontls.json" | jq '.inbounds[0].settings.clients[0].password = "'$uuid'"' > /usr/local/etc/xray/trojan-nontls.json
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/trojan-tcp.json" | jq '.inbounds[0].settings.clients[0].id = "'$uuid'"' > /usr/local/etc/xray/trojan-tcp.json
    wget -qO - "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray/trojan-go.json" | jq '.password[0] = "'$uuid'"' > /usr/local/etc/xray/trojan-go.json

    jq -n '{"vmess": [], "vless": [], "trojan": [], "trojan_tcp": [], "trojan_go": []}' > /usr/local/etc/xray/users.db

}

# Function to set up services and configurations
setup_services_and_configs() {
    rm -rf /etc/systemd/system/xray.service.d /etc/systemd/system/xray@.service.d
    wget -qO /etc/systemd/system/xray.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/xray.service
    wget -qO /etc/systemd/system/xray@.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/xray@.service
    wget -qO /etc/systemd/system/trojan-go.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/trojan-go.service
    wget -qO /etc/nginx/conf.d/xray.conf https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/xray.conf

    sleep 1
    echo -e "Restarting All Services..."
    systemctl daemon-reload
    sleep 1

    services=("xray.service" "xray@vmess-nontls.service" "xray@vless-tls.service" "xray@vless-nontls.service" "xray@trojan-tls.service" "xray@trojan-nontls.service" "xray@trojan-tcp.service" "trojan-go.service" "nginx")
    for service in "${services[@]}"; do
        echo -e "Restarting $service..."
        systemctl enable "$service"
        systemctl start "$service"
        systemctl restart "$service"
    done

    # Configure iptables rules
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 442 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport 442 -j ACCEPT
    iptables-save > /etc/iptables.up.rules
    netfilter-persistent save > /dev/null
    netfilter-persistent reload > /dev/null
}

# Main execution starts here
domain=$(cat /root/domain)
email=$(cat /root/email)

echo -e "=== Starting XRAY Core Installation ==="
sleep 1

install_essentials
install_xray_core
install_trojan_go
install_acme_and_ssl
generate_and_set_uuid
setup_services_and_configs

# Move domain file to Xray configuration directory
mv /root/domain /usr/local/etc/xray/

# Remove installation script
rm -f install-xray.sh

echo -e "=== XRAY Core Installation Completed ==="
