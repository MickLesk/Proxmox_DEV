#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/hudikhq/hoodik

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y --no-install-recommends \
  unzip \
  pkg-config \
  libasound2-dev \
  libpulse-dev \
  libvorbisidec-dev \
  libvorbis-dev \
  libopus-dev \
  libflac-dev \
  libsoxr-dev \
  alsa-utils \
  libavahi-client-dev \
  avahi-daemon \
  libexpat1-dev \
  debhelper \
  python3 \
  cmake \
  curl \
  sudo \
  git \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Snapcast (Patience)" 
cd /opt
git clone https://github.com/badaix/snapcast.git
cd snapcast
mkdir build
msg_ok "Installed Snapcast"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/snapcast.service
[Unit]
Description=Start Snapcast Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/snapcast
ExecStart=/opt/snapcast && mkdir build

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now snapcast.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
