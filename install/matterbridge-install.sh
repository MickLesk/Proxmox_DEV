#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/Luligu/matterbridge/

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  unzip \
  sudo \
  git \
  make \
  gnupg \
  ca-certificates \
  mc
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
msg_ok "Set up Node.js Repository"

msg_info "Installing Node.js"
$STD apt-get update
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Install Matterbridge" 
RELEASE=$(curl -s https://api.github.com/repos/Luligu/matterbridge/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q "https://github.com/Luligu/matterbridge/archive/refs/tags/${RELEASE}.zip"
unzip -q ${RELEASE}.zip
mv matterbridge-${RELEASE} /opt/matterbridge
rm -R ${RELEASE}.zip 
cd /opt/matterbridge
$STD npm ci
$STD npm run build
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt
msg_ok "Installed Matterbridge"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/matterbridge.service
[Unit]
Description=matterbridge
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/npm run start:bridge
WorkingDirectory=/opt/matterbridge
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=10s
TimeoutStopSec=30s
User=root
Environment=PATH=/usr/bin:/usr/local/bin:/opt/matterbridge/bin
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/matterbridge_child.service
[Unit]
Description=matterbridge - childbridge
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/npm run start:childbridge
WorkingDirectory=/opt/matterbridge
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=10s
TimeoutStopSec=30s
User=root
Environment=PATH=/usr/bin:/usr/local/bin:/opt/matterbridge/bin
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

choose_service() {
    local choice=$(whiptail --title "Choose Matterbridge Service" --radiolist \
    "Please choose your running option of matterbridge. This service enables the matterbridge, you can change this later manually." 15 60 2 \
    "1" "Matterbridge - Bridge" ON \
    "2" "Matterbridge - Childbridge" OFF 3>&1 1>&2 2>&3)
	
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then
        choice=1
    fi
    case $choice in
        1)
            systemctl enable -q --now matterbridge.service
            systemctl disable -q --now matterbridge_child.service
            msg_ok "Matterbridge - Bridge has been started."
            ;;
        2)
            systemctl enable -q --now matterbridge_child.service
            systemctl disable -q --now matterbridge.service
            msg_ok "Matterbridge - Childbridge has been started."
            ;;
        *)
            msg_error "Invalid choice. No service has been started."
            ;;
    esac
}

# Aufrufen der Auswahl-Funktion
choose_service

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
