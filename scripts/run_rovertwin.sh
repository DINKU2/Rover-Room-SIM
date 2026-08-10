#!/usr/bin/env bash
# Open RoverTwin (room + rover) in Unreal Editor.
#
# Usage:
#   ./scripts/run_rovertwin.sh
#   ./scripts/run_rovertwin.sh --setup
#   ./scripts/run_rovertwin.sh --recreate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPROJECT="$(cd "${SCRIPT_DIR}/.." && pwd)/buildrover/RoverTwin/RoverTwin.uproject"
SETUP=0
RECREATE=0

for arg in "$@"; do
  case "$arg" in
    --setup) SETUP=1 ;;
    --recreate) RECREATE=1 ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
  esac
done

export ROVER_UE_ROOT="${ROVER_UE_ROOT:-$HOME/UnrealEngine_5.3}"
export ROVER_UE_COSIM=0

if [[ "$RECREATE" == 1 ]]; then
  bash "${SCRIPT_DIR}/setup_rovertwin.sh" --recreate
elif [[ "$SETUP" == 1 || ! -f "${UPROJECT%/*}/.rovertwin_imported" ]]; then
  bash "${SCRIPT_DIR}/setup_rovertwin.sh"
fi

[[ -f "$UPROJECT" ]] || { echo "Missing $UPROJECT — run with --setup" >&2; exit 1; }

echo "Opening RoverTwin..."
exec "${SCRIPT_DIR}/launch_unreal_532.sh" "$UPROJECT"
