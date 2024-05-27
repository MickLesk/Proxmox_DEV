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
  nginx \
  apt-transport-https \
  gnupg2 \
  lsb-release \
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

msg_info "Setting up Database"
$STD sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
$STD wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
$STD sudo apt-get update
$STD sudo apt-get install -y postgresql-16 

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
sudo curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
$STD sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
$STD sudo apt update
$STD sudo apt install -y php8.3 php8.3-{bcmath,bz2,cli,common,curl,fpm,gd,intl,mbstring,mysql,sqlite3,xml,zip,pgsql}

$STD curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
$STD apt-get install nodejs -y
$STD sudo npm install --global yarn 
msg_ok "PHP & NodeJS successfully setup" 

msg_info "Installing Koel(Patience)"
$STD wget -O composer-setup.php https://getcomposer.org/installer
$STD php composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet
cd /opt
KOEL_VERSION=$(wget -q https://github.com/koel/koel/releases/latest -O - | grep "title>Release" | cut -d " " -f 4)
wget https://github.com/koel/koel/releases/download/${KOEL_VERSION}/koel-${KOEL_VERSION}.zip
unzip -q koel-${KOEL_VERSION}.zip
cd koel
$STD composer update -q
$STD composer install -q
sudo sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=pgsql/" /opt/koel/.env
sudo sed -i "s/DB_HOST=.*/DB_HOST=localhost/" /opt/koel/.env
sudo sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" /opt/koel/.env
sudo sed -i "s/DB_PORT=.*/DB_PORT=5432/" /opt/koel/.env
sudo sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" /opt/koel/.env
sudo sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" /opt/koel/.env
sudo sed -i 's|MEDIA_PATH=.*|MEDIA_PATH=/opt/koel_media|' /opt/koel/.env
$STD php artisan koel:init -q
msg_ok "Installed Koel"

msg_info "Set up web services"
cat <<EOF >/etc/nginx/conf.d/koel.conf
server {
    listen          6767;
    server_name     koel.local;
    root            /opt/koel/public;
    index           index.php;

    gzip            on;
    gzip_types      text/plain text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript application/json;
    gzip_comp_level 9;

    send_timeout    3600;
    client_max_body_size 50M;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location /media/ {
        internal;
        alias /opt/koel_media;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
EOF

systemctl reload nginx
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
