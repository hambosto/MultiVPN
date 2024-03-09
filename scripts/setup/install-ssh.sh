#!/bin/bash

# wget -O /usr/local/bin/openssh-websocket https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/ssh/openssh-websocket.py
wget -O /usr/local/bin/dropbear-websocket https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/ssh/dropbear-websocket.py
wget -O /usr/local/bin/stunnel-websocket https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/ssh/stunnel-websocket.py

# chmod +x /usr/local/bin/openssh-websocket
chmod +x /usr/local/bin/dropbear-websocket
chmod +x /usr/local/bin/stunnel-websocket

# wget -qO /etc/systemd/system/openssh-websocket.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/openssh-websocket.service
wget -qO /etc/systemd/system/dropbear-websocket.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/dropbear-websocket.service
wget -qO /etc/systemd/system/stunnel-websocket.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/stunnel-websocket.service

systemctl daemon-reload

# systemctl enable openssh-websocket.service
# systemctl start openssh-websocket.service
# systemctl restart openssh-websocket.service

systemctl enable dropbear-websocket.service
systemctl start dropbear-websocket.service
systemctl restart dropbear-websocket.service

systemctl enable stunnel-websocket.service
systemctl start stunnel-websocket.service
systemctl restart stunnel-websocket.service
