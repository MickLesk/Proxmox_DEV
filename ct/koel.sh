#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 communtiy-scripts ORG
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

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
  if [[ ! -d /opt/koel ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -s https://api.github.com/repos/koel/koel/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')

  UPD=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "SUPPORT" --radiolist --cancel-button Exit-Script "Spacebar = Select" 11 58 2 \
    "1" "Update Koel to $RELEASE" ON \
    "2" "Add Spotify Credentials" OFF \
	"3" "Add LastFM Credentials" OFF \
	"4" "Add YouTube Credentials" OFF \
	"5" "Add CDN" OFF \
	"6" "Add Amazon S3 Credentials" OFF \
    3>&1 1>&2 2>&3)
  header_info
  if [ "$UPD" == "1" ]; then
    if [[ "${RELEASE}" != "$(cat /opt/koel/.version)" ]] || [[ ! -f /opt/koel/.version ]]; then
      msg_info "Stopping Koel NGINX Service"
      systemctl stop nginx
      msg_ok "Stopped NGINX Service"

      msg_info "Updating to ${RELEASE}"
		cd /opt
		wget https://github.com/koel/koel/releases/download/${RELEASE}/koel-${RELEASE}.zip >/dev/null 2>&1
		unzip -q koel-${RELEASE}.zip >/dev/null 2>&1
		cd /opt/koel
		composer update --no-interaction >/dev/null 2>&1
		composer install --no-interaction >/dev/null 2>&1
		php artisan migrate --force >/dev/null 2>&1
		php artisan cache:clear >/dev/null 2>&1
		php artisan config:clear >/dev/null 2>&1
		php artisan view:clear >/dev/null 2>&1
		php artisan koel:init --no-interaction >/dev/null 2>&1
      msg_ok "Updated to ${RELEASE}"

      msg_info "Cleaning up"
      cd ~
      rm /opt/koel-${RELEASE}.zip
      msg_ok "Cleaned"

      msg_info "Starting NGINX Service"
      systemctl start nginx
      sleep 1
      msg_ok "Started NGINX Service"
      msg_ok "Updated Successfully!\n"
    else
      msg_ok "No update required. ${APP} is already at ${RELEASE}"
    fi
    exit
  fi
  if [ "$UPD" == "2" ]; then
    exit
  fi
}

start
build_container
description

msg_info "Setting Container to Normal Resources"
pct set $CTID -cores 2
msg_ok "Set Container to Normal Resources"

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:6767${CL} \n"
