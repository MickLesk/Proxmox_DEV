#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/roundcube/roundcubemail

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
  apache2 \
  libapache2-mod-php \
  composer \
  php8.2-{mbstring,gd,imap,mysql,curl,intl,imagick,bz2,sqlite3,zip,xml} 
msg_ok "Installed Dependencies"

msg_info "Installing Database"
sqluser="root"
sqlpass="root"
echo "mariadb-server mariadb-server/root_password password $sqlpass" | debconf-set-selections
echo "mariadb-server mariadb-server/root_password_again password $sqlpass" | debconf-set-selections
$STD apt-get install -y mariadb-server
service mysql start
mysql -u "$sqluser" -p"$sqlpass" -e "source sql/user.sql" || true
msg_ok "Installed Database"

msg_info "Setting Up MariaDB"
DB_NAME=roundcubedb
DB_USER=roundcubeuser
DB_HOST=localhost
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
mysql -u"$sqluser" -p"$sqlpass" <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST';
FLUSH PRIVILEGES;
EOF
echo "" >>~/roundcubemail.creds
echo -e "Roundcubemail Database User: $DB_USER" >>~/roundcubemail.creds
echo -e "Roundcubemail Database Password: $DB_PASS" >>~/roundcubemail.creds
echo -e "Roundcubemail Database Name: $DB_NAME" >>~/roundcubemail.creds
msg_ok "Set up MariaDB"

msg_info "Installing Roundcubemail (Patience)"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/roundcube/roundcubemail/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q "https://github.com/roundcube/roundcubemail/releases/download/${RELEASE}/roundcubemail-${RELEASE}-complete.tar.gz"
tar -xf roundcubemail-${RELEASE}-complete.tar.gz
mv roundcubemail-${RELEASE} /opt/roundcubemail
cd /opt/roundcubemail
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev
chown -R www-data:www-data temp/ logs/
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"

cat <<EOF >/etc/apache2/sites-available/roundcubemail.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /opt/roundcubemail/public_html

    <Directory /opt/roundcubemail/public_html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wallos_error.log
    CustomLog \${APACHE_LOG_DIR}/wallos_access.log combined
</VirtualHost>
EOF
$STD a2ensite roundcubemail.conf
$STD a2dissite 000-default.conf  
$STD systemctl reload apache2
msg_ok "Installed Wallos"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /opt/roundcubemail-${RELEASE}-complete.tar.gz
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"