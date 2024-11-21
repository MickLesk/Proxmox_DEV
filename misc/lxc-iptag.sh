#!/usr/bin/env bash

# Copyright (c) 2021-2024 community-scripts ORG
# Author: MickLesk
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info() {
  clear
  cat <<"EOF"
    __   _  ________   ________      _________   ______   
   / /  | |/ / ____/  /  _/ __ \    /_  __/   | / ____/   
  / /   |   / /       / // /_/ /_____/ / / /| |/ / __     
 / /___/   / /___   _/ // ____/_____/ / / ___ / /_/ /     
/_____/_/|_\____/  /___/_/         /_/ /_/  |_\____/      
                                                          
EOF
}

BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

# LXC Tagging-Function
default_cidr_list=(
    "192.168.0.0/16"
    "100.64.0.0/10"
    "10.0.0.0/8"
)

load_cidr_list() {
    local cidr_file="/opt/lxc-iptag/cidr_list.txt"

    # Überprüfe, ob die CIDR-Datei existiert
    if [[ ! -f "$cidr_file" ]]; then
        echo "[Info] CIDR list file not found. Creating with default values..."

        # Erstelle die CIDR-Datei mit den Standardwerten
        for cidr in "${default_cidr_list[@]}"; do
            echo "$cidr" >> "$cidr_file"
        done

        echo "[Info] CIDR list file created with default values."
    fi

    # Lade die CIDR-Liste aus der Datei
    mapfile -t cidr_list < "$cidr_file"
}

ip_to_int() {
    local ip="${1}"
    local a b c d
    IFS=. read -r a b c d <<< "${ip}"
    echo "$((a << 24 | b << 16 | c << 8 | d))"
}

ip_in_cidr() {
    local ip="${1}"
    local cidr="${2}"
    ip_int=$(ip_to_int "${ip}")
    netmask_int=$(ip_to_int "$(ipcalc -b "${cidr}" | grep Broadcast | awk '{print $2}')")
    masked_ip_int=$(( "${ip_int}" & "${netmask_int}" ))
    [[ ${ip_int} -eq ${masked_ip_int} ]] && return 0 || return 1
}

ip_in_cidrs() {
    local ip="${1}"
    for cidr in "${cidr_list[@]}"; do
        ip_in_cidr "${ip}" "${cidr}" && return 0
    done
    return 1
}

# Funktion zur Auswahl der Container mit whiptail
select_containers() {
  EXCLUDE_MENU=()
  MSG_MAX_LENGTH=0
  while read -r TAG ITEM; do
    OFFSET=2
    ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
    EXCLUDE_MENU+=("$TAG" "$ITEM " "OFF")
  done < <(pct list | awk 'NR>1 {print $1, $2}')

  selected_containers=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Select Containers" --checklist "\nSelect containers to tag IPs:\n" \
    16 $((MSG_MAX_LENGTH + 23)) 6 "${EXCLUDE_MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"') || exit

  # Rückgabe der ausgewählten Container-IDs
  echo "$selected_containers"
}

# Funktion zum IP-Taggen der Container
tag_container_ip() {
  container_id=$1
  header_info
  name=$(pct exec "$container_id" hostname)
  echo -e "${BL}[Info]${GN} Tagging IP for ${name} ${CL} \n"

  # IP des Containers abfragen
  container_ip=$(pct exec "$container_id" -- ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

  if [ -z "$container_ip" ]; then
    echo -e "${RD}[Error]${CL} No IP found for ${name}. Skipping...\n"
    return 1
  fi

  # IP überprüfen und taggen, wenn sie in den CIDR-Bereich fällt
  if ip_in_cidrs "$container_ip"; then
    echo -e "${BL}[Info]${GN} IP ${container_ip} for ${name} is within the CIDR range. Tagging... ${CL}"

    # Holen der bestehenden Tags des Containers
    existing_tags=$(pct config "$container_id" | grep "^tags:" | cut -d: -f2 | tr -d '[:space:]')
    
    # Wenn bereits Tags existieren, fügen wir die neue IP hinzu
    if [ -n "$existing_tags" ]; then
      new_tags="$existing_tags,$container_ip"
    else
      new_tags="$container_ip"
    fi

    # Tags setzen, ohne bestehende zu überschreiben
    pct set "$container_id" -tags "$new_tags"
    # Beispiel: echo "Container ${name} IP: ${container_ip}" >> /var/log/lxc_ip_tags.log
  else
    echo -e "${RD}[Info]${GN} IP ${container_ip} for ${name} is outside the allowed CIDR range. Skipping... ${CL}"
  fi
}

# Hauptfunktion für das IP-Taggen
main() {
  # Auswahl der Container
  selected_containers=$(select_containers)

  # Wenn keine Container ausgewählt wurden, beenden
  if [ -z "$selected_containers" ]; then
    echo -e "${RD}[Info]${CL} No containers selected, exiting."
    exit 1
  fi

  # Tagging der IPs der ausgewählten Container
  for container_id in $selected_containers; do
    # IP-Tagging durchführen
    tag_container_ip "$container_id"
  done

  echo -e "${GN} Finished tagging IPs for selected containers. ${CL} \n"
}
main
