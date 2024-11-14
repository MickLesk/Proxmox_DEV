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
    __  ___      _____ ____    __ 
   /  |/  /_  __/ ___// __ \  / / 
  / /|_/ / / / /\__ \/ / / / / /  
 / /  / / /_/ /___/ / /_/ / / /___
/_/  /_/\__, //____/\___\_\/_____/
       /____/                     
EOF
}
header_info
echo -e "Loading..."
APP="nextpvr"
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
  VERB="yes"
  echo_default
}
function update_script() {
header_info
check_container_ressources
if [[ ! -f /opt/nextpvr-helper.deb ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating ${APP} LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated Successfully"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8866${CL} \n"
