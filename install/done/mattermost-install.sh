#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://mattermost.com/

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  postgresql \
  gpg \
  curl \
  sudo \
  mc
msg_ok "Installed Dependencies"

msg_info "Setting up PostgreSQL"
DB_NAME=mattermostdb
DB_USER=mattermost
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
$STD sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' TEMPLATE template0;"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC'"
echo "" >>~/mattermost.creds
echo -e "Mattermost Database User: $DB_USER" >>~/mattermost.creds
echo -e "Mattermost Database Password: $DB_PASS" >>~/mattermost.creds
echo -e "Mattermost Database Name: $DB_NAME" >>~/mattermost.creds
msg_ok "Set up PostgreSQL"

msg_info "Installing Mattermost (Patience)"
wget -qO- https://releases.mattermost.com/10.0.0/mattermost-team-10.0.0-linux-amd64.tar.gz| tar -xzf - -C /opt
sudo mkdir /opt/mattermost/data
cd /opt/mattermost
sudo useradd --system --user-group mattermost
sudo chown -R mattermost:mattermost /opt/mattermost
sudo chmod -R g+w /opt/mattermost
sudo sed -i "s|\"DataSource\": \".*\"|\"DataSource\": \"postgres://$DB_USER:$DB_PASS@localhost/$DB_NAME?sslmode=disable&connect_timeout=10\"|" /opt/mattermost/config/config.json
msg_ok "Installed Zipline"

msg_info "Creating Service"
cat <<EOF >/lib/systemd/system/mattermost.service
[Unit]
Description=Mattermost
After=network.target

[Service]
Type=notify
ExecStart=/opt/mattermost/bin/mattermost
TimeoutStartSec=3600
KillMode=mixed
Restart=always
RestartSec=10
WorkingDirectory=/opt/mattermost
User=mattermost
Group=mattermost
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now mattermost.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"