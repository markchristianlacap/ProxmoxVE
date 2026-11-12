#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2026 community-scripts ORG
# Author: Mark Christian Lacap
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/markchristianlacap/nuxt-net-monitoring

APP="Nuxt Network Monitoring"
var_tags="${var_tags:-monitoring;network}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-no}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/nuxt-net-monitoring/.git ]]; then
    msg_error "No ${APP} installation found!"
    exit 1
  fi

  run_os_update

  msg_info "Updating ${APP}"
  cd /opt/nuxt-net-monitoring
  systemctl stop nuxt-net-monitoring
  git pull --ff-only
  NODE_VERSION="24" NODE_MODULE="pnpm@10.18.3" setup_nodejs
  $STD pnpm install --frozen-lockfile
  $STD pnpm build
  $STD pnpm db:migrate
  systemctl start nuxt-net-monitoring
  msg_ok "Updated ${APP}"
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access the setup page using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:3000/setup${CL}"
