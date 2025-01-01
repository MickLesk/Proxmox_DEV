#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
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
    if [[ ! -d /opt/komodo ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Updating ${APP}"
    BACKUP_DIR="/opt/komodo/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    for file in /opt/komodo/*; do
        filename=$(basename "$file")
        if [[ "$filename" != "compose.env" ]]; then
            if [[ -f "$file" ]]; then
                cp "$file" "$BACKUP_DIR/"
            elif [[ -d "$file" ]]; then
                cp -r "$file" "$BACKUP_DIR/"
            else
                msg_warn "Skipping $filename: Not a regular file or directory."
                continue
            fi
            wget -q -O "$file" "https://raw.githubusercontent.com/mbecker20/komodo/main/compose/$filename"
            if [[ $? -eq 0 ]]; then
                msg_ok "Updated $filename"
            else
                msg_warn "Failed to update $filename. Restoring backup."
                cp "$BACKUP_DIR/$filename" "$file"
            fi
        fi
    done
    DB_COMPOSE_FILE=""
    if [[ -f /opt/komodo/mongo.compose.yaml ]]; then
        DB_COMPOSE_FILE="mongo.compose.yaml"
    elif [[ -f /opt/komodo/sqlite.compose.yaml ]]; then
        DB_COMPOSE_FILE="sqlite.compose.yaml"
    elif [[ -f /opt/komodo/postgres.compose.yaml ]]; then
        DB_COMPOSE_FILE="postgres.compose.yaml"
    else
        msg_error "No valid compose file found in /opt/komodo!"
        exit 1
    fi

    # Restart Docker containers using the correct compose file
    docker compose -p komodo -f "/opt/komodo/$DB_COMPOSE_FILE" --env-file /opt/komodo/compose.env up -d
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