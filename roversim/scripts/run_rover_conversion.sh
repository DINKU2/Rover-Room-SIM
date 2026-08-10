#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run_rover_conversion.sh
#
# One-time setup: replace the plain "RoverTwin" Actor in MyRoom with an
# ASim3dGenericActor so that the Simulink "Simulation 3D Actor Transform Set"
# block can move it.
#
# Usage:  bash scripts/run_rover_conversion.sh
#
# What it does:
#   1. Kills any running UnrealEditor instance for this project
#   2. Launches the editor in a headless-ish mode with -ExecutePythonScript
#      (which runs the conversion script, saves the level, then exits)
#   3. Tails the log and prints a PASS/FAIL line when done
#
# After this script completes, start your normal Simulink session:
#   open_rover_control   (in MATLAB)
# ---------------------------------------------------------------------------
set -euo pipefail

UE_ROOT="${ROVER_UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-${MATLABROOT:-$HOME/MATLAB/R2024b}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

UPROJECT_SRC="${PROJECT_ROOT}/RoverTwin/RoverTwin.uproject"
UPROJECT_ALIAS="${ROVER_TWIN_UPROJECT:-$UPROJECT_SRC}"
EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
CONVERT_SCRIPT="${SCRIPT_DIR}/convert_rover_to_sim3d.py"
LOG_DIR="${PROJECT_ROOT}/RoverTwin/Saved/Logs"
LOG_FILE="${LOG_DIR}/Sim3dConversion.log"

[[ -x "$EDITOR" ]] || { echo "ERROR: UE editor not found: $EDITOR" >&2; exit 1; }
[[ -f "$UPROJECT_ALIAS" ]] || { echo "ERROR: project not found: $UPROJECT_ALIAS" >&2; exit 1; }
[[ -f "$CONVERT_SCRIPT" ]] || { echo "ERROR: conversion script not found: $CONVERT_SCRIPT" >&2; exit 1; }

echo "=== Rover → Sim3dGenericActor conversion ==="
echo "Project : $UPROJECT_ALIAS"
echo "Script  : $CONVERT_SCRIPT"
echo ""

# --- 1. Kill any running editor for this project --------------------------
if pgrep -x UnrealEditor >/dev/null 2>&1; then
    echo "[1/3] Stopping running UnrealEditor..."
    pkill -9 -x UnrealEditor 2>/dev/null || true
    sleep 3
else
    echo "[1/3] No running UnrealEditor to stop."
fi

# --- 2. Set up environment identical to launch_rovertwin_editor.sh --------
export MATLABROOT="$MATLAB_ROOT"
export MATLAB_R2024B_ROOT="$MATLAB_ROOT"
export ROVER_UE_COSIM=1

SYS_GFX="/usr/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu/nvidia/xorg"
export LD_LIBRARY_PATH="${SYS_GFX}:${UE_ROOT}/Engine/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/ProceduralMeshComponent/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/SunPosition/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Experimental/ChaosVehiclesPlugin/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux:${MATLAB_ROOT}/bin/glnxa64:${MATLAB_ROOT}/extern/bin/glnxa64:${LD_LIBRARY_PATH:-}"

mkdir -p "$LOG_DIR"
echo "[2/3] Launching editor with -ExecutePythonScript (editor will quit when done)..."
echo "      Log → $LOG_FILE"

"$EDITOR" "$UPROJECT_ALIAS" /Game/Maps/MyRoom \
    -nop4 -nosplash -unattended \
    -ExecutePythonScript="${CONVERT_SCRIPT}" \
    >"$LOG_FILE" 2>&1
EXIT_CODE=$?

# --- 3. Check the log for success or failure ------------------------------
echo "[3/3] Editor exited (code=$EXIT_CODE). Checking conversion result..."
echo ""

if grep -q "ROVER_CONVERTED_TO_SIM3D" "$LOG_FILE"; then
    echo "✓ SUCCESS — RoverTwin is now a Sim3dStaticMeshActor."
    echo "  Relevant log lines:"
    grep -E "ROVER_CONVERTED_TO_SIM3D|FOUND_ROVER|FOUND_MESH|NO_MESH_ON_OLD_ACTOR|ALREADY_CONVERTED|MESH_APPLIED" "$LOG_FILE" | sed 's/^/  /'
    echo ""
    echo "Next step: run  open_rover_control  in MATLAB."
elif grep -q "ALREADY_CONVERTED" "$LOG_FILE"; then
    echo "✓ ALREADY DONE — RoverTwin was already a Sim3dStaticMeshActor. Nothing changed."
    echo "Next step: run  open_rover_control  in MATLAB."
else
    echo "✗ CONVERSION FAILED — see log for details."
    echo "  Last 30 lines of $LOG_FILE:"
    tail -30 "$LOG_FILE" | sed 's/^/  /'
    exit 1
fi
