#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/AnalogJ/scrutiny

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
  curl \
  debian-keyring \
  debian-archive-keyring \
  gnupg   \
  apt-transport-https \
  make \
  mc
msg_ok "Installed Dependencies"

# Add RabbitMQ signing key
msg_info "Adding RabbitMQ signing key"
curl -fsSL https://packages.erlang-solutions.com/debian/erlang_solutions.asc | sudo gpg --dearmor -o /usr/share/keyrings/erlang-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/erlang-archive-keyring.gpg] https://packages.erlang-solutions.com/debian $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/erlang.list
msg_ok "Adding Erlang"

msg_info "Adding RabbitMQ repository"
curl -fsSL https://packages.rabbitmq.com/rabbitmq-release-signing-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/rabbitmq-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/rabbitmq-archive-keyring.gpg] https://packages.rabbitmq.com/debian $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/rabbitmq.list
msg_ok "RabbitMQ repository added"

msg_info "Updating package list"
apt-get update -y
msg_ok "Package list updated"

# Install Erlang / RabbitMQ server
msg_info "Installing Erlang & RabbitMQ server"
sudo apt install -y erlang
apt-get install -y rabbitmq-server
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
