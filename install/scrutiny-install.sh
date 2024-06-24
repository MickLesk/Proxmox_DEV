#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/AnalogJ/scrutiny

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  build-essential \
  sudo \
  git \
  curl \
  smartmontools  \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Scrutiny"
mkdir -p /opt/scrutiny/config
mkdir -p /opt/scrutiny/web
mkdir -p /opt/scrutiny/bin
wget -q -O wget -q -O /opt/scrutiny/config/scrutiny.yaml https://raw.githubusercontent.com/AnalogJ/scrutiny/master/example.scrutiny.yaml
RELEASE=$(curl -s https://api.github.com/repos/analogj/scrutiny/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q -O /opt/scrutiny/bin/scrutiny-web-linux-amd64 "https://github.com/AnalogJ/scrutiny/releases/download/${RELEASE}/scrutiny-web-linux-amd64"
wget -q -O /opt/scrutiny/web/scrutiny-web-frontend.tar.gz "https://github.com/AnalogJ/scrutiny/releases/download/${RELEASE}/scrutiny-web-frontend.tar.gz"
wget -q -O /opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64 "https://github.com/AnalogJ/scrutiny/releases/download/${RELEASE}/scrutiny-collector-metrics-linux-amd64"
cd /opt/scrutiny/web && tar xvzf scrutiny-web-frontend.tar.gz --strip-components 1 -C .
chmod +x /opt/scrutiny/bin/scrutiny-web-linux-amd64
chmod +x /opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64
msg_ok "Installed Scrutiny"

msg_info "Setup InfluxDB-Connection" 
DEFAULT_HOST="0.0.0.0"
DEFAULT_PORT="8086"
DEFAULT_TOKEN="my-token"
DEFAULT_ORG="my-org"
DEFAULT_BUCKET="bucket"
prompt_input() {
    local prompt="$1"
    local default_value="$2"
    local result
    result=$(whiptail --inputbox "$prompt" 8 78 "$default_value" --timeout 60 3>&1 1>&2 2>&3)
    if [ -z "$result" ]; then
        result="$default_value"
    fi
    echo "$result"
}
HOST=$(prompt_input "Enter InfluxDB-Host/IP:" "$DEFAULT_HOST")
PORT=$(prompt_input "Enter InfluxDB Port:" "$DEFAULT_PORT")
TOKEN=$(prompt_input "Enter InfluxDB Token (optional):" "$DEFAULT_TOKEN")
ORG=$(prompt_input "Enter InfluxDB Organization (optional):" "$DEFAULT_ORG")
BUCKET=$(prompt_input "Enter InfluxDB Bucket (optional):" "$DEFAULT_BUCKET")
CONFIG_FILE="/opt/scrutiny/config/scrutiny.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
fi
sed -i -e "s/^host:.*$/host: $HOST/" \
       -e "s/^port:.*$/port: $PORT/" \
       "$CONFIG_FILE"
if [ "$TOKEN" != "$DEFAULT_TOKEN" ]; then
    sed -i -e "s/^#\s*token:.*$/token: '$TOKEN'/" "$CONFIG_FILE"
else
    sed -i -e "s/^\s*token:.*$/#token: '$DEFAULT_TOKEN'/" "$CONFIG_FILE"
fi
if [ "$ORG" != "$DEFAULT_ORG" ]; then
    sed -i -e "s/^#\s*org:.*$/org: '$ORG'/" "$CONFIG_FILE"
else
    sed -i -e "s/^\s*org:.*$/#org: '$DEFAULT_ORG'/" "$CONFIG_FILE"
fi
if [ "$BUCKET" != "$DEFAULT_BUCKET" ]; then
    sed -i -e "s/^#\s*bucket:.*$/bucket: '$BUCKET'/" "$CONFIG_FILE"
else
    sed -i -e "s/^\s*bucket:.*$/#bucket: '$DEFAULT_BUCKET'/" "$CONFIG_FILE"
fi
msg_ok ""

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/scrutiny.service
[Unit]
Description=Scrutiny - Hard Drive Monitoring and Webapp
After=network.target

[Service]
Type=simple
ExecStart=/opt/scrutiny/bin/scrutiny-web-linux-amd64 start --config /opt/scrutiny/config/scrutiny.yaml
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now scrutiny.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
