#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: MickLesk
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
  clear
  cat <<"EOF"
   __  __          __      __          ____                 
  / / / /___  ____/ /___ _/ /____     / __ \___  ____  ____ 
 / / / / __ \/ __  / __ `/ __/ _ \   / /_/ / _ \/ __ \/ __ \
/ /_/ / /_/ / /_/ / /_/ / /_/  __/  / _, _/  __/ /_/ / /_/ /
\____/ .___/\__,_/\__,_/\__/\___/  /_/ |_|\___/ .___/\____/ 
    /_/                                      /_/            
EOF
}

set -eEuo pipefail
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
header_info
echo "Loading..."
NODE=$(hostname)

# Menü zur Auswahl der zu aktualisierenden Container
EXCLUDE_MENU=()
MSG_MAX_LENGTH=0
while read -r TAG ITEM; do
  OFFSET=2
  ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
  EXCLUDE_MENU+=("$TAG" "$ITEM " "OFF")
done < <(pct list | awk 'NR>1')

excluded_containers=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Proxmox VE Repo Updater" --checklist "\nSelect containers to skip:\n" 16 $((MSG_MAX_LENGTH + 23)) 6 "${EXCLUDE_MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"') || exit

# Funktion zur Aktualisierung der Konfiguration in den Containern
function update_container() {
  container=$1
  os=$(pct config "$container" | awk '/^ostype/ {print $2}')

  if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    echo -e "${BL}[Info]${GN} Updating /usr/bin/update in ${BL}$container${CL} (OS: ${GN}$os${CL})\n"
    
    # Führe die sed-Anweisung für die Konfiguration durch
    pct exec "$container" -- bash -c "sed -i 's/tteck\\/Proxmox/community-scripts\\/ProxmoxVE/g' /usr/bin/update"
  else
    echo -e "${BL}[Info]${GN} Skipping ${BL}$container${CL} (not Debian/Ubuntu)\n"
  fi
}

header_info
for container in $(pct list | awk '{if(NR>1) print $1}'); do
  if [[ " ${excluded_containers[@]} " =~ " $container " ]]; then
    echo -e "${BL}[Info]${GN} Skipping ${BL}$container${CL}\n"
    sleep 1
  else
    update_container $container
  fi
done

header_info
echo -e "${GN}The process is complete. The specified updates have been applied to the containers.${CL}\n"
