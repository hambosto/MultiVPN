#!/bin/bash

# what are you looking for?





# Install Speedtest
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
apt-get install speedtest

wget -qO /usr/local/sbin/menu https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/menu/menu.sh && chmod +x /usr/local/sbin/menu
wget -qO /usr/local/sbin/menu-vmess https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/menu/vmess.sh && chmod +x /usr/local/sbin/menu-vmess
wget -qO /usr/local/sbin/menu-vless https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/menu/vless.sh && chmod +x /usr/local/sbin/menu-vless

wget -qO /usr/local/sbin/cleaner https://raw.githubusercontent.com/hambosto/MultiVPN/main/tools/cleaner.sh && chmod +x /usr/local/sbin/cleaner
wget -qO /usr/local/sbin/tcp-bbr https://raw.githubusercontent.com/hambosto/MultiVPN/main/tools/tcp-bbr.sh && chmod +x /usr/local/sbin/tcp-bbr
