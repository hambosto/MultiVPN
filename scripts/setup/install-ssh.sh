#!/bin/bash

BASE_URL="https://raw.githubusercontent.com/hambosto/MultiVPN/main"
SCRIPTS_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"
SCRIPTS=("openssh-wss.py" "dropbear-wss.py" "stunnel-wss.py")
SERVICES=("openssh-wss.service" "dropbear-wss.service" "stunnel-wss.service")

download_and_install() {
    local file_name="$1"
    wget -qO "$SCRIPTS_DIR/$file_name" "$BASE_URL/scripts/ssh/$file_name"
    chmod +x "$SCRIPTS_DIR/$file_name"
}

download_and_install_services() {
    local service_name="$1"
    wget -qO "$SERVICE_DIR/$service_name" "$BASE_URL/config/services/$service_name"
}

# Download and install scripts
for script in "${SCRIPTS[@]}"; do
    download_and_install "$script"
done

# Download and install systemd service unit files
for service in "${SERVICES[@]}"; do
    download_and_install_services "$service"
done

# Reload systemd and enable/restart services
systemctl daemon-reload

for service in "${SERVICES[@]}"; do
    systemctl enable "$service"
    systemctl restart "$service"
done
