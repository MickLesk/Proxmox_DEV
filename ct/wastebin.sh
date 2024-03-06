#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/tteck/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/matze/wastebin


function header_info {
clear
cat <<"EOF"
 _       __           __       __    _     
| |     / /___ ______/ /____  / /_  (_)___ 
| | /| / / __ `/ ___/ __/ _ \/ __ \/ / __ \
| |/ |/ / /_/ (__  ) /_/  __/ /_/ / / / / /
|__/|__/\__,_/____/\__/\___/_.___/_/_/ /_/ 
                                            
EOF
}
header_info
echo -e "Loading..."
APP="Wastebin"
var_disk="4"
var_cpu="4"
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
if [[ ! -d /opt/wastebin ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
if (( $(df /boot | awk 'NR==2{gsub("%","",$5); print $5}') > 80 )); then
  read -r -p "Warning: Storage is dangerously low, continue anyway? <y/N> " prompt
  [[ ${prompt,,} =~ ^(y|yes)$ ]] || exit
fi
msg_info "Updating ${APP} LXC"

cd /opt/wastebin && git_output=$(git pull)
if [[ $git_output == *"Already up to date."* ]]; then
    msg_error "There is currently no update available."
    exit 0
else
	systemctl stop wastebin
    cd /opt/wastebin
    cargo update
    cargo run --release
	systemctl start wastebin
    msg_ok "Updated Successfully"
fi
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
         ${BL}http://${IP}:8088${CL} \n"
