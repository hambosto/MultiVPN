#!/bin/bash

# Function to download and set executable permissions for a script
download_and_chmod() {
    local script_url="$1"
    local destination="$2"

    echo "Downloading $destination..."
    if wget -qO "$destination" "$script_url"; then
        echo "Download successful."
        chmod +x "$destination"
    else
        echo "Error: Unable to download the script from $script_url."
        exit 1
    fi
}

# Download and set permissions for proxy3.js
download_and_chmod "https://raw.githubusercontent.com/hambosto/MultiVPN/main/bin/proxy3.js" "/usr/local/bin/proxy3.js"

# Download Dropbear WebSocket service file
dropbear_service_url="https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/dropbear-websocket.service"
dropbear_service_destination="/etc/systemd/system/dropbear-websocket.service"
download_and_chmod "$dropbear_service_url" "$dropbear_service_destination"

# Reload systemd and restart the Dropbear WebSocket service
systemctl daemon-reload
systemctl enable dropbear-websocket.service
systemctl start dropbear-websocket.service
systemctl restart dropbear-websocket.service

echo "Installation completed successfully!"
