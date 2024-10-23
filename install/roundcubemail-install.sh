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
  lsb-release \
  gnupg \
  apache2 \
  libapache2-mod-php \
  composer \
  php8.2-{mbstring,gd,imap,mysql,ldap,curl,intl,imagick,bz2,sqlite3,zip,xml} 
msg_ok "Installed Dependencies"

msg_info "Installing MySQL"
curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 | gpg --dearmor  -o /usr/share/keyrings/mysql.gpg
echo "deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian $(lsb_release -sc) mysql-8.0" >/etc/apt/sources.list.d/mysql.list
$STD apt-get update
export DEBIAN_FRONTEND=noninteractive
$STD apt-get install -y \
  mysql-community-client \
  mysql-community-server
msg_ok "Installed MySQL"

msg_info "Configure MySQL Server"
ADMIN_PASS="$(openssl rand -base64 18 | cut -c1-13)"
mysql -uroot -p"$ADMIN_PASS" -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ADMIN_PASS'; FLUSH PRIVILEGES;"
msg_ok "MySQL Server configured"

msg_info "Setting Up MySQL"
DB_NAME=roundcubedb
DB_USER=roundcubeuser
DB_HOST=localhost
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
$STD mysql -uroot -p"$ADMIN_PASS" <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST';
FLUSH PRIVILEGES;
EOF
echo "" >>~/roundcubemail.creds
echo -e "MySQL user: root" >>~/roundcubemail.creds
echo -e "MySQL password: $ADMIN_PASS" >>~/roundcubemail.creds
echo "" >~/roundcubemail.creds
echo -e "Roundcubemail Database User: $DB_USER" >>~/roundcubemail.creds
echo -e "Roundcubemail Database Password: $DB_PASS" >>~/roundcubemail.creds
echo -e "Roundcubemail Database Name: $DB_NAME" >>~/roundcubemail.creds
msg_ok "Set up MySQL"

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