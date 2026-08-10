#!/usr/bin/env bash
# Launch Unreal Engine 5.3.2 (MATLAB R2024b compatible) on NVIDIA dGPU when available.
#
# Usage:
#   ./scripts/launch_unreal_532.sh
#   ./scripts/launch_unreal_532.sh "/path/to/Project.uproject"
#
# Override:
#   ROVER_UE_ROOT=/home/dinuk/UnrealEngine_5.3
#   UNREAL_532_ROOT=/home/dinuk/UnrealEngine_5.3   (legacy alias)
#   ROVER_UE_OPENGL=0   use Vulkan instead of -OpenGL (Linux only)

set -euo pipefail

UE_ROOT="${ROVER_UE_ROOT:-${UNREAL_532_ROOT:-/home/dinuk/UnrealEngine_5.3}}"
UNREAL_EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
UNREAL_PROJECT="${1:-}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-${MATLABROOT:-/home/dinuk/MATLAB/R2024b}}"

if [[ ! -x "$UNREAL_EDITOR" ]]; then
  echo "Unreal Engine 5.3.2 not found: $UNREAL_EDITOR" >&2
  echo "Run: ./scripts/install_unreal_532.sh" >&2
  exit 1
fi

# shellcheck source=rover_nvidia_env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rover_nvidia_env.sh"

# MathWorksSimulation libs for co-sim (AutoVrtlEnv or RoverTwin MyRoom).
USE_COSIM_LIBS=0
if [[ "${ROVER_UE_COSIM:-0}" == 1 ]]; then
  USE_COSIM_LIBS=1
elif [[ "$UNREAL_PROJECT" == *AutoVrtlEnv* ]]; then
  USE_COSIM_LIBS=1
elif [[ "$UNREAL_PROJECT" == *RoverTwin* ]] || [[ "$UNREAL_PROJECT" == *RoverSIMUunreal-Linux* ]]; then
  USE_COSIM_LIBS=1
fi

if [[ "$USE_COSIM_LIBS" == 1 && -d "$MATLAB_ROOT/bin/glnxa64" ]]; then
  export MATLABROOT="$MATLAB_ROOT"
  # System graphics paths first — MATLAB bundles its own libvulkan.so.1 / libX11
  # which shadow the system ones and break Unreal's Vulkan window creation.
  UE_LIB_PATHS=(
    "/usr/lib/x86_64-linux-gnu"
    "/usr/lib/x86_64-linux-gnu/nvidia/xorg"
    "${UE_ROOT}/Engine/Binaries/Linux"
    "${UE_ROOT}/Engine/Plugins/Runtime/ProceduralMeshComponent/Binaries/Linux"
    "${UE_ROOT}/Engine/Plugins/Runtime/SunPosition/Binaries/Linux"
    "${UE_ROOT}/Engine/Plugins/Experimental/ChaosVehiclesPlugin/Binaries/Linux"
    "${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux"
    "${MATLAB_ROOT}/bin/glnxa64"
    "${MATLAB_ROOT}/extern/bin/glnxa64"
  )
  export LD_LIBRARY_PATH="$(IFS=:; echo "${UE_LIB_PATHS[*]}"):${LD_LIBRARY_PATH:-}"
fi

# UE 5.3 desktop ignores -OpenGL; Vulkan + PRIME env vars above are what matter.
DEFAULT_UE_ARGS=(-unattended)

if [[ -n "$UNREAL_PROJECT" && "$UNREAL_PROJECT" == *.uproject ]]; then
  exec "$UNREAL_EDITOR" "$UNREAL_PROJECT" "${DEFAULT_UE_ARGS[@]}" "${@:2}"
fi

exec "$UNREAL_EDITOR" "${DEFAULT_UE_ARGS[@]}" "$@"
