#!/usr/bin/env bash
# Copy imported room assets from RoverRoomSIM into AutoVrtlEnv (no UE headless import).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${PROJECT_ROOT}/unreal/RoverRoomSIM/Content/Room"
DEST="${PROJECT_ROOT}/unreal/AutoVrtlEnv/Content/Room"
IMPORT_FLAG="${PROJECT_ROOT}/unreal/AutoVrtlEnv/.room_mesh_imported"

[[ -d "$SRC" ]] || { echo "Source room assets missing. Run setup_unreal_project.sh first." >&2; exit 1; }
[[ -f "${PROJECT_ROOT}/unreal/AutoVrtlEnv/AutoVrtlEnv.uproject" ]] || { echo "AutoVrtlEnv missing. Run setup_unreal_matlab(true) first." >&2; exit 1; }

mkdir -p "$DEST"
rsync -a "$SRC/" "$DEST/"
date -Iseconds > "$IMPORT_FLAG"
echo "Copied room assets to AutoVrtlEnv/Content/Room (from RoverRoomSIM)."
