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
$STD apt-get install -y sudo
$STD apt-get install -y gnupg2
$STD apt-get install -y mc
msg_ok "Installed Dependencies"

msg_info "Installing UrBackup"
curl -fsSL https://download.opensuse.org/repositories/home:uroni/Debian_12/Release.key | gpg --dearmor >/etc/apt/trusted.gpg.d/home_uroni.gpg
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/home_uroni.gpg] http://download.opensuse.org/repositories/home:/uroni/Debian_12/ /' >/etc/apt/sources.list.d/home:uroni.list
$STD sudo apt update
$STD sudo DEBIAN_FRONTEND=noninteractive apt install urbackup-server -y
msg_ok "Installed UrBackup"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"