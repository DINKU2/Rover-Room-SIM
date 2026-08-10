#!/usr/bin/env bash
# Clear stale ROS 2 daemon + restart micro-ROS agent; wait until /odom+/scan live.
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

WAIT_SEC="${1:-45}"
echo "== Reset robot ROS stack (domain ${ROS_DOMAIN_ID}, wait up to ${WAIT_SEC}s) =="
echo "Close MATLAB Simulink models using /odom or /scan before continuing."
echo ""

"$(dirname "$0")/ros_daemon_reset.sh"
sleep 1

NAME="${MICRO_ROS_AGENT_CONTAINER:-micro_ros_udp_agent}"
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "Stopping stale micro-ROS agent: $NAME"
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  sleep 2
fi

"$(dirname "$0")/start_agent.sh"
echo ""
echo "Waiting for robot to reconnect (power-cycle ESP32 if this times out)..."

deadline=$((SECONDS + WAIT_SEC))
ok=false
while [ "$SECONDS" -lt "$deadline" ]; do
  out="$("$(dirname "$0")/check_robot.sh" 2>&1)" || true
  if echo "$out" | grep -q '\[OK\] /odom live' && echo "$out" | grep -q '\[OK\] /scan live'; then
    echo "$out"
    ok=true
    break
  fi
  sleep 3
done

if ! $ok; then
  echo ""
  echo "[!!] Robot did not come back within ${WAIT_SEC}s"
  "$(dirname "$0")/check_robot.sh" || true
  echo ""
  echo "Try: power-cycle the ESP32, then run ./scripts/reset_robot_ros.sh again"
  exit 1
fi

if echo "$out" | grep -q 'has [2-9] publishers'; then
  echo ""
  echo "[NOTE] Multiple publishers detected (stale DDS). Data is live — OK for verify."
  echo "       For a clean graph, close all MATLAB sessions and reset once more."
fi
