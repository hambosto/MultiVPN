#!/bin/bash

# Function to download a file from a URL
download_file() {
    local url="$1"
    local destination="$2"
    wget -qO "$destination" "$url"
}

# Function to enable and start a systemd service
enable_and_start_service() {
    local service="$1"
    systemctl enable "$service"
    systemctl start "$service"
}

# Function to restart a systemd service
restart_service() {
    local service="$1"
    systemctl restart "$service"
}

# Function to configure rc-local
configure_rc_local() {
    download_file "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/rc-local.service" "/etc/systemd/system/rc-local.service"
    download_file "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/rc.local" "/etc/rc.local"

    chmod +x /etc/rc.local

    systemctl daemon-reload
    enable_and_start_service "rc-local.service"

    echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6

    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

    sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
}

# Function to install BadVPN
install_badvpn() {
    echo "Installing BadVPN..."

    download_file "https://raw.githubusercontent.com/powermx/badvpn/master/badvpn-udpgw" "/usr/bin/badvpn-udpgw"
    chmod +x /usr/bin/badvpn-udpgw
    
    service_url="https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services"
    for port in 7100 7200 7300; do
        service_file="/etc/systemd/system/udpgw-${port}.service"
        download_file "${service_url}/udpgw-${port}.service" "$service_file"
    done
    
    systemctl daemon-reload

    for port in 7100 7200 7300; do
        service_name="udpgw-${port}.service"
        enable_and_start_service "$service_name"
        restart_service "$service_name"
    done

    echo "BadVPN installation complete."
}

# Function to install Node.js
install_nodejs() {
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && apt-get install -y nodejs
    echo "Node.js installation complete."
}

# Function to configure SSH
configure_ssh() {
    echo "Configuring SSH..."

    sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
    sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
    sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=1337/g' /etc/default/dropbear

    download_file "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/issue.net" "/etc/issue.net"
    chmod +x /etc/issue.net

    echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/issue.net"@g' /etc/default/dropbear
    
    echo "/bin/false" >> /etc/shells
    echo "/usr/sbin/nologin" >> /etc/shells

    restart_service "dropbear"
    restart_service "ssh"

    echo "SSH configured successfully."
}

# Function to update and upgrade the system
update_and_upgrade() {
    apt update -y
    apt upgrade -y
    apt dist-upgrade -y

    apt-get remove --purge ufw firewalld -y
    apt-get remove --purge exim4 -y

    apt install wget curl netfilter-persistent xz-utils -y

    ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

    apt install sed gnupg bc apt-transport-https cmake build-essential dropbear -y
}

# Function to install Nginx
install_nginx() {
    apt install nginx -y

    rm /etc/nginx/sites-enabled/default
    rm /etc/nginx/sites-available/default

    download_file "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/nginx.conf" "/etc/nginx/nginx.conf"
    download_file "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/webserver.conf" "/etc/nginx/conf.d/webserver.conf"

    restart_service "nginx"
}

# Function to install vnstat
install_vnstat() {
    echo "Installing vnstat..."
    apt install vnstat -y
    systemctl enable vnstat.service
    systemctl restart vnstat.service
    echo "vnstat installation complete."
}

# Function to install fail2ban and DOS-Deflate
install_fail2ban_and_dos_deflate() {
    apt install fail2ban -y

    enable_and_start_service "fail2ban"

    if [ -d '/usr/local/ddos' ]; then
        echo "Please uninstall the previous version first"
        exit 0
    else
        mkdir /usr/local/ddos
    fi

    echo "Installing DOS-Deflate..."

    for file in ddos.conf LICENSE ignore.ip.list ddos.sh; do
        download_file "http://www.inetbase.com/scripts/ddos/$file" "/usr/local/ddos/$file"
    done

    ln -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos

    echo "Download complete."

    echo "Creating a cron job to run the script every minute (Default setting)..."
    /usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
    echo "Cron job created."
}

# Function to block Torrent and P2P Traffic
block_torrent_and_p2p_traffic() {
    echo "Blocking torrent and P2P traffic strings..."

    iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
    iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
    iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
    iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
    iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
    iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
    iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
    iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
    iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
    iptables -A FORWARD -m string --algo bm --string "announce" -j DROP

    echo "Saving and applying iptables rules..."
    iptables-save > /etc/iptables.up.rules
    iptables-restore -t < /etc/iptables.up.rules

    echo "Saving and reloading netfilter-persistent rules..."
    netfilter-persistent save
    netfilter-persistent reload
}

# Function to install resolvconf service
configure_dns_resolution() {
    echo "Installing necessary packages (resolvconf, network-manager, dnsutils)..."
    apt install resolvconf network-manager dnsutils -y

    rm -rf /etc/systemd/resolved.conf

    echo "Downloading optimized resolved.conf with Cloudflare DNS..."
    download_file "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/resolved.conf" "/etc/systemd/resolved.conf"

    echo "Setting DNS to Cloudflare in /root/current-dns.txt..."
    echo "Cloudflare DNS" > /root/current-dns.txt

    echo "Starting and enabling DNS resolution services..."
    enable_and_start_service "resolvconf"
    enable_and_start_service "systemd-resolved"
    enable_and_start_service "NetworkManager"

    echo "Configuring /etc/resolv.conf..."
    rm -rf /etc/resolv.conf
    rm -rf /etc/resolvconf/resolv.conf.d/head

    echo "nameserver 127.0.0.53" >> /etc/resolv.conf
    echo "" >> /etc/resolvconf/resolv.conf.d/head

    echo "Restarting DNS resolution services..."
    restart_service "resolvconf"
    restart_service "systemd-resolved"
    restart_service "NetworkManager"

    echo "DNS resolution service installation and configuration completed successfully."
}

# Function to configure cron jobs
configure_cron_jobs() {
    echo "0 6 * * * root reboot" >> /etc/crontab
    echo "0 0 * * * root root /usr/local/sbin/expiry" >> /etc/crontab
    echo "*/2 * * * * root /usr/local/sbin/cleaner" >> /etc/crontab

    echo "Restarting cron service..."
    restart_service "cron"
}

# Function to clean up unnecessary files and packages
cleanup() {
    echo "Cleaning up unnecessary files and packages..."
    apt autoclean -y
    apt -y remove --purge unscd
    apt-get -y --purge remove samba* apache2* bind9* sendmail*
    apt autoremove -y
}

# Function to restart services
restart_services() {
    echo "Restarting services..."
    restart_service "nginx"
    restart_service "cron"
    restart_service "fail2ban"
    restart_service "resolvconf"
    restart_service "vnstat"
}

# Function to clear command history and disable further recording
clear_history_and_disable_recording() {
    echo "Clearing command history and disabling further recording..."
    history -c
    echo "unset HISTFILE" >> /etc/profile
}

# Main execution starts here
configure_rc_local
update_and_upgrade
install_nodejs
install_nginx
install_vnstat
install_fail2ban_and_dos_deflate
install_badvpn
configure_ssh
block_torrent_and_p2p_traffic
configure_dns_resolution
configure_cron_jobs
cleanup
restart_services

rm -f /root/install-vpn.sh

echo "Cleanup and restart completed."
