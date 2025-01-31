#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

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

msg_info "Installing qbittorrent-nox"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/userdocs/qbittorrent-nox-static/releases/latest | grep -oP '"tag_name": "\K[^"]+' | sed 's/release-//')
wget -q https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${RELEASE}/x86_64-qbittorrent-nox
mv x86_64-qbittorrent-nox /usr/bin/qbittorrent-nox
chmod +x /usr/bin/qbittorrent-nox
mkdir -p /root/.config/qBittorrent/
cat <<EOF >/root/.config/qBittorrent/qBittorrent.conf
[Preferences]
WebUI\Password_PBKDF2="@ByteArray(amjeuVrF3xRbgzqWQmes5A==:XK3/Ra9jUmqUc4RwzCtrhrkQIcYczBl90DJw2rT8DFVTss4nxpoRhvyxhCf87ahVE3SzD8K9lyPdpyUCfmVsUg==)"
WebUI\Port=8090
WebUI\UseUPnP=false
WebUI\Username=admin
EOF
echo "${RELEASE}" >"/opt/qbittorrent-nox_version.txt"
msg_ok "Installed qbittorrent-nox"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/qbittorrent-nox.service
[Unit]
Description=qBittorrent client
After=network.target

[Service]
User=root
Environment="HOME=/root"
ExecStart=/usr/bin/qbittorrent-nox
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now qbittorrent-nox
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
