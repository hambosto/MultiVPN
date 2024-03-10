#!/bin/bash

domain=$(cat /usr/local/etc/xray/domain)

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

to_kibyte() {
    local raw=$1
    awk 'BEGIN{printf "%.0f", '"$raw"' / 1024}'
}

calc_sum() {
    local arr=("$@")
    local s
    s=0
    for i in "${arr[@]}"; do
        s=$((s + i))
    done
    echo ${s}
}

calc_size() {
    local raw=$1
    local total_size=0
    local num=1
    local unit="KB"
    if ! [[ ${raw} =~ ^[0-9]+$ ]]; then
        echo ""
        return
    fi
    if [ "${raw}" -ge 1073741824 ]; then
        num=1073741824
        unit="TB"
    elif [ "${raw}" -ge 1048576 ]; then
        num=1048576
        unit="GB"
    elif [ "${raw}" -ge 1024 ]; then
        num=1024
        unit="MB"
    elif [ "${raw}" -eq 0 ]; then
        echo "${total_size}"
        return
    fi
    total_size=$(awk 'BEGIN{printf "%.1f", '"$raw"' / '$num'}')
    echo "${total_size} ${unit}"
}

_exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        command -v "$cmd" >/dev/null 2>&1
    else
        which "$cmd" >/dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}

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
    echo "SSH Websocket  : $(service_status dropbear-websocket)"
    echo "Vmess TLS      : $(service_status xray)"
    echo "Vmess Non TLS  : $(service_status xray@vmess-nonetls)"
    echo "Vless TLS      : $(service_status xray@vless-tls)"
    echo "Vless Non TLS  : $(service_status xray@vless-nonetls)"
    echo "Trojan TLS     : $(service_status xray@trojan-tls)"
    echo "Trojan Non TLS : $(service_status xray@trojan-nonetls)"
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
        dropbear-websocket
        xray@vmess-nonetls
        xray@vless-tls
        xray@vless-nonetls
        xray@trojan-tls
        xray@trojan-nonetls
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
    change_dns
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

status_nginx=$(get_status "nginx")
status_xray=$(get_status "xray")
status_ssh=$(get_status "dropbear-websocket")

ip_address=$(curl -s icanhazip.com/ip)

cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
cores=$(awk -F: '/^processor/ {core++} END {print core}' /proc/cpuinfo)
freq=$(awk -F'[ :]' '/cpu MHz/ {print $4;exit}' /proc/cpuinfo)
ccache=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')

tram=$(
    LANG=C
    free | awk '/Mem/ {print $2}'
)
tram=$(calc_size "$tram")
uram=$(
    LANG=C
    free | awk '/Mem/ {print $3}'
)
uram=$(calc_size "$uram")

in_kernel_no_swap_total_size=$(
    LANG=C
    df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs --total 2>/dev/null | grep total | awk '{ print $2 }'
)
swap_total_size=$(free -k | grep Swap | awk '{print $2}')
zfs_total_size=$(to_kibyte "$(calc_sum "$(zpool list -o size -Hp 2> /dev/null)")")
disk_total_size=$(calc_size $((swap_total_size + in_kernel_no_swap_total_size + zfs_total_size)))
in_kernel_no_swap_used_size=$(
    LANG=C
    df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs --total 2>/dev/null | grep total | awk '{ print $3 }'
)
swap_used_size=$(free -k | grep Swap | awk '{print $3}')
zfs_used_size=$(to_kibyte "$(calc_sum "$(zpool list -o allocated -Hp 2> /dev/null)")")
disk_used_size=$(calc_size $((swap_used_size + in_kernel_no_swap_used_size + zfs_used_size)))

swap=$(
    LANG=C
    free | awk '/Swap/ {print $2}'
)
swap=$(calc_size "$swap")
uswap=$(
    LANG=C
    free | awk '/Swap/ {print $3}'
)
uswap=$(calc_size "$uswap")

opsy=$(get_opsy)
arch=$(uname -m)
if _exists "getconf"; then
    lbit=$(getconf LONG_BIT)
else
    echo "${arch}" | grep -q "64" && lbit="64" || lbit="32"
fi
kern=$(uname -r)

up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime)
if _exists "w"; then
    load=$(
        LANG=C
        w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//'
    )
elif _exists "uptime"; then
    load=$(
        LANG=C
        uptime | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//'
    )
fi


date_today=$(date -R | cut -d " " -f -4)

today_download="$(vnstat | grep today | awk 'NR==1{print $2" "substr($3, 1, 3)}')"
today_upload="$(vnstat | grep today | awk 'NR==1{print $5" "substr($6, 1, 3)}')"
today_total="$(vnstat | grep today | awk 'NR==1{print $8" "substr($9, 1, 3)}')"

month_download="$(vnstat -m | grep $(date +%G-%m) | awk '{print $2" "substr ($3, 1 ,3)}')"
month_upload="$(vnstat -m | grep $(date +%G-%m) | awk '{print $5" "substr ($6, 1 ,3)}')"
month_total="$(vnstat -m | grep $(date +%G-%m) | awk '{print $8" "substr ($9, 1 ,3)}')"


org="$(wget -q -T10 -O- ipinfo.io/org)"
city="$(wget -q -T10 -O- ipinfo.io/city)"
country="$(wget -q -T10 -O- ipinfo.io/country)"
region="$(wget -q -T10 -O- ipinfo.io/region)"

display_banner

echo -e "------------------------------------------------------------------------------------------------"
echo -e "Date          : $date_today"
echo -e "Domain        : $domain"

if [ -n "$cname" ]; then
    echo -e "CPU Model     : $cname"
else
    echo -e "CPU Model     : CPU model not detected"
fi
if [ -n "$freq" ]; then
    echo -e "CPU Cores     : $cores @ $freq MHz"
else
    echo -e "CPU Cores     : $cores"
fi
if [ -n "$ccache" ]; then
    echo -e "CPU Cache     : $ccache"
fi

echo -e "Total Disk    : $disk_total_size ($disk_used_size Used)"
echo -e "Total Memory  : $tram ($uram Used)"

if [ "$swap" != "0" ]; then
    echo -e "Total Swap   : $swap ($uswap Used)"
fi

echo -e "System uptime : $up"
echo -e "Load average  : $load"

echo -e "OS            : $opsy"
echo -e "Arch          : $arch ($lbit Bit)"
echo -e "Kernel        : $kern"

echo -e "IP Address    : $ip_address"

if [[ -n "${org}" ]]; then
    echo -e "Organization  : $org"
fi
if [[ -n "${city}" && -n "${country}" ]]; then
    echo -e "Location      : $city / $country"
fi
if [[ -n "${region}" ]]; then
    echo -e "Region        : $region"
fi
if [[ -z "${org}" ]]; then
    echo -e "Region        : No ISP detected"
fi
echo -e "------------------------------------------------------------------------------------------------"
echo -e "Daily Bandwidth:"
echo -e "↑↑ Upload     : $today_upload"
echo -e "↓↓ Download   : $today_download"
echo -e "≈≈ Total      : $today_total"
echo -e "------------------------------------------------------------------------------------------------"
echo -e "Montly Bandwidth:"
echo -e "↑↑ Upload     : $month_upload"
echo -e "↓↓ Download   : $month_download"
echo -e "≈≈ Total      : $month_total"
echo -e "------------------------------------------------------------------------------------------------"
echo -e "VPN Service:"
echo -e "SSH WS        : $status_ssh"
echo -e "Nginx         : $status_nginx"
echo -e "V2Ray         : $status_xray"
echo -e "------------------------------------------------------------------------------------------------"
echo -e "Menu Options:"
echo -e "1. SSH Websocket       5. Restart VPN Service   9.  Speedtest VPS"
echo -e "2. Vmess Websocket     6. Change Domain         10. Install TCP BBR"
echo -e "3. Vless Websocket     7. Renew SSL             11. System Status"
echo -e "4. Trojan Websocket    8. Change DNS            12. DNS Checker"
echo -e "                                                13. Exit"
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
        restart
        ;;
    6)
        clear
        change_domain
        ;;
    7)
        clear
        renew_ssl
        ;;
    8)
        clear
        change_dns
        ;;
    9)
        clear
        speedtest
        ;;
    10)
        clear
        tcp-bbr
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
        exit
        ;;
    *)
        clear
        menu
        ;;
esac

