#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
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
CM='\xE2\x9C\x94\033'
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
header_info
echo "Loading..."
whiptail --backtitle "Proxmox VE Helper Scripts" --title "Proxmox VE LXC IP-Tag" --yesno "This can be add IP-Tags to your LXCs. Proceed?" 10 58 || exit

NODE=$(hostname)
EXCLUDE_MENU=()
MSG_MAX_LENGTH=0
while read -r TAG ITEM; do
  OFFSET=2
  ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
  EXCLUDE_MENU+=("$TAG" "$ITEM " "OFF")
done < <(pct list | awk 'NR>1')

excluded_containers=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Containers on $NODE" --checklist "\nSelect containers to skip from cleaning:\n" \
  16 $((MSG_MAX_LENGTH + 23)) 6 "${EXCLUDE_MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"') || exit  

function install_iptag_tools() {
  # Alle Installations- und Service-Dateien direkt im Skript
  container=$1
  header_info
  name=$(pct exec "$container" hostname)
  echo -e "${BL}[Info]${GN} Installing IP Tag tools on ${name} ${CL} \n"

  pct exec "$container" -- bash -c "
    sudo apt update && sudo apt install -y ipcalc
    # Installiere das lxc-iptag-Skript direkt im Container
    echo '#!/bin/bash' > /usr/local/bin/lxc-iptag
    echo 'interface=\$(ip -4 route ls dev eth0 | grep default | awk \'{print \$5}\')' >> /usr/local/bin/lxc-iptag
    echo 'ip=\$(ip -4 addr show dev \$interface | grep inet | awk \'{print \$2}\' | cut -d/ -f1)' >> /usr/local/bin/lxc-iptag
    echo 'hostname=\$(hostname)' >> /usr/local/bin/lxc-iptag
    echo 'echo \${hostname}: \${ip}' >> /usr/local/bin/lxc-iptag
    chmod +x /usr/local/bin/lxc-iptag
    # Installiere die systemd-Unit-Datei für lxc-iptag
    echo '[Unit]' > /lib/systemd/system/lxc-iptag.service
    echo 'Description=LXC IP Tag Service' >> /lib/systemd/system/lxc-iptag.service
    echo '[Service]' >> /lib/systemd/system/lxc-iptag.service
    echo 'ExecStart=/usr/local/bin/lxc-iptag' >> /lib/systemd/system/lxc-iptag.service
    echo '[Install]' >> /lib/systemd/system/lxc-iptag.service
    echo 'WantedBy=multi-user.target' >> /lib/systemd/system/lxc-iptag.service
    chmod 644 /lib/systemd/system/lxc-iptag.service
    sudo systemctl daemon-reload
    sudo systemctl enable lxc-iptag.service
    sudo systemctl start lxc-iptag.service
  "
}

for container in $(pct list | awk '{if(NR>1) print $1}'); do
  if [[ " ${excluded_containers[@]} " =~ " $container " ]]; then
    header_info
    echo -e "${BL}[Info]${GN} Skipping ${BL}$container${CL}"
    sleep 1
  else
    os=$(pct config "$container" | awk '/^ostype/ {print $2}')
    if [ "$os" != "debian" ] && [ "$os" != "ubuntu" ]; then
      header_info
      echo -e "${BL}[Info]${GN} Skipping ${name} ${RD}$container is not Debian or Ubuntu ${CL} \n"
      sleep 1
      continue
    fi

    status=$(pct status $container)
    template=$(pct config $container | grep -q "template:" && echo "true" || echo "false")
    if [ "$template" == "false" ] && [ "$status" == "status: stopped" ]; then
      echo -e "${BL}[Info]${GN} Starting${BL} $container ${CL} \n"
      pct start $container
      echo -e "${BL}[Info]${GN} Waiting For${BL} $container${CL}${GN} To Start ${CL} \n"
      sleep 5
      install_iptag_tools $container
      echo -e "${BL}[Info]${GN} Shutting down${BL} $container ${CL} \n"
      pct shutdown $container &
    elif [ "$status" == "status: running" ]; then
      install_iptag_tools $container
    fi
  fi
done

wait
header_info
echo -e "${GN} Finished, Selected Containers IP Tags Applied. ${CL} \n"