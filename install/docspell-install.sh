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
$STD apt-get install -y --no-install-recommends \
  unzip \
  htop \
  gnupg2 \
  ca-certificates \
  default-jdk \
  apt-transport-https \
  ghostscript \
  tesseract-ocr \
  tesseract-ocr-deu \
  tesseract-ocr-eng \
  unpaper \
  unoconv \
  wkhtmltopdf \
  ocrmypdf \
  wget \
  zip \
  curl \
  sudo \
  git \
  make \
  mc

$STD cd /root/
$STD wget https://downloads.apache.org/lucene/solr/8.11.3/solr-8.11.3.tgz
$STD tar xzf solr-8.11.3.tgz
$STD bash solr-8.11.3/bin/install_solr_service.sh solr-8.11.3.tgz
$STD systemctl start solr
$STD su solr -c '/opt/solr-8.11.3/bin/solr create -c docspell'
msg_ok "Installed Dependencies"

msg_info "Install/Set up PostgreSQL Database"
DB_NAME=docspelldb
DB_USER=docspell
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
echo "deb https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" >/etc/apt/sources.list.d/pgdg.list
$STD apt-get update
$STD apt-get install -y postgresql-16
$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER TEMPLATE template0;"
$STD systemctl enable postgresql
echo "" >>~/docspell.creds
echo -e "Docspell Database Name: \e[32m$DB_NAME\e[0m" >>~/docspell.creds
echo -e "Docspell Database User: \e[32m$DB_USER\e[0m" >>~/docspell.creds
echo -e "Docspell Database Password: \e[32m$DB_PASS\e[0m" >>~/docspell.creds
msg_ok "Set up PostgreSQL Database"

msg_info "Setup Docspell (Patience)"
Docspell=$(wget -q https://github.com/eikek/docspell/releases/latest -O - | grep "title>Release" | cut -d " " -f 5)
DocspellDSC=$(wget -q https://github.com/docspell/dsc/releases/latest -O - | grep "title>Release" | cut -d " " -f 4 | sed 's/^v//')
cd /opt
$STD wget https://github.com/eikek/docspell/releases/download/v${Docspell}/docspell-joex_${Docspell}_all.deb
$STD wget https://github.com/eikek/docspell/releases/download/v${Docspell}/docspell-restserver_${Docspell}_all.deb
dpkg -i docspell*
$STD wget https://github.com/docspell/dsc/releases/download/v${DocspellDSC}/dsc_amd64-musl-${DocspellDSC}
$STD mv dsc_amd* dsc
$STD chmod +x dsc
$STD mv dsc /usr/bin
$STD ln -s /etc/docspell-joex /opt/docspell/docspell-joex
$STD ln -s /etc/docspell-restserver /opt/docspell/docspell-restserver
$STD ln -s /usr/bin/dsc /opt/docspell/dsc
$STD sudo sed -i "s/user=.*/user=$DB_USER/" /opt/docspell/docspell-restserver/docspell-server.conf
$STD sudo sed -i "s/password=.*/password=$DB_PASS/" /opt/docspell/docspell-restserver/docspell-server.conf
$STD sudo sed -i "s/user=.*/user=$DB_USER/" /opt/docspell/docspell-joex/docspell-joex.conf
$STD sudo sed -i "s/password=.*/password=$DB_PASS/" /opt/docspell/docspell-joex/docspell-joex.conf
$STD systemctl start docspell-restserver
$STD systemctl enable docspell-restserver
$STD systemctl start docspell-joex
$STD systemctl enable docspell-joex

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
