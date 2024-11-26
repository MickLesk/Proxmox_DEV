#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/MickLesk/Proxmox_DEV/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

## App Default Values
APP="Zabbix"
TAGS="monitoring;alerts;network"
var_disk="5"
var_cpu="2"
var_ram="4096"
var_os="debian"
var_version="12"
#var_verbose="yes"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core 
variables
color
catch_errors

function update_script() {
header_info
check_container_storage
check_container_resources
if [[ ! -f /etc/zabbix/zabbix_server.conf ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Stopping ${APP} Services"
systemctl stop zabbix-server-pgsql zabbix-agent2
msg_ok "Stopped ${APP} Services"

msg_info "Updating $APP LXC"
mkdir -p /opt/zabbix-backup/
cp /etc/zabbix/zabbix_server.conf /opt/zabbix-backup/
cp /etc/apache2/conf-enabled/zabbix.conf /opt/zabbix-backup/
cp -R /usr/share/zabbix/ /opt/zabbix-backup/
cp -R /usr/share/zabbix-* /opt/zabbix-backup/
cd /tmp
wget -q https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_latest+debian12_all.deb
dpkg -i zabbix-release_latest+debian12_all.deb &>/dev/null
apt-get install --only-upgrade zabbix-server-pgsql zabbix-frontend-php zabbix-agent2 &>/dev/null

msg_info "Starting ${APP} Services"
systemctl start zabbix-server-pgsql zabbix-agent2
systemctl restart apache2
msg_ok "Started ${APP} Services"

msg_info "Cleaning Up"
rm -rf /tmp/zabbix-release_latest+debian12_all.deb
msg_ok "Cleaned"
msg_ok "Updated Successfully"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}/zabbix${CL} \n"
