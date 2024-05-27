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
  mariadb-server \
  apache2 \
  php \
  php-curl \
  php-bcmath \
  php-json \
  php-mysql \
  php-mbstring \
  php-xml \
  php-tokenizer \
  php-zip \
  php-gd \
  php-pdo-sqlite \
  php8.3-sqlite3 \
  lighttpd \
  gnupg2 \
  lsb-release \
  flac \
  lame \
  ffmpeg \
  wget \
  curl \
  git \
  zip \
  unzip \
  sudo \
  make \
  mc 
 msg_ok "Installed Dependencies"
sudo a2enmod rewrite

msg_info "Setting up Database"
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y \
    postgresql-16 \
    postgresql-contrib-16 \
    postgresql-server-dev-all 

DB_NAME=koel
DB_USER=koel
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
$STD sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' TEMPLATE template0;"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC'"
echo "" >>~/koel.creds
echo "Koel Database User: $DB_USER" >>~/koel.creds
echo "Koel Database Password: $DB_PASS" >>~/koel.creds
echo "Koel Database Name: $DB_NAME" >>~/koel.creds
msg_ok "Set up PostgreSQL database"

msg_info "Setting up PHP & NodeJS"
sudo dpkg -l | grep php | tee packages.txt
sudo apt install apt-transport-https
sudo curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
sudo apt update
sudo apt install php8.3 php8.3-{bcmath,bz2,cli,common,curl,fpm,gd,intl,json,mbstring,mysql,pdo-sqlite,sqlite3,tokenizer,xml,zip}
sudo a2enconf php8.3-fpm
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
apt-get install nodejs -y
sudo npm install --global yarn 
msg_ok "PHP & NodeJS successfully setup" 

msg_info "Installing Koel(Patience)"
wget https://getcomposer.org/download/latest-stable/composer.phar
mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer
cd /opt
KOEL_VERSION=$(wget -q https://github.com/koel/koel/releases/latest -O - | grep "title>Release" | cut -d " " -f 4)
wget https://github.com/koel/koel/releases/download/${KOEL_VERSION}/koel-${KOEL_VERSION}.zip
unzip -q koel-${KOEL_VERSION}.zip
cd koel
composer update
composer install
sudo sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=pgsql/" /opt/koel/.env
sudo sed -i "s/DB_HOST=.*/DB_HOST=localhost/" /opt/koel/.env
sudo sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" /opt/koel/.env
sudo sed -i "s/DB_PORT=.*/DB_PORT=5432/" /opt/koel/.env
sudo sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" /opt/koel/.env
sudo sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" /opt/koel/.env
sudo sed -i 's|MEDIA_PATH=.*|MEDIA_PATH=/opt/koel_media|' /opt/koel/.env

msg_ok "Installed Koel"

pgsql

#msg_info "Set up web services"
#cat <<EOF >/etc/nginx/conf.d/ampache.conf
#Sauerkirschen
#EOF

#systemctl enable docspell-restserver

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
