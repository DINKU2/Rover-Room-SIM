#!/usr/bin/env bash
# Quick preflight for Unreal + MATLAB co-simulation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UE_ROOT="${ROVER_UE_ROOT:-$HOME/UnrealEngine_5.3}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-$HOME/MATLAB/R2024b}"
ok=0; fail=0

check() {
  local label="$1" path="$2"
  if eval "$path"; then
    echo "[OK] $label"
    ok=$((ok + 1))
  else
    echo "[FAIL] $label"
    fail=$((fail + 1))
  fi
}

echo "Rover-Room-SIM Unreal preflight"
echo "  ROVER_UE_ROOT=${UE_ROOT}"
echo ""

check "UE 5.3 editor" "[[ -x '${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor' ]]"
check "MATLAB R2024b" "[[ -d '${MATLAB_ROOT}/bin/glnxa64' ]]"
check "my_room.fbx" "[[ -f '${PROJECT_ROOT}/matlab/my_room.fbx' ]]"
check "RoverRoomSIM project" "[[ -f '${PROJECT_ROOT}/unreal/RoverRoomSIM/RoverRoomSIM.uproject' ]]"
check "AutoVrtlEnv project" "[[ -f '${PROJECT_ROOT}/unreal/AutoVrtlEnv/AutoVrtlEnv.uproject' ]]"
check "MathWorksSimulation plugin" "[[ -f '${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux/libUnrealEditor-MathWorksSimulation.so' ]]"
check "rover_unreal_cosim.slx" "[[ -f '${PROJECT_ROOT}/simulink/rover_unreal_cosim.slx' ]]"
check "room in AutoVrtlEnv" "[[ -d '${PROJECT_ROOT}/unreal/AutoVrtlEnv/Content/Room' ]]"

export ROVER_UE_ROOT="$UE_ROOT" MATLAB_R2024B_ROOT="$MATLAB_ROOT"
if "${SCRIPT_DIR}/start_unreal_cosim.sh" --check 2>/dev/null; then
  echo "[OK] plugin library chain"
  ok=$((ok + 1))
else
  echo "[FAIL] plugin library chain (run setup_unreal_matlab in MATLAB)"
  fail=$((fail + 1))
fi

echo ""
if [[ "$fail" -eq 0 ]]; then
  echo "All checks passed. Run: ./scripts/start_unreal_cosim.sh --bg"
  exit 0
fi
echo "${fail} check(s) failed, ${ok} passed."
exit 1
