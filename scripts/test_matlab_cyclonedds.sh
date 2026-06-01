#!/usr/bin/env bash
# Test MATLAB ROS receive with CycloneDDS (both shell + MATLAB).
set -e
cd "$(dirname "$0")/.."
source ./setup.bash
export ROS_DOMAIN_ID=20
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export ROS_LOCALHOST_ONLY=0

./scripts/stop_matlab_bridge.sh 2>/dev/null || true
ros2 daemon stop 2>/dev/null || true
sleep 1

pkill -f "matlab_dds_test" 2>/dev/null || true
ros2 topic pub /matlab_dds_test std_msgs/msg/String "{data: cyclone_ping}" -r 10 &
PUBPID=$!
sleep 2

echo "=== MATLAB CycloneDDS receive test ==="
/home/dinuk/MATLAB/R2026a/bin/matlab -batch "cd('$(pwd)/matlab'); ok=ros_cyclonedds_test; exit(~ok)"
RC=$?

kill "$PUBPID" 2>/dev/null || true
pkill -f "matlab_dds_test" 2>/dev/null || true
exit "$RC"
