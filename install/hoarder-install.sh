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
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Installing Hoarder"

INSTALLATION_DIR=/opt/hoarder
DATA_DIR=/var/lib/hoarder
CONFIG_DIR=/etc/hoarder/hoarder.env
ENV_FILE="$CONFIG_DIR/hoarder.env"

# Prepare the directories
mkdir -p $INSTALLATION_DIR $DATA_DIR $CONFIG_DIR

# Download and extract the latest release
/mkdir -p /tmp/hoarder
cd /tmp/hoarder
RELEASE=$(curl -s https://api.github.com/repos/hoarder-app/hoarder/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/hoarder-app/hoarder/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv hoarder-${RELEASE} $INSTALLATION_DIR

# Install dependencies
cd $INSTALLATION_DIR
corepack enable
export PUPPETEER_SKIP_DOWNLOAD="true"
cd $INSTALLATION_DIR/apps/web && pnpm install --frozen-lockfile
cd $INSTALLATION_DIR/apps/workers && pnpm install --frozen-lockfile

# Build the web app
cd $INSTALLATION_DIR/apps/web
pnpm exec next build --experimental-build-mode compile

echo "${RELEASE}" >"/opt/hoarder_version.txt"

# Prepare the environment file
cat <<EOF >$ENV_FILE
NEXTAUTH_SECRET="$(openssl rand -base64 36)"
DATA_DIR="/var/lib/hoarder"
MEILI_ADDR="http://127.0.0.1:7700"
MEILI_MASTER_KEY="$(openssl rand -base64 36)"
NEXTAUTH_URL="http://localhost:3000"
NODE_ENV=production
EOF
msg_ok "Installed Hoarder"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/hoarder-web.service
[Unit]
Description=Hoarder Web
After=network.target

[Service]
ExecStart=pnpm start
WorkingDirectory=$INSTALLATION_DIR/apps/web
Restart=always
RestartSec=10

EnvironmentFile=$ENV_FILE

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/hoarder-workers.service
[Unit]
Description=Hoarder Workers
After=network.target

[Service]
ExecStart=pnpm start:prod
WorkingDirectory=$INSTALLATION_DIR/apps/workers
Restart=always
RestartSec=10

EnvironmentFile=$ENV_FILE

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hoarder-web.service
systemctl enable -q --now hoarder-workers.service
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
rm -R /tmp/hoarder
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"