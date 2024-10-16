#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
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
$STD apt-get install -y \
  build-essential \
  gpg \
  curl \
  sudo \
  git \
  gnupg2 \
  ca-certificates \
  lsb-release \
  php8.2-full \
  composer \
  redis-server \
  ffmpeg \
  jpegoptim \
  optipng \
  pngquant \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Configure Redis Socket"
sed -i 's/^port .*/port 0/' /etc/redis/redis.conf
sed -i 's|^# unixsocket .*|unixsocket /run/redis/redis.sock|' /etc/redis/redis.conf
sed -i 's/^# unixsocketperm .*/unixsocketperm 770/' /etc/redis/redis.conf
systemctl restart redis
msg_ok "Redis Socket configured"

msg_info "Add pixelfed user"
useradd -rU -s /bin/bash pixelfed
msg_ok "Pixelfed User Added"

msg_info "Configure PHP-FPM for Pixelfed"
cp /etc/php/8.2/fpm/pool.d/www.conf /etc/php/8.2/fpm/pool.d/pixelfed.conf
sed -i 's/\[www\]/\[pixelfed\]/' /etc/php/8.2/fpm/pool.d/pixelfed.conf
sed -i 's/^user = www-data/user = pixelfed/' /etc/php/8.2/fpm/pool.d/pixelfed.conf
sed -i 's/^group = www-data/group = pixelfed/' /etc/php/8.2/fpm/pool.d/pixelfed.conf
sed -i 's|^listen = .*|listen = /run/php-fpm/pixelfed.sock|' /etc/php/8.2/fpm/pool.d/pixelfed.conf
systemctl restart php8.2-fpm
msg_ok "successfully configured PHP-FPM"

msg_info "Setup Postgres Database"
DB_NAME=pixelfed_db
DB_USER=pixelfed_user
DB_ENCODING=utf8
DB_TIMEZONE=UTC
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
sed -i -e "s|DB_CONNECTION=.*|DB_CONNECTION=pgsql|g" \
	   -e "s|DB_PORT=.*|DB_PORT=5432|g" \
       -e "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|g" \
       -e "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|g" \
       -e "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|g" /opt/pixelfed/.env


curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
echo "deb https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" >/etc/apt/sources.list.d/pgdg.list
$STD apt-get update
$STD apt-get install -y postgresql-17
$STD sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER TEMPLATE template0;"
$STD sudo -u postgres psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
$STD sudo -u postgres psql -c "GRANT CREATE ON SCHEMA public TO $DB_USER;" 
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC'"
echo "" >>~/pixelfed.creds
echo -e "Pixelfed Database Name: $DB_NAME" >>~/pixelfed.creds
echo -e "Pixelfed Database User: $DB_USER" >>~/pixelfed.creds
echo -e "Pixelfed Database Password: $DB_PASS" >>~/pixelfed.creds
export $(cat /opt/pixelfed/.env |grep "^[^#]" | xargs)
msg_ok "Set up PostgreSQL Database successfully"

msg_info "Installing Pixelfed (Patience)"
RELEASE=$(curl -s https://api.github.com/repos/pixelfed/pixelfed/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q "https://github.com/pixelfed/pixelfed/archive/refs/tags/${RELEASE}.zip"
unzip -q ${RELEASE}.zip 
mv pixelfed-${RELEASE:1} /opt/pixelfed
rm -R ${RELEASE}.zip 
cd /opt/pixelfed
cd /opt/pixelfed
sudo chown -R www-data:www-data . 
sudo find . -type d -exec chmod 755 {} \;  
sudo find . -type f -exec chmod 644 {} \;  
composer install --no-ansi --no-interaction --optimize-autoloader
cp .env.example .env
php artisan key:generate
php artisan storage:link
php artisan migrate --force
php artisan import:cities
php artisan instance:actor
php artisan passport:keys
php artisan route:cache
php artisan view:cache
msg_ok "Pixelfed successfully set up"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/pixelfed.service
[Unit]
Description=Pixelfed task queueing via Laravel Horizon
After=network.target
Requires=postgresql
Requires=php-fpm
Requires=redis

[Service]
Type=simple
ExecStart=/usr/bin/php /opt/pixelfed/artisan serve --host=0.0.0.0 --port=8000
WorkingDirectory=/opt/pixelfed
User=root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now pixelfed.service
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"