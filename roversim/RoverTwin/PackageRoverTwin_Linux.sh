#!/usr/bin/env bash
set -euo pipefail

UE_ROOT="${UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-${MATLABROOT:-$HOME/MATLAB/R2024b}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/RoverTwin.uproject"
ARCHIVE="$SCRIPT_DIR/../Linux"

export MATLABROOT="$MATLAB_ROOT"
export MATLAB_R2024B_ROOT="$MATLAB_ROOT"
SYS_GFX="/usr/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu/nvidia/xorg"
export LD_LIBRARY_PATH="${SYS_GFX}:${UE_ROOT}/Engine/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/ProceduralMeshComponent/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/SunPosition/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Experimental/ChaosVehiclesPlugin/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux:${MATLAB_ROOT}/bin/glnxa64:${MATLAB_ROOT}/extern/bin/glnxa64:${LD_LIBRARY_PATH:-}"

echo
echo "Packaging RoverTwin for Linux..."
echo "Project: $PROJECT"
echo "Output:  $ARCHIVE"
echo
echo "Close Unreal Editor before packaging."
echo

# Development (not Shipping): Shipping strips Sim3d IPC so MATLAB never gets the ready signal.
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun \
  -project="$PROJECT" \
  -noP4 \
  -platform=Linux \
  -clientconfig=Development \
  -serverconfig=Development \
  -cook \
  -map=/Game/Maps/MyRoom \
  -build \
  -stage \
  -pak \
  -archive \
  -archivedirectory="$ARCHIVE"

echo
echo "Packaging complete."
echo "Run the game from the Linux/ folder."
