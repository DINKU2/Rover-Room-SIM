#!/usr/bin/env bash
# TCP bridge: ROS 2 <-> MATLAB (bypasses DDS data-plane issues).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

if [ -f /opt/ros/humble/setup.bash ]; then
  . /opt/ros/humble/setup.bash
fi

# Bridge uses plain ROS — not discovery-server super-client profile
unset FASTRTPS_DEFAULT_PROFILES_FILE
unset ROS_DISCOVERY_SERVER
unset ROS_SUPER_CLIENT

PORT="${MATLAB_BRIDGE_PORT:-8765}"
if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "[OK] MATLAB bridge already listening on port ${PORT}"
  exit 0
fi

echo "Starting MATLAB bridge on port ${PORT}..."
echo "MATLAB: matlab_connect_bridge"
nohup python3 "$REPLICA_ROOT/scripts/matlab_bridge.py" >/tmp/matlab_bridge.log 2>&1 &
sleep 1
if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "[OK] Bridge running (log: /tmp/matlab_bridge.log)"
else
  echo "[!!] Bridge failed — tail /tmp/matlab_bridge.log"
  tail -10 /tmp/matlab_bridge.log 2>/dev/null || true
  exit 1
fi
