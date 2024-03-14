#!/bin/bash

display_banner() {
    curl -sS https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/banner
}

function check_vmess() {
    clear

    users_file="/usr/local/etc/xray/users.db"
    access_log="/var/log/xray/access.log"

    vmess_accounts=( $(jq -r '.vmess[].user' "$users_file" | sort -u) )

    if [[ ${#vmess_accounts[@]} -eq 0 ]]; then
        echo "No VMESS accounts found in the configuration file."
        echo "---------------------------------------------------"
        echo ""
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu_vmess
    fi

    echo "VMESS WEBSOCKET USERS"
    echo "---------------------------------------------------"

    for account in "${vmess_accounts[@]}"
    do
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
    menu-vmess
}

function renew_vmess() {
    clear

    users_file="/usr/local/etc/xray/users.db"
    client_count=$(jq -r '.vmess | length' "$users_file")

    if [[ $client_count -eq 0 ]]; then
        echo "No existing VMESS clients found."
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu-vmess
    fi

    echo "VMESS WEBSOCKET USERS"
    echo "---------------------------------------------------"

    jq -r '.vmess | to_entries[] | "\(.key + 1) - \(.value.user) \(.value.expiry)"' "$users_file" | while read -r line; do echo "$line"; done
    echo ""
    echo "Press Enter to Go Back To Main"
    echo "---------------------------------------------------"

    read -rp "Select client: " client_number
    
    if [[ -z $client_number ]]; then
        clear
        menu-vmess
    fi

    read -r -p "Expired (days): " expiration_days
    selected_index=$((client_number - 1))
    selected_user=$(jq -r --argjson index "$selected_index" '.vmess[$index]' "$users_file")

    client_user=$(echo "$selected_user" | jq -r '.user')
    client_exp=$(echo "$selected_user" | jq -r '.expiry')
    current_date=$(date +%Y-%m-%d)
    expiration_timestamp=$(date -d "$client_exp" +%s)
    current_timestamp=$(date -d "$current_date" +%s)
    new_expiration=$(( (expiration_timestamp - current_timestamp) / 86400 + expiration_days ))
    new_exp_date=$(date -d "@$((current_timestamp + new_expiration * 86400))" +"%Y-%m-%d")

    echo "$(jq --argjson index "$selected_index" --arg new_exp_date "$new_exp_date" '.vmess[$index].expiry = $new_exp_date' "$users_file")" > "$users_file" 

    
    systemctl restart xray.service
    service cron restart
    clear

    echo "VMESS WEBSOCKET RENEWAL"
    echo "---------------------------------------------------"
    echo "Client Name : $client_user"
    echo "Expired On  : $new_exp_date"
    echo "Status      : Renewed Successfully"
    echo "---------------------------------------------------"

    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu-vmess
}

function delete_vmess() {
    clear
    
    users_file="/usr/local/etc/xray/users.db"
    xray_config="/usr/local/etc/xray/config.json"

    num_clients=$(jq -r '.vmess | length' "$users_file")

    if [[ $num_clients -eq 0 ]]; then
        echo "No existing VMESS clients found."
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu-vmess
    fi

    echo "VMESS WEBSOCKET USERS"
    echo "---------------------------------------------------"
    jq -r '.vmess | to_entries[] | "\(.key + 1) - \(.value.user) \(.value.expiry)"' "$users_file" | while read -r line; do echo "$line"; done
    echo ""
    echo "Press Enter to Go Back To Main"
    echo "---------------------------------------------------"

    read -rp "Select client: " selected_client

    if [[ -z $selected_client ]]; then
        clear
        menu-vmess
    fi

    selected_index=$((selected_client - 1))
    username=$(jq -r --argjson index "$selected_index" '.vmess[$index].user' "$users_file")
    expiry_date=$(jq -r --argjson index "$selected_index" '.vmess[$index].expiry' "$users_file")

    # Delete user from config.db
    echo "$(jq --argjson index "$selected_index" '.vmess |= del(.[$index])' "$users_file")" > "$users_file"

    # Delete user from config.json
    echo "$(jq --arg username "$username" '.inbounds[1].settings.clients = (.inbounds[1].settings.clients | map(select(.email != $username)))' "$xray_config")" > "$xray_config"
    echo "$(jq --arg username "$username" '.inbounds[2].settings.clients = (.inbounds[2].settings.clients | map(select(.email != $username)))' "$xray_config")" > "$xray_config"

    # Uncomment the lines below if you want to restart services and delete files
    systemctl restart xray.service

    rm -f "/usr/local/etc/xray/$username-tls.json"
    rm -f "/usr/local/etc/xray/$username-nonetls.json"

    clear

    echo "VMESS WEBSOCKET DELETION"
    echo "---------------------------------------------------"
    echo "Client Name : $username"
    echo "Expired On  : $expiry_date"
    echo "Status      : Deleted Successfully"
    echo "---------------------------------------------------"

    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu-vmess
}

function user_vmess() {
    clear
    users_file="/usr/local/etc/xray/users.db"
    client_count=$(jq -r '.vmess | length' "$users_file")

    if [[ ${client_count} == '0' ]]; then
        echo "No existing clients found."
        read -n 1 -s -r -p "Press any key to go back to the menu"
        menu-vmess
    fi

    echo "VMESS WEBSOCKET"
    echo "---------------------------------------------------"
    jq -r '.vmess | to_entries[] | "\(.key + 1) - \(.value.user) \(.value.expiry)"' "$users_file" | while read -r line; do echo "$line"; done
    echo ""
    echo "Press Enter to Go Back To Main"
    echo "---------------------------------------------------"

    read -rp "Select a client: " client_number

    if [ -z "$client_number" ]; then
        clear
        menu-vmess
    fi

    selected_index=$((client_number - 1))
    username=$(jq -r --argjson index "$selected_index" '.vmess[$index].user' "$users_file")
    client_uuid=$(jq -r --argjson index "$selected_index" '.vmess[$index].uuid' "$users_file")
    expiration_date=$(jq -r --argjson index "$selected_index" '.vmess[$index].expiry' "$users_file")

    tls_port="443"
    none_tls_port="80"
    domain=$(cat /usr/local/etc/xray/domain)
    today=$(date -d "0 days" +"%Y-%m-%d")
    link_ws_tls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-tls.json)"
    link_ws_none_tls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-nonetls.json)"

    # clear
    echo "VMESS WEBSOCKET"
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
    echo "Path TLS          : /vmess-tls"
    echo "Path None TLS     : /vmess-nonetls"
    echo "---------------------------------------------------"
    echo "Link WS TLS       : ${link_ws_tls}"
    echo "Link WS None TLS  : ${link_ws_none_tls}"
    echo "---------------------------------------------------"
    
    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu-vmess
}

function add_vmess() {
  # clear

  display_banner

  domain=$(cat /usr/local/etc/xray/domain)
  users_file="/usr/local/etc/xray/users.db"

  xray_config="/usr/local/etc/xray/config.json"

  read -rp "Username: " -e username
  existing_user=$(jq -r --arg username "$username" '.vmess[] | select(.user == $username)' "$users_file")

  if [ -n "$existing_user" ]; then
    echo "Error: User already exists."
    read -n 1 -s -r -p "Press any key to go back to the menu"
    menu-vmess
  fi

  # Set expiration days
  read -r -p "Set expiration (days): " expiration_days
  expiration_days=${expiration_days:-1}

  read -r -p "Destination Host [google.com]: " destination_host
  destination_host=${destination_host:-"google.com"}

  echo -e "---------------------------------------------------"
  echo -e "1) wss://destination_host/path"
  echo -e "2) Host & SNI"
  echo -e "3) Reverse Proxy"
  echo -e ""
  echo -e "Press [ENTER] for Standard Config"
  echo -e "---------------------------------------------------"
  echo -e ""
  read -r -p "Input your choice: " format

  uuid=$(cat /proc/sys/kernel/random/uuid)
  expiration_date=$(date -d "$expiration_days days" +"%Y-%m-%d")
  today=$(date -d "0 days" +"%Y-%m-%d")

  echo "$(jq --arg username "$username" --arg uuid "$uuid" --arg expiration_date "$expiration_date" '.vmess += [{"user": $username, "uuid": $uuid, "expiry": $expiration_date}]' "$users_file")" > "$users_file"

  echo "$(jq --arg username "$username" --arg uuid "$uuid" '.inbounds[1].settings.clients += [{"id": $uuid, "alterId": 0, "email": $username}]' "$xray_config")" > "$xray_config"
  echo "$(jq --arg username "$username" --arg uuid "$uuid" '.inbounds[2].settings.clients += [{"id": $uuid, "alterId": 0, "email": $username}]' "$xray_config")" > "$xray_config"

  
  systemctl restart xray.service
  service cron restart

  # Check the chosen format
  case $format in
    1)
      jq -n --arg username "$username" --arg destination_host "$destination_host" --arg domain "$domain" --arg uuid "$uuid" '{"v":"2","ps":$username,"add":$destination_host,"port":"443","id":$uuid,"aid":"0","net":"ws","path":"wss://\($destination_host)/vmess-tls","type":"none","host":$domain,"tls":"tls","sni":$destination_host}' > "/usr/local/etc/xray/$username-tls.json"
      jq -n --arg username "$username" --arg destination_host "$destination_host" --arg domain "$domain" --arg uuid "$uuid" '{"v":"2","ps":$username,"add":$destination_host,"port":"80","id":$uuid,"aid":"0","net":"ws","path":"/vmess-nonetls","type":"none","host":$domain,"tls":"none"}' > "/usr/local/etc/xray/$username-nonetls.json"
      vmess_tls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-tls.json)"
      vmess_nontls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-nonetls.json)"
      ;;
    2)
      jq -n --arg username "$username" --arg domain "$domain" --arg destination_host "$destination_host" --arg uuid "$uuid" '{"v":"2","ps":$username,"add":$domain,"port":"443","id":$uuid,"aid":"0","net":"ws","path":"/vmess-tls","type":"none","host":$destination_host,"tls":"tls","sni":$destination_host}' > "/usr/local/etc/xray/$username-tls.json"
      jq -n --arg username "$username" --arg domain "$domain" --arg destination_host "$destination_host" --arg uuid "$uuid" '{"v":"2","ps":$username,"add":$domain,"port":"80","id":$uuid,"aid":"0","net":"ws","path":"/vmess-nonetls","type":"none","host":$destination_host,"tls":"none"}' > "/usr/local/etc/xray/$username-nonetls.json"
      vmess_tls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-tls.json)"
      vmess_nontls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-nonetls.json)"
      ;;
    3)
      jq -n --arg username "$username" --arg destination_host "$destination_host" --arg domain "$domain" --arg uuid "$uuid" '{"v":"2","ps":$username,"add":$destination_host,"port":"443","id":$uuid,"aid":"0","net":"ws","path":"/vmess-tls","type":"none","host":$domain,"tls":"tls","sni":$destination_host}' > "/usr/local/etc/xray/$username-tls.json"
      jq -n --arg username "$username" --arg destination_host "$destination_host" --arg domain "$domain" --arg uuid "$uuid" '{"v":"2","ps":$username,"add":$destination_host,"port":"80","id":$uuid,"aid":"0","net":"ws","path":"/vmess-nonetls","type":"none","host":$domain,"tls":"none"}' > "/usr/local/etc/xray/$username-nonetls.json"
      vmess_tls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-tls.json)"
      vmess_nontls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-nonetls.json)"
      ;;
    *)
      jq -n --arg username "$username" --arg domain "$domain" --arg destination_host "$destination_host" --arg uuid "$uuid" '{"v":"2","ps":$username,"add":$domain,"port":"443","id":$uuid,"aid":"0","net":"ws","path":"/vmess-tls","type":"none","host":$destination_host,"tls":"tls","sni":$destination_host}' > "/usr/local/etc/xray/$username-tls.json"
      jq -n --arg username "$username" --arg domain "$domain" --arg destination_host "$destination_host" --arg uuid "$uuid" '{"v":"2","ps":$username,"add":$domain,"port":"80","id":$uuid,"aid":"0","net":"ws","path":"/vmess-nonetls","type":"none","host":$destination_host,"tls":"none"}' > "/usr/local/etc/xray/$username-nonetls.json"
      vmess_tls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-tls.json)"
      vmess_nontls="vmess://$(base64 -w 0 /usr/local/etc/xray/"$username"-nonetls.json)"
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
  echo "Path TLS          : /vmess-tls"
  echo "Path None TLS     : /vmess-nonetls"
  echo "---------------------------------------------------"
  echo "Link WS TLS       : $vmess_tls"
  echo ""
  echo "Link WS None TLS  : $vmess_nontls"
  echo "---------------------------------------------------"
  echo ""
  read -n 1 -s -r -p "Press any key to go back to the menu"
  menu-vmess
}


clear
display_banner

echo "---------------------------------------------------"
echo "1. Create Vmess"
echo "2. Delete Vmess"
echo "3. Renew Vmess"
echo "4. Check Config"
echo "5. Users Online"
echo "0. Go Back to Menu"
echo ""
read -r -p "Select menu: " menu
echo "---------------------------------------------------"

case $menu in
    1) clear ; add_vmess ;;
    2) clear ; delete_vmess ;;
    3) clear ; renew_vmess ;;
    4) clear ; user_vmess ;;
    5) clear ; check_vmess ;;
    *) clear ; menu ;;
esac
