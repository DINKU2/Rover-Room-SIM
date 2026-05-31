#!/usr/bin/env bash
# Fast DDS discovery server on 127.0.0.1 (optional MATLAB/agent helper).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [ -f /opt/ros/humble/setup.bash ]; then
  . /opt/ros/humble/setup.bash
fi

ADDR="${ROS_DISCOVERY_SERVER_ADDR:-127.0.0.1}"
PORT="${ROS_DISCOVERY_SERVER_PORT:-11811}"
LOG="${ROS_DISCOVERY_SERVER_LOG:-/tmp/fastdds_discovery.log}"

# Server process must NOT load super-client profile
unset FASTRTPS_DEFAULT_PROFILES_FILE
unset ROS_SUPER_CLIENT

if ss -ulnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "[OK] Discovery server already listening on ${ADDR}:${PORT}"
  exit 0
fi

nohup fastdds discovery -i 0 -l "$ADDR" -p "$PORT" >"$LOG" 2>&1 &
sleep 1

if ss -ulnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "[OK] Discovery server ${ADDR}:${PORT} (log: $LOG)"
else
  echo "[!!] Discovery server failed — see $LOG"
  tail -5 "$LOG" 2>/dev/null || true
  exit 1
fi
