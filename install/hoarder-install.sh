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
$STD apt-get install -y \
  g++ \
  build-essential \
  curl \
  sudo \
  gnupg \
  ca-certificates \
  chromium \
  mc

wget -q https://github.com/Y2Z/monolith/releases/latest/download/monolith-gnu-linux-x86_64 -O monolith && \
  chmod +x monolith && mv monolith /usr/bin

wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O yt-dlp && \
  chmod +x yt-dlp && mv yt-dlp /usr/bin

wget -q https://github.com/meilisearch/meilisearch/releases/latest/download/meilisearch.deb && \
  $STD dpkg -i meilisearch.deb &>/dev/null && rm meilisearch.deb

msg_ok "Installed Dependencies"

msg_info "Installing Node.js"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Installing Hoarder (More patience)"

TMP_DIR=/tmp/hoarder
INSTALL_DIR=/opt/hoarder
DATA_DIR=/var/lib/hoarder
CONFIG_DIR=/etc/hoarder
ENV_FILE="$CONFIG_DIR/hoarder.env"

mkdir -p $TMP_DIR $INSTALL_DIR $DATA_DIR $CONFIG_DIR

cd $TMP_DIR
RELEASE=$(curl -s https://api.github.com/repos/hoarder-app/hoarder/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/hoarder-app/hoarder/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv hoarder-${RELEASE}/* $INSTALL_DIR

cd $INSTALL_DIR
corepack enable
export NEXT_TELEMETRY_DISABLED=1
export PUPPETEER_SKIP_DOWNLOAD="true"
cd $INSTALL_DIR/apps/web && echo y\n | pnpm install --frozen-lockfile >/dev/null 2>&1
cd $INSTALL_DIR/apps/workers && $STD pnpm install --frozen-lockfile

cd $INSTALL_DIR/apps/web
$STD pnpm exec next build --experimental-build-mode compile
cp -r $INSTALL_DIR/apps/web/.next/standalone/apps/web/server.js $INSTALL_DIR/apps/web

# this will fail - not yet sure why
# msg_info "Building cli"
# cd /opt/hoarder/apps/cli
# pnpm build >/dev/null 2>&1
# msg_ok "cli installed"

echo "${RELEASE}" >"/opt/hoarder_version.txt"
HOARDER_SECRET="$(openssl rand -base64 32 | cut -c1-24)"
MEILI_SECRET="$(openssl rand -base64 36)"
echo "" >>~/hoarder.creds && chmod 600 ~/hoarder.creds
echo -e "NextAuth Secret: $HOARDER_SECRET" >>~/hoarder.creds
echo -e "Meilisearch Master Key: $MEILI_SECRET" >>~/hoarder.creds

cat <<EOF >$ENV_FILE
NEXTAUTH_SECRET="$HOARDER_SECRET"
NEXTAUTH_URL=
DATA_DIR="$DATA_DIR"
MEILI_ADDR="http://127.0.0.1:7700"
MEILI_MASTER_KEY="$MEILI_SECRET"
BROWSER_WEB_URL="http://127.0.0.1:9222"
CRAWLER_VIDEO_DOWNLOAD=true
#CRAWLER_VIDEO_DOWNLOAD_MAX_SIZE=
#OLLAMA_BASE_URL=
#INFERENCE_TEXT_MODEL=
#INFERENCE_IMAGE_MODEL=
EOF
chmod 600 $ENV_FILE
msg_ok "Installed Hoarder"

msg_info "Creating users and Services"

$STD /usr/sbin/useradd -U -s /usr/sbin/nologin -r -m -d /var/lib/meilisearch meilisearch
$STD /usr/sbin/useradd -U -s /usr/sbin/nologin -r -d $INSTALL_DIR hoarder

chown -R hoarder:hoarder $INSTALL_DIR
chown -R hoarder:hoarder $CONFIG_DIR

cat <<EOF >/lib/systemd/system/meilisearch.service
[Unit]
Description=MeiliSearch is a RESTful search API
Documentation=https://docs.meilisearch.com/
Requires=network-online.target
After=network-online.target

[Service]
User=meilisearch
Group=meilisearch
Restart=on-failure
WorkingDirectory=/var/lib/meilisearch
ExecStart=/usr/bin/meilisearch --no-analytics
EnvironmentFile=/etc/meilisearch.conf
NoNewPrivileges=true
ProtectHome=true
ReadWritePaths=/var/lib/meilisearch
ProtectSystem=full
ProtectHostname=true
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectKernelLogs=true
ProtectClock=true
LockPersonality=true
RestrictRealtime=yes
RestrictNamespaces=yes
MemoryDenyWriteExecute=yes
PrivateDevices=yes
PrivateTmp=true
CapabilityBoundingSet=
RemoveIPC=true

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/meilisearch.conf
MEILI_MASTER_KEY="$MEILI_SECRET"
EOF

cat <<EOF >/etc/systemd/system/hoarder-browser.service
[Unit]
Description=Hoarder browser
Wants=network-online.target
After=network-online.target

[Service]
Restart=on-failure
ExecStart=/usr/bin/chromium --headless --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --hide-scrollbars
TimeoutStopSec=5
SyslogIdentifier=hoarder-browser

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/hoarder-workers.service
[Unit]
Description=Hoarder workers
Wants=network-online.target hoarder-browser.service
After=network-online.target hoarder-browser.service

[Service]
Restart=always
RestartSec=10
User=hoarder
Group=hoarder
EnvironmentFile=$ENV_FILE
WorkingDirectory=$INSTALL_DIR/apps/workers
ExecStart=/usr/bin/pnpm run start:prod
TimeoutStopSec=5
SyslogIdentifier=hoarder-workers

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/hoarder-web.service
[Unit]
Description=Hoarder web
Wants=network-online.target hoarder-workers.service meilisearch.service
After=network-online.target hoarder-workers.service meilisearch.service

[Service]
Restart=always
RestartSec=10
User=hoarder
Group=hoarder
Environment=SERVER_VERSION=$RELEASE
EnvironmentFile=-$ENV_FILE
WorkingDirectory=$INSTALL_DIR/apps/web
ExecStart=/usr/bin/node server.js
TimeoutStopSec=5
SyslogIdentifier=hoarder-web

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/hoarder.target
[Unit]
Description=Hoarder Services
After=network-online.target
Wants=hoarder-web.service hoarder-workers.service hoarder-browser.service

[Install]
WantedBy=multi-user.target
EOF

msg_ok "Created users and Services"

msg_info "Performing database migration"
export DATA_DIR=$DATA_DIR && cd $INSTALL_DIR/packages/db && pnpm migrate \
  && chown -R hoarder:hoarder $DATA_DIR
msg_ok "Migrated database"

motd_ssh
customize

msg_info "Cleaning up"
systemctl enable -q --now meilisearch.service hoarder.target
rm -R $TMP_DIR
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
