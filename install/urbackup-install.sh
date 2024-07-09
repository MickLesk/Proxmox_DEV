#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://www.urbackup.org/index.html

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sqlite3
$STD apt-get install -y libfuse2
$STD apt-get install -y sudo
$STD apt-get install -y mc
msg_ok "Installed Dependencies"

msg_info "Installing Urbackup"
VERSION=$(wget -q -O - https://hndl.urbackup.org/Server/latest/debian/bookworm/ | grep -oP 'urbackup-server_\K[\d\.]+(?=_amd64\.deb)' | head -1)
wget -q https://hndl.urbackup.org/Server/latest/debian/bookworm/urbackup-server_${VERSION}_amd64.deb 
$STD sudo dpkg -i --force-confdef urbackup-server_${VERSION}_amd64.deb
$STD sudo apt install -f
msg_ok "Installed Urbackup"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf urbackup-server_${VERSION}_amd64.deb
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"