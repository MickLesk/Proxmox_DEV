#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  apt-transport-https \
  apache2 \
  composer \
  libapache2-mod-php \
  php8.2-{mbstring,gd,intl,pdo,mysql,tokenizer,zip,xml} 
msg_ok "Installed Dependencies"
OnP96wIe5pF9p

msg_info "Installing Database"
apt-get install -y mariadb-server
service mysql start
ADMIN_PASS="$(openssl rand -base64 18 | cut -c1-13)"
sudo mariadb -uroot -p"$ADMIN_PASS" -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$ADMIN_PASS'); FLUSH PRIVILEGES;"
msg_ok "Installed Database"


RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/Heimdall/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]')
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt
msg_info "Installing Heimdall Dashboard ${RELEASE}"
wget -q https://github.com/linuxserver/Heimdall/archive/${RELEASE}.tar.gz
tar xzf ${RELEASE}.tar.gz
VER=$(curl -s https://api.github.com/repos/linuxserver/Heimdall/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
rm -rf ${RELEASE}.tar.gz
mv Heimdall-${VER} /opt/Heimdall
cd /opt/Heimdall
cp .env.example .env
$STD php artisan key:generate
msg_ok "Installed Heimdall Dashboard ${RELEASE}"

msg_info "Creating Service"
service_path="/etc/systemd/system/heimdall.service"
echo "[Unit]
Description=Heimdall
After=network.target

[Service]
Restart=always
RestartSec=5
Type=simple
User=root
WorkingDirectory=/opt/Heimdall
ExecStart="/usr/bin/php" artisan serve --port 7990 --host 0.0.0.0
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target" >$service_path
systemctl enable -q --now heimdall.service
cd /opt/Heimdall
COMPOSER_ALLOW_SUPERUSER=1 composer dump-autoload &>/dev/null
systemctl restart heimdall.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"