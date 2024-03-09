#!/bin/bash

wget -qO /usr/local/bin/openssh-wss https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/ssh/openssh-wss.py
wget -qO /usr/local/bin/dropbear-wss https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/ssh/dropbear-wss.py
wget -qO /usr/local/bin/stunnel-wss https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/ssh/stunnel-wss.py

chmod +x /usr/local/bin/openssh-wss
chmod +x /usr/local/bin/dropbear-wss
chmod +x /usr/local/bin/stunnel-wss

wget -qO /etc/systemd/system/openssh-wss.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/openssh-wss.service
wget -qO /etc/systemd/system/dropbear-wss.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/dropbear-wss.service
wget -qO /etc/systemd/system/stunnel-wss.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/stunnel-wss.service

systemctl daemon-reload

systemctl enable openssh-wss
systemctl restart openssh-wss

systemctl enable dropbear-wss
systemctl restart dropbear-wss

systemctl enable stunnel-wss
systemctl restart stunnel-wss
