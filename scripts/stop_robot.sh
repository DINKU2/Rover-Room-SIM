#!/usr/bin/env bash
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

STOP='{linear: {x: 0.0, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}'
echo "Emergency stop on /cmd_vel (ROS_DOMAIN_ID=$ROS_DOMAIN_ID)..."
for _ in 1 2 3 4 5 6 7 8 9 10; do
  ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "$STOP" >/dev/null 2>&1 || true
  sleep 0.08
done
echo "Done."
