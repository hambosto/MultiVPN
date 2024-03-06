#!/bin/bash

domain=$(cat /usr/local/etc/xray/domain)

display_banner() {
    clear
    curl -sS https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/banner
}

service_status() {
    local service_name="$1"
    local status=$(systemctl show "${service_name}.service" --no-page)
    local active_state=$(echo "${status}" | grep 'ActiveState=' | cut -f2 -d=)

    if [ "${active_state}" == "active" ]; then
        echo "On"
    else
        echo "Off"
    fi
}

restart_service() {
    local service_name="$1"
    systemctl restart "${service_name}.service"
    sleep 2
    if [ $? -eq 0 ]; then
        echo "Restarted ${service_name} services successfully."
    else
        echo "Failed to restart ${service_name} services."
    fi
}

status() {
    clear
    echo "Services Status:"
    echo "---------------------------------------------------------"
    echo "Cron           : $(service_status cron)"
    echo "Nginx          : $(service_status nginx)"
    echo "Fail2ban       : $(service_status fail2ban)"
    echo "SSH Websocket  : Off"
    echo "Vmess TLS      : $(service_status xray)"
    echo "Vmess Non TLS  : $(service_status xray@vmess-nonetls)"
    echo "Vless TLS      : $(service_status xray@vless-tls)"
    echo "Vless Non TLS  : $(service_status xray@vless-nonetls)"
    echo "Trojan TLS     : $(service_status xray@trojan-tls)"
    echo "Trojan Non TLS : $(service_status xray@trojan-nonetls)"
    echo "Trojan TCP     : $(service_status xray@trojan-tcp)"
    echo "Trojan GO      : $(service_status trojan-go)"
    echo "---------------------------------------------------------"

    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu
}

restart() {
    clear
    echo "RESTARTING SERVICES"
    echo "-------------------"
    echo "Starting..."
    echo ""

    services_to_restart=(
        fail2ban
        cron
        nginx
        xray
        xray@vmess-nonetls
        xray@vless-tls
        xray@vless-nonetls
        xray@trojan-tls
        xray@trojan-nonetls
        xray@trojan-tcp
        trojan-go
    )

    for service in "${services_to_restart[@]}"; do
        restart_service "$service"
    done

    echo ""
    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu
}

# Define setup_dns function
setup_dns() {
    clear
    echo "Setting up $1"
    
    cat > /etc/systemd/resolved.conf << END
[Resolve]
DNS=$2
Domains=~.
ReadEtcHosts=yes
END

    systemctl restart resolvconf
    systemctl restart systemd-resolved
    systemctl restart NetworkManager

    echo "$1" > /root/current-dns.txt

    echo "Setup Completed"
    sleep 1.5
    clear
    changer
}

# Define setup_custom_dns function
setup_custom_dns() {
    clear
    read -p "Please Insert Custom DNS (IPv4 Only): " custom

    if [ -z "$custom" ]; then
        echo "Invalid input. Custom DNS not set."
    else
        setup_dns "Custom DNS" "$custom"
    fi
}

change_dns() {
    clear

    echo "DNS Setting"
    echo "------------"

    current_dns=$(cat /root/current-dns.txt 2>/dev/null)

    echo -e "Current DNS: $current_dns"

    echo "1.  Google DNS"
    echo "2.  Cloudflare DNS"
    echo "3.  Cisco OpenDNS"
    echo "4.  Quad9 DNS"
    echo "5.  Level 3 DNS"
    echo "6.  Freenom World DNS"
    echo "7.  Neustar DNS"
    echo "8.  AdGuard DNS"
    echo "9.  Control D DNS"
    echo "10. Custom DNS"
    echo "11. Back To Main Menu"

    read -p "Select Option [1-11]: " dns

    case $dns in
    1) setup_dns "Google DNS" "8.8.8.8 8.8.4.4" ;;
    2) setup_dns "Cloudflare DNS" "1.1.1.1 1.0.0.1" ;;
    3) setup_dns "Cisco OpenDNS" "208.67.222.222 208.67.222.220" ;;
    4) setup_dns "Quad9 DNS" "9.9.9.9 149.112.112.112" ;;
    5) setup_dns "Level 3 DNS" "4.2.2.1 4.2.2.2" ;;
    6) setup_dns "Freenom World DNS" "80.80.80.80 80.80.81.81" ;;
    7) setup_dns "Neustar DNS" "156.154.70.2 156.154.71.2" ;;
    8) setup_dns "AdGuard DNS" "94.140.14.14 94.140.15.15" ;;
    9) setup_dns "Control D DNS" "76.76.2.43 76.76.10.43" ;;
    10) setup_custom_dns ;;
    11) menu ;;
    *) echo "Invalid option. Please enter a number between 1 and 11." ;;
    esac
}

change_domain() {
    clear
    echo "Change Domain"
    echo "----------------"

    read -p "New Domain: " new_domain
    echo

    if [ -z "$new_domain" ]; then
        echo "Error: Domain cannot be empty"
    else
        echo "New Domain: $new_domain"
        echo "Domain Added Successfully"
        echo "Please Renew Your Domain SSL"
        echo "$new_domain" > /usr/local/etc/xray/domain
    fi

    echo
    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu
}

renew_ssl() {
    clear
    echo "Renew SSL"
    echo "----------------"

    # Stop the process using port 80, if any
    process=$(lsof -i:80 | awk 'NR==2 {print $1}')
    if [[ ! -z "$process" ]]; then
        echo "Detected port 80 used by $process"
        systemctl stop "$process"
        sleep 2
        echo "Stopped $process"
        sleep 1
    fi

    # Start renewing the certificate
    echo "Starting renew cert..."
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /usr/local/etc/xray/xray.crt --keypath /usr/local/etc/xray/xray.key --ecc

    echo "Renew cert done..."
    sleep 2

    # Restart the processes
    echo "Starting services..."
    echo "$domain" > /usr/local/etc/xray/domain
    systemctl restart "$process"
    systemctl restart nginx
    sleep 1

    echo "SSL Renewed Successfully."
    echo "-------------------------"

    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu
}

# Function to get service status
get_status() {
    service_name="$1"
    status=$(systemctl is-active "$service_name")
    if [[ $status == "active" ]]; then
        echo "On"
    else
        echo "Off"
    fi
}

# Get service statuses
status_nginx=$(get_status "nginx")
status_xray=$(get_status "xray")
status_trojan_go=$(get_status "trojan-go")

ip_address=$(curl -s icanhazip.com/ip)

today_download="$(vnstat | grep today | awk '{print $2" "substr ($3, 1, 3)}')"
today_upload="$(vnstat | grep today | awk '{print $5" "substr ($6, 1, 3)}')"
today_total="$(vnstat | grep today | awk '{print $8" "substr ($9, 1, 3)}')"
month_download="$(vnstat -m | grep $(date +%G-%m) | awk '{print $2" "substr ($3, 1 ,3)}')"
month_upload="$(vnstat -m | grep $(date +%G-%m) | awk '{print $5" "substr ($6, 1 ,3)}')"
month_total="$(vnstat -m | grep $(date +%G-%m) | awk '{print $8" "substr ($9, 1 ,3)}')"


org="$(wget -q -T10 -O- ipinfo.io/org)"
city="$(wget -q -T10 -O- ipinfo.io/city)"
country="$(wget -q -T10 -O- ipinfo.io/country)"
region="$(wget -q -T10 -O- ipinfo.io/region)"

display_banner

echo -e "------------------------------------------------------------------------------------------------"
echo -e "Domain       : $domain"
echo -e "IP Address   : $ip_address"

if [[ -n "${org}" ]]; then
    echo -e "Organization : $org"
fi
if [[ -n "${city}" && -n "${country}" ]]; then
    echo -e "Location     : $city / $country"
fi
if [[ -n "${region}" ]]; then
    echo -e "Region       : $region"
fi
if [[ -z "${org}" ]]; then
    echo -e "Region       : No ISP detected"
fi
echo -e "------------------------------------------------------------------------------------------------"
echo -e "Daily Bandwidth:"
echo -e "↑↑ Upload    : $today_upload"
echo -e "↓↓ Download  : $today_download"
echo -e " ≈ Total     : $today_total"
echo -e "------------------------------------------------------------------------------------------------"
echo -e "Montly Bandwidth:"
echo -e "↑↑ Upload    : $month_upload"
echo -e "↓↓ Download  : $month_download"
echo -e " ≈ Total     : $month_total"
echo -e "------------------------------------------------------------------------------------------------"
echo -e "VPN Service:"
echo -e "SSH WS       : Off (Coming Soon)"
echo -e "Nginx        : $status_nginx"
echo -e "V2Ray        : $status_xray"
echo -e "Trojan Go    : $status_trojan_go"
echo -e "------------------------------------------------------------------------------------------------"
echo -e "Menu Options:"
echo -e "1.  SSH Websocket      4.  Trojan Websocket    7.  Change Domain        10. Restart VPN Service"
echo -e "2.  Vmess Websocket    5.  Trojan Go           8.  Renew SSL            11. System Status      "
echo -e "3.  Vless Websocket    6.  Trojan TCP          9.  Change DNS           12. DNS Checker        "
echo -e "13. Speedtest VPS      14. Install TCP BBR     15. Exit"
echo -e "------------------------------------------------------------------------------------------------"

# Read user input
read -p "Select menu: " menu

# Case statement for menu options
case $menu in
1)
    clear
    menu-ssh # for ssh, later.
    ;;
2)
    clear
    menu-vmess
    ;;
3)
    clear
    menu-vless
    ;;
4)
    clear
    menu-trojan
    ;;
5)
    clear
    menu-go
    ;;
5)
    clear
    menu-tcp
    ;;
7)
    clear
    change_domain
    ;;
8)
    clear
    renew_ssl
    ;;
9)
    clear
    change_dns
    ;;
10)
    clear
    restart_service
    ;;
11)
    clear
    status
    ;;
12)
    clear
    bash <(curl -L -s check.unlock.media) -E
    ;;
13)
    clear
    speedtest
    ;;
14)
    clear
    tcp-bbr
    ;;
15)
    clear
    exit
    ;;
*)
    clear
    menu
    ;;
esac
