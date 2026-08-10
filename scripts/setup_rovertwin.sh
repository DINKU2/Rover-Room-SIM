#!/usr/bin/env bash
# Rebuild buildrover/RoverTwin on Linux from matlab/my_room.fbx + rover OBJ sources.
#
# Usage:
#   ./scripts/setup_rovertwin.sh
#   ./scripts/setup_rovertwin.sh --recreate
#   ./scripts/setup_rovertwin.sh --skip-import
#
# Environment:
#   ROVER_UE_ROOT=/path/to/UnrealEngine_5.3
#   ROVER_PROJECT_ROOT=/path/to/Rover-Room-SIM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${ROVER_PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
UE_ROOT="${ROVER_UE_ROOT:-$HOME/UnrealEngine_5.3}"
UE_EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
UE_CONTENT="${UE_ROOT}/Templates/TemplateResources/Standard/SimBlank/Content"

TWIN_DIR="${PROJECT_ROOT}/buildrover/RoverTwin"
UPROJECT="${TWIN_DIR}/RoverTwin.uproject"
ROOM_FBX="${PROJECT_ROOT}/matlab/my_room.fbx"
ROVER_OBJ_DIR="${TWIN_DIR}/Content/Rover/Import"
IMPORT_SCRIPT="${PROJECT_ROOT}/buildrover/Scripts/import_rovertwin_scene.py"
IMPORT_FLAG="${TWIN_DIR}/.rovertwin_imported"
SKIP_IMPORT=0
RECREATE=0

for arg in "$@"; do
  case "$arg" in
    --recreate) RECREATE=1 ;;
    --skip-import) SKIP_IMPORT=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

die() { echo "setup_rovertwin: $*" >&2; exit 1; }

[[ -x "$UE_EDITOR" ]] || die "Unreal Editor not found: $UE_EDITOR"
[[ -d "$UE_CONTENT" ]] || die "SimBlank template content not found: $UE_CONTENT"
[[ -f "$ROOM_FBX" ]] || die "Room FBX not found: $ROOM_FBX"
[[ -f "$IMPORT_SCRIPT" ]] || die "Import script not found: $IMPORT_SCRIPT"
[[ -f "$UPROJECT" ]] || die "RoverTwin project not found: $UPROJECT"

echo "== RoverTwin Linux rebuild =="
echo "  Project:  ${TWIN_DIR}"
echo "  UE:       ${UE_ROOT}"
echo "  Room FBX: ${ROOM_FBX}"
echo "  Rover:    ${ROVER_OBJ_DIR}"

mkdir -p "${TWIN_DIR}/Content/Maps" "${TWIN_DIR}/Saved/Logs" "${PROJECT_ROOT}/buildrover/Scripts"

if [[ "$RECREATE" -eq 1 ]]; then
  echo "Clearing generated RoverTwin content..."
  pkill -f "UnrealEditor.*RoverTwin" 2>/dev/null || true
  sleep 2
  rm -rf \
    "${TWIN_DIR}/Content/Maps" \
    "${TWIN_DIR}/Content/MyRoom" \
    "${TWIN_DIR}/Content/Rover/Meshes" \
    "${TWIN_DIR}/Content/SimBlank" \
    "${TWIN_DIR}/Binaries" \
    "${TWIN_DIR}/Intermediate" \
    "${TWIN_DIR}/Saved" \
    "${TWIN_DIR}/DerivedDataCache" \
    "${PROJECT_ROOT}/buildrover/Linux" \
    "${IMPORT_FLAG}"
  mkdir -p "${TWIN_DIR}/Content/Maps" "${TWIN_DIR}/Saved/Logs"
fi

if [[ ! -d "${TWIN_DIR}/Content/SimBlank" ]]; then
  echo "Copying SimBlank template content (game mode + sky)..."
  rsync -a "${UE_CONTENT}/" "${TWIN_DIR}/Content/SimBlank/"
  chmod -R u+w "${TWIN_DIR}/Content/SimBlank"
fi

if [[ "$SKIP_IMPORT" -eq 1 ]]; then
  echo "Skipping scene import (--skip-import)."
  exit 0
fi

if [[ -f "$IMPORT_FLAG" && "$RECREATE" -eq 0 ]]; then
  echo "RoverTwin already imported ($(cat "$IMPORT_FLAG")). Use --recreate to rebuild."
  exit 0
fi

export ROVER_ROOM_FBX="$ROOM_FBX"
export ROVER_OBJ_DIR="$ROVER_OBJ_DIR"
export ROVER_UE_COSIM=0
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/nvidia_icd.json}"

IMPORT_LOG="$(realpath "${TWIN_DIR}/Saved/Logs/import_rovertwin.log")"
CONSOLE_LOG="$(realpath "${TWIN_DIR}/Saved/Logs/import_rovertwin_console.log")"
echo "Importing room + rover into MyRoom (2–10 min)..."
echo "Log: ${IMPORT_LOG}"

set +e
"$UE_EDITOR" "$UPROJECT" \
  -ExecutePythonScript="$IMPORT_SCRIPT" \
  -Unattended \
  -nosplash \
  -DisableSourceControl \
  -log="$IMPORT_LOG" \
  2>&1 | tee "$CONSOLE_LOG"
import_status=${PIPESTATUS[0]}
set -e

if [[ "$import_status" -ne 0 ]]; then
  echo "Import failed (exit ${import_status}). See: ${IMPORT_LOG}" >&2
  exit "$import_status"
fi

if ! grep -q "RoverTwin scene import complete" "$IMPORT_LOG" "$CONSOLE_LOG" 2>/dev/null; then
  if [[ ! -f "${TWIN_DIR}/Content/Maps/MyRoom.umap" ]]; then
    echo "Import script did not finish successfully. Check: ${CONSOLE_LOG}" >&2
    grep -i 'RoverTwin\|LogPython: Error\|Error' "$CONSOLE_LOG" 2>/dev/null | tail -20 >&2 || true
    exit 1
  fi
  echo "Import log missing success line, but MyRoom.umap exists — continuing."
fi

date -Iseconds > "$IMPORT_FLAG"
echo ""
echo "RoverTwin import complete."
echo "  Preview:  ./scripts/run_rovertwin.sh"
echo "  Package:  ./buildrover/RoverTwin/PackageRoverTwin_Linux.sh"
echo "  MATLAB:   open_unreal_room('rovertwin')"
