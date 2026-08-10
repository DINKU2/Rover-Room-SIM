#!/usr/bin/env bash
# Open RoverTwin in Unreal Editor for manual work (Blueprint, level edits).
# Uses /tmp/RoverTwinUnrealProject symlink — required because spaces in the
# Desktop path break Unreal map loading on Linux.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ALIAS="/tmp/RoverTwinUnrealProject"
UPROJECT_ALIAS="${PROJECT_ALIAS}/RoverTwin/RoverTwin.uproject"
LOG="${PROJECT_ROOT}/RoverTwin/Saved/Logs/UnrealEditorLaunch.log"

ln -sfn "$PROJECT_ROOT" "$PROJECT_ALIAS"
[[ -f "$UPROJECT_ALIAS" ]] || { echo "ERROR: symlink failed: $UPROJECT_ALIAS" >&2; exit 1; }

pkill -x UnrealEditor 2>/dev/null || true
sleep 1

mkdir -p "$(dirname "$LOG")"
echo "Opening: $UPROJECT_ALIAS"
echo "Log: $LOG"

ROVER_TWIN_UPROJECT="$UPROJECT_ALIAS" setsid -f "${SCRIPT_DIR}/launch_rovertwin_editor.sh" \
  -nop4 -nosplash \
  >"$LOG" 2>&1 &

echo "Unreal Editor starting (PID $!). Wait ~30s for the window."
echo "If it fails, check: $LOG"
