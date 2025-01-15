#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (Canbiz)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y \
    curl \
    git \
    unzip \
    sudo \
    make \
    php8.3 \
    php8.3-{cli,fpm,tidy,xml,mbstring,zip,gd,curl} \
    composer \
    apache2 \
    libapache2-mod-php \
    mariadb-server
msg_ok "Installed Dependencies"

msg_info "Setting up Database"
DB_NAME=wallabag_db
DB_USER=wallabag
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
$STD mysql -u root -e "CREATE DATABASE $DB_NAME;"
$STD mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
$STD mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
{
    echo "Wallabag Credentials"
    echo "Database User: $DB_USER"
    echo "Database Password: $DB_PASS"
    echo "Database Name: $DB_NAME"
} >> ~/wallabag.creds
msg_ok "Set up Database"

msg_info "Installing Wallabag (Patience)"
# Wallabag Repository klonen
mkdir -p /opt/wallabag
cd /opt/wallabag
git clone https://github.com/wallabag/wallabag.git .
# Abhängigkeiten installieren
composer install --no-dev --prefer-dist --optimize-autoloader
msg_ok "Installed Wallabag"

msg_info "Setting up Virtual Host"
cat <<EOF > /etc/apache2/sites-available/wallabag.conf
<VirtualHost *:80>
    ServerName yourdomain.com
    DocumentRoot /opt/wallabag/web

    <Directory /opt/wallabag/web>
        AllowOverride None
        Require all granted
        <IfModule mod_rewrite.c>
            RewriteEngine On
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteRule ^(.*)$ app.php [QSA,L]
        </IfModule>
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wallabag_error.log
    CustomLog \${APACHE_LOG_DIR}/wallabag_access.log combined
</VirtualHost>
EOF
$STD a2enmod rewrite
$STD a2ensite wallabag.conf
$STD a2dissite 000-default.conf
systemctl reload apache2
msg_ok "Configured Virtual Host"

msg_info "Setting Permissions"
chown -R www-data:www-data /opt/wallabag/{bin,app/config,vendor,data,var,web}
msg_ok "Set Permissions"

msg_info "Running Wallabag Installation"
php bin/console wallabag:install --env=prod
msg_ok "Wallabag Installed"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
