#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# Co-Author: remz1337
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y \
    curl sudo mc git gpg ca-certificates automake build-essential xz-utils libtool ccache pkg-config \
    libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev \
    libjpeg-dev libpng-dev libtiff-dev gfortran openexr libatlas-base-dev libssl-dev libtbb-dev \
    libopenexr-dev libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev gcc gfortran \
    libopenblas-dev liblapack-dev libusb-1.0-0-dev jq moreutils tclsh libhdf5-dev libopenexr-dev
msg_ok "Dependencies Installed"

msg_info "Setting Up Python3"
$STD apt-get install -y python3 python3-dev python3-setuptools python3-distutils python3-pip
$STD pip install --upgrade pip
msg_ok "Python3 Setup Complete"

msg_info "Installing Node.js"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
msg_ok "Node.js Installed"

msg_info "Installing go2rtc"
mkdir -p /usr/local/go2rtc/bin
cd /usr/local/go2rtc/bin
wget -qO go2rtc "https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_amd64"
chmod +x go2rtc
ln -sf /usr/local/go2rtc/bin/go2rtc /usr/local/bin/go2rtc
msg_ok "Installed go2rtc"

msg_info "Setting Up Hardware Acceleration"
$STD apt-get -y install {va-driver-all,ocl-icd-libopencl1,intel-opencl-icd,vainfo,intel-gpu-tools}
if [[ "$CTTYPE" == "0" ]]; then
  chgrp video /dev/dri
  chmod 755 /dev/dri
  chmod 660 /dev/dri/*
fi
if [[ "$CTTYPE" == "0" ]]; then
  sed -i -e 's/^kvm:x:104:$/render:x:104:root,frigate/' -e 's/^render:x:105:root$/kvm:x:105:/' /etc/group
else
  sed -i -e 's/^kvm:x:104:$/render:x:104:frigate/' -e 's/^render:x:105:$/kvm:x:105:/' /etc/group
fi
echo "tmpfs   /tmp/cache      tmpfs   defaults        0       0" >> /etc/fstab
msg_ok "Set Up Hardware Acceleration"

msg_info "Building and Installing libUSB without udev"
wget -qO /tmp/libusb.zip https://github.com/libusb/libusb/archive/v1.0.26.zip
unzip -q /tmp/libusb.zip -d /tmp/
cd /tmp/libusb-1.0.26
$STD ./bootstrap.sh
$STD ./configure --disable-udev --enable-shared
$STD make -j$(nproc --all)
$STD make install
$STD ldconfig
rm -rf /tmp/libusb.zip /tmp/libusb-1.0.26
msg_ok "libUSB Installed without udev"


msg_info "Installing Frigate"
RELEASE=$(curl -s https://api.github.com/repos/blakeblackshear/frigate/releases/latest | jq -r '.tag_name')
mkdir -p /opt/frigate/models
wget -q https://github.com/blakeblackshear/frigate/archive/refs/tags/${RELEASE}.zip 
unzip -q v${RELEASE}.zip
mv frigate-${RELEASE} /opt/frigate
cd /opt/frigate
$STD pip install -r /opt/frigate/docker/main/requirements.txt --break-system-packages
$STD pip install -r /opt/frigate/docker/main/requirements-ov.txt --break-system-packages
$STD pip3 wheel --wheel-dir=/wheels -r /opt/frigate/docker/main/requirements-wheels.txt
$STD  pip3 install -U /wheels/*.whl
cp -a /opt/frigate/docker/main/rootfs/. /
msg_ok "Frigate Installed - Version: $RELEASE"

read -p "Semantic Search requires a dedicated GPU and at least 16GB RAM. Would you like to install it? (y/n): " semantic_choice
if [[ "$semantic_choice" == "y" ]]; then
    msg_info "Configuring Semantic Search & AI Models"
    mkdir -p /opt/frigate/models/semantic_search
    wget -qO /opt/frigate/models/semantic_search/clip_model.pt https://huggingface.co/openai/clip-vit-base-patch32/resolve/main/pytorch_model.bin
    msg_ok "Semantic Search Models Installed"
else
    msg_ok "Skipped Semantic Search Setup"
fi
msg_info "Building and Installing libUSB without udev"
cd /opt/frigate
export CCACHE_DIR=/root/.ccache
export CCACHE_MAXSIZE=2G
wget -q https://github.com/libusb/libusb/archive/v1.0.26.zip
unzip -q v1.0.26.zip
rm v1.0.26.zip
cd libusb-1.0.26
$STD ./bootstrap.sh
$STD ./configure --disable-udev --enable-shared
$STD make -j $(nproc --all)
cd /opt/frigate/libusb-1.0.26/libusb
mkdir -p /usr/local/lib
$STD /bin/bash ../libtool  --mode=install /usr/bin/install -c libusb-1.0.la '/usr/local/lib'
mkdir -p /usr/local/include/libusb-1.0
$STD /usr/bin/install -c -m 644 libusb.h '/usr/local/include/libusb-1.0'
ldconfig
cd /
wget -qO edgetpu_model.tflite https://github.com/google-coral/test_data/raw/release-frogfish/ssdlite_mobiledet_coco_qat_postprocess_edgetpu.tflite
wget -qO cpu_model.tflite https://github.com/google-coral/test_data/raw/release-frogfish/ssdlite_mobiledet_coco_qat_postprocess.tflite
cp /opt/frigate/labelmap.txt /labelmap.txt
wget -qO yamnet-tflite-classification-tflite-v1.tar.gz https://www.kaggle.com/api/v1/models/google/yamnet/tfLite/classification-tflite/1/download
tar xzf yamnet-tflite-classification-tflite-v1.tar.gz
rm -rf yamnet-tflite-classification-tflite-v1.tar.gz
mv 1.tflite cpu_audio_model.tflite
cp /opt/frigate/audio-labelmap.txt /audio-labelmap.txt
mkdir -p /media/frigate
wget -qO /media/frigate/person-bicycle-car-detection.mp4 https://github.com/intel-iot-devkit/sample-videos/raw/master/person-bicycle-car-detection.mp4
msg_ok "Installed Coral Object Detection Model"

msg_info "Building Nginx with Custom Modules"
$STD /opt/frigate/docker/main/build_nginx.sh
sed -e '/s6-notifyoncheck/ s/^#*/#/' -i /opt/frigate/docker/main/rootfs/etc/s6-overlay/s6-rc.d/nginx/run
ln -sf /usr/local/nginx/sbin/nginx  /usr/local/bin/nginx
msg_ok "Built Nginx"

msg_info "Installing Tempio"
sed -i 's|/rootfs/usr/local|/usr/local|g' /opt/frigate/docker/main/install_tempio.sh
$STD /opt/frigate/docker/main/install_tempio.sh
chmod +x /usr/local/tempio/bin/tempio
ln -sf /usr/local/tempio/bin/tempio /usr/local/bin/tempio
msg_ok "Installed Tempio"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/create_directories.service
[Unit]
Description=Create necessary directories for logs

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/bin/mkdir -p /dev/shm/logs/{frigate,go2rtc,nginx} && /bin/touch /dev/shm/logs/{frigate/current,go2rtc/current,nginx/current} && /bin/chmod -R 777 /dev/shm/logs'

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now create_directories
sleep 3
cat <<EOF >/etc/systemd/system/go2rtc.service
[Unit]
Description=go2rtc service
After=network.target
After=create_directories.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
ExecStartPre=+rm /dev/shm/logs/go2rtc/current
ExecStart=/bin/bash -c "bash /opt/frigate/docker/main/rootfs/etc/s6-overlay/s6-rc.d/go2rtc/run 2> >(/usr/bin/ts '%%Y-%%m-%%d %%H:%%M:%%.S ' >&2) | /usr/bin/ts '%%Y-%%m-%%d %%H:%%M:%%.S '"
StandardOutput=file:/dev/shm/logs/go2rtc/current
StandardError=file:/dev/shm/logs/go2rtc/current

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now go2rtc
sleep 3
cat <<EOF >/etc/systemd/system/frigate.service
[Unit]
Description=Frigate service
After=go2rtc.service
After=create_directories.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
# Environment=PLUS_API_KEY=
ExecStartPre=+rm /dev/shm/logs/frigate/current
ExecStart=/bin/bash -c "bash /opt/frigate/docker/main/rootfs/etc/s6-overlay/s6-rc.d/frigate/run 2> >(/usr/bin/ts '%%Y-%%m-%%d %%H:%%M:%%.S ' >&2) | /usr/bin/ts '%%Y-%%m-%%d %%H:%%M:%%.S '"
StandardOutput=file:/dev/shm/logs/frigate/current
StandardError=file:/dev/shm/logs/frigate/current

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now frigate
sleep 3
cat <<EOF >/etc/systemd/system/nginx.service
[Unit]
Description=Nginx service
After=frigate.service
After=create_directories.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
ExecStartPre=+rm /dev/shm/logs/nginx/current
ExecStart=/bin/bash -c "bash /opt/frigate/docker/main/rootfs/etc/s6-overlay/s6-rc.d/nginx/run 2> >(/usr/bin/ts '%%Y-%%m-%%d %%H:%%M:%%.S ' >&2) | /usr/bin/ts '%%Y-%%m-%%d %%H:%%M:%%.S '"
StandardOutput=file:/dev/shm/logs/nginx/current
StandardError=file:/dev/shm/logs/nginx/current

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now nginx
msg_ok "Configured Services"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
