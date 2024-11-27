#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://nextpvr.com/

## App Default Values
APP="Hoarder"
TAGS="bookmark;links"
var_disk="11"
var_cpu="4"
var_ram="4096"
var_os="debian"
var_version="12"
var_verbose="yes"

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
if [[ ! -d /opt/hoarder ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
RELEASE=$(curl -s https://api.github.com/repos/hoarder-app/hoarder/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
PREV_VERSION=$(cat /opt/${APP}_version.txt)
if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "${PREV_VERSION}" ]]; then
  msg_info "Stopping ${APP} Service"
  systemctl stop hoarder-web hoarder-workers hoarder-browser hoarder.target
  msg_ok "Stopped ${APP} Services"
  msg_info "Updating ${APP} to ${RELEASE}"
  cd /opt
  mv /opt/hoarder /opt/hoarder_bak
  wget -q "https://github.com/hoarder-app/hoarder/archive/refs/tags/v${RELEASE}.zip"
  unzip -q v${RELEASE}.zip
  mv hoarder-${RELEASE} /opt/hoarder
  cd hoarder/apps/web
  pnpm install --frozen-lockfile >/dev/null 2>&1
  cd ../workers
  pnpm install --frozen-lockfile >/dev/null 2>&1
  cd ../web
  export NEXT_TELEMETRY_DISABLED=1
  pnpm exec next build --experimental-build-mode compile >/dev/null 2>&1
  cp -r .next/standalone/apps/web/server.js .
  export DATA_DIR=/var/lib/hoarder
  cd ../../packages/db
  pnpm migrate >/dev/null 2>&1
  echo "${RELEASE}" >/opt/${APP}_version.txt
  chown -R hoarder:hoarder /opt/hoarder
  sed -i "s/SERVER_VERSION=${PREV_VERSION}/SERVER_VERSION=${RELEASE}/" /etc/systemd/system/hoarder-web.service
  systemctl daemon-reload
  msg_ok "Updated ${APP} to ${RELEASE}"
  msg_info "Starting ${APP}"
  systemctl start hoarder.target
  msg_ok "Started ${APP}"
  msg_info "Cleaning up"
  rm -R /opt/v${RELEASE}.zip
  rm -rf /opt/hoarder_bak
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
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:3000${CL} \n"
