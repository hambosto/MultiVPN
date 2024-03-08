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

    # Disable IPv6 permanently by adding the command to /etc/rc.local
    sed -i -e '/^exit 0/i echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
}

install_badvpn() {
    echo "Installing BadVPN..."

    # Change to a temporary directory for building
    cd /tmp

    # Create a temporary build directory
    mkdir build_temp
    cd build_temp

    # Download and extract the source code
    echo "Downloading and extracting BadVPN source code..."
    wget -q https://github.com/ambrop72/badvpn/archive/refs/tags/1.999.130.tar.gz
    tar xvzf 1.999.130.tar.gz
    cd badvpn-1.999.130

    # Configure and build
    echo "Configuring and building BadVPN..."
    cmake -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1

    # Install the binary and libraries
    echo "Installing BadVPN binary and libraries..."
    sudo make install

    # Remove the temporary build directory and files
    echo "Cleaning up temporary files..."
    cd /tmp && rm -rf build_temp

    # Change to a home directory
    echo "Returning to the home directory..."
    cd $HOME

    echo "BadVPN installation complete."
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
install_nodejs
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
