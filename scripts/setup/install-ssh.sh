#!/bin/bash

wget -qO /usr/local/bin/openssh-wss https://raw.githubusercontent.com/hambosto/MultiVPN/main/scripts/ssh/openssh-wss.py
chmod +x /usr/local/bin/openssh-wss

wget -qO /etc/systemd/system/openssh-wss.service https://raw.githubusercontent.com/hambosto/MultiVPN/main/config/services/openssh-wss.service

systemctl daemon-reload
systemctl enable openssh-wss
systemctl restart openssh-wss
