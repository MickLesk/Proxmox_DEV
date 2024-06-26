#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/metabase/metabase


function header_info {
clear
cat <<"EOF"
    __  ___     __        __                  
   /  |/  /__  / /_____ _/ /_  ____ _________ 
  / /|_/ / _ \/ __/ __ `/ __ \/ __ `/ ___/ _ \
 / /  / /  __/ /_/ /_/ / /_/ / /_/ (__  )  __/
/_/  /_/\___/\__/\__,_/_.___/\__,_/____/\___/ 
                                                                   
EOF
}
header_info
echo -e "Loading..."
APP="Metabase"
var_disk="5"
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
if [[ ! -d /opt/metabase ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
if (( $(df /boot | awk 'NR==2{gsub("%","",$5); print $5}') > 80 )); then
  read -r -p "Warning: Storage is dangerously low, continue anyway? <y/N> " prompt
  [[ ${prompt,,} =~ ^(y|yes)$ ]] || exit
fi
msg_info "Stopping ErsatzTV"
systemctl stop metabase
msg_ok "Stopped ErsatzTV"

msg_info "Updating ErsatzTV"
RELEASE=$(curl -s https://api.github.com/repos/ErsatzTV/ErsatzTV/releases | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
LATEST_RELEASE=$(echo $RELEASE | awk '{print $1}')
cd /opt
if [ -d ErsatzTV_bak ]; then
  rm -rf ErsatzTV_bak
fi
mv ErsatzTV ErsatzTV_bak
wget -q --no-check-certificate "https://github.com/ErsatzTV/ErsatzTV/releases/download/${LATEST_RELEASE}/ErsatzTV-${LATEST_RELEASE}-linux-x64.tar.gz"
tar -xf ErsatzTV-${LATEST_RELEASE}-linux-x64.tar.gz 
mv ErsatzTV-${LATEST_RELEASE}-linux-x64 ErsatzTV
msg_ok "Updated ErsatzTV"

msg_info "Starting ErsatzTV"
systemctl start ersatzTV
msg_ok "Started ErsatzTV"

msg_info "Cleaning Up"
cd /opt
rm -R ErsatzTV-${LATEST_RELEASE}-linux-x64.tar.gz
rm -R ErsatzTV_bak 
msg_ok "Cleaned"
msg_ok "Updated Successfully"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8409${CL} \n"
