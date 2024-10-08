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

msg_info "Installing MySQL"
curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 | gpg --dearmor  -o /usr/share/keyrings/mysql.gpg
echo "deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian $(lsb_release -sc) mysql-8.0" >/etc/apt/sources.list.d/mysql.list
$STD sudo apt update
export DEBIAN_FRONTEND=noninteractive
$STD apt-get install -y \
  mysql-common \
  mysql-community-client \
  mysql-community-server
msg_ok "Installed MySQL"

msg_info "Configure MySQL Server"
ADMIN_PASS="$(openssl rand -base64 18 | cut -c1-13)"
$STD sudo mysql -uroot -p"$ADMIN_PASS" -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ADMIN_PASS'; FLUSH PRIVILEGES;"
echo "" >>~/mysql.creds
echo -e "MySQL Root Password: $ADMIN_PASS" >>~/mysql.creds
msg_ok "MySQL Server configured"

read -r -p "Would you like to add PhpMyAdmin? <y/N> " prompt
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  msg_info "Adding phpMyAdmin"
  $STD apt-get install -y \
    apache2 \
    php \
    php-mysqli \
    php-mbstring \
    php-zip \
    php-gd \
    php-json \
    php-curl 
	
	wget -q "https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz"
	sudo mkdir -p /var/www/html/phpMyAdmin
	$STD sudo tar xvf phpMyAdmin-5.2.1-all-languages.tar.gz --strip-components=1 -C /var/www/html/phpMyAdmin
	sudo cp /var/www/html/phpMyAdmin/config.sample.inc.php /var/www/html/phpMyAdmin/config.inc.php
	SECRET=$(openssl rand -base64 32)
	sudo sed -i "s#\$cfg\['blowfish_secret'\] = '';#\$cfg['blowfish_secret'] = '${SECRET}';#" /var/www/html/phpMyAdmin/config.inc.php
	sudo chmod 660 /var/www/html/phpMyAdmin/config.inc.php
	sudo chown -R www-data:www-data /var/www/html/phpMyAdmin
	sudo systemctl restart apache2
  msg_ok "Added phpMyAdmin"
fi

msg_info "Start Service"
sudo systemctl enable -q --now mysql
msg_ok "Service started"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
