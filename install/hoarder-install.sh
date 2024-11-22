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
  g++ \
  build-essential \
  curl \
  sudo \
  gnupg \
  ca-certificates \
  chromium-shell \
  mc

wget -q https://github.com/Y2Z/monolith/releases/latest/download/monolith-gnu-linux-x86_64 -O monolith && \
  chmod +x monolith && mv monolith /usr/bin

wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O yt-dlp && \
  chmod +x yt-dlp && mv yt-dlp /usr/bin

wget -q https://github.com/meilisearch/meilisearch/releases/latest/download/meilisearch.deb && \
  dpkg -i meilisearch.deb && rm meilisearch.deb

msg_ok "Installed Dependencies"

msg_info "Installing Node.js"
export NEXT_TELEMETRY_DISABLED=1
export PUPPETEER_SKIP_DOWNLOAD="true"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
$STD npm install -g pnpm
export NODE_OPTIONS="--max_old_space_size=4096"
msg_ok "Installed Node.js"

msg_info "Installing Hoarder (Extreme Patience)"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/hoarder-app/hoarder/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/hoarder-app/hoarder/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv hoarder-${RELEASE} /opt/hoarder
cd /opt/hoarder
pnpm install --frozen-lockfile

cd /opt/hoarder/packages/db
pnpm dlx @vercel/ncc build migrate.ts -o ../../db_migrations
cp -R drizzle /../..db_migrations

cd /opt/hoarder/apps/web
pnpm exec next build --experimental-build-mode compile

cd /opt/hoarder/apps/workers
pnpm deploy --node-linker=isolated --filter @hoarder/workers --prod workers

cd /opt/hoarder/apps/cli
pnpm build

echo "${RELEASE}" >"/opt/hoarder_version.txt"
HOARDER_SECRET="$(openssl rand -base64 32 | cut c1-24)"
MEILI_SECRET="$(openssl rand -base64 36)"
echo "" >>~/hoarder.creds
echo -e "NextAuth Secret: $HOARDER_SECRET" >>~/hoarder.creds
echo -e "Meilisearch Master Key: $MEILI_SECRET" >>~/hoarder.creds

cat <<EOF >/opt/hoarder/.env
NEXTAUTH_SECRET="$HOARDER_SECRET"
NEXTAUTH_URL="http://localhost:3000"
DATA_DIR="/opt/hoarder/data"
MEILI_ADDR="http://127.0.0.1:7700"
MEILI_MASTER_KEY="$MEILI_SECRET"
BROWSER_WEB_URL="http://127.0.0.1:9222"
CRAWLER_VIDEO_DOWNLOAD=true
#CRAWLER_VIDEO_DOWNLOAD_MAX_SIZE=
#OLLAMA_BASE_URL=
#INFERENCE_TEXT_MODEL=
#INFERENCE_IMAGE_MODEL=
EOF
# cd /opt/hoarder/src/server
# $STD pnpm db:migrate:apply
msg_ok "Installed Hoarder"

msg_info "Creating users and Services"

/usr/sbin/useradd -U -s /usr/sbin/nologin -r -m -d /var/lib/meilisearch meilisearch

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
ExecStart=/usr/bin/chromium-shell --headless --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --hide-scrollbars
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
Restart=on-failure
EnvironmentFile=/opt/hoarder/.env
WorkingDirectory=/opt/hoarder/apps/workers
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
Restart=on-failure
Environment=SERVER_VERSION=$RELEASE
Environment=NODE_ENV=production
EnvironmentFile=-/opt/hoarder/.env
WorkingDirectory=/opt/hoarder/db_migrations
ExecStartPre=/usr/bin/node index.js
ExecStart=/usr/bin/node /opt/hoarder/apps/web/server.js
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
# systemctl enable -q --now meilisearch.service hoarder.target
msg_ok "Created users and Services"

motd_ssh
customize

msg_info "Cleaning up"
rm -R /opt/v${RELEASE}.zip
#rm -rf /opt/hoarder/src/client
#rm -rf /opt/hoarder/website
#rm -rf /opt/hoarder/reporter
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
