#!/usr/bin/env bash
# Reset a stuck ros2 daemon (domain mismatch or hung DDS). Safe to re-run.
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-20}"

echo "Resetting ROS 2 daemon (domain $ROS_DOMAIN_ID)..."
timeout 4s ros2 daemon stop >/dev/null 2>&1 || true
pkill -9 -f _ros2_daemon >/dev/null 2>&1 || true
sleep 1
timeout 6s ros2 daemon start >/dev/null 2>&1 || true
echo "Done."
