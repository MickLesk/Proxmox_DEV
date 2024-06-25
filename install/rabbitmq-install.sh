#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://www.rabbitmq.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  sudo \
  lsb-release \
  curl \
  debian-keyring \
  debian-archive-keyring \
  gnupg   \
  apt-transport-https \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Adding RabbitMQ signing key"
wget -qO- "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | gpg --dearmor >/usr/share/keyrings/com.rabbitmq.team.gpg
wget -qO- "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key" | gpg --dearmor >/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg
wget -qO- "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key" | gpg --dearmor >/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg

msg_ok "Adding Erlang"

msg_info "Adding RabbitMQ repository"
sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Provides modern Erlang/OTP releases from a Cloudsmith mirror
deb [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/debian $(lsb_release -cs) main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/debian $(lsb_release -cs) main

## Provides RabbitMQ from a Cloudsmith mirror
deb [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/debian $(lsb_release -cs) main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/debian $(lsb_release -cs) main
EOF
msg_ok "RabbitMQ repository added"

msg_info "Updating package list"
sudo apt-get update -y
msg_ok "Package list updated"

# Install Erlang / RabbitMQ server
msg_info "Installing Erlang & RabbitMQ server"
sudo apt-get install -y erlang-base \
                        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                        erlang-runtime-tools erlang-snmp erlang-ssl \
                        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl \
                        rabbitmq-server
msg_ok "RabbitMQ server installed"

# Start RabbitMQ service
msg_info "Starting RabbitMQ service"
systemctl start rabbitmq-server
msg_ok "RabbitMQ service started"

# Enable RabbitMQ management plugin
msg_info "Enabling RabbitMQ management plugin"
rabbitmq-plugins enable rabbitmq_management
msg_ok "RabbitMQ management plugin enabled"

# Set permissions for guest user (optional)
msg_info "Setting permissions for guest user"
rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"
msg_ok "Permissions set for guest user"

# Display RabbitMQ management UI information
RABBITMQ_IP=$(hostname -I | awk '{print $1}')
msg_info "RabbitMQ installation completed successfully"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
