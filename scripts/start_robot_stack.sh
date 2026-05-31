#!/usr/bin/env bash
# Start agent + MATLAB TCP bridge (native Linux MATLAB workflow).
set -e
DIR="$(dirname "$0")"
"$DIR/start_agent.sh"
"$DIR/start_matlab_bridge.sh"
echo ""
echo "Next: power-cycle robot, wait ~15s, then ./scripts/check_robot.sh"
echo "MATLAB: matlab_connect_bridge"
