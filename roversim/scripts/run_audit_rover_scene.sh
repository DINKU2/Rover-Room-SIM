#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UE_ROOT="${ROVER_UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-${MATLABROOT:-$HOME/MATLAB/R2024b}}"
UPROJECT="${PROJECT_ROOT}/RoverTwin/RoverTwin.uproject"
EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
SCRIPT="${SCRIPT_DIR}/setup_disable_collision.py"
LOG="${PROJECT_ROOT}/RoverTwin/Saved/Logs/AuditRoverScene.log"

export MATLABROOT="$MATLAB_ROOT" MATLAB_R2024B_ROOT="$MATLAB_ROOT"
SYS_GFX="/usr/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu/nvidia/xorg"
export LD_LIBRARY_PATH="${SYS_GFX}:${UE_ROOT}/Engine/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/ProceduralMeshComponent/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/SunPosition/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Experimental/ChaosVehiclesPlugin/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux:${MATLAB_ROOT}/bin/glnxa64:${MATLAB_ROOT}/extern/bin/glnxa64:${LD_LIBRARY_PATH:-}"

pkill -9 -x UnrealEditor 2>/dev/null || true
sleep 2
mkdir -p "$(dirname "$LOG")"
"$EDITOR" "$UPROJECT" /Game/Maps/MyRoom -nop4 -nosplash -unattended \
    -ExecutePythonScript="$SCRIPT" >"$LOG" 2>&1 || true

echo "=== Audit Rover Scene ==="
grep "Warning: " "$LOG" | grep -E "ROVER|AUDIT|DEBUG_ORB" | sed 's/.*Warning: //'
grep "DISABLE_COLLISION_DONE" "$LOG" >/dev/null && echo "OK — one visible RoverTwin in MyRoom (collision off)" || exit 1

echo ""
echo "Collision is OFF. To re-enable wall blocking run:  bash ${SCRIPT_DIR}/run_all_collision_setup.sh"
