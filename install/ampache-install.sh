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
  cron \
  flac \
  vorbis-tools \
  lame \
  ffmpeg \
  gosu \
  wget \
  curl \
  git \
  zip \
  unzip \
  sudo \
  make \
  mc 
 msg_ok "Installed Dependencies"
 
msg_info "Setting up PHP"
sudo curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
$STD sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
$STD sudo apt update
$STD sudo apt install -y php8.3 php8.3-{bcmath,bz2,cli,common,curl,fpm,gd,imagick,intl,mbstring,mysql,sqlite3,xml,xmlrpc,zip}
$STD apt-get install -y --no-install-recommends \
  libapache2-mod-php \
  inotify-tools \
  libavcodec-extra \
  libev-libevent-dev \
  libmp3lame-dev \
  libtheora-dev \
  libvorbis-dev \
  libvpx-dev 
msg_ok "PHP successfully setup"  

msg_info "Installing Ampache(Patience)"
#sudo sed -i 's|short_open_tag=.*|MEDIA_PATH=/opt/koel_media|' /etc/php/8.3/apache2/php.ini
#sudo sed -i 's|memory_limit=/usr/local/bin/ffmpeg|FFMPEG_PATH=/usr/bin/ffmpeg|' /etc/php/8.3/apache2/php.ini
#sudo sed -i 's|cgi.fix_pathinfo=.*|MEDIA_PATH=/opt/koel_media|' /etc/php/8.3/apache2/php.ini
#sudo sed -i 's|FFMPEG_PATH=/usr/local/bin/ffmpeg|FFMPEG_PATH=/usr/bin/ffmpeg|' /etc/php/8.3/apache2/php.ini
#sudo sed -i 's|MEDIA_PATH=.*|MEDIA_PATH=/opt/koel_media|' /etc/php/8.3/apache2/php.ini
#sudo sed -i 's|FFMPEG_PATH=/usr/local/bin/ffmpeg|FFMPEG_PATH=/usr/bin/ffmpeg|' /etc/php/8.3/apache2/php.ini
#sudo sed -i 's|MEDIA_PATH=.*|MEDIA_PATH=/opt/koel_media|' /etc/php/8.3/apache2/php.ini
#sudo sed -i 's|FFMPEG_PATH=/usr/local/bin/ffmpeg|FFMPEG_PATH=/usr/bin/ffmpeg|' /opt/koel/.env
#nano /etc/php/8.3/apache2/php.ini
#short_open_tag = On
#memory_limit = 256M
#cgi.fix_pathinfo = 0
#max_execution_time = 360
#upload_max_filesize = 64M
#post_max_size = 64M
#systemctl restart apache2


cd /opt
AMPACHE_VERSION=$(wget -q https://github.com/ampache/ampache/releases/latest -O - | grep "title>Release" | cut -d " " -f 4)
wget https://github.com/ampache/ampache/releases/download/${AMPACHE_VERSION}/ampache-${AMPACHE_VERSION}_all_php8.3.zip
unzip -q ampache-${AMPACHE_VERSION}_all_php8.3.zip -d ampache
rm -rf /var/www/html
ln -s /opt/ampache/public /var/www/html
msg_ok "Installed Ampache"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
