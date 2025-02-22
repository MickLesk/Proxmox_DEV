#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    ____                        __           __                         _ __
   / __ \____  __  ______  ____/ /______  __/ /_  ___  ____ ___  ____ _(_) /
  / /_/ / __ \/ / / / __ \/ __  / ___/ / / / __ \/ _ \/ __ `__ \/ __ `/ / / 
 / _, _/ /_/ / /_/ / / / / /_/ / /__/ /_/ / /_/ /  __/ / / / / / /_/ / / /  
/_/ |_|\____/\__,_/_/ /_/\__,_/\___/\__,_/_.___/\___/_/ /_/ /_/\__,_/_/_/   
                                                                            
EOF
}
header_info
echo -e "Loading..."
APP="Roundcubemail"
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
  VERB="yes"
  echo_default
}

function update_script() {
header_info
if [[ ! -d /opt/roundcubemail ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
if (( $(df /boot | awk 'NR==2{gsub("%","",$5); print $5}') > 80 )); then
  read -r -p "Warning: Storage is dangerously low, continue anyway? <y/N> " prompt
  [[ ${prompt,,} =~ ^(y|yes)$ ]] || exit
fi
RELEASE=$(curl -s https://api.github.com/repos/roundcube/roundcubemail/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
  msg_info "Updating ${APP} to ${RELEASE}"
  cd /opt
  wget -q "https://github.com/roundcube/roundcubemail/releases/download/${RELEASE}/roundcubemail-${RELEASE}-complete.tar.gz"
  tar -xf roundcubemail-${RELEASE}-complete.tar.gz
  mv roundcubemail-${RELEASE} /opt/roundcubemail
  cd /opt/roundcubemail
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev
  chown -R www-data:www-data temp/ logs/
  msg_ok "Updated ${APP}"

  msg_info "Reload Apache2"
  systemctl reload apache2
  msg_ok "Apache2 Reloaded"

  msg_info "Cleaning Up"
  rm -rf /opt/roundcubemail-${RELEASE}-complete.tar.gz
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
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}/installer ${CL} \n"
