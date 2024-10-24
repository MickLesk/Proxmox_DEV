#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/seanmorley15/AdventureLog

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
  mc \
  git \
  gdal-bin \
  libgdal-dev \
  python3-venv \
  python3-pip
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
msg_ok "Set up Node.js Repository"

msg_info "Setting up PostgreSQL Repository"
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
echo "deb https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" >/etc/apt/sources.list.d/pgdg.list
msg_ok "Set up PostgreSQL Repository"

msg_info "Installing Node.js"
$STD apt-get update
$STD apt-get install -y nodejs
$STD npm install -g pnpm
msg_ok "Installed Node.js"

msg_info "Install/Set up PostgreSQL Database"
$STD apt-get install -y postgresql-16 postgresql-16-postgis
DB_NAME="adventurelog_db"
DB_USER="adventurelog_user"
DB_PASS="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)"
SECRET_KEY="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | cut -c1-32)"
DJANGO_ADMIN_USER="djangoadmin"
DJANGO_ADMIN_PASS="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)"
DJANGO_ADMIN_EMAIL="django@localhost.com"
sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' TEMPLATE template0;"
sudo -u postgres psql -c "CREATE EXTENSION postgis; $DB_NAME"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';"
{
    echo "AdventureLog-Credentials"
    echo "AdventureLog Database User: $DB_USER"
    echo "AdventureLog Database Password: $DB_PASS"
    echo "AdventureLog Database Name: $DB_NAME"
    echo "AdventureLog Secret: $SECRET_KEY"
    echo ""
    echo "Django-Credentials"
    echo "Django Admin User: $DJANGO_ADMIN_USER"
    echo "Django Admin Password: $DJANGO_ADMIN_PASS"
    echo "Django E-Mail: $DJANGO_ADMIN_EMAIL"
} >> ~/adventurelog.creds
msg_ok "Set up PostgreSQL"

msg_info "Installing AdventureLog (Patience)"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/seanmorley15/AdventureLog/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/seanmorley15/AdventureLog/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv AdventureLog-${RELEASE} /opt/adventurelog
cd /opt/adventurelog/backend/server
mv .env.example .env
sed -i -e "s|PGHOST=''|PGHOST='localhost'|" \
       -e "s|PGDATABASE=''|PGDATABASE='$DB_NAME'|" \
       -e "s|PGUSER=''|PGUSER='$DB_USER'|" \
       -e "s|PGPASSWORD=''|PGPASSWORD='$DB_PASS'|" \
       -e "s|SECRET_KEY=.*|SECRET_KEY='$SECRET_KEY'|" \
       -e "s|DEBUG=True|DEBUG=False|" .env
cd /opt/adventurelog/backend/server
pip install --upgrade pip
pip install -r requirements.txt
python3 manage.py collectstatic --noinput --verbosity 2
python3 manage.py migrate
cd /opt/adventurelog/frontend
mv .env.example .env
pnpm install
pnpm run build
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Installed AdventureLog"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/adventurelog-backend.service
[Unit]
Description=AdventureLog Backend Service
After=network.target postgresql.service

[Service]
WorkingDirectory=/opt/adventurelog/backend/server
ExecStart=python3 manage.py runserver 0.0.0.0:8000
Restart=always
EnvironmentFile=/opt/adventurelog/backend/server/.env

[Install]
WantedBy=multi-user.target
EOF
cat <<EOF >/etc/systemd/system/adventurelog-frontend.service
[Unit]
Description=AdventureLog SvelteKit Frontend Service
After=network.target

[Service]
WorkingDirectory=/opt/adventurelog/frontend
ExecStart=/usr/bin/node build
Restart=always
EnvironmentFile=/opt/adventurelog/frontend/.env

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now adventurelog-backend.service
systemctl enable --now adventurelog-frontend.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /opt/v${RELEASE}.zip
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"