#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD dnf install -y curl &>/dev/null
$STD dnf install -y sudo &>/dev/null
$STD dnf install -y mc &>/dev/null
msg_ok "Installed Dependencies"

motd_ssh
customize

msg_info "Cleaning up"
$STD dnf -y autoremove &>/dev/null
$STD dnf -y clean all &>/dev/null
msg_ok "Cleaned"