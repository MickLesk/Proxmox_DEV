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
  sudo \
  curl \
  smartmontools  \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Scrutiny"
mkdir -p /opt/scrutiny/config
mkdir -p /opt/scrutiny/web
mkdir -p /opt/scrutiny/bin
wget -q -O /opt/scrutiny/config/scrutiny.yaml https://raw.githubusercontent.com/AnalogJ/scrutiny/master/example.scrutiny.yaml
RELEASE=$(curl -s https://api.github.com/repos/analogj/scrutiny/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q -O /opt/scrutiny/bin/scrutiny-web-linux-amd64 "https://github.com/AnalogJ/scrutiny/releases/download/${RELEASE}/scrutiny-web-linux-amd64"
wget -q -O /opt/scrutiny/web/scrutiny-web-frontend.tar.gz "https://github.com/AnalogJ/scrutiny/releases/download/${RELEASE}/scrutiny-web-frontend.tar.gz"
#wget -q -O /opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64 "https://github.com/AnalogJ/scrutiny/releases/download/${RELEASE}/scrutiny-collector-metrics-linux-amd64"
cd /opt/scrutiny/web && tar xzf scrutiny-web-frontend.tar.gz --strip-components 1 -C .
chmod +x /opt/scrutiny/bin/scrutiny-web-linux-amd64
chmod +x /opt/scrutiny/bin/scrutiny-collector-metrics-linux-amd64
msg_ok "Installed Scrutiny"

DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8086"
DEFAULT_TOKEN="my-token"
DEFAULT_ORG="my-org"
DEFAULT_BUCKET="bucket"

# Prompt the user for input
read -r -p "Enter InfluxDB Host/IP [$DEFAULT_HOST]: " HOST
HOST=${HOST:-$DEFAULT_HOST}

read -r -p "Enter InfluxDB Port [$DEFAULT_PORT]: " PORT
PORT=${PORT:-$DEFAULT_PORT}

read -r -p "Enter InfluxDB Token [$DEFAULT_TOKEN]: " TOKEN
TOKEN=${TOKEN:-$DEFAULT_TOKEN}

read -r -p "Enter InfluxDB Organization [$DEFAULT_ORG]: " ORG
ORG=${ORG:-$DEFAULT_ORG}

read -r -p "Enter InfluxDB Bucket [$DEFAULT_BUCKET]: " BUCKET
BUCKET=${BUCKET:-$DEFAULT_BUCKET}

msg_info "Setup InfluxDB-Connection" 
# Path to the config file
CONFIG_FILE="/opt/scrutiny/config/scrutiny.yaml"

# Update the config file using sed
sed -i -e "/influxdb:/,/^  [^ ]/s/^\(\s*host:\).*/\1 $HOST/" \
       -e "/influxdb:/,/^  [^ ]/s/^\(\s*port:\).*/\1 $PORT/" \
       "$CONFIG_FILE"

if [ "$TOKEN" != "$DEFAULT_TOKEN" ]; then
    sed -i -e "/influxdb:/,/^  [^ ]/s/^#\s*\(token:\).*/  \1 '$TOKEN'/" "$CONFIG_FILE"
else
    sed -i -e "/influxdb:/,/^  [^ ]/s/^\s*\(token:\).*/#  \1 '$DEFAULT_TOKEN'/" "$CONFIG_FILE"
fi

if [ "$ORG" != "$DEFAULT_ORG" ]; then
    sed -i -e "/influxdb:/,/^  [^ ]/s/^#\s*\(org:\).*/  \1 '$ORG'/" "$CONFIG_FILE"
else
    sed -i -e "/influxdb:/,/^  [^ ]/s/^\s*\(org:\).*/#  \1 '$DEFAULT_ORG'/" "$CONFIG_FILE"
fi

if [ "$BUCKET" != "$DEFAULT_BUCKET" ]; then
    sed -i -e "/influxdb:/,/^  [^ ]/s/^#\s*\(bucket:\).*/  \1 '$BUCKET'/" "$CONFIG_FILE"
else
    sed -i -e "/influxdb:/,/^  [^ ]/s/^\s*\(bucket:\).*/#  \1 '$DEFAULT_BUCKET'/" "$CONFIG_FILE"
fi
msg_ok "Setup InfluxDB-Connection"

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
