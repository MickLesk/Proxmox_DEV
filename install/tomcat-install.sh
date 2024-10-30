#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y lsb-base
$STD apt-get install -y lsb-release
$STD apt-get install -y gnupg2
msg_ok "Installed Dependencies"

# Choose Tomcat version
read -r -p "Which Tomcat version would you like to install? (9, 10.1, 11): " version
case $version in
  9)
    TOMCAT_VERSION="9"
    echo "Which JDK version would you like to use? (8, 11, 17): "
    read -r jdk_version
    case $jdk_version in
      8)
        msg_info "Installing OpenJDK 8 for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y openjdk-8-jdk
        ;;
      11|17)
        msg_info "Installing OpenJDK 11 for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y openjdk-11-jdk
        ;;
      *)
        echo -e "\e[31m[ERROR] Invalid JDK version selected. Please enter 8, 11, or 17.\e[0m"
        exit 1
        ;;
    esac
    ;;
  10.1)
    TOMCAT_VERSION="10.1"
    echo "Which JDK version would you like to use? (11, 17): "
    read -r jdk_version
    case $jdk_version in
      11)
        msg_info "Installing OpenJDK 11 for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y openjdk-11-jdk
        ;;
      17)
        msg_info "Installing OpenJDK 17 for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y openjdk-17-jdk
        ;;
      *)
        echo -e "\e[31m[ERROR] Invalid JDK version selected. Please enter 11 or 17.\e[0m"
        exit 1
        ;;
    esac
    ;;
  11)
    TOMCAT_VERSION="11"
    msg_info "Installing OpenJDK 17 for Tomcat $TOMCAT_VERSION"
    $STD apt-get install -y openjdk-17-jdk
    ;;
  *)
    echo -e "\e[31m[ERROR] Invalid version selected. Please enter 9, 10.1, or 11.\e[0m"
    exit 1
    ;;
esac

msg_info "Installing Tomcat $TOMCAT_VERSION"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-$TOMCAT_VERSION/latest/apache-tomcat-$TOMCAT_VERSION*.tar.gz"
wget -qO /tmp/tomcat.tar.gz "$TOMCAT_URL"
catch_errors

tar -xzf /tmp/tomcat.tar.gz -C /opt/
catch_errors

# Create a symbolic link
ln -s /opt/apache-tomcat-$TOMCAT_VERSION.* /opt/tomcat
catch_errors

# Set permissions
chown -R $(whoami):$(whoami) /opt/apache-tomcat-$TOMCAT_VERSION.*
catch_errors

# Set up Tomcat as a service
cat <<EOT > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=simple
User=$(whoami)
Group=$(whoami)
Environment=JAVA_HOME=/usr/lib/jvm/java-${jdk_version}-openjdk-amd64
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOT

# Enable and start the service
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat
msg_ok "Tomcat $TOMCAT_VERSION installed and started"

msg_info "Cleaning up"
rm -f /tmp/tomcat.tar.gz
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
