#!/bin/bash

clear

clear_logs() {
    local log_files=("$@")

    for log in "${log_files[@]}"; do
        echo "$log clear"
        echo > "$log"
    done
}

# Find log files and clear them
log_files=( $(find /var/log/ -name '*.log' -o -name '*.err' -o -name 'mail.*') )
clear_logs "${log_files[@]}"

# Clear specific log files
declare -a specific_logs=(
    "/var/log/syslog"
    "/var/log/btmp"
    "/var/log/messages"
    "/var/log/debug"
)

clear_logs "${specific_logs[@]}"

# Log the action
echo "$(date): All Log Files Cleared Successfully" >> /root/clear_log
