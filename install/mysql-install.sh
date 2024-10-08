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
  sudo \
  lsb-release \
  curl \
  gnupg   \
  apt-transport-https \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Setup Repository..."
curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 | gpg --dearmor  -o /usr/share/keyrings/mysql.gpg
echo "deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian $(lsb_release -sc) mysql-8.0" >/etc/apt/sources.list.d/mysql.list
msg_ok "Repository set" 


msg_info "Installing MySQL"
export DEBIAN_FRONTEND=noninteractive
$STD apt-get install -y \
  mysql-common \
  mysql-community-client \
  mysql-client \
  mysql-community-server
msg_ok "Installed MySQL"

read -r -p "Would you like to add PhpMyAdmin? <y/N> " prompt
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  msg_info "Adding PhpMyAdmin"
  $STD apt-get install -y \
    apache2 \
    php \
    php-mysqli \
    php-mbstring \
    php-zip \
    php-gd \
    php-json \
    php-curl \
    phpmyadmin
sudo a2enmod rewrite
sudo systemctl restart apache2
  msg_ok "Added PhpMyAdmin"
fi

msg_info "Start Service"
sudo systemctl enable --now mysql
msg_ok "Service started"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
