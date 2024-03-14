#!/bin/bash

users_file="/usr/local/etc/xray/users.db"
xray_config="/usr/local/etc/xray/config.json"

current_date=$(date "+%Y-%m-%d")

remove_expired_users() {
    local user_type="$1"
    local filtered_data="$(jq --arg current_date "$current_date" --arg user_type "$user_type" '.[$user_type] | map(select(.expiry == $current_date))' "$users_file")"

    if [ -n "$filtered_data" ]; then
        echo $(jq --arg current_date "$current_date" --arg user_type "$user_type" '.[$user_type] |= map(select(.expiry != $current_date))' "$users_file") > "$users_file"

        local username="$(echo "$filtered_data" | jq -r '.[0].user')"
        local start_index=1
        local end_index=0
        
        case "$user_type" in
            "vmess") end_index=2 ;;
            "vless") start_index=3; end_index=4 ;;
            "trojan") start_index=5; end_index=6 ;;
        esac

        # Loop through the inbounds sections
        for ((i=start_index; i<=end_index; i++)); do
            echo $(jq --arg username "$username" --argjson index "$i" '.inbounds[$index].settings.clients = (.inbounds[$index].settings.clients | map(select(.email != $username)))' "$xray_config") > "$xray_config"
        done
        systemctl restart xray.service
    fi
}

# Remove expired users for vmess
remove_expired_users "vmess"

# Remove expired users for vless
remove_expired_users "vless"

# Remove expired users for trojan
remove_expired_users "trojan"
