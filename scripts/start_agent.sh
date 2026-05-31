#!/usr/bin/env bash
# micro-ROS UDP agent — requires native docker.io (--net=host) on Linux.
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

NAME="${MICRO_ROS_AGENT_CONTAINER:-micro_ros_udp_agent}"
PORT="${MICRO_ROS_AGENT_PORT:-8090}"

echo "Agent: UDP port $PORT  (ESP must target MICRO_ROS_AGENT_IP in config/env)"
[ -n "${MICRO_ROS_AGENT_IP:-}" ] && echo "  Expected robot target IP: $MICRO_ROS_AGENT_IP"

if ! [ -S /var/run/docker.sock ] && [ -n "${DOCKER_HOST:-}" ]; then
  echo "[!!] Docker Desktop cannot bind UDP 8090 on your LAN IP."
  echo "    Install native engine:  sudo apt install docker.io && sudo systemctl enable --now docker"
  echo "    Then log out/in and re-run this script."
fi

if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "Agent already running: $NAME"
  docker logs --tail 5 "$NAME"
  if ! ss -ulnp 2>/dev/null | grep -q ":${PORT} "; then
    echo "[!!] Port ${PORT} not listening on host — restart agent after fixing Docker"
  fi
  exit 0
fi

docker rm -f "$NAME" 2>/dev/null || true
FG=false
for arg in "$@"; do
  case "$arg" in
    --fg|-f) FG=true ;;
  esac
done
echo "Starting UDP micro-ROS agent on port $PORT (--net=host, detached) ..."
if $FG && [ -t 0 ]; then
  exec docker run -it --rm --name "$NAME" --net=host \
    -e "ROS_DOMAIN_ID=${ROS_DOMAIN_ID}" \
    microros/micro-ros-agent:humble udp4 --port "$PORT" -v4
fi
docker run -d --rm --name "$NAME" --net=host \
  -e "ROS_DOMAIN_ID=${ROS_DOMAIN_ID}" \
  microros/micro-ros-agent:humble udp4 --port "$PORT" -v4
sleep 1
if ss -ulnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "Agent running (UDP ${PORT} on host). Logs: docker logs -f $NAME"
  echo "  (use --fg to attach foreground for debug)"
else
  echo "[!!] Agent started but port ${PORT} not on host — check Docker setup"
fi
