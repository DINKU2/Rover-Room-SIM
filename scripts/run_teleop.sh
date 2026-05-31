#!/usr/bin/env bash
# Keyboard drive (Yahboom-style). Keep this terminal focused for keys.
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

echo "REPLICA_ROOT=$REPLICA_ROOT"
echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "Drive: i=fwd  ,=back  j/l=turn  q/z=speed  space=stop"
echo "Agent in another tab: ./scripts/start_agent.sh"
echo ""
exec python3 "$REPLICA_ROOT/teleop/teleop_keyboard.py"
