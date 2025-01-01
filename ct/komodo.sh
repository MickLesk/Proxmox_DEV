#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/Proxmox_DEV/develop/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://dockge.kuma.pet/

# App Default Values
APP="Komodo"
var_tags="docker"
var_cpu="2"
var_ram="2048"
var_disk="10"
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
    if [[ ! -d /opt/dockge ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Updating ${APP}"
    cd /opt/kommodo
    docker compose pull
    docker compose up -d
    msg_ok "Updated ${APP}"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9120${CL}"