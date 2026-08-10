#!/usr/bin/env bash
# Sync config/env + config/wifi.env → lidar_publisher sdkconfig (agent IP, Wi-Fi).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
# shellcheck source=lib/wifi_env.sh
source "$(dirname "$0")/lib/wifi_env.sh"

require_wifi_credentials

FW_DIR="$REPLICA_FIRMWARE_DEFAULT"
SDK="$FW_DIR/sdkconfig"
DEFAULTS="$FW_DIR/sdkconfig.defaults"
DRIVE_BAK="$FW_DIR/sdkconfig.drive.bak"
CAMERA_DEFAULTS="$FW_DIR/sdkconfig.defaults.camera"

LAN_IP="${MICRO_ROS_AGENT_IP:-$(hostname -I | awk '{print $1}')}"
PORT="${MICRO_ROS_AGENT_PORT:-8090}"
DOMAIN="${ROS_DOMAIN_ID:-20}"
WIFI_SSID="${ESP_WIFI_SSID}"
WIFI_PASS="${ESP_WIFI_PASSWORD}"

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

echo "Syncing firmware config from config/env + config/wifi.env:"
echo "  ROS_DOMAIN_ID=$DOMAIN"
echo "  MICRO_ROS_AGENT_IP=$LAN_IP"
echo "  MICRO_ROS_AGENT_PORT=$PORT"
echo "  ESP_WIFI_SSID=$WIFI_SSID"

set_kv "CONFIG_MICRO_ROS_DOMAIN_ID" "$DOMAIN" "$SDK"
set_kv 'CONFIG_MICRO_ROS_AGENT_IP' "\"${LAN_IP}\"" "$SDK"
set_kv 'CONFIG_MICRO_ROS_AGENT_PORT' "\"${PORT}\"" "$SDK"
set_kv 'CONFIG_ESP_WIFI_SSID' "\"${WIFI_SSID}\"" "$SDK"
set_kv 'CONFIG_ESP_WIFI_PASSWORD' "\"${WIFI_PASS}\"" "$SDK"

if [ -f "$DRIVE_BAK" ]; then
  set_kv "CONFIG_MICRO_ROS_DOMAIN_ID" "$DOMAIN" "$DRIVE_BAK"
  set_kv 'CONFIG_MICRO_ROS_AGENT_IP' "\"${LAN_IP}\"" "$DRIVE_BAK"
  set_kv 'CONFIG_MICRO_ROS_AGENT_PORT' "\"${PORT}\"" "$DRIVE_BAK"
  set_kv 'CONFIG_ESP_WIFI_SSID' "\"${WIFI_SSID}\"" "$DRIVE_BAK"
  set_kv 'CONFIG_ESP_WIFI_PASSWORD' "\"${WIFI_PASS}\"" "$DRIVE_BAK"
fi

if [ -f "$CAMERA_DEFAULTS" ]; then
  set_kv 'CONFIG_ESP_WIFI_SSID' "\"${WIFI_SSID}\"" "$CAMERA_DEFAULTS"
  set_kv 'CONFIG_ESP_WIFI_PASSWORD' "\"${WIFI_PASS}\"" "$CAMERA_DEFAULTS"
  set_kv 'CONFIG_MICRO_ROS_AGENT_IP' "\"${LAN_IP}\"" "$CAMERA_DEFAULTS"
fi

cat >"$DEFAULTS" <<EOF
# Synced from config/env + config/wifi.env — run ./scripts/sync_firmware_config.sh
CONFIG_MICRO_ROS_DOMAIN_ID=${DOMAIN}
CONFIG_MICRO_ROS_AGENT_IP="${LAN_IP}"
CONFIG_MICRO_ROS_AGENT_PORT="${PORT}"
CONFIG_ESP_WIFI_SSID="${WIFI_SSID}"
CONFIG_ESP_WIFI_PASSWORD="${WIFI_PASS}"
EOF

echo ""
echo "=== Firmware verify ==="
grep -E 'CONFIG_MICRO_ROS_DOMAIN_ID|CONFIG_MICRO_ROS_AGENT|CONFIG_ESP_WIFI_SSID' "$SDK"
echo ""
echo "=== PC config/env ==="
grep -E 'ROS_DOMAIN_ID|MICRO_ROS_AGENT' "$REPLICA_ROOT/config/env" 2>/dev/null || echo "(config/env not found)"
echo ""
echo "=== Topics in firmware (main.c) ==="
grep -E 'ENABLE_LIDAR_PUBLISH|ENABLE_ODOM_PUBLISH|cmd_vel|"scan"|"odom"' \
  "$FW_DIR/main/main.c" | head -10
