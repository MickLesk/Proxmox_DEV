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

function get_installed_version() {
    if [ -f /usr/local/bin/filebrowser ]; then
        INSTALLED_VERSION=$(/usr/local/bin/filebrowser --version 2>/dev/null)
        echo "$INSTALLED_VERSION"
    else
        echo ""
    fi
}

function get_latest_version() {
    RELEASE=$(curl -fsSL https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -o '"tag_name": ".*"' | sed 's/"//g' | sed 's/tag_name: //g')
    echo "$RELEASE"
}

INSTALLED_VERSION=$(get_installed_version)
LATEST_VERSION=$(get_latest_version)

# Deinstallationsdialog
if [ -f /root/filebrowser.db ]; then
  read -r -p "Would you like to uninstall ${APP} on $hostname? (y/N): " prompt
  if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
    systemctl disable -q --now filebrowser.service
    rm -rf /usr/local/bin/filebrowser /root/filebrowser.db /etc/systemd/system/filebrowser.service
    msg_ok "$APP has been uninstalled."
    exit 0
  else
    clear
  fi
fi

# Installations- oder Update-Dialog
if [ -n "$INSTALLED_VERSION" ]; then
    echo "Installed version: $INSTALLED_VERSION"
    echo "Latest version: $LATEST_VERSION"
    
    if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]; then
        echo -e "${GN}FileBrowser is already up-to-date!${CL}"
        exit 0
    else
        echo -e "${RD}An update is available!${CL}"
    fi
else
    echo -e "${RD}FileBrowser is not installed. Installing now...${CL}"
fi

# Prompt user for installation or update
read -p "Would you like to install or update FileBrowser? (y/n): " yn
case $yn in
    [Yy]*) 
        msg_info "Installing/Updating ${APP}"
        apt-get install -y curl &>/dev/null
        curl -fsSL https://github.com/filebrowser/filebrowser/releases/download/$LATEST_VERSION/linux-amd64-filebrowser.tar.gz | tar -xzv -C /usr/local/bin &>/dev/null
        ;;
    [Nn]*) 
        exit 0
        ;;
    *)
        echo "Please answer yes or no."
        exit 1
        ;;
esac

read -r -p "Would you like to use No Authentication? <y/N> " prompt

if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
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

msg_ok "Installed ${APP} on $hostname"

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
msg_ok "Created Service"

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://$IP:8080${CL} \n"
