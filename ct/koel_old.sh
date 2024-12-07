#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 communtiy-scripts ORG
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

## Old App Default Values
## For Information: Only APP needed, TAGS can be removed to
## 125 Lines | 2920 Chars (with all comments) started ad line 11 
function header_info {
clear
cat <<"EOF"
    __ __           __
   / //_/___  ___  / /
  / ,< / __ \/ _ \/ / 
 / /| / /_/ /  __/ /  
/_/ |_\____/\___/_/   
                           
EOF
}
header_info
echo -e "Loading..."
APP="Koel"
var_disk="10"
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
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/koel ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -s https://api.github.com/repos/koel/koel/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
  if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_info "Stopping ${APP} Service"
    systemctl stop nginx
    msg_ok "Stopped ${APP} Service"

    msg_info "Updating ${APP} to v${RELEASE}"
	cd /opt
	wget -q https://github.com/koel/koel/releases/download/${RELEASE}/koel-${RELEASE}.zip
	unzip -q koel-${RELEASE}.zip
	cd /opt/koel
	composer update --no-interaction >/dev/null 2>&1
	composer install --no-interaction >/dev/null 2>&1
	php artisan migrate --force >/dev/null 2>&1
	php artisan cache:clear >/dev/null 2>&1
	php artisan config:clear >/dev/null 2>&1
	php artisan view:clear >/dev/null 2>&1
	php artisan koel:init --no-interaction >/dev/null 2>&1
    msg_ok "Updated ${APP} to v${RELEASE}"

    msg_info "Starting ${APP} Service"
    systemctl start nginx
	msg_ok "Started ${APP} Service"
	
    msg_info "Cleaning up"
    rm -rf /opt/koel-${RELEASE}.zip
    msg_ok "Cleaned"
    msg_ok "Updated Successfully!\n"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN} ${APP} setup has been successfully initialized!${CL}\n"
echo -e "${INFO}${YW} Access it using the following URL:${CL}\n"
echo -e "${TAB}${BGN}http://${IP}:6767${CL}\n"

