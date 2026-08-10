#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$1"
TRIGGER_FILE="${PROJECT_ROOT}/MATLAB/.start_rover_pie"
LOG_FILE="${PROJECT_ROOT}/RoverTwin/Saved/Logs/SimulinkEditorLaunch.log"

for _ in $(seq 1 240); do
  if [[ -f "$TRIGGER_FILE" ]]; then
    WINDOW_ID="$(xdotool search --name '^RoverTwin - Unreal Editor$' 2>/dev/null | head -n 1 || true)"
    if [[ -n "$WINDOW_ID" ]] && grep -q "Total Editor Startup Time" "$LOG_FILE" 2>/dev/null; then
      rm -f "$TRIGGER_FILE"
      sleep 10
      for _ in $(seq 1 6); do
        xdotool windowactivate --sync "$WINDOW_ID"
        sleep 1
        xdotool key --clearmodifiers alt+p
        sleep 4
        if grep -q "New page: PIE session:" "$LOG_FILE" 2>/dev/null; then
          printf '\nSIMULINK_PIE_STARTED\n' >>"$LOG_FILE"
          exit 0
        fi
      done
      printf '\nSIMULINK_PIE_SHORTCUT_FAILED\n' >>"$LOG_FILE"
      exit 1
    fi
  fi
  sleep 0.5
done

echo "SIMULINK_PIE_SHORTCUT_TIMEOUT" >>"$LOG_FILE"
exit 1
