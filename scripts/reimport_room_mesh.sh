#!/usr/bin/env bash
# Re-import my_room.fbx and place MyRoom actor in SimBlank level.
#
# Usage:
#   ./scripts/reimport_room_mesh.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOM_DIR="${PROJECT_ROOT}/unreal/RoverRoomSIM"
UPROJECT="${ROOM_DIR}/RoverRoomSIM.uproject"
IMPORT_FLAG="${ROOM_DIR}/.room_mesh_imported"
IMPORT_SCRIPT="${PROJECT_ROOT}/unreal/Scripts/import_room_mesh.py"
UE_ROOT="${ROVER_UE_ROOT:-$HOME/UnrealEngine_5.3}"
UE_EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
ROOM_FBX="${PROJECT_ROOT}/matlab/my_room.fbx"

[[ -x "$UE_EDITOR" ]] || { echo "UE not found: $UE_EDITOR" >&2; exit 1; }
[[ -f "$UPROJECT" ]] || { echo "Run ./scripts/run_room_preview.sh --setup first" >&2; exit 1; }
[[ -f "$ROOM_FBX" ]] || { echo "FBX missing: $ROOM_FBX" >&2; exit 1; }

rm -f "$IMPORT_FLAG"
mkdir -p "${ROOM_DIR}/Saved/Logs" "${ROOM_DIR}/Content/Room"
chmod -R u+w "${ROOM_DIR}/Content" "${ROOM_DIR}/Config" 2>/dev/null || true

# Stale uassets from another UE build cause "partially loaded" save failures.
echo "Removing old /Game/Room assets for clean reimport..."
rm -rf "${ROOM_DIR}/Content/Room"/*
mkdir -p "${ROOM_DIR}/Content/Room"

export ROVER_ROOM_FBX="$ROOM_FBX"
export ROVER_UE_COSIM=0
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/nvidia_icd.json}"

IMPORT_LOG="${ROOM_DIR}/Saved/Logs/import_room_mesh.log"
echo "Re-importing room mesh and saving level (2–5 min)..."
echo "Log: ${IMPORT_LOG}"

# Fix SimBlank.umap if present (TemplateResources copy may be newer than this UE build).
TEMPLATE_MAP="${UE_ROOT}/Templates/TemplateResources/Standard/SimBlank/Content/Levels/SimBlank.umap"
if [[ -f "$TEMPLATE_MAP" ]]; then
  cp "$TEMPLATE_MAP" "${ROOM_DIR}/Content/Levels/SimBlank.umap" 2>/dev/null || true
  chmod u+w "${ROOM_DIR}/Content/Levels/SimBlank.umap" 2>/dev/null || true
fi

"$UE_EDITOR" "$UPROJECT" \
  -ExecutePythonScript="$IMPORT_SCRIPT" \
  -Unattended \
  -nosplash \
  -DisableSourceControl \
  2>&1 | tee "$IMPORT_LOG"
import_status=${PIPESTATUS[0]}

if [[ "$import_status" -ne 0 ]]; then
  echo "Import failed (exit ${import_status}). See: ${IMPORT_LOG}" >&2
  grep -i 'RoverRoomSIM\|LogPython: Error' "$IMPORT_LOG" 2>/dev/null | tail -10 >&2 || true
  exit "$import_status"
fi

if ! grep -q "Saved level + packages" "$IMPORT_LOG" 2>/dev/null; then
  echo "Import script did not save the level. Check log: ${IMPORT_LOG}" >&2
  grep -i 'LogPython\|Error' "$IMPORT_LOG" 2>/dev/null | tail -15 >&2 || true
  exit 1
fi

date -Iseconds > "$IMPORT_FLAG"
bash "${SCRIPT_DIR}/patch_rover_startup_map.sh"
echo "Done. Open preview: ./scripts/run_room_preview.sh"
echo "In Outliner, look for actor 'MyRoom' under folder Room."
