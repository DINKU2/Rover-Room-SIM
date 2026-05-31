#!/usr/bin/env bash
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

TOPIC="${LIDAR_TOPIC:-/scan}"
MAX_RANGE="${LIDAR_MAX_RANGE:-8}"

echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID  topic=$TOPIC"
echo "Agent: ./scripts/start_agent.sh"
echo ""
exec python3 "$REPLICA_ROOT/viz/plot_lidar.py" --topic "$TOPIC" --max-range "$MAX_RANGE" "$@"
