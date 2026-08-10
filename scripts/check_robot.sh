#!/usr/bin/env bash
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

echo "REPLICA_ROOT=$REPLICA_ROOT"
echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo ""

NAME="${MICRO_ROS_AGENT_CONTAINER:-micro_ros_udp_agent}"
AGENT_STATE="$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo missing)"
case "$AGENT_STATE" in
  running)
    echo "[OK] UDP agent container: $NAME (running)"
    if ! ss -ulnp 2>/dev/null | grep -q ":${MICRO_ROS_AGENT_PORT:-8090} "; then
      echo "[!!] UDP ${MICRO_ROS_AGENT_PORT:-8090} NOT on host — Docker Desktop cannot reach Wi-Fi"
      echo "    Fix: sudo apt install docker.io && sudo systemctl enable --now docker"
      echo "    Log out/in, then: ./scripts/start_agent.sh"
    fi
    ;;
  exited)
    echo "[!!] UDP agent CRASHED (exited) — ./scripts/start_agent.sh"
    docker logs --tail 5 "$NAME" 2>&1 | sed 's/^/    /'
    ;;
  missing)
    echo "[!!] UDP agent NOT running — ./scripts/start_agent.sh"
    ;;
  *)
    echo "[!!] UDP agent state: $AGENT_STATE — ./scripts/start_agent.sh"
    ;;
esac

if pgrep -f "matlab_bridge.py" >/dev/null 2>&1; then
  echo "[!!] matlab_bridge still running (extra DDS load) — ./scripts/stop_matlab_bridge.sh"
fi

if [ -n "${ROS_DISCOVERY_SERVER:-}" ]; then
  PORT="${ROS_DISCOVERY_SERVER#*:}"
  PORT="${PORT:-11811}"
  if ss -ulnp 2>/dev/null | grep -q ":${PORT} "; then
    echo "[OK] Discovery server port ${PORT}"
  else
    echo "[!!] Discovery server not running — ./scripts/start_dds_discovery.sh"
  fi
fi
echo ""
echo "Topics on the graph:"
"$(dirname "$0")/ros_daemon_reset.sh" >/dev/null 2>&1 || true
timeout 10s ros2 topic list 2>/dev/null || echo "(ros2 failed or timed out — run ./scripts/ros_daemon_reset.sh)"
echo ""

topic_publishers() {
  local topic="$1"
  timeout 8s ros2 topic info "$topic" -v 2>/dev/null | awk '/Publisher count:/{print $3; exit}'
}

echo "Live data (proves robot is publishing, not just topic ghosts):"
ODOM_PUBS="$(topic_publishers /odom)"
SCAN_PUBS="$(topic_publishers /scan)"
if [ "${ODOM_PUBS:-0}" = "0" ]; then
  echo "[!!] /odom has 0 publishers (ghost topic or agent down)"
else
  if [ "${ODOM_PUBS:-0}" -gt 1 ] 2>/dev/null; then
    echo "[!!] /odom has ${ODOM_PUBS} publishers (stale DDS — ./scripts/reset_robot_ros.sh)"
  fi
  if timeout 6s ros2 topic echo /odom --once --no-arr >/dev/null 2>&1; then
    echo "[OK] /odom live (${ODOM_PUBS} publisher(s))"
  else
    echo "[!!] /odom publisher seen but no sample in 6s"
    echo "    Try: ./scripts/reset_robot_ros.sh"
  fi
fi

if [ "${SCAN_PUBS:-0}" = "0" ]; then
  echo "[!!] /scan has 0 publishers — agent likely crashed on LaserScan"
else
  if [ "${SCAN_PUBS:-0}" -gt 1 ] 2>/dev/null; then
    echo "[!!] /scan has ${SCAN_PUBS} publishers (stale DDS — ./scripts/reset_robot_ros.sh)"
  fi
  if timeout 8s ros2 topic echo /scan --qos-reliability reliable --once >/dev/null 2>&1; then
    SCAN_PTS="$(timeout 5s ros2 topic echo /scan --qos-reliability reliable --once --full-length 2>/dev/null \
      | python3 -c "import sys,yaml; d=yaml.safe_load(sys.stdin.read().split('---')[0]); print(len(d.get('ranges',[])))" 2>/dev/null || echo "?")"
    echo "[OK] /scan live (${SCAN_PUBS} publisher(s), ${SCAN_PTS} pts, reliable QoS)"
    if [ "${SCAN_PTS:-0}" = "360" ] 2>/dev/null; then
      echo "    (360 pts = full lidar ring, reliable QoS on firmware)"
    elif [ "${SCAN_PTS:-0}" = "90" ] 2>/dev/null; then
      echo "    (90 pts = older firmware downsampling — reflash for 360)"
    fi
  else
    echo "[!!] /scan registered but no samples (DDS message loss)"
    echo "    Try: ./scripts/diag_scan.sh"
    echo "    Fix: reflash firmware — ./scripts/flash_firmware.sh (smaller LaserScan payload)"
  fi
fi
echo ""
echo "Expected (odom + cmd_vel; /scan if lidar enabled in firmware):"
echo "  /odom /cmd_vel  [/scan]"
