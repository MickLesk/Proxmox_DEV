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
   _____       _ ________           __ 
  / ___/____  (_) __/ __/___  ___  / /_
  \__ \/ __ \/ / /_/ /_/ __ \/ _ \/ __/
 ___/ / / / / / __/ __/ / / /  __/ /_  
/____/_/ /_/_/_/ /_/ /_/ /_/\___/\__/  
                                                                
EOF
}
header_info
echo -e "Loading..."
APP="Sniffnet"
var_disk="10"
var_cpu="4"
var_ram="4096"
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
if [[ ! -d /opt/sniffnet ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
if (( $(df /boot | awk 'NR==2{gsub("%","",$5); print $5}') > 80 )); then
  read -r -p "Warning: Storage is dangerously low, continue anyway? <y/N> " prompt
  [[ ${prompt,,} =~ ^(y|yes)$ ]] || exit
fi
msg_info "Stopping Sniffnet"
systemctl stop Sniffnet
msg_ok "Stopped Sniffnet"

msg_info "Updating Sniffnet"
RELEASE=$(curl -s https://api.github.com/repos/GyulyVGC/sniffnet/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }') &>/dev/null
cd /opt
if [ -d sniffnet_bak ]; then
  rm -rf sniffnet_bak
fi
mv sniffnet sniffnet_bak
wget -q --no-check-certificate "https://codeload.github.com/GyulyVGC/sniffnet/zip/refs/tags/${RELEASE}"
unzip -q ${RELEASE} &>/dev/null
CLEAN_RELEASE=$(echo "$RELEASE" | sed 's/^v//')
mv "sniffnet-${CLEAN_RELEASE}" /opt/sniffnet
cd /opt/sniffnet
cargo update -q 
cargo build -q --release
msg_ok "Updated Sniffnet"

msg_info "Starting Sniffnet"
systemctl start Sniffnet
msg_ok "Started Sniffnet"

msg_info "Cleaning Up"
cd /opt
rm -R ${RELEASE} 
rm -R sniffnet_bak 
msg_ok "Cleaned"
msg_ok "Updated Successfully"
exit
}

start
build_container
description

msg_info "Setting Container to Normal Resources"
pct set $CTID -cores 2
msg_ok "Set Container to Normal Resources"

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}${CL} \n"
