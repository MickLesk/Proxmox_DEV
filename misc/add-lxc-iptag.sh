#!/usr/bin/env bash

# Copyright (c) 2024 MickLesk
# License: MIT
# https://github.com/MickLesk/Proxmox_DEV

function header_info {
    cat <<"EOF"
    __   _  ________   ________      ______           
   / /  | |/ / ____/  /  _/ __ \    /_  __/___ _____ _
  / /   |   / /       / // /_/ /_____/ / / __ `/ __ `/
 / /___/   / /___   _/ // ____/_____/ / / /_/ / /_/ / 
/_____/_/|_\____/  /___/_/         /_/  \__,_/\__, /  
                                             /____/   
EOF
}

# Farbvariablen
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
RD=$(echo "\033[01;31m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD=" "
CM=" ✔️ ${CL}"
CROSS=" ✖️ ${CL}"

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
set -xe
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR

function error_exit() {
    trap - ERR
    local reason="Unknown failure occurred."
    local msg="${1:-$reason}"
    local flag="${CROSS} ERROR ${CL}$EXIT@$LINE"
    echo -e "$flag $msg" 1>&2
    exit $EXIT
}

clear
header_info

APP="LXC IP-Tag"
hostname=$(hostname)

while true; do
    read -p "This will install ${APP} on ${hostname}. Proceed? (y/n): " yn
    case $yn in
    [Yy]*) break ;;
    [Nn]*) echo "Installation cancelled."; exit ;;
    *) echo "Please answer yes or no." ;;
    esac
done

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_info "Installing Prerequisites"
apt-get update &>/dev/null
apt-get install -y ipcalc &>/dev/null
msg_ok "Installed Prerequisites"

msg_info "Setting up IP-Tag Scripts"
curl -sSL https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/refs/heads/main/misc/lxc-iptag/iptag.func -o /usr/local/bin/iptag
chmod +x /usr/local/bin/iptag
curl -sSL https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/refs/heads/main/misc/lxc-iptag/iptag.conf -o /usr/local/etc/iptag.conf
curl -sSL https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/refs/heads/main/misc/lxc-iptag/iptag.service -o /lib/systemd/system/iptag.service
msg_ok "Setup IP-Tag Scripts"

msg_info "Configuring Systemd Service"
systemctl daemon-reload &>/dev/null
systemctl enable -q --now iptag.service &>/dev/null
msg_ok "Configured and Started IPTAG Service"

echo -e "\n${APP} installation completed successfully!"

