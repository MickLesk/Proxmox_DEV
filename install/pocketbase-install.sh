#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/diced/zipline

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Pocketbase (Patience)"
mkdir -p /opt/pocketbase
cd /opt/pocketbase
RELEASE=$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${RELEASE}/pocketbase_${RELEASE}_linux_amd64.zip"
unzip -q pocketbase_${RELEASE}_linux_amd64.zip
ln -s /opt/pocketbase/pocketbase /usr/local/bin/pocketbase
chmod +x /opt/pocketbase/pocketbase
rm -R pocketbase_${RELEASE}_linux_amd64.zip
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Installed Pocketbase"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/pocketbase.service
[Unit]
Description=PocketBase Service
After=network.target

[Service]
WorkingDirectory=/opt
ExecStart=/opt/pocketbase/pocketbase serve --http 0.0.0.0:8090
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now pocketbase.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"