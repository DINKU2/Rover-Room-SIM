#!/usr/bin/env bash
# Diagnose /scan delivery (publisher visible but samples lost).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

NAME="${MICRO_ROS_AGENT_CONTAINER:-micro_ros_udp_agent}"
echo "=== /scan diagnostics (ROS_DOMAIN_ID=$ROS_DOMAIN_ID) ==="
echo ""
ros2 topic info /scan -v 2>&1 | head -25
echo ""
echo "15s rate test:"
timeout 15s ros2 topic hz /scan 2>&1 || echo "(no messages received)"
echo ""
echo "One-shot echo (watch for 'A message was lost'):"
timeout 10s ros2 topic echo /scan --once --no-arr 2>&1 | head -15 || true
echo ""
echo "Agent tail (raise verbosity if empty):"
docker logs --tail 15 "$NAME" 2>&1 || true
echo ""
echo "If publisher=1 but no rate: agent drops LaserScan from ESP."
echo "Reflash: ./scripts/flash_firmware.sh  (intensities removed in firmware)"
