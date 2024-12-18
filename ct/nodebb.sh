#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

# App Default Values
APP="NodeBB"
var_tags="forum"
var_disk="10"
var_cpu="4"
var_ram="2048"
var_os="ubuntu"
var_version="24.04"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"

# Core
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/nodebb ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -s https://api.github.com/repos/linkwarden/linkwarden/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
  if [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
    msg_info "Stopping ${APP}"
    systemctl stop nodebb
    msg_ok "Stopped ${APP}"

    msg_info "Updating ${APP} to ${RELEASE}"
    cd /opt/nodebb
    git pull
    yarn
    npx playwright install-deps
    yarn playwright install
    yarn prisma generate
    yarn build
    yarn prisma migrate deploy
    echo "${RELEASE}" >/opt/${APP}_version.txt
    msg_ok "Updated ${APP} to ${RELEASE}"

    msg_info "Starting ${APP}"
    systemctl start linkwarden
    msg_ok "Started ${APP}"
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
echo -e "${APP}${CL} should be reachable by going to the following URL.
         ${BL}http://${IP}:4567${CL} \n"
