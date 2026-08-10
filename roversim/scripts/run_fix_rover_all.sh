#!/usr/bin/env bash
# Fix two-rover, collision, and spawn issues in one shot.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UE_ROOT="${ROVER_UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-${MATLABROOT:-$HOME/MATLAB/R2024b}}"
UPROJECT="${ROVER_TWIN_UPROJECT:-${PROJECT_ROOT}/RoverTwin/RoverTwin.uproject}"
EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
echo "DEPRECATED: use scripts/run_audit_rover_scene.sh" >&2
exec "${SCRIPT_DIR}/run_audit_rover_scene.sh"
SCRIPT="${SCRIPT_DIR}/fix_rover_all.py"
LOG="${PROJECT_ROOT}/RoverTwin/Saved/Logs/FixRoverAll.log"

export MATLABROOT="$MATLAB_ROOT" MATLAB_R2024B_ROOT="$MATLAB_ROOT"
SYS_GFX="/usr/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu/nvidia/xorg"
export LD_LIBRARY_PATH="${SYS_GFX}:${UE_ROOT}/Engine/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/ProceduralMeshComponent/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/SunPosition/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Experimental/ChaosVehiclesPlugin/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux:${MATLAB_ROOT}/bin/glnxa64:${MATLAB_ROOT}/extern/bin/glnxa64:${LD_LIBRARY_PATH:-}"

pkill -9 -x UnrealEditor 2>/dev/null || true
sleep 2
mkdir -p "$(dirname "$LOG")"
"$EDITOR" "$UPROJECT" /Game/Maps/MyRoom -nop4 -nosplash -unattended \
    -ExecutePythonScript="$SCRIPT" >"$LOG" 2>&1 || true

echo "=== Fix Rover All ==="
grep "Warning: " "$LOG" | grep -E "ROOM|SPAWN|GHOST|VISIBLE|ACTUAL|CONSTRAINT|FIX_ALL|DUPLICATE" | sed 's/.*Warning: //'
if grep -q "FIX_ALL_DONE" "$LOG"; then
    echo ""
    echo "Next: in MATLAB run  open_rover_control  then click Run."
else
    grep "LogPython: Error:" "$LOG" | tail -5
    exit 1
fi
