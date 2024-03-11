#!/bin/bash

display_banner() {
    clear
    curl -sS https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/banner
}

function check_vless() {
    clear

    users_file="/usr/local/etc/xray/users.db"
    access_log="/var/log/xray/access2.log"

    vless_accounts=($(jq -r '.vless[].user' "$users_file" | sort -u))

    if [[ ${#vless_accounts[@]} -eq 0 ]]; then
        echo "No vless accounts found in the configuration file."
        echo "---------------------------------------------------"
        echo ""
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu-vless
    fi

    echo "VLESS WEBSOCKET USERS"
    echo "---------------------------------------------------"

    for account in "${vless_accounts[@]}"; do
        if [[ -z "$account" ]]; then
            continue
        fi

        user_ips=$(grep -w "$account" "$access_log" | cut -d " " -f 3 | sed 's/tcp://g' | cut -d ":" -f 1 | sort -u)

        if [[ -z "$user_ips" ]]; then
            echo "User: $account - Offline"
        else
            echo "User: $account - IP Address: $user_ips"
        fi
    done

    echo "---------------------------------------------------"
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu-vless
}

function renew_vless() {
    clear

    users_file="/usr/local/etc/xray/users.db"
    client_count=$(jq -r '.vless | length' "$users_file")

    if [[ $client_count -eq 0 ]]; then
        echo "No existing VLESS clients found."
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu-vless
    fi

    echo "vless WEBSOCKET USERS"
    echo "---------------------------------------------------"

    jq -r '.vless | to_entries[] | "\(.key + 1) - \(.value.user) \(.value.expiry)"' "$users_file" | while read -r line; do echo "$line"; done
    echo ""
    echo "Press Enter to Go Back To Main"
    echo "---------------------------------------------------"

    read -rp "Select client: " client_number

    if [[ -z $client_number ]]; then
        clear
        menu-vless
    fi

    read -p "Expired (days): " expiration_days
    selected_index=$((client_number - 1))
    selected_user=$(jq -r --argjson index "$selected_index" '.vless[$index]' "$users_file")

    client_user=$(echo "$selected_user" | jq -r '.user')
    client_exp=$(echo "$selected_user" | jq -r '.expiry')
    current_date=$(date +%Y-%m-%d)
    expiration_timestamp=$(date -d "$client_exp" +%s)
    current_timestamp=$(date -d "$current_date" +%s)
    new_expiration=$(((expiration_timestamp - current_timestamp) / 86400 + expiration_days))
    new_exp_date=$(date -d "@$((current_timestamp + new_expiration * 86400))" +"%Y-%m-%d")

    echo "$(jq --argjson index "$selected_index" --arg new_exp_date "$new_exp_date" '.vless[$index].expiry = $new_exp_date' "$users_file")" >"$users_file"

    systemctl restart xray@vless-tls.service
    systemctl restart xray@vless-nontls.service
    service cron restart
    clear

    echo "VLESS WEBSOCKET RENEWAL"
    echo "---------------------------------------------------"
    echo "Client Name : $client_user"
    echo "Expired On  : $new_exp_date"
    echo "Status      : Renewed Successfully"
    echo "---------------------------------------------------"

    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu-vmess
}

function delete_vless() {
    clear

    users_file="/usr/local/etc/xray/users.db"
    config_tls="/usr/local/etc/xray/vless-tls.json"]
    config_nonetls="/usr/local/etc/xray/vless-nonetls.json"

    num_clients=$(jq -r '.vless | length' "$users_file")

    if [[ $num_clients -eq 0 ]]; then
        echo "No existing vless clients found."
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu-vless
    fi

    echo "VLESS WEBSOCKET USERS"
    echo "---------------------------------------------------"
    jq -r '.vless | to_entries[] | "\(.key + 1) - \(.value.user) \(.value.expiry)"' "$users_file" | while read -r line; do echo "$line"; done
    echo ""
    echo "Press Enter to Go Back To Main"
    echo "---------------------------------------------------"

    read -rp "Select client: " selected_client

    if [[ -z $selected_client ]]; then
        clear
        menu-vless
    fi

    selected_index=$((selected_client - 1))
    username=$(jq -r --argjson index "$selected_index" '.vless[$index].user' "$users_file")
    expiry_date=$(jq -r --argjson index "$selected_index" '.vless[$index].expiry' "$users_file")

    # Delete user from config.db
    echo "$(jq --argjson index "$selected_index" '.vless |= del(.[$index])' "$users_file")" >"$users_file"

    # Delete user from config.json
    echo "$(jq --arg username "$username" '.inbounds[0].settings.clients = (.inbounds[0].settings.clients | map(select(.email != $username)))' "$config_tls")" >"$config_tls"
    echo "$(jq --arg username "$username" '.inbounds[1].settings.clients = (.inbounds[1].settings.clients | map(select(.email != $username)))' "$config_nonetls")" >"$config_nonetls"

    # Uncomment the lines below if you want to restart services and delete files
    systemctl restart xray@vless-tls.service
    systemctl restart xray@vless-nontls.service

    clear

    echo "VLESS WEBSOCKET DELETION"
    echo "---------------------------------------------------"
    echo "Client Name : $username"
    echo "Expired On  : $expiry_date"
    echo "Status      : Deleted Successfully"
    echo "---------------------------------------------------"

    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu
}

function user_vless() {
    clear
    users_file="/usr/local/etc/xray/users.db"
    client_count=$(jq -r '.vless | length' "$users_file")

    if [[ ${client_count} == '0' ]]; then
        echo "No existing clients found."
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu-vless
    fi

    echo "VLESS WEBSOCKET"
    echo "---------------------------------------------------"
    jq -r '.vless | to_entries[] | "\(.key + 1) - \(.value.user) \(.value.expiry)"' "$users_file" | while read -r line; do echo "$line"; done
    echo ""
    echo "Press Enter to Go Back To Main"
    echo "---------------------------------------------------"

    read -rp "Select a client: " client_number

    if [ -z $client_number ]; then
        clear
        menu-vless
    fi

    selected_index=$((client_number - 1))
    username=$(jq -r --argjson index "$selected_index" '.vless[$index].user' "$users_file")
    client_uuid=$(jq -r --argjson index "$selected_index" '.vless[$index].uuid' "$users_file")
    expiration_date=$(jq -r --argjson index "$selected_index" '.vless[$index].expiry' "$users_file")

    tls_port="443"
    none_tls_port="80"
    domain=$(cat /usr/local/etc/xray/domain)
    today=$(date -d "0 days" +"%Y-%m-%d")

    vless_ws_tls="vless://${client_uuid}@${domain}:$tls_port?type=ws&encryption=none&security=tls&host=${domain}&path=/vless-tls&allowInsecure=1&sni=bug.com#${username}"
    vless_ws_non_tls="vless://${client_uuid}@${domain}:$none_tls_port?type=ws&encryption=none&security=none&host=${domain}&path=/vless-nontls#${username}"

    clear
    echo "VLESS WEBSOCKET"
    echo "---------------------------------------------------"
    echo "Remarks           : ${username}"
    echo "Created On        : $today"
    echo "Expired On        : $expiration_date"
    echo "Domain            : ${domain}"
    echo "Port TLS          : ${tls_port}"
    echo "Port None TLS     : ${none_tls_port}"
    echo "UUID              : ${client_uuid}"
    echo "Security          : Auto"
    echo "Network           : WS"
    echo "Path TLS          : /vless-tls"
    echo "Path None TLS     : /vless-nonetls"
    echo "---------------------------------------------------"
    echo "Link WS TLS       : ${vless_ws_tls}"
    echo "Link WS None TLS  : ${vless_ws_non_tls}"
    echo "---------------------------------------------------"

    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu
}

function add_vless() {
    clear

    domain=$(cat /usr/local/etc/xray/domain)
    users_file="/usr/local/etc/xray/users.db"

    config_tls="/usr/local/etc/xray/vless-tls.json"
    config_nonetls="/usr/local/etc/xray/vless-nonetls.json"

    read -rp "Username: " -e username
    existing_user=$(jq -r --arg username "$username" '.vless[] | select(.user == $username)' "$users_file")

    if [ -n "$existing_user" ]; then
        echo "Error: User already exists."
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu
    fi

    # Set expiration days
    read -p "Set expiration (days): " expiration_days
    expiration_days=${expiration_days:-1}

    # Set Bug
    read -p "Hostname [google.com]: " hostname
    hostname=${hostname:-"google.com"}

    echo -e "---------------------------------------------------"
    echo -e "1) wss://bug/path"
    echo -e "2) Host & SNI"
    echo -e "3) Reverse Proxy"
    echo -e ""
    echo -e "Press [ENTER] for Standard Config"
    echo -e "---------------------------------------------------"
    echo -e ""
    read -p "Input your choice: " format

    uuid=$(cat /proc/sys/kernel/random/uuid)
    expiration_date=$(date -d "$expiration_days days" +"%Y-%m-%d")
    today=$(date -d "0 days" +"%Y-%m-%d")

    echo $(jq --arg username "$username" --arg uuid "$uuid" --arg expiration_date "$expiration_date" '.vless += [{"user": $username, "uuid": $uuid, "expiry": $expiration_date}]' $users_file) > $users_file
    echo $(jq --arg username "$username" --arg uuid "$uuid" '.inbounds[0].settings.clients += [{"id": $uuid, "alterId": 0, "email": $username}]' $config_tls) > $config_tls
    echo $(jq --arg username "$username" --arg uuid "$uuid" '.inbounds[1].settings.clients += [{"id": $uuid, "alterId": 0, "email": $username}]' $config_nonetls) > $config_nonetls

    systemctl restart xray.service
    systemctl restart xray@vless-nonetls.service
    service cron restart

    tls_port="443"
    none_tls_port="80"

    # Check the chosen format
    case $format in
    1)
        vless_tls="vless://${uuid}@${hostname}:${tls_port}?type=ws&encryption=none&security=tls&host=${domain}&path=wss://${hostname}/vless-tls&allowInsecure=1&sni=${hostname}#${username}"
        vless_nonetls="vless://${uuid}@${domain}:${none_tls_port}?type=ws&encryption=none&security=none&host=${hostname}&path=/vless-nonetls#${username}"
        ;;
    2)
        vless_tls="vless://${uuid}@${domain}:${tls_port}?type=ws&encryption=none&security=tls&host=${hostname}&path=/vless-tls&allowInsecure=1&sni=${hostname}#${username}"
        vless_nonetls="vless://${uuid}@${domain}:${none_tls_port}?type=ws&encryption=none&security=none&host=${hostname}&path=/vless-nonetls#${username}"
        ;;
    3)
        vless_tls="vless://${uuid}@${hostname}:${tls_port}?type=ws&encryption=none&security=tls&host=${domain}&path=/vless-tls&allowInsecure=1&sni=${hostname}#${username}"
        vless_nonetls="vless://${uuid}@${hostname}:${none_tls_port}?type=ws&encryption=none&security=none&host=${domain}&path=/vless-nonetls#${username}"
        ;;
    *)
        vless_tls="vless://${uuid}@${domain}:${tls_port}?type=ws&encryption=none&security=tls&host=${hostname}&path=/vlessWsTLS&allowInsecure=1&sni=${hostname}#${username}"
        vless_nonetls="vless://${uuid}@${domain}:${none_tls_port}?type=ws&encryption=none&security=none&host=${hostname}&path=/vless-nonetls#${username}"
        ;;
    esac

    # Display information
    clear
    echo "---------------------------------------------------"
    echo "Remarks           : $username"
    echo "Created On        : $today"
    echo "Expired On        : $expiration_date"
    echo "Domain            : $domain"
    echo "Port TLS          : 443"
    echo "Port None TLS     : 80"
    echo "UUID              : $uuid"
    echo "Security          : Auto"
    echo "Network           : WS"
    echo "Path TLS          : /vless-tls"
    echo "Path None TLS     : /vless-nonetls"
    echo "---------------------------------------------------"
    echo "Link WS TLS       : $vless_tls"
    echo ""
    echo "Link WS None TLS  : $vless_nonetls"
    echo "---------------------------------------------------"
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu-vless
}

display_banner
echo "---------------------------------------------------"
echo "1. Create VLess"
echo "2. Delete VLess"
echo "3. Renew VLess"
echo "4. Check Config"
echo "5. Users Online"
echo "0. Go Back"
echo ""
read -p "Select menu: " menu
echo "---------------------------------------------------"

case $menu in
1)
    clear
    add_vless
    ;;
2)
    clear
    delete_vless
    ;;
3)
    clear
    renew_vless
    ;;
4)
    clear
    user_vless
    ;;
5)
    clear
    check_vless
    ;;
0)
    clear
    menu
    ;;
*)
    clear
    menu-vless
    ;;
esac

