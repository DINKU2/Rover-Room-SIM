#!/usr/bin/env bash
# Collision setup is disabled — use single visible RoverTwin instead.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "NOTE: run_setup_rover_scene.sh now disables collision (single RoverTwin)."
exec bash "${SCRIPT_DIR}/run_disable_collision.sh"
