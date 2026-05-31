#!/usr/bin/env bash
# One command to enter project env (fixes CRLF, sources setup). Usage:
#   bash ~/Desktop/project/Rover-Room-SIM/enter.sh
R="$(cd "$(dirname "$0")" && pwd)"
sed -i 's/\r$//' "$R/setup.bash" "$R/config/env" 2>/dev/null || true
# shellcheck source=setup.bash
source "$R/setup.bash"
echo "Ready. REPLICA_ROOT=$REPLICA_ROOT  ROS_DOMAIN_ID=$ROS_DOMAIN_ID  AGENT=$MICRO_ROS_AGENT_IP:${MICRO_ROS_AGENT_PORT:-8090}"
