#!/usr/bin/env bash
# Yahboom WiFi camera module uses micro-ROS agent UDP port 9999 (drive board uses 8090).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

NAME="${MICRO_ROS_CAMERA_AGENT_CONTAINER:-micro_ros_camera_agent}"
PORT="${MICRO_ROS_CAMERA_AGENT_PORT:-9999}"

echo "Camera agent: UDP $PORT (Yahboom WiFi camera module → /espRos/esp32camera)"

if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "Already running: $NAME"
  docker logs --tail 3 "$NAME"
  exit 0
fi

docker rm -f "$NAME" 2>/dev/null || true
docker run -d --rm --name "$NAME" --net=host \
  -e "ROS_DOMAIN_ID=${ROS_DOMAIN_ID}" \
  microros/micro-ros-agent:humble udp4 --port "$PORT" -v4
sleep 1
if ss -ulnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "Camera agent listening on UDP $PORT"
else
  echo "[!!] Port $PORT not on host"
fi
