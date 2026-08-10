#!/usr/bin/env bash
# Re-attach RoverProxyFeedback to visible RoverProxy (included in full sweep setup).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/run_setup_rover_sweep_complete.sh"
