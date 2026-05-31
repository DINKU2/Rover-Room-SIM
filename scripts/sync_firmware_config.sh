#!/usr/bin/env bash
# Sync config/env → lidar_publisher sdkconfig (agent IP, port, domain ID).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

FW_DIR="$REPLICA_FIRMWARE_DEFAULT"
SDK="$FW_DIR/sdkconfig"
DEFAULTS="$FW_DIR/sdkconfig.defaults"

LAN_IP="${MICRO_ROS_AGENT_IP:-$(hostname -I | awk '{print $1}')}"
PORT="${MICRO_ROS_AGENT_PORT:-8090}"
DOMAIN="${ROS_DOMAIN_ID:-20}"

[ -f "$SDK" ] || { echo "Missing $SDK"; exit 1; }

set_kv() {
  local key="$1" val="$2" file="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$file"
  elif grep -q "^# ${key} is not set" "$file" 2>/dev/null; then
    sed -i "s|^# ${key} is not set|${key}=${val}|" "$file"
  else
    echo "${key}=${val}" >>"$file"
  fi
}

echo "Syncing firmware config from config/env:"
echo "  ROS_DOMAIN_ID=$DOMAIN"
echo "  MICRO_ROS_AGENT_IP=$LAN_IP"
echo "  MICRO_ROS_AGENT_PORT=$PORT"

set_kv "CONFIG_MICRO_ROS_DOMAIN_ID" "$DOMAIN" "$SDK"
set_kv 'CONFIG_MICRO_ROS_AGENT_IP' "\"${LAN_IP}\"" "$SDK"
set_kv 'CONFIG_MICRO_ROS_AGENT_PORT' "\"${PORT}\"" "$SDK"

cat >"$DEFAULTS" <<EOF
# Synced from config/env — run ./scripts/sync_firmware_config.sh
CONFIG_MICRO_ROS_DOMAIN_ID=${DOMAIN}
CONFIG_MICRO_ROS_AGENT_IP="${LAN_IP}"
CONFIG_MICRO_ROS_AGENT_PORT="${PORT}"
EOF

echo ""
echo "=== Firmware verify ==="
grep -E 'CONFIG_MICRO_ROS_DOMAIN_ID|CONFIG_MICRO_ROS_AGENT' "$SDK"
echo ""
echo "=== PC config/env ==="
grep -E 'ROS_DOMAIN_ID|MICRO_ROS_AGENT' "$REPLICA_ROOT/config/env"
echo ""
echo "=== Topics in firmware (main.c) ==="
grep -E 'ENABLE_LIDAR_PUBLISH|ENABLE_ODOM_PUBLISH|cmd_vel|"scan"|"odom"' \
  "$FW_DIR/main/main.c" | head -10
