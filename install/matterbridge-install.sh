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
  unzip \
  build-essential \
  curl \
  sudo \
  git \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Install NodeJS / NPM"
$STD curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
$STD apt install -y nodejs 
msg_ok "Installed NodeJS / NPM"

msg_info "Install Matterbridge" 
RELEASE=$(curl -s https://api.github.com/repos/Luligu/matterbridge/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
$STD wget -q "https://github.com/Luligu/matterbridge/archive/refs/tags/${RELEASE}.zip"
$STD unzip -q ${RELEASE}.zip
mv matterbridge-${RELEASE} /opt/matterbridge
rm -R ${RELEASE}.zip 
msg_ok "Installed Matterbridge"

msg_info "Creating Service"
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
systemctl enable -q --now matterbridge.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
