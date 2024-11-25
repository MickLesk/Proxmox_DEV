#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://nextpvr.com/

function header_info {
clear
generate_app_name "NextPVR"
}
header_info

## App Default Values
APP="NextPVR"
var_disk="3"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"
var_verbose="yes"
base_settings

variables
color
catch_errors
echo_default

function update_script() {
header_info
check_container_storage
check_container_resources
if [[ ! -d /opt/nextpvr ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Stopping ${APP}"
systemctl stop nextpvr-server
msg_ok "Stopped ${APP}"

msg_info "Updating LXC packages"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated LXC packages"

msg_info "Updating ${APP}"
cd /opt
wget -q https://nextpvr.com/nextpvr-helper.deb
dpkg -i nextpvr-helper.deb &>/dev/null
msg_ok "Updated ${APP}"

msg_info "Starting ${APP}"
systemctl start nextpvr-server
msg_ok "Started ${APP}"

msg_info "Cleaning Up"
rm -rf /opt/nextpvr-helper.deb
msg_ok "Cleaned"
msg_ok "Updated Successfully"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8866${CL} \n"
