#!/usr/bin/env bash
# Start agent, reset ESP, verify robot connection.
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
if [ -f /opt/ros/humble/setup.bash ]; then . /opt/ros/humble/setup.bash; fi

docker rm -f micro_ros_udp_agent 2>/dev/null || true
"$(dirname "$0")/start_agent.sh"
sleep 2
"$(dirname "$0")/reset_esp_and_verify.sh"
