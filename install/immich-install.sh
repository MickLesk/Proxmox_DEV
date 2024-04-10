#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
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
$STD apt-get install -y --no-install-recommends \
  postgresql \
  postgresql-contrib \
  postgresql-server-dev-all \
  redis-server \
  python3 \
  python3-dev \
  python3-setuptools \
  uuid-runtime \
  ffmpeg \
  python3-venv \
  build-essential \
  curl \
  sudo \
  cmake \
  git \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Setup Immich User (Patience)"
sudo adduser \
  --home /opt/immich \
  --shell /usr/sbin/nologin \
  --no-create-home \
  --disabled-password \
  --disabled-login \
  --gecos "" \
  immich
sudo mkdir -p /opt/immich
sudo chown immich:immich /opt/immich
sudo chmod 700 /opt/immich
msg_ok "User Setup successfully" 

msg_info "Setting up Database"
DB_NAME=immich
DB_USER=immich
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 
$STD sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
echo "" >>~/immich.creds
echo -e "Immich Database User: \e[32m$DB_USER\e[0m" >>~/immich.creds
echo -e "Immich Database Password: \e[32m$DB_PASS\e[0m" >>~/immich.creds
echo -e "Immich Database Name: \e[32m$DB_NAME\e[0m" >>~/immich.creds
msg_ok "Set up PostgreSQL database"

msg_info "Setting up Env"
cd /opt/immich
cat <<EOF >/opt/immich/env
# You can find documentation for all the supported env variables at https://immich.app/docs/install/environment-variables

# Connection secret for postgres. You should change it to a random password
DB_PASSWORD=

# The values below this line do not need to be changed
###################################################################################
NODE_ENV=production

DB_USERNAME=immich
DB_DATABASE_NAME=immich
DB_VECTOR_EXTENSION=pgvector

# The location where your uploaded files are stored
UPLOAD_LOCATION=./library

# The Immich version to use. You can pin this to a specific version like "v1.71.0"
IMMICH_VERSION=release

# Hosts & ports
DB_HOSTNAME=127.0.0.1
MACHINE_LEARNING_HOST=127.0.0.1
IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003
REDIS_HOSTNAME=127.0.0.1
EOF
sudo sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" /opt/immich/env
sudo chown immich:immich /opt/immich/env
msg_ok "Env successfully set up"

msg_info "Setup Immich Dependencies (NodeJS, Redis...)"
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs 
cd /tmp
git clone --branch v0.6.2 https://github.com/pgvector/pgvector.git
cd pgvector
make
make install
rm -R /tmp/pgvector
$STD sudo -u postgres psql -c "CREATE EXTENSION vector;"
msg_ok "Dependencies Setup successfully" 

msg_info "Setup Immich" 
IMMICH_PATH=/opt/immich
APP=$IMMICH_PATH/app
mkdir -p $IMMICH_PATH
chown immich:immich $IMMICH_PATH
mkdir -p /var/log/immich
chown immich:immich /var/log/immich
rm -rf $APP
mkdir -p $APP
rm -rf $IMMICH_PATH/home
mkdir -p $IMMICH_PATH/home
TMP=/tmp/immich-$(uuidgen)
git clone https://github.com/immich-app/immich $TMP
cd $TMP
# immich-server
cd server
npm ci
npm run build
npm prune --omit=dev --omit=optional
cd -

cd open-api/typescript-sdk
npm ci
npm run build
cd -

cd web
npm ci
npm run build
cd -

cp -a server/node_modules server/dist server/bin $APP/
cp -a web/build $APP/www
cp -a server/resources server/package.json server/package-lock.json $APP/
cp -a server/start*.sh $APP/
cp -a LICENSE $APP/
cd $APP
npm cache clean --force
cd -

# immich-machine-learning
mkdir -p $APP/machine-learning
python3 -m venv $APP/machine-learning/venv
(
  # Initiate subshell to setup venv
  . $APP/machine-learning/venv/bin/activate
  pip3 install poetry
  cd machine-learning
  # pip install poetry
  poetry install --no-root --with dev --with cpu
  cd ..
)
cp -a machine-learning/ann machine-learning/start.sh machine-learning/app $APP/machine-learning/
# Replace /usr/src
cd $APP
grep -Rl /usr/src | xargs -n1 sed -i -e "s@/usr/src@$IMMICH_PATH@g"
ln -sf $IMMICH_PATH/app/resources $IMMICH_PATH/
mkdir -p $IMMICH_PATH/cache
sed -i -e "s@\"/cache\"@\"$IMMICH_PATH/cache\"@g" $APP/machine-learning/app/config.py

# Install sharp
cd $APP
npm install sharp

# Setup upload directory
mkdir -p $IMMICH_PATH/upload
ln -s $IMMICH_PATH/upload $APP/
ln -s $IMMICH_PATH/upload $APP/machine-learning/
# Use 127.0.0.1
sed -i -e "s@app.listen(port)@app.listen(port, '127.0.0.1')@g" $APP/dist/main.js
cat <<EOF > $APP/start.sh
#!/bin/bash

set -a
. $IMMICH_PATH/env
set +a

cd $APP
exec node $APP/dist/main "\$@"
EOF

cat <<EOF > $APP/machine-learning/start.sh
#!/bin/bash

set -a
. $IMMICH_PATH/env
set +a

cd $APP/machine-learning
. venv/bin/activate

: "\${MACHINE_LEARNING_HOST:=127.0.0.1}"
: "\${MACHINE_LEARNING_PORT:=3003}"
: "\${MACHINE_LEARNING_WORKERS:=1}"
: "\${MACHINE_LEARNING_WORKER_TIMEOUT:=120}"

exec gunicorn app.main:app \
        -k app.config.CustomUvicornWorker \
        -w "\$MACHINE_LEARNING_WORKERS" \
        -b "\$MACHINE_LEARNING_HOST":"\$MACHINE_LEARNING_PORT" \
        -t "\$MACHINE_LEARNING_WORKER_TIMEOUT" \
        --log-config-json log_conf.json \
        --graceful-timeout 0
EOF

# Cleanup
rm -rf $TMP

sudo cp immich*.service /etc/systemd/system/
sudo systemctl daemon-reload
for i in immich*.service; do
  sudo systemctl enable $i
  sudo systemctl start $i
done

msg_info "Set up web services"
cat <<EOF >/etc/systemd/system/immich-machine-learning.service
[Unit]
Description=immich machine-learning
Documentation=https://github.com/immich-app/immich

[Service]
User=immich
Group=immich
Type=simple
Restart=on-failure

WorkingDirectory=/opt/immich/app
EnvironmentFile=/opt/immich/env
ExecStart=/opt/immich/app/machine-learning/start.sh

SyslogIdentifier=immich-machine-learning
StandardOutput=append:/var/log/immich/immich-machine-learning.log
StandardError=append:/var/log/immich/immich-machine-learning.log

[Install]
WantedBy=multi-user.target
EOF
cat <<EOF >/etc/systemd/system/immich-microservices.service
[Unit]
Description=immich microservices
Documentation=https://github.com/immich-app/immich
Requires=redis-server.service
Requires=postgresql.service

[Service]
User=immich
Group=immich
Type=simple
Restart=on-failure

WorkingDirectory=/opt/immich/app
EnvironmentFile=/opt/immich/env
ExecStart=node /opt/immich/app/dist/main microservices

SyslogIdentifier=immich-microservices
StandardOutput=append:/var/log/immich/immich-microservices.log
StandardError=append:/var/log/immich/immich-microservices.log

[Install]
WantedBy=multi-user.target
EOF
cat <<EOF >/etc/systemd/system/immich.service
[Unit]
Description=immich server
Documentation=https://github.com/immich-app/immich
Requires=redis-server.service
Requires=postgresql.service
Requires=immich-machine-learning.service
Requires=immich.service

[Service]
User=immich
Group=immich
Type=simple
Restart=on-failure

WorkingDirectory=/opt/immich/app
EnvironmentFile=/opt/immich/env
ExecStart=node /opt/immich/app/dist/main immich

SyslogIdentifier=immich
StandardOutput=append:/var/log/immich/immich.log
StandardError=append:/var/log/immich/immich.log

[Install]
WantedBy=multi-user.target
EOF


$STD sudo systemctl enable --now gunicorn_tandoor
$STD sudo systemctl reload nginx
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
