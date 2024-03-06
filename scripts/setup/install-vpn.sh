#!/bin/bash

# Function to configure rc-local
configure_rc_local() {
    # Edit rc-local.service
    wget -qO /etc/systemd/system/rc-local.service "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/rc-local.service"

    # Create or recreate /etc/rc.local
    wget -qO /etc/rc.local "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/rc.local"

    # Make /etc/rc.local executable
    chmod +x /etc/rc.local

    # Reload systemd to apply changes
    systemctl daemon-reload

    # Enable and start the rc-local service
    systemctl enable rc-local
    # systemctl enable rc-local.service
    systemctl start rc-local.service

    # Disable IPv6 temporarily
    echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6

    # Disable IPv6 permanently by adding the command to /etc/rc.local
    sed -i -e '/^exit 0/i echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
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
    apt -y install nano sed gnupg bc dnsutils apt-transport-https build-essential git

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

    # Download custom vps_server.conf
    wget -qO /etc/nginx/conf.d/vps_server.conf "https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/vps.conf"

    # Restart Nginx
    /etc/init.d/nginx restart
}

# Function to install vnstat
install_vnstat() {
    # Install vnstat
    apt-get install vnstat -y

    # Enable vnstat service to start on boot
    systemctl enable vnstat.service

    # Start vnstat service
    systemctl start vnstat.service
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
    clear

    echo "Installing DOS-Deflate..."

    # Downloading configuration files and the script
    wget -qO /usr/local/ddos/ddos.conf http://www.inetbase.com/scripts/ddos/ddos.conf
    wget -qO /usr/local/ddos/LICENSE http://www.inetbase.com/scripts/ddos/LICENSE
    wget -qO /usr/local/ddos/ignore.ip.list http://www.inetbase.com/scripts/ddos/ignore.ip.list
    wget -qO /usr/local/ddos/ddos.sh http://www.inetbase.com/scripts/ddos/ddos.sh

    # Creating symbolic link for convenience
    cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos

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
install_resolvconf() {
    # Install resolvconf service
    echo "Installing resolvconf service..."
    apt install resolvconf -y

    # Start resolvconf service
    echo "Starting resolvconf service..."
    systemctl start resolvconf.service

    # Enable resolvconf service to start on boot
    echo "Enabling resolvconf service to start on boot..."
    systemctl enable resolvconf.service

    echo "Resolvconf service installation and configuration completed successfully."
}

# Function to configure cron jobs
configure_cron_jobs() {
    # Configure cron jobs
    echo "0 6 * * * root reboot" >> /etc/crontab
    echo "0 0 * * * root root /usr/local/sbin/expiry" >> /etc/crontab
    echo "*/2 * * * * root /usr/local/sbin/cleaner" >> /etc/crontab

    # Restart cron service
    echo -e "Restarting cron service..."
    service cron restart > /dev/null 2>&1
    service cron reload > /dev/null 2>&1
}

# Function to clean up unnecessary files and packages
cleanup() {
    # Clean up unnecessary files and packages
    echo -e "Cleaning up unnecessary files and packages..."
    apt autoclean -y
    apt -y remove --purge unscd
    apt-get -y --purge remove samba*
    apt-get -y --purge remove apache2*
    apt-get -y --purge remove bind9*
    apt-get -y remove sendmail*
    apt autoremove -y
}

# Function to restart services
restart_services() {
    # Restart services
    echo -e "Restarting nginx..."
    /etc/init.d/nginx restart >/dev/null 2>&1
    sleep 1
    echo -e "Restarting cron..."
    /etc/init.d/cron restart >/dev/null 2>&1
    sleep 1
    echo -e "Restarting fail2ban..."
    /etc/init.d/fail2ban restart >/dev/null 2>&1
    sleep 1
    echo -e "Restarting resolvconf..."
    /etc/init.d/resolvconf restart >/dev/null 2>&1
    sleep 1
    echo -e "Restarting vnstat..."
    /etc/init.d/vnstat restart >/dev/null 2>&1
}

# Function to clear command history and disable further recording
clear_history_and_disable_recording() {
    # Clear command history and disable further recording
    echo -e "Clearing command history and disabling further recording..."
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
    echo -e "Cleanup and restart completed."
}

# Main execution starts here

configure_rc_local
update_and_upgrade
install_nginx
install_vnstat
install_fail2ban_and_dos_deflate
block_torrent_and_p2p_traffic
install_resolvconf
configure_cron_jobs
cleanup
restart_services
clear_history_and_disable_recording
cleanup_and_remove_script
finishing_touches
