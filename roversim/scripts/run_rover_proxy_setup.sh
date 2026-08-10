#!/usr/bin/env bash
# Full swept-collision rover setup (ghost + visible proxy + feedback).
# Requires Unreal Editor open on MyRoom with Remote Execution enabled.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Step 1: audit RoverTwin ghost ==="
bash "${SCRIPT_DIR}/run_audit_rover_scene.sh" || true

echo ""
echo "=== Step 2: swept proxy + feedback ==="
bash "${SCRIPT_DIR}/run_setup_rover_sweep_complete.sh"
