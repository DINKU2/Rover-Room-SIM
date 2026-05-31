#!/usr/bin/env bash
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

echo "=============================================="
echo "  SLAM / TF diagnostic"
echo "  ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "=============================================="
echo ""

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q micro_ros_udp_agent; then
  echo "[OK] micro-ROS UDP agent running"
else
  echo "[!!] agent NOT running — ./scripts/start_agent.sh"
fi
echo ""

echo "--- Topics ---"
ros2 topic list 2>/dev/null || { echo "ros2 failed"; exit 1; }
echo ""

check_topic() {
  local t="$1"
  if ros2 topic list 2>/dev/null | grep -qx "$t"; then
    local pub sub
    pub=$(ros2 topic info "$t" 2>/dev/null | awk '/Publisher count/{print $3}')
    sub=$(ros2 topic info "$t" 2>/dev/null | awk '/Subscription count/{print $3}')
    printf "[OK] %-12s  pub=%s sub=%s\n" "$t" "$pub" "$sub"
    return 0
  fi
  printf "[--] %-12s  MISSING\n" "$t"
  return 1
}

have_scan=0 have_odom=0 have_map=0
check_topic /scan && have_scan=1
check_topic /odom && have_odom=1
check_topic /cmd_vel && true
check_topic /map && have_map=1
echo ""

echo "--- TF (3s) ---"
if timeout 3 ros2 run tf2_ros tf2_echo odom base_footprint 2>&1 | grep -q "At time"; then
  echo "[OK] TF odom -> base_footprint"
else
  echo "[!!] TF odom -> base_footprint MISSING (need /odom + slam_toolbox)"
fi
if timeout 3 ros2 run tf2_ros tf2_echo base_link laser_frame 2>&1 | grep -q "At time"; then
  echo "[OK] TF base_link -> laser_frame"
else
  echo "[!!] TF base_link -> laser_frame MISSING (run slam launch for static TF)"
fi
echo ""

if [ "$have_odom" = 0 ]; then
  echo ">>> /odom missing — flash merged lidar_publisher firmware (see docs/FIRMWARE.md)"
fi
if [ "$have_map" = 1 ]; then
  echo "[OK] /map present — SLAM is publishing"
fi
