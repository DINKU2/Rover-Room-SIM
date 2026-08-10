#!/usr/bin/env bash
set -euo pipefail

UE_ROOT="${ROVER_UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-${MATLABROOT:-$HOME/MATLAB/R2024b}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UPROJECT="${ROVER_TWIN_UPROJECT:-${PROJECT_ROOT}/RoverTwin/RoverTwin.uproject}"
EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"

[[ -x "$EDITOR" ]] || { echo "Missing UE editor: $EDITOR" >&2; exit 1; }
[[ -f "$UPROJECT" ]] || { echo "Missing project: $UPROJECT" >&2; exit 1; }

export MATLABROOT="$MATLAB_ROOT"
export MATLAB_R2024B_ROOT="$MATLAB_ROOT"
export ROVER_UE_COSIM=1

# UE 5.3's Vulkan swapchain can lose the NVIDIA device when an X11 editor
# viewport is resized while VRR/compositor bypass is active. Keep presentation
# on the normal compositor path; this does not affect Sim3D or ROS data.
export __GL_GSYNC_ALLOWED=0
export __GL_VRR_ALLOWED=0
export SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR=0

SYS_GFX="/usr/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu/nvidia/xorg"
export LD_LIBRARY_PATH="${SYS_GFX}:${UE_ROOT}/Engine/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/ProceduralMeshComponent/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/SunPosition/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Experimental/ChaosVehiclesPlugin/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux:${MATLAB_ROOT}/bin/glnxa64:${MATLAB_ROOT}/extern/bin/glnxa64:${LD_LIBRARY_PATH:-}"

MAP="${ROVER_TWIN_MAP:-/Game/Maps/MyRoom}"
exec "$EDITOR" "$UPROJECT" "$MAP" "$@"
