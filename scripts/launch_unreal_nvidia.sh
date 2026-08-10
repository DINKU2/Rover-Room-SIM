#!/usr/bin/env bash
# Launch Unreal Editor on the NVIDIA dGPU (PRIME on-demand laptops/desktops).
#
# Usage:
#   ./scripts/launch_unreal_nvidia.sh
#   ./scripts/launch_unreal_nvidia.sh "/path/to/OtherProject.uproject"
#   ./scripts/launch_unreal_nvidia.sh -OpenGL
#
# Override defaults:
#   UNREAL_EDITOR=/path/to/UnrealEditor
#   UNREAL_PROJECT=/path/to/MyProject.uproject

set -euo pipefail

UE_ROOT="${ROVER_UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
UNREAL_EDITOR="${UNREAL_EDITOR:-${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor}"
UNREAL_PROJECT="${UNREAL_PROJECT:-/home/dinuk/Desktop/project/Rover-Room-SIM/unreal/RoverRoomSIM/RoverRoomSIM.uproject}"

if [[ "${1:-}" == *.uproject ]]; then
  UNREAL_PROJECT="$1"
  shift
fi

if [[ ! -x "$UNREAL_EDITOR" ]]; then
  echo "Unreal Editor not found or not executable: $UNREAL_EDITOR" >&2
  exit 1
fi

if [[ ! -f "$UNREAL_PROJECT" ]]; then
  echo "Unreal project not found: $UNREAL_PROJECT" >&2
  exit 1
fi

# shellcheck source=rover_nvidia_env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rover_nvidia_env.sh"

# Avoid Vulkan window crash on PRIME Linux (see launch_unreal_532.sh).
DEFAULT_UE_ARGS=(-unattended)

echo "Launching Unreal on NVIDIA GPU"
echo "  Editor:  $UNREAL_EDITOR"
echo "  Project: $UNREAL_PROJECT"
echo "Verify with: nvidia-smi  (look for UnrealEditor)"
echo

exec "$UNREAL_EDITOR" "$UNREAL_PROJECT" "${DEFAULT_UE_ARGS[@]}" "$@"
