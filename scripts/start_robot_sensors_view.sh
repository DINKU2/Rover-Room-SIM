#!/usr/bin/env bash
# View lidar + camera together: micro-ROS agent, image bridge, RViz laser scan.
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

RVIZ_CONFIG="${RVIZ_CONFIG:-$REPLICA_ROOT/ros/yahboomcar_ws/src/yahboomcar_nav/rviz/sensors_view.rviz}"

echo "=== Robot sensors view (lidar + camera) ==="
echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID  agent=${MICRO_ROS_AGENT_IP:-?}:${MICRO_ROS_AGENT_PORT:-8090}"
echo ""

"$REPLICA_SCRIPTS/start_agent.sh"
"$REPLICA_SCRIPTS/start_camera_agent.sh"

cleanup() {
  [ -n "${SUB_IMG_PID:-}" ] && kill "$SUB_IMG_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Starting camera viewer (subscribes /espRos/esp32camera → /esp32_img + OpenCV window)..."
ros2 run yahboom_esp32_camera sub_img &
SUB_IMG_PID=$!
sleep 2

echo ""
echo "ROS topics (expect /scan, /odom from drive board + /espRos/esp32camera from WiFi camera module):"
timeout 5 ros2 topic list 2>/dev/null | grep -E 'scan|odom|esp32|cmd_vel' || true
echo ""

if timeout 4 ros2 topic hz /espRos/esp32camera 2>/dev/null | grep -q average; then
  echo "[ok] Camera publishing JPEG frames"
else
  echo "[!!] No camera frames yet on /espRos/esp32camera"
  echo "     Yahboom camera uses agent port 9999 (started). Configure module WiFi:"
  echo "     ./scripts/configure_camera_wifi.sh  (camera module serial, not main board)"
fi

if timeout 4 ros2 topic hz /scan 2>/dev/null | grep -q average; then
  echo "[ok] Lidar /scan active"
else
  echo "[!!] No /scan yet — check drive board Wi-Fi and agent IP"
fi

echo ""
echo "Opening RViz (LaserScan on /scan). Add Image display → /esp32_img for camera overlay."
if [ -f "$RVIZ_CONFIG" ]; then
  rviz2 -d "$RVIZ_CONFIG"
else
  rviz2
fi
