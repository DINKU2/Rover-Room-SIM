#!/usr/bin/env bash
# Package RoverRoomSIM as a standalone Linux game (no Editor, no MATLAB).
#
# Usage:
#   ./scripts/package_rover_room.sh
#
# Output:
#   unreal/RoverRoomSIM/Packaged/Linux/RoverRoomSIM.sh
#
# First package can take 20–60 minutes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UE_ROOT="${ROVER_UE_ROOT:-$HOME/UnrealEngine_5.3}"
UPROJECT="${PROJECT_ROOT}/unreal/RoverRoomSIM/RoverRoomSIM.uproject"
ARCHIVE="${PROJECT_ROOT}/unreal/RoverRoomSIM/Packaged/Linux"
GAME="${ARCHIVE}/RoverRoomSIM.sh"
GAME_ALT="${ARCHIVE}/RoverRoomSIM/RoverRoomSIM.sh"
RUNUAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"

[[ -x "$RUNUAT" ]] || { echo "RunUAT not found: $RUNUAT" >&2; exit 1; }
[[ -f "$UPROJECT" ]] || { echo "Run ./scripts/run_room_preview.sh --setup first" >&2; exit 1; }

export ROVER_UE_ROOT="$UE_ROOT"
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/nvidia_icd.json}"

mkdir -p "$ARCHIVE"

echo "Packaging RoverRoomSIM for Linux (this takes a while)..."
echo "  Project: $UPROJECT"
echo "  Output:  $ARCHIVE"

"$RUNUAT" BuildCookRun \
  -project="$UPROJECT" \
  -noP4 \
  -platform=Linux \
  -clientconfig=Development \
  -serverconfig=Development \
  -cook \
  -build \
  -stage \
  -pak \
  -archive \
  -archivedirectory="$ARCHIVE"

if [[ -x "$GAME" ]]; then
  echo ""
  echo "Done. Launch the room viewer:"
  echo "  $GAME"
elif [[ -x "$GAME_ALT" ]]; then
  echo ""
  echo "Done. Launch the room viewer:"
  echo "  $GAME_ALT"
else
  echo "Package finished; look under: $ARCHIVE"
fi
