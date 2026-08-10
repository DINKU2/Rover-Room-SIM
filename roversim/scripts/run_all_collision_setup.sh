#!/usr/bin/env bash
# Full collision pipeline: convex mesh hulls + floorplan boundary shell + rover proxy.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1/3 Auto convex collision on MyRoom meshes ==="
bash "${SCRIPT_DIR}/run_setup_room_convex_collision.sh"

echo "=== 2/3 Perimeter boundary shell (occupancy-grid style) ==="
bash "${SCRIPT_DIR}/run_setup_room_boundary_shell.sh"

echo "=== 3/3 Rover proxy + sweep runtime ==="
bash "${SCRIPT_DIR}/run_setup_rover_sweep_complete.sh"

echo "ALL COLLISION SETUP DONE — restart PIE, run open_rover_control in MATLAB."
