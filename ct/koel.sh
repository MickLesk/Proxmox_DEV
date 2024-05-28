#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    __ __           __
   / //_/___  ___  / /
  / ,< / __ \/ _ \/ / 
 / /| / /_/ /  __/ /  
/_/ |_\____/\___/_/   
                           
EOF
}
header_info
echo -e "Loading..."
APP="Koel"
var_disk="10"
var_cpu="4"
var_ram="2048"
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

function update_script() {
  if [[ ! -d /opt/koel ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
# Funktion zur Anzeige des Whiptail-Dialogs für die Auswahl der Aufgabe
show_task_selection() {
    local RELEASE=$1

    # Whiptail-Dialog anzeigen
    UPD=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "SUPPORT" --radiolist --cancel-button Exit-Script "Spacebar = Select" 14 58 6 \
        "1" "Update Koel to $RELEASE" ON \
        "2" "Add Spotify Credentials" OFF \
        "3" "Add LastFM Credentials" OFF \
        "4" "Add YouTube Credentials" OFF \
        "5" "Add CDN Credentials" OFF \
        "6" "Add Amazon S3 Credentials" OFF \
        3>&1 1>&2 2>&3)
}

# Funktion zum Hinzufügen von Anmeldeinformationen für einen Dienst
add_credentials() {
    local SERVICE=$1
    local CREDENTIALS=()

    case $SERVICE in
        "Spotify")
            CREDENTIALS+=("SPOTIFY_CLIENT_ID" "SPOTIFY_CLIENT_SECRET")
            ;;
        "LastFM")
            CREDENTIALS+=("LASTFM_API_KEY" "LASTFM_API_SECRET")
            ;;
        "YouTube")
            CREDENTIALS+=("YOUTUBE_API_KEY")
            ;;
        "CDN")
            CREDENTIALS+=("CDN_URL")
            ;;
        "Amazon S3")
            CREDENTIALS+=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_REGION" "AWS_ENDPOINT")
            ;;
        *)
            echo "Ungültiger Dienst."
            exit 1
            ;;
    esac

    local INPUTS=()
    for CRED in "${CREDENTIALS[@]}"; do
        local VALUE=$(whiptail --inputbox "Bitte geben Sie Ihren $SERVICE $CRED ein:" 8 80 "" --title "$SERVICE $CRED" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            echo "Abgebrochen. Das Script wird beendet."
            exit 1
        fi
        INPUTS+=("$CRED=$VALUE")
    done

    # Werte in die Datei /opt/koel/.env schreiben
    for INPUT in "${INPUTS[@]}"; do
        local KEY="${INPUT%%=*}"
        local VAL="${INPUT#*=}"
        sudo sed -i "s|$KEY=.*|$INPUT|" /opt/koel/.env
    done

    # Erfolgsmeldung anzeigen
    whiptail --msgbox "Die $SERVICE-Credentials wurden erfolgreich hinzugefügt." 8 60
}

# Hauptprogramm

# Bestimmen Sie, ob ein Update ausgeführt wird (angenommen, $RELEASE wird irgendwoher definiert)
RELEASE=$(curl -s https://api.github.com/repos/koel/koel/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
# Beispielwert, den Sie möglicherweise ersetzen müssen
# Hier Code einfügen, um zu überprüfen, ob ein Update ausgeführt wird

# Dialog zur Auswahl der Aufgabe anzeigen
show_task_selection "$RELEASE"

# Fallunterscheidung basierend auf der ausgewählten Aufgabe
case "$UPD" in
    1)  
		  if [[ "${RELEASE}" != "$(cat /opt/koel/.version)" ]] || [[ ! -f /opt/koel/.version ]]; then
		  msg_info "Stopping Koel NGINX Service"
		  systemctl stop nginx
		  msg_ok "Stopped NGINX Service"

		  msg_info "Updating to ${RELEASE}"
			cd /opt
			wget https://github.com/koel/koel/releases/download/${RELEASE}/koel-${RELEASE}.zip >/dev/null 2>&1
			unzip -q koel-${RELEASE}.zip >/dev/null 2>&1
			cd /opt/koel
			composer update --no-interaction >/dev/null 2>&1
			composer install --no-interaction >/dev/null 2>&1
			php artisan migrate --force >/dev/null 2>&1
			php artisan cache:clear >/dev/null 2>&1
			php artisan config:clear >/dev/null 2>&1
			php artisan view:clear >/dev/null 2>&1
			php artisan koel:init --no-interaction >/dev/null 2>&1
		  msg_ok "Updated to ${RELEASE}"

		  msg_info "Cleaning up"
		  cd ~
		  rm /opt/koel-${RELEASE}.zip
		  msg_ok "Cleaned"

		  msg_info "Starting NGINX Service"
		  systemctl start nginx
		  sleep 1
		  msg_ok "Started NGINX Service"
		  msg_ok "Updated Successfully!\n"
		else
		  msg_ok "No update required. ${APP} is already at ${RELEASE}"
		fi
		exit
        ;;
    2)  
        add_credentials "Spotify"
        ;;
    3)  
        add_credentials "LastFM"
        ;;
    4)  
        add_credentials "YouTube"
        ;;
    5)  
        add_credentials "CDN"
        ;;
    6)  
        add_credentials "Amazon S3"
        ;;
    *)
        echo "Abgebrochen. Das Script wird beendet."
        ;;
es

}

start
build_container
description

msg_info "Setting Container to Normal Resources"
pct set $CTID -cores 2
msg_ok "Set Container to Normal Resources"

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:6767${CL} \n"
