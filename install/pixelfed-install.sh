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
$STD apt-get install -y --no-install-recommends \
  build-essential \
  gpg \
  curl \
  sudo \
  git \
  php8.2-{bz2,pgsql,curl,sqlite3,zip,xml} \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Pixelfed (Patience)"
RELEASE=$(curl -s https://api.github.com/repos/pixelfed/pixelfed/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q "https://github.com/pixelfed/pixelfed/archive/refs/tags/${RELEASE}.zip"
unzip -q ${RELEASE}.zip 
mv pixelfed-${RELEASE:1} /opt/pixelfed
rm -R ${RELEASE}.zip 
cd /opt/pixelfed
composer install --no-ansi --no-interaction --optimize-autoloader
cp .env.example .env

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
#$STD apt-get update
#$STD apt-get install -y postgresql-16
#$STD 
sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
#$STD 
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER TEMPLATE template0;"
sudo -u postgres psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
#$STD 
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
sudo -u postgres psql -c "GRANT CREATE ON SCHEMA public TO $DB_USER;"
#$STD 
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
#$STD 
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC'"
echo "" >>~/pixelfed.creds
echo -e "Pixelfed Database Name: \e[32m$DB_NAME\e[0m" >>~/pixelfed.creds
echo -e "Pixelfed Database User: \e[32m$DB_USER\e[0m" >>~/pixelfed.creds
echo -e "Pixelfed Database Password: \e[32m$DB_PASS\e[0m" >>~/pixelfed.creds
export $(cat /opt/pixelfed/.env |grep "^[^#]" | xargs)

php artisan key:generate
php artisan storage:link
php artisan migrate --force
php artisan import:cities
php artisan instance:actor
php artisan passport:keys
php artisan route:cache
php artisan view:cache


/usr/bin/python3 /opt/tandoor/manage.py migrate >/dev/null 2>&1
/usr/bin/python3 /opt/tandoor/manage.py collectstatic --no-input >/dev/null 2>&1
/usr/bin/python3 /opt/tandoor/manage.py collectstatic_js_reverse >/dev/null 2>&1
msg_ok "Set up PostgreSQL Database"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/pixelfed.service
[Unit]
Description=Pixelfed task queueing via Laravel Horizon
After=network.target
Requires=postgresql
Requires=php-fpm
Requires=redis
Requires=nginx

[Service]
Type=simple
ExecStart=/usr/bin/php /usr/share/webapps/pixelfed/artisan horizon
User=http
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' >/etc/nginx/conf.d/tandoor.conf
server {
    listen 8002;
    #access_log /var/log/nginx/access.log;
    #error_log /var/log/nginx/error.log;
    client_max_body_size 128M;
    # serve media files
    location /static/ {
        alias /opt/tandoor/staticfiles/;
    }

    location /media/ {
        alias /opt/tandoor/mediafiles/;
    }

    location / {
        proxy_set_header Host $http_host;
        proxy_pass http://unix:/opt/tandoor/tandoor.sock;
    }
}
EOF
systemctl reload nginx
systemctl enable -q --now gunicorn_tandoor
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"