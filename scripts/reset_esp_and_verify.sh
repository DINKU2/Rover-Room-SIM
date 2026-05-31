#!/usr/bin/env bash
# Reset ESP and wait for agent + robot session.
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

export IDF_PATH="$REPLICA_ROOT/esp/esp-idf"
export IDF_TOOLS_PATH="$REPLICA_ROOT/tooling/espressif"
# shellcheck source=/dev/null
. "$IDF_PATH/export.sh"

PORT="${ESP_SERIAL_PORT:-/dev/ttyUSB0}"
[ -e "$PORT" ] || PORT=/dev/ttyACM0

echo "Agent must be running first: ./scripts/start_agent.sh"
echo "Resetting ESP on $PORT..."
python "$IDF_PATH/components/esptool_py/esptool/esptool.py" -p "$PORT" run

echo "Waiting 35s (WiFi + odom + delayed scan)..."
sleep 35

echo ""
docker inspect -f 'Agent running: {{.State.Running}}' micro_ros_udp_agent 2>/dev/null || echo "Agent missing"
docker logs --tail 20 micro_ros_udp_agent 2>&1 || true
echo ""
"$(dirname "$0")/check_robot.sh"
echo ""
"$(dirname "$0")/verify_topic_data.sh"
