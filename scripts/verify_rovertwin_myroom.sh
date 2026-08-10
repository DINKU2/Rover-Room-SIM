#!/usr/bin/env bash
# Step 3 preflight: confirm MyRoom level + assets exist in RoverTwin editor project.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TWIN_DIR="${ROVER_TWIN_DIR:-${PROJECT_ROOT}/RoverSIMUunreal-Linux/RoverTwin}"
UPROJECT="${TWIN_DIR}/RoverTwin.uproject"
MAP="${TWIN_DIR}/Content/Maps/MyRoom.umap"
ROOM_DIR="${TWIN_DIR}/Content/MyRoom"
ROVER_MESHES="${TWIN_DIR}/Content/Rover/Meshes"
SIMBLANK="${TWIN_DIR}/Content/SimBlank"

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

echo "RoverTwin MyRoom verification (Path 3, step 3)"
echo "  ROVER_TWIN_DIR=${TWIN_DIR}"
echo ""

check "RoverTwin.uproject" "[[ -f '${UPROJECT}' ]]"
check "MyRoom.umap" "[[ -f '${MAP}' ]]"
check "room meshes (Content/MyRoom)" "[[ -d '${ROOM_DIR}' ]] && ls '${ROOM_DIR}'/SM_my_room_*.uasset >/dev/null 2>&1"
check "rover meshes (Content/Rover/Meshes)" "[[ -d '${ROVER_MESHES}' ]] && ls '${ROVER_MESHES}'/SM_*.uasset >/dev/null 2>&1"
check "SimBlank game mode" "[[ -d '${SIMBLANK}/Blueprints' ]]"
check "startup map = MyRoom" "grep -q '/Game/Maps/MyRoom' '${TWIN_DIR}/Config/DefaultEngine.ini'"
check "MathWorksSimulation plugin enabled" "grep -q 'MathWorksSimulation' '${UPROJECT}' && python3 -c \"import json; d=json.load(open('${UPROJECT}')); print(any(p.get('Name')=='MathWorksSimulation' and p.get('Enabled') for p in d.get('Plugins',[])))\""

echo ""
if [[ "$fail" -eq 0 ]]; then
  echo "MyRoom ready for editor co-sim. Simulink scene: /Game/Maps/MyRoom"
  exit 0
fi
echo "${fail} check(s) failed, ${ok} passed."
echo "If MyRoom.umap is missing, re-import room + rover into ${TWIN_DIR}."
exit 1
