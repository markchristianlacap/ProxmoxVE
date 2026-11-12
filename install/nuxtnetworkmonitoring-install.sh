#!/usr/bin/env bash

# Copyright (c) 2026 community-scripts ORG
# Author: Mark Christian Lacap
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/markchristianlacap/nuxt-net-monitoring

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing system dependencies"
$STD apt install -y \
  curl \
  git \
  iputils-ping \
  openssl \
  postgresql \
  snmp
msg_ok "Installed system dependencies"

msg_info "Installing Ookla Speedtest CLI"
SPEEDTEST_REPO_SCRIPT="$(mktemp)"
curl -fsSL https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh -o "$SPEEDTEST_REPO_SCRIPT"
$STD bash "$SPEEDTEST_REPO_SCRIPT"
rm -f "$SPEEDTEST_REPO_SCRIPT"
$STD apt install -y speedtest
msg_ok "Installed Ookla Speedtest CLI"

NODE_VERSION="24" NODE_MODULE="pnpm@10.18.3" setup_nodejs

msg_info "Starting PostgreSQL"
systemctl enable -q --now postgresql
msg_ok "Started PostgreSQL"

msg_info "Creating application database"
DB_PASSWORD="$(openssl rand -hex 32)"
runuser -u postgres -- psql --set=ON_ERROR_STOP=1 <<SQL
CREATE ROLE nuxt_net_monitor LOGIN PASSWORD '${DB_PASSWORD}';
CREATE DATABASE "net-monitor" OWNER nuxt_net_monitor;
SQL
install -d -m 755 /opt/nuxt-net-monitoring
msg_ok "Created application database"

msg_info "Downloading Nuxt Network Monitoring"
git clone --depth 1 https://github.com/markchristianlacap/nuxt-net-monitoring.git /opt/nuxt-net-monitoring
cat <<EOF >/opt/nuxt-net-monitoring/.env
NUXT_DB_HOST=127.0.0.1
NUXT_DB_PORT=5432
NUXT_DB_USER=nuxt_net_monitor
NUXT_DB_PASSWORD=${DB_PASSWORD}
NUXT_DB_NAME=net-monitor
EOF
chmod 600 /opt/nuxt-net-monitoring/.env
unset DB_PASSWORD
msg_ok "Downloaded application"

msg_info "Installing and building Nuxt Network Monitoring"
cd /opt/nuxt-net-monitoring
$STD pnpm install --frozen-lockfile
$STD pnpm db:migrate
$STD pnpm build
msg_ok "Installed and built application"

msg_info "Creating service user"
useradd --system --user-group --home-dir /var/lib/nuxt-net-monitoring --create-home --shell /usr/sbin/nologin nuxt-net-monitoring
chown root:nuxt-net-monitoring /opt/nuxt-net-monitoring/.env
chmod 640 /opt/nuxt-net-monitoring/.env
msg_ok "Created service user"

msg_info "Creating systemd service"
cat <<'EOF' >/etc/systemd/system/nuxt-net-monitoring.service
[Unit]
Description=Nuxt Network Monitoring
Wants=network-online.target postgresql.service
After=network-online.target postgresql.service

[Service]
Type=simple
User=nuxt-net-monitoring
Group=nuxt-net-monitoring
WorkingDirectory=/opt/nuxt-net-monitoring
EnvironmentFile=/opt/nuxt-net-monitoring/.env
Environment=NODE_ENV=production
Environment=NITRO_HOST=0.0.0.0
Environment=NITRO_PORT=3000
ExecStart=/usr/bin/node .output/server/index.mjs
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now nuxt-net-monitoring
msg_ok "Created and started systemd service"

motd_ssh
customize
cleanup_lxc
