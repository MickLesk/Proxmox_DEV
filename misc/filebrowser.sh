#!/usr/bin/env bash

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

function msg_info() {
    local msg="$1"
    echo -ne " - ${YW}${msg}...${CL}"
}

function msg_ok() {
    local msg="$1"
    echo -e " ${GN}✓ ${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e " ${RD}✗ ${msg}${CL}"
}

# Farben
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
RD=$(echo "\033[01;31m")
CL=$(echo "\033[m")
APP="FileBrowser"

# Version prüfen
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

header_info

INSTALLED_VERSION=$(get_installed_version)
LATEST_VERSION=$(get_latest_version)

# FileBrowser-Status prüfen
if [ -n "$INSTALLED_VERSION" ]; then
    echo -e "${GN}${APP} is already installed.${CL}"
    echo -e "Installed version: ${YW}$INSTALLED_VERSION${CL}"
    echo -e "Latest version: ${YW}$LATEST_VERSION${CL}"
    
    # Deinstallationsabfrage
    read -p "Would you like to uninstall ${APP}? (y/n): " uninstall_prompt
    if [[ "${uninstall_prompt,,}" =~ ^(y|yes)$ ]]; then
        msg_info "Removing ${APP}"
        systemctl disable -q --now filebrowser.service
        rm -rf /usr/local/bin/filebrowser /root/filebrowser.db /etc/systemd/system/filebrowser.service
        msg_ok "${APP} has been uninstalled."
        exit 0
    fi

    # Update-Abfrage
    read -p "Would you like to update ${APP} to the latest version? (y/n): " update_prompt
    if [[ "${update_prompt,,}" =~ ^(y|yes)$ ]]; then
        msg_info "Updating ${APP} to version $LATEST_VERSION"
        curl -fsSL https://github.com/filebrowser/filebrowser/releases/download/$LATEST_VERSION/linux-amd64-filebrowser.tar.gz | tar -xzv -C /usr/local/bin &>/dev/null
        msg_ok "${APP} has been updated to version ${LATEST_VERSION}"

        # Authentifizierungsdialog
        read -p "Would you like to use No Authentication? (y/n): " auth_prompt
        if [[ "${auth_prompt,,}" =~ ^(y|yes)$ ]]; then
            filebrowser config init -a '0.0.0.0' &>/dev/null
            filebrowser config set --auth.method=noauth &>/dev/null
        else
            filebrowser config init -a '0.0.0.0' &>/dev/null
        fi
        msg_ok "Configuration updated."
        exit 0
    else
        echo -e "${RD}Update skipped. Exiting.${CL}"
        exit 0
    fi
else
    echo -e "${RD}${APP} is not installed.${CL}"
    read -p "Would you like to install ${APP}? (y/n): " install_prompt
    if [[ "${install_prompt,,}" =~ ^(y|yes)$ ]]; then
        msg_info "Installing ${APP}"
        apt-get install -y curl &>/dev/null
        curl -fsSL https://github.com/filebrowser/filebrowser/releases/download/$LATEST_VERSION/linux-amd64-filebrowser.tar.gz | tar -xzv -C /usr/local/bin &>/dev/null
        msg_ok "${APP} has been installed."

        # Authentifizierungsdialog
        read -p "Would you like to use No Authentication? (y/n): " auth_prompt
        if [[ "${auth_prompt,,}" =~ ^(y|yes)$ ]]; then
            filebrowser config init -a '0.0.0.0' &>/dev/null
            filebrowser config set --auth.method=noauth &>/dev/null
        else
            filebrowser config init -a '0.0.0.0' &>/dev/null
        fi

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
        msg_ok "Service created."

        echo -e "${APP} should be reachable at: ${GN}http://$(hostname -I | awk '{print $1}'):8080${CL}"
    else
        echo -e "${RD}Installation skipped. Exiting.${CL}"
        exit 0
    fi
fi
