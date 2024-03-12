#!/bin/bash

SYSCTL_CONF="/etc/sysctl.conf"
LOG_FILE="install_bbr.log"

_os_full() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

get_char() {
    SAVEDSTTY=$(stty -g)
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty "$SAVEDSTTY"
}

check_bbr_status() {
    local param
    param=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    [[ "${param}" == "bbr" ]]
}

sysctl_config() {
    sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
    sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
    echo "net.core.default_qdisc = fq" >> "$SYSCTL_CONF"
    echo "net.ipv4.tcp_congestion_control = bbr" >> "$SYSCTL_CONF"
    sysctl -p >/dev/null 2>&1
}

reboot_os() {
    echo
    echo "The system needs to reboot."
    read -rp "Do you want to restart the system? [y/n]" is_reboot
    if [[ "${is_reboot}" == "y" || "${is_reboot}" == "Y" ]]; then
        reboot
    else
        echo "Reboot has been canceled..."
        exit 0
    fi
}

install_bbr() {
    if check_bbr_status; then
        echo
        echo "TCP BBR has already been enabled. Nothing to do..."
        exit 0
    fi
    sysctl_config
    reboot_os
}

cur_dir="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root."
        exit 1
    fi
}

clear
echo "---------- System Information ----------"
echo " OS      : $(_os_full)"
echo " Arch    : $(uname -m) ($(getconf LONG_BIT) Bit)"
echo " Kernel  : $(uname -r)"
echo "----------------------------------------"
echo " Automatically enable TCP BBR script"
echo "----------------------------------------"
echo
echo "Press any key to start...or Press Ctrl+C to cancel"
char=$(get_char)

install_bbr 2>&1 | tee "${cur_dir}/${LOG_FILE}"
