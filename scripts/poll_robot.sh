#!/usr/bin/env bash
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
if [ -f /opt/ros/humble/setup.bash ]; then . /opt/ros/humble/setup.bash; fi

for i in 1 2 3 4 5 6; do
  echo "--- poll $i ---"
  docker inspect -f 'agent={{.State.Running}}' micro_ros_udp_agent 2>/dev/null || echo agent=missing
  ros2 topic list 2>/dev/null || true
  ros2 topic info /odom -v 2>/dev/null | grep -E 'Publisher|Node name' || true
  sleep 5
done
docker logs --tail 25 micro_ros_udp_agent 2>&1 || true
