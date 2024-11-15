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

msg_info "Installing Dependencies"
$STD apt-get install -y \
  postgresql \
  python3 \
  g++ \
  build-essential \
  curl \
  sudo \
  gnupg \
  ca-certificates \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Node.js"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
$STD npm install -g pnpm
$STD pnpm add typescript
export NODE_OPTIONS="--max_old_space_size=4096"
msg_ok "Installed Node.js"

msg_info "Setting up PostgreSQL"
DB_NAME=hoarder_db
DB_USER=hoarder_user
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
HOARDER_SECRET="$(openssl rand -base64 32 | cut -c1-24)"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 
$STD sudo -u postgres psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
$STD sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
echo "" >>~/hoarder.creds
echo -e "Hoarder Database User: $DB_USER" >>~/hoarder.creds
echo -e "Hoarder Database Password: $DB_PASS" >>~/hoarder.creds
echo -e "Hoarder Database Name: $DB_NAME" >>~/hoarder.creds
echo -e "Hoarder Secret: $HOARDER_SECRET" >>~/hoarder.creds
msg_ok "Set up PostgreSQL"

msg_info "Installing Hoarder (Extreme Patience)"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/hoarder-app/hoarder/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/hoarder-app/hoarder/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv hoarder-${RELEASE} /opt/hoarder
cd /opt/hoarder
pnpm install --no-frozen-lockfile

cd /opt/hoarder/packages/db
pnpm dlx @vercel/ncc build migrate.ts -o /db_migrations
cp -R drizzle /db_migrations

cd /opt/hoarder/apps/web
pnpm exec next build --experimental-build-mode compile

#cd /opt/hoarder/apps/workers
#pnpm deploy --node-linker=isolated --filter @hoarder/workers --prod /prod/workers

cd /opt/hoarder/apps/cli
pnpm build

echo "${RELEASE}" >"/opt/hoarder_version.txt"
cat <<EOF >/opt/hoarder/src/server/.env
DATABASE_URL="postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME?schema=public"
NEXTAUTH_SECRET="$HOARDER_SECRET"
DATA_DIR="/data"
MEILI_ADDR="http://127.0.0.1:7700"
MEILI_MASTER_KEY="$(openssl rand -base64 36)"
NEXTAUTH_URL="http://localhost:3000"
EOF
cd /opt/hoarder/src/server
$STD pnpm db:migrate:apply
msg_ok "Installed Hoarder"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/hoarder.service
[Unit]
Description=Hoarder Server
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/hoarder/src/server/dist/src/server/main.js
WorkingDirectory=/opt/hoarder/src/server
Restart=always
RestartSec=10

Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hoarder.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -R /opt/v${RELEASE}.zip
rm -rf /opt/hoarder/src/client
rm -rf /opt/hoarder/website
rm -rf /opt/hoarder/reporter
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
