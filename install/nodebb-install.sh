#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/NodeBB/NodeBB

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y --no-install-recommends \
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
msg_ok "Set up Node.js Repository"

msg_info "Installing Node.js"
$STD apt-get update
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Installing MongoDB"
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
$STD sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl start mongod
msg_ok "Installed MongoDB"   

msg_info "Configure MongoDB"
MONGO_ADMIN_USER="admin"
MONGO_ADMIN_PWD="$(openssl rand -base64 18 | cut -c1-13)"
NODEBB_USER="nodebb"
NODEBB_PWD="$(openssl rand -base64 18 | cut -c1-13)"
NODEBB_SECRET=$(uuidgen)
echo "" >>~/nodebb.creds
echo -e "Mongo-Database User:$MONGO_ADMIN_USER" >>~/nodebb.creds
echo -e "Mongo-Database Password: $MONGO_ADMIN_PWD" >>~/nodebb.creds
echo -e "NodeBB User: $NODEBB_USER" >>~/nodebb.creds
echo -e "NodeBB Password: $NODEBB_PWD" >>~/nodebb.creds
echo -e "NodeBB Secret: $NODEBB_SECRET" >>~/nodebb.creds

mongosh <<EOF
use admin
db.createUser({
  user: "$MONGO_ADMIN_USER",
  pwd: "$MONGO_ADMIN_PWD",
  roles: [{ role: "root", db: "admin" }]
})

use nodebb
db.createUser({
  user: "$NODEBB_USER",
  pwd: "$NODEBB_PWD",
  roles: [
    { role: "readWrite", db: "nodebb" },
    { role: "clusterMonitor", db: "admin" }
  ]
})
quit()
EOF
sudo sed -i '/security:/d' /etc/mongod.conf
sudo bash -c 'echo -e "\nsecurity:\n  authorization: enabled" >> /etc/mongod.conf'
sudo systemctl restart mongod
msg_ok "MongoDB successfully configurated" 

msg_info "Install NodeBB" 
RELEASE=$(curl -s https://api.github.com/repos/NodeBB/NodeBB/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q "https://github.com/NodeBB/NodeBB/archive/refs/tags/${RELEASE}.zip"
unzip -q ${RELEASE}.zip
CLEAN_RELEASE=$(echo $RELEASE | sed 's/^v//')
mv NodeBB-${CLEAN_RELEASE} /opt/nodebb
rm -R ${RELEASE}.zip 
cd /opt/nodebb
NODEBB_USER=$(grep "NodeBB User" ~/nodebb.creds | awk -F: '{print $2}' | xargs)
NODEBB_PWD=$(grep "NodeBB Password" ~/nodebb.creds | awk -F: '{print $2}' | xargs)
NODEBB_SECRET=$(grep "NodeBB Secret" ~/nodebb.creds | awk -F: '{print $2}' | xargs)
cat <<EOF >/opt/nodebb/config.json
{
    "url": "http://localhost:4567",
    "secret": "$NODEBB_SECRET",
    "database": "mongo",
    "mongo": {
        "host": "127.0.0.1",
        "port": "27017",
        "username": "$NODEBB_USER",
        "password": "$NODEBB_PWD",
        "database": "nodebb",
        "uri": ""
    },
    "port": "4567"
}
EOF
$STD npm ci
$STD npm run build
echo "${CLEAN_RELEASE}" >/opt/${APPLICATION}_version.txt
msg_ok "Installed NodeBB"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/nodebb.service
[Unit]
Description=NodeBB Launcher
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/npm run start
WorkingDirectory=/opt/nodebb
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now nodebb
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
