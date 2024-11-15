#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
                         _____ __  _______ ______
  ____  ____  ___  ____ / ___// / / / ___// ____/
 / __ \/ __ \/ _ \/ __ \\__ \/ / / /\__ \/ __/   
/ /_/ / /_/ /  __/ / / /__/ / /_/ /___/ / /___   
\____/ .___/\___/_/ /_/____/\____//____/_____/   
    /_/                                          
	
EOF
}
header_info
echo -e "Loading..."
APP="openSUSE"
var_disk="2"
var_cpu="1"
var_ram="512"
var_os="opensuse"
var_version="15"
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
zypper refresh &>/dev/null
zypper update -y &>/dev/null
msg_ok "Updated $APP LXC"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
