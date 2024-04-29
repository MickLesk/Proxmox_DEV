#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
apt-get install -y --no-install-recommends \
  build-essential  \
  libncursesw5-dev \
  libssl-dev \
  libsqlite3-dev \
  tk-dev \
  libgdbm-dev \
  libc6-dev \
  libbz2-dev \
  pkg-config \
  libffi-dev \
  zlib1g-dev \
  libxmlsec1 \
  libxmlsec1-dev \
  libxmlsec1-openssl \
  libmaxminddb0 \
  python3 \
  python3-dev \
  python3-setuptools \
  python3-venv \
  software-properties-common \
  golang \
  wget \
  curl \
  git \
  zip \
  unzip \
  sudo \
  make \
  mc 
 msg_ok "Installed Dependencies"

 
 
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq 
chmod +x /usr/bin/yq
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 
apt-get install -y nodejs 
sudo npm install --global yarn  

useradd --create-home --home-dir /opt/authentik --user-group --system --shell /bin/bash authentik
chown -R authentik:authentik /opt/authentik
cd /opt/authentik
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
rm -rf get-pip.py
python3 -m pip install virtualenv
 
cd /opt/authentik
rm -rf ./src
git clone https://github.com/goauthentik/authentik.git src
cd /opt/authentik/src/
python3 -m virtualenv ./.venv
source .venv/bin/activate
pip install --no-cache-dir poetry
--poetry export -f requirements.txt --output requirements.txt
--poetry export -f requirements.txt --dev --output requirements-dev.txt
--pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt
cd /opt/authentik/src/website
npm i
npm run build-docs-only
cd /opt/authentik/src/web
npm i
npm run build
cd /opt/authentik/src
sed -i "s/c.Setup(\".\/authentik\/lib\/default.yml\", \".\/local.env.yml\")/c.Setup(\"\/etc\/authentik\/config.yml\", \".\/authentik\/lib\/default.yml\", \".\/local.env.yml\")/" /opt/authentik/src/internal/config/config.go
/usr/local/go/bin/go build -o /opt/authentik/src/authentik-server  ./cmd/server/

msg_info "Set up web services"
cat <<EOF >/etc/systemd/system/authentik-server.service
[Unit]
Description = Authentik Server (web/api/sso)

[Service]
ExecStart=/bin/bash -c 'source /opt/authentik/src/.venv/bin/activate && python -m lifecycle.migrate && /opt/authentik/src/authentik-server'
WorkingDirectory=/opt/authentik/src

User=authentik
Group=authentik

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cat <<EOF >/etc/systemd/system/authentik-worker.service
[Unit]
Description = Authentik Worker (background tasks)

[Service]
ExecStart=/bin/bash -c 'source /opt/authentik/src/.venv/bin/activate && celery -A authentik.root.celery worker -Ofair --max-tasks-per-child=1 --autoscale 3,1 -E -B -s /tmp/celerybeat-schedule -Q authentik,authentik_scheduled,authentik_events'
WorkingDirectory=/opt/authentik/src

User=authentik
Group=authentik

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/authentik
mkdir -p /opt/authentik/certs
mkdir -p /opt/authentik/blueprints

cp /opt/authentik/src/authentik/lib/default.yml /etc/authentik/config.yml
cp -r /opt/authentik/src/blueprints /opt/authentik/blueprints

yq -i ".secret_key = \"$(openssl rand -hex 32)\"" /etc/authentik/config.yml

yq -i ".error_reporting.enabled = false" /etc/authentik/config.yml
yq -i ".disable_update_check = true" /etc/authentik/config.yml
yq -i ".disable_startup_analytics = true" /etc/authentik/config.yml
yq -i ".avatars = \"none\"" /etc/authentik/config.yml

yq -i ".cert_discovery_dir = \"/opt/authentik/certs\"" /etc/authentik/config.yml
yq -i ".blueprints_dir = \"/opt/authentik/blueprints\"" /etc/authentik/config.yml
yq -i ".geoip = \"/opt/authentik/GeoLite2-City.mmdb\""  /etc/authentik/config.yml

systemctl start authentik-server
systemctl enable authentik-server
systemctl start authentik-worker
systemctl enable authentik-worker

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
