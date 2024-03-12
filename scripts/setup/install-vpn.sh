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

    # echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
    # sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

    # sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
}

# # Function to install BadVPN
# install_badvpn() {
#     echo "Installing BadVPN..."

#     # Download and install BadVPN binary
#     download_file "https://raw.githubusercontent.com/powermx/badvpn/master/badvpn-udpgw" "/usr/bin/badvpn-udpgw"
#     chmod +x /usr/bin/badvpn-udpgw
#     echo "BadVPN binary installed successfully."

#     # Download and install systemd service file
#     download_file "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/udpgw-7300.service" "/etc/systemd/system/udpgw-7300.service"
#     echo "Systemd service file installed successfully."

#     # Reload systemd to recognize the new service file
#     systemctl daemon-reload
#     echo "Systemd daemon reloaded."

#     # Enable and start the BadVPN service
#     enable_and_start_service "udpgw-7300.service"
#     echo "BadVPN service enabled and started."

#     # Restart the BadVPN service for changes to take effect
#     restart_service "udpgw-7300.service"
#     echo "BadVPN service restarted."

#     echo "BadVPN installation complete."
# }

# Function to install Node.js
# install_nodejs() {
#     echo "Installing Node.js..."
#     #!/bin/bash

#     # Check if /etc/os-release file exists
#     if [ -e /etc/os-release ]; then
#         # Source the /etc/os-release file
#         source /etc/os-release

#         # Check if the ID variable contains "debian" or "ubuntu"
#         if [[ "$ID" == "debian" ]]; then
#             # Install Node.js for Debian
#             curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - &&\
#             apt-get install -y nodejs
#         elif [[ "$ID" == "ubuntu" ]]; then
#             # Install Node.js for Ubuntu
#             curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - &&\
#             sudo apt-get install -y nodejs
#         else
#             echo "Unsupported operating system."
#             exit 1
#         fi
#     else
#         echo "Unable to determine the operating system."
#         exit 1
#     fi

#     echo "Node.js installation complete."
# }

# Function to configure SSH
# configure_ssh() {
#     apt install dropbear -y
#     echo "Configuring SSH..."

#     # sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

#     sed -i 's/#Port 22/Port 22/g' /etc/ssh/sshd_config
    
#     sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
#     sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=110/g' /etc/default/dropbear

#     download_file "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/issue.net" "/etc/issue.net"
#     chmod +x /etc/issue.net

#     echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
#     sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/issue.net"@g' /etc/default/dropbear
    
#     echo "/bin/false" >> /etc/shells
#     echo "/usr/sbin/nologin" >> /etc/shells

#     restart_service "dropbear"
#     restart_service "ssh"

#     echo "SSH configured successfully."
# }

# Function to update and upgrade the system
update_and_upgrade() {
    DEBIAN_FRONTEND=noninteractive
    apt update -y
    apt upgrade -y
    apt dist-upgrade -y

    # Remove unwanted packages
    apt-get remove --purge ufw firewalld exim4 -y

    # Install necessary packages
    apt install wget -y
    apt install curl -y
    apt install netfilter-persistent -y
    apt install xz-utils -y
    # apt install sed -y
    # apt install gnupg -y
    # apt install bc -y
    apt install apt-transport-https -y
    apt install cmake -y
    apt install build-essential -y
    apt install cron -y

    # Set timezone
    ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
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
    echo "Installing necessary packages (resolvconf)..."
    apt install resolvconf -y
    # apt install network-manager -y
    # apt install dnsutils -y

    echo "Starting and enabling DNS resolution services..."
    enable_and_start_service "resolvconf"
    # enable_and_start_service "systemd-resolved"
    # enable_and_start_service "NetworkManager"

    echo "Removing existing DNS configuration files..."
    rm /etc/resolv.conf
    rm /etc/resolvconf/resolv.conf.d/head

    echo "Creating empty DNS configuration files..."
    touch /etc/resolv.conf
    touch /etc/resolvconf/resolv.conf.d/head

    echo "Setting DNS to Cloudflare in /root/current-dns.txt..."
    echo "Cloudflare DNS" > /root/current-dns.txt
    echo "nameserver 1.1.1.1" >> /etc/resolvconf/resolv.conf.d/head
    echo "nameserver 1.0.0.1" >> /etc/resolvconf/resolv.conf.d/head

    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    echo "nameserver 1.0.0.1" >> /etc/resolv.conf
    echo "nameserver 127.0.0.53" >> /etc/resolv.conf

    echo "Restarting DNS resolution services..."
    restart_service "resolvconf"
    # restart_service "systemd-resolved"
    # restart_service "NetworkManager"

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
    # apt autoclean -y
    # apt -y remove --purge unscd
    # apt-get -y --purge remove samba* apache2* bind9* sendmail*
    # apt autoremove -y
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

# Main execution starts here
configure_rc_local
update_and_upgrade
# install_nodejs
install_nginx
install_vnstat
install_fail2ban_and_dos_deflate
# install_badvpn
# configure_ssh
block_torrent_and_p2p_traffic
configure_dns_resolution
configure_cron_jobs
# cleanup
restart_services

rm -f /root/install-vpn.sh

echo "Cleanup and restart completed."
