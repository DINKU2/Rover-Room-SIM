#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run_rover_physics_setup.sh
#
# One-time setup: adds physics-based collision to the RoverTwin simulation.
#
# What this creates in MyRoom:
#   RoverTwin   (existing Sim3dStaticMeshActor) → made INVISIBLE (ghost)
#               Simulink still teleports this actor for position control
#   RoverVisible (new StaticMeshActor) → VISIBLE, simulate_physics=true,
#               BlockAll collision, 5 kg mass
#   RoverConstraint (PhysicsConstraintActor) → spring-links ghost to visible:
#               stiffness=200 N/cm, damping=40, maxForce=5000 N
#
# Effect: Simulink still commands the rover's position. The ghost actor
# teleports (through walls). The VISIBLE rover follows via physics spring
# but STOPS at real wall collision — it cannot pass through anything.
#
# Usage:  bash scripts/run_rover_physics_setup.sh
#
# After this script, start Simulink normally:   open_rover_control  in MATLAB
# ---------------------------------------------------------------------------
set -euo pipefail

UE_ROOT="${ROVER_UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-${MATLABROOT:-$HOME/MATLAB/R2024b}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

UPROJECT_SRC="${PROJECT_ROOT}/RoverTwin/RoverTwin.uproject"
UPROJECT_ALIAS="${ROVER_TWIN_UPROJECT:-$UPROJECT_SRC}"
EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
SETUP_echo "DEPRECATED: use scripts/run_audit_rover_scene.sh" >&2
exec "${SCRIPT_DIR}/run_audit_rover_scene.sh"
SCRIPT="${SCRIPT_DIR}/setup_rover_physics.py"
LOG_DIR="${PROJECT_ROOT}/RoverTwin/Saved/Logs"
LOG_FILE="${LOG_DIR}/RoverPhysicsSetup.log"

[[ -x "$EDITOR" ]]        || { echo "ERROR: UE editor not found: $EDITOR" >&2; exit 1; }
[[ -f "$UPROJECT_ALIAS" ]] || { echo "ERROR: project not found: $UPROJECT_ALIAS" >&2; exit 1; }
[[ -f "$SETUP_SCRIPT" ]]  || { echo "ERROR: setup script not found: $SETUP_SCRIPT" >&2; exit 1; }

echo "=== Rover Physics Collision Setup ==="
echo "Project : $UPROJECT_ALIAS"
echo "Script  : $SETUP_SCRIPT"
echo ""

# --- 1. Kill any running editor ------------------------------------------------
if pgrep -x UnrealEditor >/dev/null 2>&1; then
    echo "[1/3] Stopping running UnrealEditor..."
    pkill -9 -x UnrealEditor 2>/dev/null || true
    sleep 3
else
    echo "[1/3] No running UnrealEditor."
fi

# --- 2. Environment -----------------------------------------------------------
export MATLABROOT="$MATLAB_ROOT"
export MATLAB_R2024B_ROOT="$MATLAB_ROOT"
export ROVER_UE_COSIM=1

SYS_GFX="/usr/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu/nvidia/xorg"
export LD_LIBRARY_PATH="${SYS_GFX}:${UE_ROOT}/Engine/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/ProceduralMeshComponent/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/SunPosition/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Experimental/ChaosVehiclesPlugin/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux:${MATLAB_ROOT}/bin/glnxa64:${MATLAB_ROOT}/extern/bin/glnxa64:${LD_LIBRARY_PATH:-}"

mkdir -p "$LOG_DIR"
echo "[2/3] Launching editor (-ExecutePythonScript, will quit when done)..."
echo "      Log → $LOG_FILE"

"$EDITOR" "$UPROJECT_ALIAS" /Game/Maps/MyRoom \
    -nop4 -nosplash -unattended \
    -ExecutePythonScript="${SETUP_SCRIPT}" \
    >"$LOG_FILE" 2>&1 || true        # non-zero exit is normal on Linux

# --- 3. Result ----------------------------------------------------------------
echo "[3/3] Checking result..."
echo ""

if grep -q "SETUP_COMPLETE\|ALREADY_SETUP" "$LOG_FILE"; then
    echo "✓ SUCCESS — Physics collision rover is ready."
    echo "  Key steps:"
    grep -E "GHOST_FOUND|GHOST_HIDDEN|ROVER_VISIBLE|CONSTRAINT_CREATED|LEVEL_SAVED|ALREADY_SETUP" \
        "$LOG_FILE" | grep "Warning:" | sed 's/.*Warning: /  /'
    echo ""
    echo "How it works:"
    echo "  • RoverTwin (HIDDEN) = ghost driven by Simulink (teleports through walls)"
    echo "  • RoverVisible       = real collision rover, stops at walls"
    echo "  • PhysicsConstraint  = spring that pulls RoverVisible toward ghost"
    echo ""
    echo "Next step: run  open_rover_control  in MATLAB."
else
    echo "✗ SETUP FAILED — see log:"
    grep -E "LogPython: Error:|RuntimeError|Traceback" "$LOG_FILE" \
        | grep -v "LogAutomation\|FLightConfig\|Sim3dWeather" | tail -20 | sed 's/^/  /'
    exit 1
fi
