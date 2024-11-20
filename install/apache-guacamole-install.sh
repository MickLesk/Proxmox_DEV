#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://guacamole.apache.org/

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y gcc vim curl wget g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev \
  libtool-bin libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  build-essential libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev libpulse-dev \
  libssl-dev libvorbis-dev libwebp-dev libwebsockets-dev freerdp2-dev freerdp2-x11 xrdp
msg_ok "Installed Dependencies"

msg_info "Installing OpenJDK 11"
$STD apt-get install -y openjdk-11-jdk
msg_ok "Installed OpenJDK 11"

msg_info "Installing Apache Tomcat 9.0.97"
TOMCAT_VERSION="9.0.97"
TOMCAT_USER="tomcat"
TOMCAT_DIR="/opt/tomcat"

useradd -m -U -d $TOMCAT_DIR -s /bin/false $TOMCAT_USER
wget -q "https://downloads.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C $TOMCAT_DIR
mv $TOMCAT_DIR/apache-tomcat-${TOMCAT_VERSION} $TOMCAT_DIR/tomcatapp
chown -R $TOMCAT_USER: $TOMCAT_DIR
find $TOMCAT_DIR/tomcatapp/bin/ -type f -iname "*.sh" -exec chmod +x {} \;

cat <<EOF >/etc/systemd/system/tomcat.service
[Unit]
Description=Tomcat 9 servlet container
After=network.target

[Service]
Type=forking
User=$TOMCAT_USER
Group=$TOMCAT_USER
Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true"
Environment="CATALINA_BASE=$TOMCAT_DIR/tomcatapp"
Environment="CATALINA_HOME=$TOMCAT_DIR/tomcatapp"
Environment="CATALINA_PID=$TOMCAT_DIR/tomcatapp/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
ExecStart=$TOMCAT_DIR/tomcatapp/bin/startup.sh
ExecStop=$TOMCAT_DIR/tomcatapp/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now tomcat
msg_ok "Installed Apache Tomcat 9.0.97"

msg_info "Installing Apache Guacamole 1.5.5"
GUACAMOLE_VERSION="1.5.5"

wget -q "https://apache.org/dyn/closer.lua/guacamole/${GUACAMOLE_VERSION}/source/guacamole-server-${GUACAMOLE_VERSION}.tar.gz"
tar -xzf guacamole-server-${GUACAMOLE_VERSION}.tar.gz
cd guacamole-server-${GUACAMOLE_VERSION}/
./configure --with-init-dir=/etc/init.d
make -j$(nproc) && make install
ldconfig
mkdir -p /etc/guacamole
cat <<EOF >/etc/guacamole/guacd.conf
[daemon]
pid_file = /var/run/guacd.pid

[server]
bind_host = 127.0.0.1
bind_port = 4822
EOF

systemctl daemon-reload
systemctl enable --now guacd
msg_ok "Installed Apache Guacamole Server"

wget -q "https://archive.apache.org/dist/guacamole/${GUACAMOLE_VERSION}/binary/guacamole-${GUACAMOLE_VERSION}.war"
mv guacamole-${GUACAMOLE_VERSION}.war /etc/guacamole/guacamole.war
ln -s /etc/guacamole/guacamole.war $TOMCAT_DIR/tomcatapp/webapps
echo "GUACAMOLE_HOME=/etc/guacamole" | tee -a /etc/default/tomcat /etc/profile
ln -s /etc/guacamole $TOMCAT_DIR/tomcatapp/.guacamole
chown -R $TOMCAT_USER: $TOMCAT_DIR

cat <<EOF >/etc/guacamole/guacamole.properties
guacd-hostname: localhost
guacd-port:  4822
user-mapping:  /etc/guacamole/user-mapping.xml
auth-provider:  net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
EOF

msg_info "Restarting Services"
systemctl restart tomcat guacd
msg_ok "Restarted Tomcat and Guacamole Services"

msg_info "Cleaning up"
cd ..
rm -rf guacamole-server-${GUACAMOLE_VERSION}*
rm apache-tomcat-${TOMCAT_VERSION}.tar.gz
msg_ok "Cleaned"