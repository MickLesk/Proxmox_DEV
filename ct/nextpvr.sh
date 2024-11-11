#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://nextpvr.com/

function header_info {
clear
cat <<"EOF"
    _   __          __  ____ _    ______ 
   / | / /__  _  __/ /_/ __ \ |  / / __ \
  /  |/ / _ \| |/_/ __/ /_/ / | / / /_/ /
 / /|  /  __/>  </ /_/ ____/| |/ / _, _/ 
/_/ |_/\___/_/|_|\__/_/     |___/_/ |_|  
                                         
EOF
}
header_info
echo -e "Loading..."
APP="NextPVR"
var_disk="4"
var_cpu="1"
var_ram="1024"
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
if [[ ! -f /opt/nextpvr-helper.deb ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
if (( $(df /boot | awk 'NR==2{gsub("%","",$5); print $5}') > 80 )); then
  read -r -p "Warning: Storage is dangerously low, continue anyway? <y/N> " prompt
  [[ ${prompt,,} =~ ^(y|yes)$ ]] || exit
msg_info "Updating $APP"
systemctl stop nextpvr-server

sudo apt-get update >/dev/null 2>&1
sudo apt-get upgrade >/dev/null 2>&1
dpkg -i /opt/nextpvr-helper.deb >/dev/null 2>&1
 
systemctl start rdtc
msg_ok "Updated $APP"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8866${CL} \n"