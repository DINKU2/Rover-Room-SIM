#!/usr/bin/env bash
# Reflash firmware, restart agent, verify live data (native Linux).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

echo "=== Fix robot + agent ==="
echo ""
echo "1. Power OFF the robot. Press Enter when off..."
read -r _

echo ""
echo "2. Starting agent (robot must stay OFF)..."
"$(dirname "$0")/start_agent.sh"
sleep 2
if ! docker inspect -f '{{.State.Running}}' micro_ros_udp_agent 2>/dev/null | grep -q true; then
  echo "[FAIL] Agent not running — check docker logs"
  exit 1
fi
echo "[OK] Agent stable with robot off"
echo ""

echo "3. Flash firmware..."
if ! "$(dirname "$0")/flash_firmware.sh"; then
  echo "[!!] Flash failed — check /dev/ttyUSB0 and dialout group"
  exit 1
fi

echo ""
echo "4. Restart agent after flash..."
docker rm -f micro_ros_udp_agent 2>/dev/null || true
"$(dirname "$0")/start_agent.sh"
echo ""
echo "5. Power ON the robot. Waiting 20s..."
sleep 20

echo ""
"$(dirname "$0")/check_robot.sh"
echo ""
if [ -x "$(dirname "$0")/verify_topic_data.sh" ]; then
  "$(dirname "$0")/verify_topic_data.sh"
fi
