#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/matze/wastebin


function header_info {
clear
cat <<"EOF"
    __  ___      __  __                                 __ 
   /  |/  /___ _/ /_/ /____  _________ ___  ____  _____/ /_
  / /|_/ / __ `/ __/ __/ _ \/ ___/ __ `__ \/ __ \/ ___/ __/
 / /  / / /_/ / /_/ /_/  __/ /  / / / / / / /_/ (__  ) /_  
/_/  /_/\__,_/\__/\__/\___/_/  /_/ /_/ /_/\____/____/\__/  
                                                           
EOF
}
header_info
echo -e "Loading..."
APP="Mattermost"
var_disk="10"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
header_info
if [[ ! -d /opt/mattermost ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
RELEASE=$(curl -s https://api.github.com/repos/matze/wastebin/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
  msg_info "Stopping Wastebin"
  systemctl stop wastebin
  msg_ok "Wastebin Stopped"

  msg_info "Updating Wastebin"
  wget -q https://github.com/matze/wastebin/releases/download/${RELEASE}/wastebin_${RELEASE}_x86_64-unknown-linux-musl.tar.zst
  tar -xf wastebin_${RELEASE}_x86_64-unknown-linux-musl.tar.zst
  cp -f wastebin /opt/wastebin/
  chmod +x /opt/wastebin/wastebin
  echo "${RELEASE}" >/opt/${APP}_version.txt
  msg_ok "Updated Wastebin"

  msg_info "Starting Wastebin"
  systemctl start wastebin
  msg_ok "Started Wastebin"

  msg_info "Cleaning Up"
  rm -rf wastebin_${RELEASE}_x86_64-unknown-linux-musl.tar.zst
  msg_ok "Cleaned"
  msg_ok "Updated Successfully"
else
  msg_ok "No update required. ${APP} is already at ${RELEASE}"
fi
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8086${CL} \n"