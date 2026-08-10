#!/usr/bin/env bash
# Open the scanned room in Unreal — no MATLAB, no Simulink, no co-sim.
#
# Usage:
#   ./scripts/run_room_preview.sh
#   ./scripts/run_room_preview.sh --setup     # create project + import FBX first
#   ./scripts/run_room_preview.sh --recreate  # delete project, recreate, import FBX
#
# Fly in the viewport: right-click + WASD, mouse look.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UPROJECT="${PROJECT_ROOT}/unreal/RoverRoomSIM/RoverRoomSIM.uproject"
SETUP=0
RECREATE=0

for arg in "$@"; do
  case "$arg" in
    --setup) SETUP=1 ;;
    --recreate) RECREATE=1 ;;
    --reimport) REIMPORT=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

REIMPORT="${REIMPORT:-0}"

export ROVER_UE_ROOT="${ROVER_UE_ROOT:-$HOME/UnrealEngine_5.3}"
export ROVER_UE_COSIM=0

if [[ "$RECREATE" == 1 ]]; then
  echo "Recreating RoverRoomSIM from matlab/my_room.fbx..."
  bash "${SCRIPT_DIR}/setup_unreal_project.sh" --recreate
elif [[ "$SETUP" == 1 || ! -f "$UPROJECT" ]]; then
  echo "Setting up RoverRoomSIM + importing my_room.fbx (one-time)..."
  bash "${SCRIPT_DIR}/setup_unreal_project.sh"
fi

if [[ "$REIMPORT" == 1 ]]; then
  bash "${SCRIPT_DIR}/reimport_room_mesh.sh"
fi

if [[ ! -f "$UPROJECT" ]]; then
  echo "Missing ${UPROJECT}" >&2
  exit 1
fi

echo "Opening room preview (RoverRoomSIM)..."
exec "${SCRIPT_DIR}/launch_unreal_532.sh" "$UPROJECT" "$@"
