#!/usr/bin/env bash
# SLAM launcher (Ubuntu desktop with gnome-terminal).
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

print_help() {
  echo "Usage: ./scripts/run_slam.sh [OPTION]"
  echo ""
  echo "  (no option)   Open 4 gnome-terminal windows"
  echo "  --agent       micro-ROS UDP agent only"
  echo "  --slam        SLAM + RViz only"
  echo "  --teleop      Keyboard teleop only"
  echo "  --plot        Lidar plot only"
  echo "  --save-map    Save map via slam_toolbox"
  echo "  --help"
}

open_term() {
  local title="$1"
  shift
  gnome-terminal --title="$title" -- bash -c "$*; exec bash" &
}

case "${1:-}" in
  --help) print_help; exit 0 ;;
  --agent) exec "$REPLICA_SCRIPTS/start_agent.sh" ;;
  --slam)
    exec python3 -m launch "$REPLICA_ROOT/launch/slam_launch.py"
    ;;
  --teleop) exec "$REPLICA_SCRIPTS/run_teleop.sh" ;;
  --plot) exec "$REPLICA_SCRIPTS/run_lidar_plot.sh" ;;
  --save-map)
    MAP_NAME="${2:-yahboom_map_$(date +%Y%m%d_%H%M%S)}"
    echo "Saving map as: $MAP_NAME"
    ros2 service call /slam_toolbox/save_map slam_toolbox/srv/SaveMap \
      "{name: {data: '$MAP_NAME'}}"
    exit 0
    ;;
  "") ;;
  *) echo "Unknown option: $1"; print_help; exit 1 ;;
esac

echo "Launching SLAM stack (ROS_DOMAIN_ID=$ROS_DOMAIN_ID) ..."

open_term "micro-ROS Agent" \
  "source '$REPLICA_ROOT/setup.bash'; '$REPLICA_SCRIPTS/start_agent.sh'"
sleep 1
open_term "SLAM + RViz" \
  "source '$REPLICA_ROOT/setup.bash'; python3 -m launch '$REPLICA_ROOT/launch/slam_launch.py'"
sleep 2
open_term "Teleop" \
  "source '$REPLICA_ROOT/setup.bash'; '$REPLICA_SCRIPTS/run_teleop.sh'"
open_term "Lidar Plot" \
  "source '$REPLICA_ROOT/setup.bash'; '$REPLICA_SCRIPTS/run_lidar_plot.sh'"

echo "Done. Save map: ./scripts/run_slam.sh --save-map [name]"
