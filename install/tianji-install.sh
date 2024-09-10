#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/MickLesk/Proxmox_DEV/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y --no-install-recommends \
  postgresql \
  build-essential \
  curl \
  unzip \
  sudo \
  git \
  make \
  gnupg \
  ca-certificates \
  mc
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
msg_ok "Set up Repositories"

msg_info "Installing Node.js, pnpm & pm2"
$STD apt-get install -y nodejs
$STD npm install -g pnpm@9.7.1
$STD npm install -g pm2 
msg_ok "Installed Node.js, pnpm & pm2"


msg_info "Setup Tianji (Patience)"
cd /opt
$STD git clone https://github.com/msgbyte/tianji.git
cd tianji
$STD pnpm install
$STD pnpm build
msg_ok "Initial Setup complete"

msg_info "Setting up Database"
DB_NAME=tianji_db
DB_USER=tianji
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
TIANJI_SECRET=$(uuidgen)
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 
$STD sudo -u postgres psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
$STD sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
echo "" >>~/tianji.creds
echo -e "Tianji Database User: $DB_USER" >>~/tianji.creds
echo -e "Tianji Database Password: $DB_PASS" >>~/tianji.creds
echo -e "Tianji Database Name: $DB_NAME" >>~/tianji.creds
msg_ok "Set up PostgreSQL database"

msg_info "Setting up Tianji Env"
cat <<EOF >/opt/tianji/src/server/.env
DATABASE_URL="postgresql://$DB_USER:$DB_PASS@127.0.0.1:5432/$DB_NAME?schema=public"
JWT_SECRET="$TIANJI_SECRET"
EOF
msg_ok ".env successfully set up"

msg_info "Initialize Application"
cd /opt/tianji
npm install pm2 -g && pm2 install pm2-logrotate
cd src/server
pnpm db:migrate:apply
pm2 start ./dist/src/server/main.js --name tianji
msg_ok "Application Initialized"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
