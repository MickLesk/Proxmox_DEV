#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    __  __                     __         
   / / / /___  ____ __________/ /__  _____
  / /_/ / __ \/ __ `/ ___/ __  / _ \/ ___/
 / __  / /_/ / /_/ / /  / /_/ /  __/ /    
/_/ /_/\____/\__,_/_/   \__,_/\___/_/     
                                          
EOF
}
header_info
echo -e "Loading..."
APP="Hoarder"
var_disk="8"
var_cpu="2"
var_ram="4096"
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
header_info
check_container_storage
check_container_resources
if [[ ! -d /opt/hoarder ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
RELEASE=$(curl -s https://api.github.com/repos/msgbyte/hoarder/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
  msg_info "Stopping ${APP} Service"
  systemctl stop hoarder
  msg_ok "Stopped ${APP} Service"
  msg_info "Updating ${APP} to ${RELEASE}"
  cd /opt
  cp /opt/hoarder/src/server/.env /opt/.env
  mv /opt/hoarder /opt/hoarder_bak
  wget -q "https://github.com/msgbyte/hoarder/archive/refs/tags/v${RELEASE}.zip"
  unzip -q v${RELEASE}.zip
  mv hoarder-${RELEASE} /opt/hoarder
  cd hoarder
  pnpm install --filter @hoarder/client... --config.dedupe-peer-dependents=false --frozen-lockfile >/dev/null 2>&1
  pnpm build:static >/dev/null 2>&1
  pnpm install --filter @hoarder/server... --config.dedupe-peer-dependents=false >/dev/null 2>&1
  mkdir -p ./src/server/public >/dev/null 2>&1
  cp -r ./geo ./src/server/public >/dev/null 2>&1
  pnpm build:server >/dev/null 2>&1
  mv /opt/.env /opt/hoarder/src/server/.env 
  cd src/server
  pnpm db:migrate:apply >/dev/null 2>&1
  echo "${RELEASE}" >/opt/${APP}_version.txt
  msg_ok "Updated ${APP} to ${RELEASE}"
  msg_info "Starting ${APP}"
  systemctl start hoarder
  msg_ok "Started ${APP}"
  msg_info "Cleaning up"
  rm -R /opt/v${RELEASE}.zip
  rm -rf /opt/hoarder_bak
  rm -rf /opt/hoarder/src/client
  rm -rf /opt/hoarder/website
  rm -rf /opt/hoarder/reporter
  msg_ok "Cleaned"
  msg_ok "Updated Successfully"
else
  msg_ok "No update required.  ${APP} is already at ${RELEASE}."
fi
exit
}

start
build_container
description

msg_info "Setting Container RAM to 2GB"
pct set $CTID -memory 2048
msg_ok "RAM set to 2GB"

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:3000${CL} \n"
