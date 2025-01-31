#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.qbittorrent.org/

# App Default Values
APP="qBittorrent"
var_tags="torrent"
var_cpu="2"
var_ram="2048"
var_disk="8"
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
  if [[ ! -f /etc/systemd/system/qbittorrent-nox.service ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -s https://api.github.com/repos/userdocs/qbittorrent-nox-static/releases/latest | grep -oP '"tag_name": "\K[^"]+' | sed 's/release-//')
  if [[ ! -f /opt/qbittorrent-nox_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/qbittorrent-nox_version.txt)" ]]; then
    msg_info "Stopping ${APP}"
    systemctl stop qbittorrent-nox
    msg_ok "${APP} Stopped"

    msg_info "Updating ${APP} to ${RELEASE}"
    mv /usr/bin/qbittorrent-nox /opt/qbittorrent-nox_bak
    cd /opt
    wget -q https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-${RELEASE}/x86_64-qbittorrent-nox
    mv x86_64-qbittorrent-nox /usr/bin/qbittorrent-nox
    echo "${RELEASE}" >/opt/qbittorrent-nox_version.txt
    msg_ok "Updated ${APP}"

    msg_info "Starting ${APP}"
    systemctl start qbittorrent-nox
    msg_ok "Started ${APP}"

    msg_info "Updating ${APP} LXC"
    apt-get update &>/dev/null
    apt-get -y upgrade &>/dev/null
    msg_ok "Updated ${APP} LXC"
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
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
