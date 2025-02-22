#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    ___    __                __    _                 
   /   |  / /___ ___  ____ _/ /   (_)___  __  ___  __
  / /| | / / __ `__ \/ __ `/ /   / / __ \/ / / / |/_/
 / ___ |/ / / / / / / /_/ / /___/ / / / / /_/ />  <  
/_/  |_/_/_/ /_/ /_/\__,_/_____/_/_/ /_/\__,_/_/|_|  
                                                     
EOF
}
header_info
echo -e "Loading..."
APP="AlmaLinux"
var_disk="2"
var_cpu="1"
var_ram="512"
var_os="almalinux"
var_version="9"
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
if [[ ! -d /var ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating $APP LXC"
dnf check-update &>/dev/null
dnf -y update &>/dev/null
msg_ok "Updated $APP LXC"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
