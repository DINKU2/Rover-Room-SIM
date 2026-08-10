#!/usr/bin/env bash
# Report lidar + camera ROS status and explain Yahboom two-ESP layout.
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

echo "=== Robot sensor check (domain $ROS_DOMAIN_ID) ==="
echo "Agent target: ${MICRO_ROS_AGENT_IP:-?}:${MICRO_ROS_AGENT_PORT:-8090}"
echo ""

"$REPLICA_SCRIPTS/start_agent.sh" 2>/dev/null || true
"$REPLICA_SCRIPTS/start_camera_agent.sh" 2>/dev/null || true

check_hz() {
  local topic=$1
  if timeout 4 ros2 topic hz "$topic" 2>/dev/null | grep -q average; then
    echo "  [OK] $topic publishing"
    return 0
  fi
  echo "  [--] $topic — no data"
  return 1
}

echo "Drive board (main ESP, Wi-Fi):"
check_hz /scan || true
check_hz /odom || true

echo ""
echo "Camera module (second ESP, Wi-Fi):"
check_hz /espRos/esp32camera || true

echo ""
if [ -e /dev/ttyUSB0 ]; then
  echo "USB serial: /dev/ttyUSB0 (this is the MAIN board when robot is on USB)"
  "$REPLICA_SCRIPTS/identify_esp_port.sh" /dev/ttyUSB0 2>/dev/null || true
else
  echo "USB serial: none (normal when only the robot battery is on)"
fi

echo ""
echo "Architecture: camera cable → main board port → separate WiFi camera ESP."
echo "See docs/CAMERA_HARDWARE.md"
echo ""
echo "View lidar + camera: ./scripts/start_robot_sensors_view.sh"
echo "Flash/configure camera module (module USB, not main board): ./scripts/setup_camera_module.sh"
