#!/usr/bin/env bash
# Dump rover-related actors in MyRoom (editor must be open, not in PIE).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UE_ROOT="${UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
UE_EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
UPROJECT="${PROJECT_ROOT}/RoverTwin/RoverTwin.uproject"
LOG="${PROJECT_ROOT}/RoverTwin/Saved/Logs/DebugRoverScene.log"

export LD_LIBRARY_PATH="${UE_ROOT}/Engine/Binaries/ThirdParty/Qualcomm/Linux:${LD_LIBRARY_PATH:-}"

echo "=== Debug Rover Scene ==="
echo "Log: ${LOG}"

"${UE_EDITOR}" "${UPROJECT}" \
    -ExecutePythonScript="${PROJECT_ROOT}/scripts/debug_rover_scene.py" \
    -stdout -unattended -nop4 -nosplash \
    2>&1 | tee "${LOG}"

echo "Done. Search log for DEBUG_ACTOR and DEBUG_SUMMARY."
