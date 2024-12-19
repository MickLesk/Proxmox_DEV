#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/documenso/documenso

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  gpg \
  curl \
  sudo \
  libc6-compat \
  jq \
  postgresql 
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
msg_ok "Set up Node.js Repository"

msg_info "Installing Node.js"
$STD apt-get update
$STD apt-get install -y nodejs
$STD npm install -g pnpm
$STD npm install -g "turbo@^1.9.3"
msg_ok "Installed Node.js"

msg_info "Setting up PostgreSQL"
DB_NAME="documenso_db"
DB_USER="documenso_user"
DB_PASS="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)"
$STD sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' TEMPLATE template0;"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC'"
{
    echo "Documenso-Credentials"
    echo "Database Name: $DB_NAME"
    echo "Database User: $DB_USER"
    echo "Database Password: $DB_PASS"
} >> ~/documenso.creds
msg_ok "Set up PostgreSQL"

msg_info "Installing Documenso (Patience)"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/documenso/documenso/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/documenso/documenso/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv documenso-${RELEASE} /opt/documenso
cd /opt/documenso
mv .env.example .env
sed -i "s|NEXTAUTH_URL=.*|NEXTAUTH_URL='http://localhost:9000'|" /opt/documenso/.env
sed -i "s|NEXTAUTH_SECRET=.*|NEXTAUTH_SECRET='$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | cut -c1-32)'|" /opt/documenso/.env
sed -i "s|NEXT_PUBLIC_WEBAPP_URL=.*|NEXT_PUBLIC_WEBAPP_URL='http://localhost:9000'|" /opt/documenso/.env
sed -i "s|NEXT_PRIVATE_DATABASE_URL=.*|NEXT_PRIVATE_DATABASE_URL=\"postgres://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME\"|" /opt/documenso/.env
export NODE_OPTIONS="--max-old-space-size=3072"
export TURBO_CACHE=1
export NEXT_TELEMETRY_DISABLED=1

$STD npm ci
echo "install done"
npm run build
echo "run build done"
npm run prisma:migrate-deploy
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Installed Documenso"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/documenso.service
[Unit]
Description=Documenso Service
After=network.target postgresql.service

[Service]
WorkingDirectory=/opt/documenso
ExecStart=/usr/bin/npm run start
Restart=always
EnvironmentFile=/opt/documenso/.env

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now documenso.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"