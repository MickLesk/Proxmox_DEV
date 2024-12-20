#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
    clear
    cat <<"EOF"
    _______ __     ____
   / ____(_) /__  / __ )_________ _      __________  _____
  / /_  / / / _ \/ __  / ___/ __ \ | /| / / ___/ _ \/ ___/
 / __/ / / /  __/ /_/ / /  / /_/ / |/ |/ (__  )  __/ / 
/_/   /_/_/\___/_____/_/   \____/|__/|__/____/\___/_/   
EOF
}

IP=$(hostname -I | awk '{print $1}')
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
APP="FileBrowser"
hostname="$(hostname)"
header_info

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e "${BFR} ${RD}✗ ${msg}${CL}"
}

function get_installed_version() {
    if command -v /usr/local/bin/filebrowser &>/dev/null; then
        /usr/local/bin/filebrowser --version 2>/dev/null | awk '{print $2}'
    else
        echo ""
    fi
}

function get_latest_version() {
    curl -fsSL https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")'
}

INSTALLED_VERSION=$(get_installed_version)
LATEST_VERSION=$(get_latest_version)

# Schritt 1: Prüfen, ob FileBrowser bereits installiert ist
if [ -n "$INSTALLED_VERSION" ]; then
    echo -e "Installed version: ${GN}$INSTALLED_VERSION${CL}"
    echo -e "Latest version: ${GN}$LATEST_VERSION${CL}"

    # 1.1 Deinstallationsabfrage
    read -r -p "Would you like to uninstall ${APP}? (y/N): " uninstall_prompt
    if [[ "${uninstall_prompt,,}" =~ ^(y|yes)$ ]]; then
        msg_info "Removing ${APP}"
        systemctl disable -q --now filebrowser.service
        rm -rf /usr/local/bin/filebrowser /root/filebrowser.db /etc/systemd/system/filebrowser.service
        msg_ok "${APP} has been uninstalled."
        exit 0
    fi

    # 1.1.2 Update-Abfrage
    read -r -p "Would you like to update ${APP}? (y/N): " update_prompt
    if [[ "${update_prompt,,}" =~ ^(y|yes)$ ]]; then
        msg_info "Updating ${APP} to latest version"
        curl -fsSL https://github.com/filebrowser/filebrowser/releases/download/$LATEST_VERSION/linux-amd64-filebrowser.tar.gz | tar -xzv -C /usr/local/bin &>/dev/null
        msg_ok "${APP} updated to version ${LATEST_VERSION}"

        # Authentifizierungsdialog nach Update
        read -r -p "Would you like to use No Authentication? (y/N): " auth_prompt
        if [[ "${auth_prompt,,}" =~ ^(y|yes)$ ]]; then
            filebrowser config init -a '0.0.0.0' &>/dev/null
            filebrowser config set -a '0.0.0.0' &>/dev/null
            filebrowser config init --auth.method=noauth &>/dev/null
            filebrowser config set --auth.method=noauth &>/dev/null
            filebrowser users add ID 1 --perm.admin &>/dev/null  
        else
            filebrowser config init -a '0.0.0.0' &>/dev/null
            filebrowser config set -a '0.0.0.0' &>/dev/null
            filebrowser users add admin helper-scripts.com --perm.admin &>/dev/null
        fi
        msg_ok "Configuration updated after FileBrowser upgrade."
        exit 0
    else
        echo -e "${APP} update skipped. Exiting script."
        exit 0
    fi
fi

# Schritt 2: Neuinstallation, falls nicht installiert
echo -e "${RD}FileBrowser is not installed.${CL}"
read -p "Would you like to install ${APP}? (y/n): " install_prompt
if [[ "${install_prompt,,}" =~ ^(y|yes)$ ]]; then
    msg_info "Installing ${APP}"
    apt-get install -y curl &>/dev/null
    curl -fsSL https://github.com/filebrowser/filebrowser/releases/download/$LATEST_VERSION/linux-amd64-filebrowser.tar.gz | tar -xzv -C /usr/local/bin &>/dev/null

    # Authentifizierungsdialog nach Neuinstallation
    read -r -p "Would you like to use No Authentication? (y/N): " auth_prompt
    if [[ "${auth_prompt,,}" =~ ^(y|yes)$ ]]; then
        filebrowser config init -a '0.0.0.0' &>/dev/null
        filebrowser config set -a '0.0.0.0' &>/dev/null
        filebrowser config init --auth.method=noauth &>/dev/null
        filebrowser config set --auth.method=noauth &>/dev/null
        filebrowser users add ID 1 --perm.admin &>/dev/null  
    else
        filebrowser config init -a '0.0.0.0' &>/dev/null
        filebrowser config set -a '0.0.0.0' &>/dev/null
        filebrowser users add admin helper-scripts.com --perm.admin &>/dev/null
    fi

    msg_ok "${APP} installed and configured on $hostname."

    # Service erstellen
    msg_info "Creating Service"
    cat <<EOF >/etc/systemd/system/filebrowser.service
[Unit]
Description=Filebrowser
After=network-online.target

[Service]
User=root
WorkingDirectory=/root/
ExecStart=/usr/local/bin/filebrowser -r /

[Install]
WantedBy=default.target
EOF
    systemctl enable -q --now filebrowser.service
    msg_ok "Service created successfully."

    echo -e "${APP} is reachable at: ${BL}http://$IP:8080${CL}"
else
    echo -e "Installation aborted. Exiting script."
    exit 0
fi
