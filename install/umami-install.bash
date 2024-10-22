#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/diced/zipline

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

msg_info "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
msg_ok "Set up Node.js Repository"

msg_info "Installing Node.js"
$STD apt-get update
$STD apt-get install -y nodejs
$STD npm install -g yarn
msg_ok "Installed Node.js"

msg_info "Setting up PostgreSQL"
DB_NAME=umamidb
DB_USER=umami
DB_PASS="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)"
$STD sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' TEMPLATE template0;"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC'"
echo "" >>~/umami.creds
echo -e "Umami Database User: $DB_USER" >>~/umami.creds
echo -e "Umami Database Password: $DB_PASS" >>~/umami.creds
echo -e "Umami Database Name: $DB_NAME" >>~/umami.creds
msg_ok "Set up PostgreSQL"

msg_info "Installing Umami (Patience)"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/umami-software/umami/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/umami-software/umami/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv umami-${RELEASE} /opt/umami
cd /opt/umami
$STD yarn install
cat <<EOF >/opt/umami/.env
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME
EOF
$STD yarn build
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Installed Umami"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/umami.service
[Unit]
Description=Umami Service
After=network.target

[Service]
WorkingDirectory=/opt/umami
ExecStart=/usr/bin/yarn start
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now umami.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"