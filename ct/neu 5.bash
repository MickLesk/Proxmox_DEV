#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/windmill-labs/windmill

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y --no-install-recommends \
  unzip \
  debian-keyring \
  debian-archive-keyring \
  apt-transport-https \
  pkg-config \
  gnupg \
  python3 \
  python3-dev \
  python3-setuptools \
  python3-venv \
  build-essential \
  curl \
  sudo \
  git \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Rust (Patience)" 
$STD bash <(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs) -y
source ~/.cargo/env
cargo install deno --locked
cd /opt
git clone https://github.com/llvm/llvm-project llvm-project
cd llvm-project
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS=lld -DCMAKE_INSTALL_PREFIX=/usr/local ../llvm-project/llvm
make install
msg_ok "Installed Rust" 

msg_info "Setting up Database"
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y \
    postgresql-16 \
    postgresql-contrib-16 \
    postgresql-server-dev-all \
    postgresql-16-pgvector
echo "DB Done" 
DB_NAME=windmill
DB_USER=windmill
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 
$STD sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
#$STD sudo -u postgres psql -c "CREATE EXTENSION vectors;"
echo "" >>~/windmill.creds
echo -e "Windmill Database User: \e[32m$DB_USER\e[0m" >>~/windmill.creds
echo -e "Windmill Database Password: \e[32m$DB_PASS\e[0m" >>~/windmill.creds
echo -e "Windmill Database Name: \e[32m$DB_NAME\e[0m" >>~/windmill.creds
cd /opt

msg_ok "Set up PostgreSQL database"

msg_info "Installing Windmill (Patience)" 
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/windmill-labs/windmill/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
$STD wget -q --no-check-certificate "https://github.com/windmill-labs/windmill/archive/refs/tags/${RELEASE}.zip"
$STD unzip -q ${RELEASE}.zip
CLEAN_RELEASE=$(echo "$RELEASE" | sed 's/^v//')
mv "windmill-${CLEAN_RELEASE}" windmill
rm -R ${RELEASE}.zip 
cd windmill
cargo install sqlx-cli
env DATABASE_URL=127.0.0.1:5432 sqlx migrate run
cargo build -q --release
msg_ok "Installed Windmill"

msg_info "Setup Dependencies"
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
curl -fsSL https://deno.land/install.sh | sh
apt install -y nodejs 

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/hoodik.service
[Unit]
Description=Start Hoodik Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/hoodik
ExecStart=/root/.cargo/bin/cargo run -q --release

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hoodik.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
