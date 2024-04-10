#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/GyulyVGC/sniffnet

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y --no-install-recommends \
  libpcap-dev \
  dnsutils \
  iputils-ping \
  libasound2-dev \
  libfontconfig1-dev \
  libgtk-3-dev \
  build-essential \
  unzip \
  pkg-config \
  curl \
  sudo \
  git \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Rust (Patience)" 
$STD bash <(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs) -y
source ~/.cargo/env
msg_ok "Installed Rust" 

msg_info "Installing Sniffnet (Patience)" 
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/GyulyVGC/sniffnet/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
$STD wget -q --no-check-certificate "https://codeload.github.com/GyulyVGC/sniffnet/zip/refs/tags/${RELEASE}"
$STD unzip -q ${RELEASE}
CLEAN_RELEASE=$(echo "$RELEASE" | sed 's/^v//')
mv "sniffnet-${CLEAN_RELEASE}" sniffnet
rm -R ${RELEASE} 
cd sniffnet
cargo build -q --release
msg_ok "Installed Sniffnet"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/sniffnet.service
[Unit]
Description=Start Sniffnet Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/sniffnet
ExecStart=/root/.cargo/bin/cargo run -q --release

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now sniffnet.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
