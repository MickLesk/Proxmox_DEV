#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (Canbiz)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/getmaxun/maxun

# App Default Values
APP="Maxun"
var_tags="scraper"
var_disk="7"
var_cpu="2"
var_ram="3072"
var_os="debian"
var_version="12"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/maxun ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -s https://api.github.com/repos/getmaxun/maxun/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
  if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_info "Stopping Services"
    systemctl stop maxun minio redis
    msg_ok "Services Stopped"

    msg_info "Updating ${APP} to ${RELEASE}"
      
    #echo "${RELEASE}" >/opt/${APP}_version.txt
    msg_ok "Currently we don't support an Update for ${APP} and it should be updated via the user interface."

    msg_info "Update Dependencies" 
    
    msg_ok "Updated Dependencies"

    msg_info "Starting Services"
      systemctl start minio redis maxun
    msg_ok "Started Services"

    #msg_info "Cleaning Up"
    #rm -rf v${RELEASE}.zip
    #msg_ok "Cleaned"
    #msg_ok "Updated Successfully"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5173${CL}"