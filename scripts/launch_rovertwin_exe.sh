#!/usr/bin/env bash
# Launch packaged RoverTwin with NVIDIA Vulkan env (fixes "Unable to create a Vulkan window").
#
# Usage:
#   ./scripts/launch_rovertwin_exe.sh
#   ./scripts/launch_rovertwin_exe.sh /path/to/custom/RoverTwin.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=rover_nvidia_env.sh
source "${SCRIPT_DIR}/rover_nvidia_env.sh"

GAME="${1:-${ROVER_TWIN_GAME:-${PROJECT_ROOT}/buildrover/Linux/RoverTwin.sh}}"

if [[ ! -f "$GAME" ]]; then
  echo "Packaged RoverTwin not found: $GAME" >&2
  echo "Run: ./scripts/setup_rovertwin.sh && ./buildrover/RoverTwin/PackageRoverTwin_Linux.sh" >&2
  exit 1
fi

GAME_ROOT="$(cd "$(dirname "$GAME")" && pwd)"
BINARY="${GAME_ROOT}/RoverTwin/Binaries/Linux/RoverTwin-Linux-Shipping"
if [[ ! -f "$BINARY" ]]; then
  echo "RoverTwin binary missing: $BINARY" >&2
  echo "Re-run: ./buildrover/RoverTwin/PackageRoverTwin_Linux.sh" >&2
  exit 1
fi

export ROVER_UE_COSIM=0
MAP="${ROVER_TWIN_MAP:-/Game/Maps/MyRoom}"
echo "Launching RoverTwin (NVIDIA Vulkan)"
echo "  Launcher: $GAME"
echo "  Map:      $MAP"
echo "  VK_ICD:   $VK_ICD_FILENAMES"
exec bash "$GAME" "$MAP" "${@:2}"
