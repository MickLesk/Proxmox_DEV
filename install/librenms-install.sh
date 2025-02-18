#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: SvennD
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# dependencies
msg_info "Installing Dependencies"
$STD apt-get install -y \
        lsb-release \
        ca-certificates \
        wget \
        acl \
        curl \
        fping \
        git \
        graphviz \
        imagemagick \
        mariadb-client \
        mariadb-server \
        mtr-tiny \
        nginx-full \
        nmap \
        php8.2-{bcmath,common,ctype,curl,fileinfo,gmp,fpm,gd,iconv,intl,mbstring,mysql,soap,xml,xsl,zip,cli,snmp} \
        python3-{dotenv,pymysql,redis,setuptools,systemd,pip} \
        rrdtool \
        snmp \
        snmpd \
        unzip \
        whois\
        composer\
        sudo

# system user is required
$STD useradd librenms -d /opt/librenms -M -r

# set timezone
$STD timedatectl set-timezone Etc/UTC
msg_ok "Installed Dependencies"


msg_info "php config"
# do a move since we don't need www pool
mv /etc/php/8.2/fpm/pool.d/www.conf /etc/php/8.2/fpm/pool.d/librenms.conf
sed -i -e "s|^\[www\]|\[librenms\]|" \
    -e "s|^listen = /run/php/php8.2-fpm.sock|listen = /run/php/librenms.sock|" \
    -e "s|^user = www-data|user = librenms|" \
    -e "s|^group = www-data|group = librenms|" /etc/php/8.2/fpm/pool.d/librenms.conf

# set timezone
sed -i 's/^;date\.timezone =/date.timezone = Etc\/UTC/' /etc/php/8.2/fpm/php.ini

systemctl restart php8.2-fpm
msg_ok "php config"

msg_info "download librenms"

cd /opt
RELEASE=$(curl -s https://api.github.com/repos/librenms/librenms/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q "https://github.com/librenms/librenms/archive/refs/tags/${RELEASE}.zip"
unzip -q ${RELEASE}.zip
mkdir -p /opt/librenms
mv librenms-${RELEASE}/ /opt/librenms
rm -rf ${RELEASE}.zip
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt

chown -R librenms:librenms /opt/librenms && chmod 771 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
$STD sudo -u librenms /opt/librenms/scripts/composer_wrapper.php install --no-dev

# cron
cp /opt/librenms/dist/librenms.cron /etc/cron.d/librenms

# scheduler
cp /opt/librenms/dist/librenms-scheduler.service /opt/librenms/dist/librenms-scheduler.timer /etc/systemd/system/
systemctl enable -q —now librenms-scheduler.timer

msg_ok "download librenms"

# database stuff
msg_info "Setting up database"

DB_NAME=librenms_db
DB_USER=librenms
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
mysql -u root -e "CREATE DATABASE $DB_NAME;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password AS PASSWORD('$DB_PASS');"
mysql -u root -e "GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
{
    echo "librenms-Credentials"
    echo "librenms Database User: $DB_USER"
    echo "librenms Database Password: $DB_PASS"
    echo "librenms Database Name: $DB_NAME"
} >> ~/librenms.creds

cd /opt/librenms
IPADDRESS=$(hostname -I | awk '{print $1}')

sed -i -e "s|^#APP_URL=.*|APP_URL=http://$IPADDRESS|" \
    -e "s|^#DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" \
    -e "s|^#DB_USERNAME=.*|DB_USERNAME=$DB_USER|" \
    -e "s|^#DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" .env

# requested by librenms
echo innodb_file_per_table=1 >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo lower_case_table_names=0 >> /etc/mysql/mariadb.conf.d/50-server.cnf

# restart to activate
systemctl restart mariadb

msg_ok "Set up database"

msg_info "configure nginx"
cat <<EOF >/etc/nginx/conf.d/librenms.conf
server {
        listen 80;
        root /opt/librenms/html;
        server_name $IPADDRESS; 
        index index.php;
                
        location / {
                try_files \$uri \$uri/ /index.php?\$query_string;
        }
        
        location ~ \.php\$ {
                include fastcgi.conf;
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/librenms.sock;
                fastcgi_split_path_info ^(.+\.php)(/.+)\$;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                include fastcgi_params;
        }
}
EOF
rm /etc/nginx/sites-enabled/default
systemctl reload nginx
msg_ok "Configured Service"

msg_info "validation steps"
sudo ln -s /opt/librenms/lnms /usr/local/bin/lnms
sudo cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/
sudo cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms
msg_ok "validation steps"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
