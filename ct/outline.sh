#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2024 community-scripts ORG
# Author: Gerhard Burger (burgerga)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

## App Default Values
APP="Outline"
TAGS="team;management"
var_disk="5"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"
#var_verbose="yes"

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
if [[ ! -d /opt/outline ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
RELEASE=$(curl -s https://api.github.com/repos/outline/outline/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
  msg_info "Stopping ${APP}"
  systemctl stop outline
  msg_ok "Stopped ${APP}"

  msg_info "Updating ${APP} to ${RELEASE} (Patience)"
  cd /opt
  cp /opt/outline/.env /opt/.env
  mv /opt/outline /opt/outline_bak
  wget -q "https://github.com/outline/outline/archive/refs/tags/v${RELEASE}.zip"
  unzip -q v${RELEASE}.zip
  mv outline-${RELEASE} /opt/outline
  cd /opt/outline

  yarn install --no-optional --frozen-lockfile &>/dev/null
  yarn cache clean &>/dev/null
  yarn build &>/dev/null

  rm -rf ./node_modules
  yarn install --production=true --frozen-lockfile &>/dev/null
  yarn cache clean &>/dev/null

  mv /opt/.env /opt/outline/.env

  echo "${RELEASE}" >/opt/${APP}_version.txt
  msg_ok "Updated ${APP} to ${RELEASE}"

  msg_info "Starting ${APP}"
  systemctl start outline
  msg_ok "Started ${APP}"

  msg_info "Cleaning up"
  rm -rf /opt/v${RELEASE}.zip
  rm -rf /opt/outline_bak
  msg_ok "Cleaned"
  msg_ok "Updated Successfully"
else
  msg_ok "No update required.  ${APP} is already at ${RELEASE}."
fi
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
