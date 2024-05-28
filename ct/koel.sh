#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

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
  RELEASE=$(curl -s https://api.github.com/repos/paperless-ngx/paperless-ngx/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')

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
    if [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
      msg_info "Stopping all Paperless-ngx Services"
      systemctl stop paperless-consumer paperless-webserver paperless-scheduler paperless-task-queue.service
      msg_ok "Stopped all Paperless-ngx Services"

      msg_info "Updating to ${RELEASE}"
		cd /opt/koel
		git config --global --add safe.directory /opt/koel >/dev/null 2>&1
		git pull origin release >/dev/null 2>&1
		composer install --no-interaction --no-dev >/dev/null 2>&1
		php artisan migrate --force >/dev/null 2>&1
		php artisan cache:clear
		php artisan config:clear
		php artisan view:clear
      msg_ok "Updated to ${RELEASE}"

      msg_info "Cleaning up"
      cd ~
      rm paperless-ngx-$RELEASE.tar.xz
      rm -rf paperless-ngx
      msg_ok "Cleaned"

      msg_info "Starting all Paperless-ngx Services"
      systemctl start paperless-consumer paperless-webserver paperless-scheduler paperless-task-queue.service
      sleep 1
      msg_ok "Started all Paperless-ngx Services"
      msg_ok "Updated Successfully!\n"
    else
      msg_ok "No update required. ${APP} is already at ${RELEASE}"
    fi
    exit
  fi
  if [ "$UPD" == "2" ]; then
    cat paperless.creds
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
