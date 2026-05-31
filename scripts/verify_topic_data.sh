#!/usr/bin/env bash
# Prove topics have real samples (not just names on the graph).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [ -f /opt/ros/humble/setup.bash ]; then
  . /opt/ros/humble/setup.bash
fi

echo "=== Topic data verification (ROS_DOMAIN_ID=$ROS_DOMAIN_ID) ==="
echo ""

topic_publishers() {
  timeout 8s ros2 topic info "$1" -v 2>/dev/null | awk '/Publisher count:/{print $3; exit}'
}

check_odom() {
  local pubs
  pubs="$(topic_publishers /odom)"
  echo "--- /odom (nav_msgs/Odometry, RELIABLE) ---"
  echo "Publishers: ${pubs:-0}"
  if [ "${pubs:-0}" = "0" ]; then
    echo "[FAIL] No publisher"
    return 1
  fi
  local out
  out="$(timeout 8s ros2 topic echo /odom --once 2>/dev/null)" || true
  if [ -z "$out" ]; then
    echo "[FAIL] Publisher exists but no sample in 8s"
    return 1
  fi
  local x y
  x="$(echo "$out" | awk '/position:/{getline; if (/x:/) print $2}' | head -1)"
  y="$(echo "$out" | awk '/position:/{getline; getline; if (/y:/) print $2}' | head -1)"
  echo "[OK] Sample received  position x=${x:-?} y=${y:-?}"
  echo "$out" | head -20
  return 0
}

check_scan() {
  local pubs
  pubs="$(topic_publishers /scan)"
  echo ""
  echo "--- /scan (sensor_msgs/LaserScan, BEST_EFFORT) ---"
  echo "Publishers: ${pubs:-0}"
  if [ "${pubs:-0}" = "0" ]; then
    echo "[FAIL] No publisher"
    return 1
  fi
  local out
  out="$(timeout 8s ros2 topic echo /scan --qos-profile sensor_data --once --no-arr 2>/dev/null)" || true
  if [ -z "$out" ]; then
    echo "[FAIL] Publisher exists but no sample in 8s (try sensor_data QoS)"
    return 1
  fi
  local n
  n="$(echo "$out" | awk '/length:/{print $2; exit}')"
  if [ -z "$n" ]; then
    n="$(echo "$out" | awk '/ranges:/{print $2}' | sed "s/['<>]//g" | sed 's/sequence//g')"
  fi
  echo "[OK] Sample received  ranges=${n:-?}"
  echo "$out" | head -18
  return 0
}

FAIL=0
check_odom || FAIL=1
check_scan || FAIL=1

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "=== RESULT: live data confirmed ==="
else
  echo "=== RESULT: topic names may exist but data path is broken ==="
  exit 1
fi
