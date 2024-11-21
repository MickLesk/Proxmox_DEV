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
whiptail --backtitle "Proxmox VE Helper Scripts" --title "Proxmox VE LXC IP-Tag" --yesno "This can add IP-Tags to your LXCs. Proceed?" 10 58 || exit

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
  container=$1
  header_info
  name=$(pct exec "$container" hostname)

  # Hier die IP-Tagging-Logik für den Container anwenden
  cidr_list=( 192.168.0.0/16 100.64.0.0/10 10.0.0.0/8 )

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

  is_valid_ipv4() {
      local ip=$1
      local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
      if [[ $ip =~ $regex ]]; then
          IFS='.' read -r -a parts <<< "$ip"
          for part in "${parts[@]}"; do
              if ! [[ $part =~ ^[0-9]+$ ]] || ((part < 0 || part > 255)); then
                  return 1
              fi
          done
          return 0
      else
          return 1
      fi
  }

  main() {
      lxc_name_list=$(pct list 2>/dev/null | grep -v VMID | awk '{print $1}')
      for lxc_name in ${lxc_name_list}; do
          new_tags=()
          old_ips=()
          new_ips=()

          old_tags=$(pct config "${lxc_name}" | grep tags | awk '{print $2}' | sed 's/;/ /g')
          for old_tag in ${old_tags}; do
              if is_valid_ipv4 "${old_tag}"; then
                  old_ips+=("${old_tag}")
                  continue
              fi
              new_tags+=("${old_tag}")
          done

          ips=$(lxc-info -n "${lxc_name}" -i | awk '{print $2}')
          for ip in ${ips}; do
              if is_valid_ipv4 "${ip}" && ip_in_cidrs "${ip}"; then
                  new_ips+=("${ip}")
                  new_tags+=("${ip}")
              fi
          done

          if [[ "$(echo "${old_ips[@]}" | tr ' ' '\n' | sort -u)" == "$(echo "${new_ips[@]}" | tr ' ' '\n' | sort -u)" ]]; then
              echo "Skipping ${lxc_name} because IPs haven't changed"
              continue
          fi

          joined_tags=$(IFS=';'; echo "${new_tags[*]}")
          echo "Setting ${lxc_name} tags from ${old_tags} to ${joined_tags}"
          pct set "${lxc_name}" -tags "${joined_tags}"
      done
      sleep 60
  }

  main

  # Service-Datei erstellen und aktivieren
  cat <<EOF >/lib/systemd/system/lxc-iptag.service
  [Unit]
  Description=Start lxc-iptag service
  After=network.target
  
  [Service]
  Type=simple
  ExecStart=/usr/local/bin/lxc-iptag
  Restart=always
  
  [Install]
  WantedBy=multi-user.target
  EOF

  systemctl daemon-reload
  systemctl enable -q -now lxc-iptag.service
}

# Container durchgehen
for container in $excluded_containers; do
  os=$(pct config "$container" | awk '/^ostype/ {print $2}')
  if [ "$os" != "debian" ] && [ "$os" != "ubuntu" ]; then
    header_info
    echo -e "${BL}[Info]${GN} Skipping ${RD}$container is not Debian or Ubuntu ${CL} \n"
    sleep 1
    continue
  fi

  status=$(pct status $container)
  template=$(pct config $container | grep -q "template:" && echo "true" || echo "false")
  if [ "$template" == "false" ] && [ "$status" == "status: stopped" ]; then
    echo -e "${BL}[Info]${GN} Starting ${BL}$container ${CL} \n"
    pct start $container
    echo -e "${BL}[Info]${GN} Waiting For ${BL}$container ${GN} To Start ${CL} \n"
    sleep 5
    install_iptag_tools $container
    echo -e "${BL}[Info]${GN} Shutting down ${BL}$container ${CL} \n"
    pct shutdown $container &
  elif [ "$status" == "status: running" ]; then
    install_iptag_tools $container
  fi
done

wait
header_info
echo -e "${GN} Finished, IP Tags applied to selected containers. ${CL} \n"
