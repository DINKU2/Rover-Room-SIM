#!/usr/bin/env bash
# Stop TCP bridge (not used for direct DDS MATLAB).
set -e
PORT="${MATLAB_BRIDGE_PORT:-8765}"
pkill -f "matlab_bridge.py" 2>/dev/null || true
sleep 1
if pgrep -f "matlab_bridge.py" >/dev/null 2>&1; then
  pkill -9 -f "matlab_bridge.py" 2>/dev/null || true
  sleep 1
fi
if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "[!!] Port ${PORT} still in use"
  ss -tlnp | grep ":${PORT} " || true
  exit 1
fi
echo "[OK] MATLAB bridge stopped"
