#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/RoverTwin/Saved/Logs/SimulinkEditorLaunch.log"
PROJECT_ALIAS="/tmp/RoverTwinUnrealProject"
UPROJECT_ALIAS="${PROJECT_ALIAS}/RoverTwin/RoverTwin.uproject"

mkdir -p "$(dirname "$LOG_FILE")"
ln -sfn "$PROJECT_ROOT" "$PROJECT_ALIAS"

pkill -x UnrealEditor 2>/dev/null || true

for _ in $(seq 1 20); do
  if ! pgrep -x UnrealEditor >/dev/null; then
    break
  fi
  sleep 0.25
done

pkill -9 -x UnrealEditor 2>/dev/null || true

# Do not use -ExecutePythonScript here: Unreal runs the script then sends
# QUIT_EDITOR, which closes the editor before Simulink can connect and PIE.
ROVER_TWIN_UPROJECT="$UPROJECT_ALIAS" setsid -f "${SCRIPT_DIR}/launch_rovertwin_editor.sh" \
  -nop4 -nosplash -norhithread -windowed -ResX=1600 -ResY=900 \
  >"$LOG_FILE" 2>&1 &

setsid -f "${SCRIPT_DIR}/watch_rovertwin_play.sh" "$PROJECT_ROOT" \
  >/dev/null 2>&1 &
