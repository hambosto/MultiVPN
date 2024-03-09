#!/bin/bash

# Function to configure rc-local
configure_rc_local() {
    # Download and configure rc-local.service
    wget -qO /etc/systemd/system/rc-local.service "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/rc-local.service"

    # Create or recreate /etc/rc.local
    wget -qO /etc/rc.local "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/rc.local"

    # Make /etc/rc.local executable
    chmod +x /etc/rc.local

    # Reload systemd to apply changes
    systemctl daemon-reload

    # Enable and start the rc-local service
    systemctl enable rc-local
    systemctl start rc-local.service

    # Disable IPv6 temporarily
    echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6

    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

    # Disable IPv6 permanently by adding the command to /etc/rc.local
    sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

    # Allow IPv4 forwarding
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

}

install_badvpn() {
    echo "Installing BadVPN..."

    # Download and install badvpn-udpgw binary
    wget -qO /usr/bin/badvpn-udpgw https://raw.githubusercontent.com/powermx/badvpn/master/badvpn-udpgw
    chmod +x /usr/bin/badvpn-udpgw
    
    # Download systemd service files for different ports
    service_url="https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services"
    for port in 7100 7200 7300; do
        service_file="/etc/systemd/system/udpgw-${port}.service"
        wget -qO "$service_file" "${service_url}/udpgw-${port}.service"
    done
    
    # Reload systemd and start services
    echo "Reloading systemd and starting services..."
    systemctl daemon-reload

    # Enable, start, and restart services for each port
    for port in 7100 7200 7300; do
        service_name="udpgw-${port}.service"
        systemctl enable "$service_name"
        systemctl start "$service_name"
        systemctl restart "$service_name"
    done

    echo "BadVPN installation complete."
}

configure_ssh() {
    echo "Configuring SSH..."
    sed -i '/Port 22/a Port 500' /etc/ssh/sshd_config
    sed -i '/Port 22/a Port 40000' /etc/ssh/sshd_config
    sed -i '/Port 22/a Port 51443' /etc/ssh/sshd_config
    sed -i '/Port 22/a Port 58080' /etc/ssh/sshd_config
    sed -i '/Port 22/a Port 200' /etc/ssh/sshd_config
    sed -i 's/#Port 22/Port 22/g' /etc/ssh/sshd_config
    /etc/init.d/ssh restart
    echo "SSH configured successfully."
}

install_dropbear() {
    echo "Installing Dropbear..."
    apt install dropbear -y
    sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
    sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=143/g' /etc/default/dropbear
    sed -i 's/DROPBEAR_EXTRA_ARGS=/DROPBEAR_EXTRA_ARGS="-p 50000 -p 109 -p 110 -p 69"/g' /etc/default/dropbear
    echo "/bin/false" >> /etc/shells
    echo "/usr/sbin/nologin" >> /etc/shells
    /etc/init.d/ssh restart
    /etc/init.d/dropbear restart
    echo "Dropbear installed and configured successfully."
}

configure_stunnel() {
    # Set your certificate information
    country="US"
    state="California"
    locality="San Francisco"
    organization="Github"
    organizationalunit="IT"
    commonname="MultiVPN"
    email="abuse@hambosto.cloud"


    echo "Installing stunnel4..."
    apt install stunnel4 -y

    echo "Configuring stunnel..."
    wget -qO /etc/stunnel/stunnel.conf https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/stunnel.conf

    echo "Generating stunnel certificate..."
    openssl genrsa -out /etc/stunnel/key.pem 2048
    openssl req -new -x509 -key /etc/stunnel/key.pem -out /etc/stunnel/cert.pem -days 1095 \
    -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
    cat /etc/stunnel/key.pem /etc/stunnel/cert.pem >> /etc/stunnel/stunnel.pem

    echo "Enabling stunnel4..."
    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
    /etc/init.d/stunnel4 restart
}

# Function to update and upgrade the system
update_and_upgrade() {
    # Update and upgrade the system
    apt update -y
    apt upgrade -y
    apt dist-upgrade -y

    # Remove firewalls and mail server
    apt-get remove --purge ufw firewalld -y
    apt-get remove --purge exim4 -y

    # Install essential tools
    apt -y install wget curl netfilter-persistent

    # Set timezone to Asia/Jakarta
    ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

    # Disable AcceptEnv in SSH configuration
    sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

    # Install Xray dependencies
    apt -y install xz-utils

    # Clean up unnecessary packages
    apt autoremove -y

    # Install additional tools if needed
    apt -y install nano sed gnupg bc apt-transport-https cmake build-essential git
}

# Function to install Nginx
install_nginx() {
    # Install Nginx
    apt -y install nginx

    # Remove default Nginx site configurations
    rm /etc/nginx/sites-enabled/default
    rm /etc/nginx/sites-available/default

    # Download custom nginx.conf
    wget -qO /etc/nginx/nginx.conf "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/nginx.conf"

    # Download custom webserver.conf
    wget -qO /etc/nginx/conf.d/webserver.conf "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/webserver.conf"

    # Restart Nginx
    systemctl restart nginx
}

# Function to install vnstat
install_vnstat() {
    # Install vnstat
    apt-get install vnstat -y

    # Enable vnstat service to start on boot
    systemctl enable vnstat.service

    # Restart vnstat service
    systemctl restart vnstat.service
}

# Function to install fail2ban and DOS-Deflate
install_fail2ban_and_dos_deflate() {
    # Install fail2ban
    apt -y install fail2ban

    # Install DOS-Deflate 0.6
    if [ -d '/usr/local/ddos' ]; then
        echo "Please uninstall the previous version first"
        exit 0
    else
        mkdir /usr/local/ddos
    fi

    echo "Installing DOS-Deflate..."

    # Downloading configuration files and the script
    for file in ddos.conf LICENSE ignore.ip.list ddos.sh; do
        wget -qO "/usr/local/ddos/$file" "http://www.inetbase.com/scripts/ddos/$file"
    done

    # Creating symbolic link for convenience
    ln -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos

    echo "Download complete."

    # Setting up a cron job to run the script every minute
    echo "Creating a cron job to run the script every minute (Default setting)..."
    /usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
    echo "Cron job created."
}

# Function to block Torrent and P2P Traffic
block_torrent_and_p2p_traffic() {
    # Block specific strings associated with torrent and P2P traffic
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

    # Save and apply iptables rules
    echo "Saving and applying iptables rules..."
    iptables-save > /etc/iptables.up.rules
    iptables-restore -t < /etc/iptables.up.rules

    # Save and reload netfilter-persistent rules
    echo "Saving and reloading netfilter-persistent rules..."
    netfilter-persistent save
    netfilter-persistent reload
}

# Function to install resolvconf service
configure_dns_resolution() {
    # Install and configure DNS resolution services
    echo "Installing necessary packages (resolvconf, network-manager, dnsutils)..."
    apt install resolvconf network-manager dnsutils -y

    # Remove existing resolved.conf
    rm -rf /etc/systemd/resolved.conf

    # Download optimized resolved.conf file with Cloudflare DNS
    echo "Downloading optimized resolved.conf with Cloudflare DNS..."
    wget -qO - https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/resolved.conf > /etc/systemd/resolved.conf

    # Record current DNS information
    echo "Setting DNS to Cloudflare in /root/current-dns.txt..."
    echo "Cloudflare DNS" > /root/current-dns.txt

    # Start and enable DNS resolution services
    echo "Starting and enabling DNS resolution services..."
    systemctl enable resolvconf
    systemctl enable systemd-resolved
    systemctl enable NetworkManager

    # Configure /etc/resolv.conf
    echo "Configuring /etc/resolv.conf..."
    rm -rf /etc/resolv.conf
    rm -rf /etc/resolvconf/resolv.conf.d/head

    echo "nameserver 127.0.0.53" >> /etc/resolv.conf
    echo "" >> /etc/resolvconf/resolv.conf.d/head

    # Restart DNS resolution services for changes to take effect
    echo "Restarting DNS resolution services..."
    systemctl restart resolvconf
    systemctl restart systemd-resolved
    systemctl restart NetworkManager

    echo "DNS resolution service installation and configuration completed successfully."
}

# Function to configure cron jobs
configure_cron_jobs() {
    # Configure cron jobs
    echo "0 6 * * * root reboot" >> /etc/crontab
    echo "0 0 * * * root root /usr/local/sbin/expiry" >> /etc/crontab
    echo "*/2 * * * * root /usr/local/sbin/cleaner" >> /etc/crontab

    # Restart cron service
    echo "Restarting cron service..."
    systemctl restart cron
}

# Function to clean up unnecessary files and packages
cleanup() {
    # Clean up unnecessary files and packages
    echo "Cleaning up unnecessary files and packages..."
    apt autoclean -y
    apt -y remove --purge unscd
    apt-get -y --purge remove samba* apache2* bind9* sendmail*
    apt autoremove -y
}

# Function to restart services
restart_services() {
    # Restart services
    echo "Restarting services..."
    systemctl restart nginx cron fail2ban resolvconf vnstat
}

# Function to clear command history and disable further recording
clear_history_and_disable_recording() {
    # Clear command history and disable further recording
    echo "Clearing command history and disabling further recording..."
    history -c
    echo "unset HISTFILE" >> /etc/profile
}

# Function to cleanup and remove the script
cleanup_and_remove_script() {
    # Cleanup and remove script
    cd
    rm -f /root/install-vpn.sh
}

# Function to perform finishing touches
finishing_touches() {
    # Finishing touches
    clear
    echo "Cleanup and restart completed."
}

# Main execution starts here

configure_rc_local
update_and_upgrade
install_nginx
install_vnstat
install_fail2ban_and_dos_deflate
install_badvpn
block_torrent_and_p2p_traffic
configure_dns_resolution
configure_cron_jobs
cleanup
restart_services
clear_history_and_disable_recording
cleanup_and_remove_script
finishing_touches
