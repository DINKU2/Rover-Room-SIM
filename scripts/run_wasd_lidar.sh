#!/usr/bin/env bash
# Recommended 3-terminal workflow (do not combine teleop + matplotlib in one process).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

echo "=============================================="
echo "  Yahboom micro-ROS — 3 terminals"
echo "  REPLICA_ROOT=$REPLICA_ROOT"
echo "  ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "=============================================="
echo ""
echo "  Tab 1 — agent:"
echo "    cd '$REPLICA_ROOT' && source setup.bash && ./scripts/start_agent.sh"
echo ""
echo "  Tab 2 — drive (focus here):"
echo "    cd '$REPLICA_ROOT' && source setup.bash && ./scripts/run_teleop.sh"
echo ""
echo "  Tab 3 — lidar plot:"
echo "    cd '$REPLICA_ROOT' && source setup.bash && ./scripts/run_lidar_plot.sh"
echo ""
echo "  SLAM:     ./scripts/run_slam.sh --slam"
echo "  Check:    ./scripts/check_robot.sh"
echo "  Stop:     ./scripts/stop_robot.sh"
echo ""

case "${1:-}" in
  --check) exec "$REPLICA_SCRIPTS/check_robot.sh" ;;
  --teleop) exec "$REPLICA_SCRIPTS/run_teleop.sh" ;;
  --plot) exec "$REPLICA_SCRIPTS/run_lidar_plot.sh" ;;
esac

echo "Or run:  ./scripts/run_wasd_lidar.sh --teleop | --plot | --check"
