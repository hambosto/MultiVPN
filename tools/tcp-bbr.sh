#!/bin/bash

add_to_new_line() {
    if [ "$(tail -n1 "$1" | wc -l)" == "0" ]; then
        echo "" >> "$1"
    fi
    echo "$2" >> "$1"
}

check_and_add_line() {
    if [ -z "$(grep "$2" "$1")" ]; then
        add_to_new_line "$1" "$2"
    fi
}

install_bbr() {
    clear
    echo "Installing TCP_BBR..."
    
    if lsmod | grep -q bbr; then
        echo "TCP_BBR is already installed."
        return 1
    fi

    modprobe tcp_bbr
    add_to_new_line "/etc/modules-load.d/modules.conf" "tcp_bbr"
    add_to_new_line "/etc/sysctl.conf" "net.core.default_qdisc = fq"
    add_to_new_line "/etc/sysctl.conf" "net.ipv4.tcp_congestion_control = bbr"
    sysctl -p

    if sysctl net.ipv4.tcp_available_congestion_control | grep -q bbr &&
       sysctl net.ipv4.tcp_congestion_control | grep -q bbr &&
       lsmod | grep -q "tcp_bbr"; then
        echo "TCP_BBR Installed Successfully."
    else
        echo "Failed to install TCP_BBR."
    fi
}

optimize_parameters() {
    echo "Optimizing Parameters..."
    
    check_and_add_line "/etc/security/limits.conf" "* soft nofile 51200"
    check_and_add_line "/etc/security/limits.conf" "* hard nofile 51200"
    check_and_add_line "/etc/security/limits.conf" "root soft nofile 51200"
    check_and_add_line "/etc/security/limits.conf" "root hard nofile 51200"
    check_and_add_line "/etc/sysctl.conf" "fs.file-max = 51200"
    check_and_add_line "/etc/sysctl.conf" "net.core.rmem_max = 67108864"
    check_and_add_line "/etc/sysctl.conf" "net.core.wmem_max = 67108864"
    check_and_add_line "/etc/sysctl.conf" "net.core.netdev_max_backlog = 250000"
    check_and_add_line "/etc/sysctl.conf" "net.core.somaxconn = 4096"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_syncookies = 1"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_tw_reuse = 1"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_fin_timeout = 30"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_keepalive_time = 1200"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.ip_local_port_range = 10000 65000"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_max_syn_backlog = 8192"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_max_tw_buckets = 5000"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_fastopen = 3"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_mem = 25600 51200 102400"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_rmem = 4096 87380 67108864"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_wmem = 4096 65536 67108864"
    check_and_add_line "/etc/sysctl.conf" "net.ipv4.tcp_mtu_probing = 1"
    
    echo "Optimization of Parameters Done."

    read -rp "Reboot Your System Now? (y/n): " menu_num
    case $menu_num in
        Y | y) clear ; reboot ;;
        N | n) clear ;;
        *) clear ; reboot ;;
    esac
}

display_banner
install_bbr
optimize_parameters
rm -f /root/tcp-bbr.sh
