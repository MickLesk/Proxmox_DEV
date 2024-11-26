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
  git \
  sudo \
  gnupg \
  ca-certificates \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Hoarder Dependencies"
cd /tmp

wget -q https://github.com/Y2Z/monolith/releases/latest/download/monolith-gnu-linux-x86_64 -O monolith 
chmod +x monolith
mv monolith /usr/bin

wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O yt-dlp
chmod +x yt-dlp 
mv yt-dlp /usr/bin

wget -q https://github.com/meilisearch/meilisearch/releases/latest/download/meilisearch.deb
$STD dpkg -i meilisearch.deb 
msg_ok "Installed Hoarder Dependencies"

msg_info "Installing Node.js"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Installing Hoarder"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/hoarder-app/hoarder/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/hoarder-app/hoarder/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv hoarder-${RELEASE} /opt/hoarder
cd /opt/hoarder
corepack enable
export PUPPETEER_SKIP_DOWNLOAD="true"
export NEXT_TELEMETRY_DISABLED=1
cd /opt/hoarder/apps/web
echo -e "web start" 
yes | pnpm install --frozen-lockfile 
echo -e "web done" 
cd /opt/hoarder/apps/workers
echo -e "worker start" 
pnpm install --frozen-lockfile
echo -e "worker done" 

# Build the web app
echo -e "web build start" 
cd /opt/hoarder/apps/web
pnpm exec next build --experimental-build-mode compile
cp -r /opt/hoarder/apps/web/.next/standalone/apps/web/server.js /opt/hoarder/apps/web

echo "${RELEASE}" >"/opt/Hoarder_version.txt"
HOARDER_SECRET="$(openssl rand -base64 32 | cut -c1-24)"
MEILI_SECRET="$(openssl rand -base64 36)"
{
    echo ""
    echo "Hoarder-Credentials"
    echo "Meilisearch Secret: $MEILI_SECRET"
    echo "Hoarder Secret: $HOARDER_SECRET"
} >> ~/babybuddy.creds
# Prepare the environment file
cat <<EOF >/opt/hoarder/.env
NEXTAUTH_SECRET="$HOARDER_SECRET"
NEXTAUTH_URL="http://localhost:3000"
DATA_DIR="/opt/hoarder"
MEILI_ADDR="http://127.0.0.1:7700"
MEILI_MASTER_KEY="$MEILI_SECRET"
BROWSER_WEB_URL="http://127.0.0.1:9222"
CRAWLER_VIDEO_DOWNLOAD=true
#CRAWLER_VIDEO_DOWNLOAD_MAX_SIZE=
#OLLAMA_BASE_URL=
#INFERENCE_TEXT_MODEL=
#INFERENCE_IMAGE_MODEL=
EOF

cd /opt/hoarder/packages/db
pnpm migrate
msg_ok "Installed Hoarder"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/hoarder-web.service
[Unit]
Description=Hoarder Web
After=network.target

[Service]
ExecStart=pnpm start
WorkingDirectory=/opt/hoarder/apps/web
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
WorkingDirectory=/opt/hoarder/apps/workers
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
rm -rf /tmp/meilisearch.deb
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"