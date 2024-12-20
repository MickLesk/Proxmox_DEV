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

APP="FileBrowser"
INSTALL_PATH="/usr/local/bin/filebrowser"
SERVICE_PATH="/etc/systemd/system/filebrowser.service"
DB_PATH="/root/filebrowser.db"
IP=$(hostname -I | awk '{print $1}')
header_info

function msg_info() {
    echo -ne " - $1..."
}

function msg_ok() {
    echo -e " ✓ $1"
}

function msg_error() {
    echo -e " ✗ $1"
}

# Prüfen, ob FileBrowser installiert ist
if [ -f "$INSTALL_PATH" ]; then
    echo -e "${APP} is already installed."
    read -r -p "Would you like to uninstall ${APP}? (y/N): " uninstall_prompt
    if [[ "${uninstall_prompt,,}" =~ ^(y|yes)$ ]]; then
        msg_info "Uninstalling ${APP}"
        systemctl disable -q --now filebrowser.service
        rm -f "$INSTALL_PATH" "$DB_PATH" "$SERVICE_PATH"
        msg_ok "${APP} has been uninstalled."
        exit 0
    fi

    read -r -p "Would you like to update ${APP}? (y/N): " update_prompt
    if [[ "${update_prompt,,}" =~ ^(y|yes)$ ]]; then
        msg_info "Updating ${APP}"
        curl -fsSL https://github.com/filebrowser/filebrowser/releases/latest/download/linux-amd64-filebrowser.tar.gz | tar -xzv -C /usr/local/bin &>/dev/null
        msg_ok "Updated ${APP}"
        exit 0
    else
        echo "Update skipped. Exiting."
        exit 0
    fi
fi

# Installation, falls nicht vorhanden
echo -e "${APP} is not installed."
read -r -p "Would you like to install ${APP}? (y/n): " install_prompt
if [[ "${install_prompt,,}" =~ ^(y|yes)$ ]]; then
    msg_info "Installing ${APP}"
    apt-get install -y curl &>/dev/null
    curl -fsSL https://github.com/filebrowser/filebrowser/releases/latest/download/linux-amd64-filebrowser.tar.gz | tar -xzv -C /usr/local/bin &>/dev/null
    msg_ok "Installed ${APP}"

    read -r -p "Would you like to use No Authentication? (y/N): " auth_prompt
    if [[ "${auth_prompt,,}" =~ ^(y|yes)$ ]]; then
        filebrowser config init -a '0.0.0.0' &>/dev/null
        filebrowser config set -a '0.0.0.0' &>/dev/null
        filebrowser config init --auth.method=noauth &>/dev/null
        filebrowser config set --auth.method=noauth &>/dev/null
    else
        filebrowser config init -a '0.0.0.0' &>/dev/null
        filebrowser config set -a '0.0.0.0' &>/dev/null
        filebrowser users add admin helper-scripts.com --perm.admin &>/dev/null
    fi

    msg_info "Creating service"
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

    echo -e "${APP} is reachable at: http://$IP:8080"
else
    echo "Installation skipped. Exiting."
    exit 0
fi
