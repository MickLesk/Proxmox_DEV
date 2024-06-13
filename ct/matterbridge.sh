#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    __  ___      __  __            __         _     __         
   /  |/  /___ _/ /_/ /____  _____/ /_  _____(_)___/ /___ ____ 
  / /|_/ / __ `/ __/ __/ _ \/ ___/ __ \/ ___/ / __  / __ `/ _ \
 / /  / / /_/ / /_/ /_/  __/ /  / /_/ / /  / / /_/ / /_/ /  __/
/_/  /_/\__,_/\__/\__/\___/_/  /_.___/_/  /_/\__,_/\__, /\___/ 
                                                  /____/                                      
EOF
}
header_info
echo -e "Loading..."
APP="Matterbridge"
var_disk="4"
var_cpu="1"
var_ram="1024"
var_os="debian"
var_version="12"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

choose_service() {
    local choice=$(whiptail --title "Choose Matterbridge Service" --menu \
    "Please choose your running option of matterbridge." 15 60 3 \
    "1" "Start Matterbridge - Bridge (beends Childbridge if active)" \
    "2" "Start Matterbridge - Childbridge (beends Bridge if active)" \
    "3" "Cancel" 3>&1 1>&2 2>&3)

    local exit_status=$?

    if [ $exit_status -eq 0 ]; then
        case $choice in
            1)
                systemctl stop matterbridge_child.service >/dev/null 2>&1
                systemctl start matterbridge.service
                msg_ok "Started Matterbridge - Bridge"
                ;;
            2)
                systemctl stop matterbridge.service >/dev/null 2>&1
                systemctl start matterbridge_child.service
                msg_ok "Started Matterbridge - Childbridge"
                ;;
            3)
                msg_info "Update canceled."
                ;;
            *)
                msg_error "Invalid selection."
                ;;
        esac
    else
        msg_info "Update canceled."
    fi
}

# Funktion zum Update des Skripts
update_script() {
    header_info
    APP="Matterbridge"
    
    # Prüfen, ob Matterbridge installiert ist
    if [[ ! -d /opt/matterbridge ]]; then
        msg_error "No ${APP} Installation Found!"
    fi
    
    # Abfragen der neuesten Version von GitHub
    RELEASE=$(curl -s https://api.github.com/repos/Luligu/matterbridge/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
    
    # Prüfen, ob ein Update erforderlich ist
    if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
        msg_info "Stopping ${APP} Service..."
        systemctl stop matterbridge.service >/dev/null 2>&1
        systemctl stop matterbridge_child.service >/dev/null 2>&1
        msg_ok "Stopped ${APP} Services"
    
        msg_info "Updating ${APP} to ${RELEASE}"
        cd /opt
        wget -q "https://github.com/Luligu/matterbridge/archive/refs/tags/${RELEASE}.zip" 
        unzip -q ${RELEASE}.zip
        mv matterbridge-${RELEASE} /opt/matterbridge
        cd /opt/matterbridge
        npm ci >/dev/null 2>&1
        npm run build >/dev/null 2>&1
        echo "${RELEASE}" >/opt/${APP}_version.txt
        msg_ok "Updated ${APP} to ${RELEASE}"
    
        msg_info "Cleaning up..."
        rm ${RELEASE}.zip 
        msg_ok "Cleaned up"
    
        # Nach dem Update den Dienst auswählen und starten
        choose_service
    else
        msg_ok "No update required. ${APP} is already at ${RELEASE}"
    fi
    
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8283${CL} \n"