#!/usr/bin/env bash
# Launch RoverTwin (MyRoom) for MATLAB/Simulink co-simulation (Path 3, step 5).
#
# Usage:
#   ./scripts/start_rovertwin_cosim.sh              # launch + wait
#   ./scripts/start_rovertwin_cosim.sh --bg         # launch in background, wait, print pid
#   ./scripts/start_rovertwin_cosim.sh --check      # verify prerequisites only
#
# After this script succeeds:
#   MATLAB:  run_rover_unreal_cosim(false)
#   Unreal:  confirm MyRoom is open, then click Play when Simulink runs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UE_ROOT="${ROVER_UE_ROOT:-${UNREAL_532_ROOT:-$HOME/UnrealEngine_5.3}}"
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-${MATLABROOT:-$HOME/MATLAB/R2024b}}"
TWIN_DIR="${ROVER_TWIN_DIR:-${PROJECT_ROOT}/RoverSIMUunreal-Linux/RoverTwin}"
UPROJECT="${ROVER_TWIN_UPROJECT:-${TWIN_DIR}/RoverTwin.uproject}"
MAP="${TWIN_DIR}/Content/Maps/MyRoom.umap"
LAUNCH="${SCRIPT_DIR}/launch_unreal_532.sh"
LOG="${ROVER_UE_LOG:-/tmp/rover_rovertwin.log}"
WAIT_SEC="${ROVER_UE_WAIT_SEC:-180}"
BG=0

for arg in "$@"; do
  case "$arg" in
    --bg) BG=1 ;;
    --check) CHECK_ONLY=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
  esac
done

die() { echo "start_rovertwin_cosim: $*" >&2; exit 1; }

echo "== RoverTwin MyRoom co-sim launcher =="

[[ -x "${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor" ]] || \
  die "UE 5.3 not found at ${UE_ROOT}. Run ./scripts/install_unreal_532.sh"
[[ -f "$UPROJECT" ]] || die "RoverTwin project missing: ${UPROJECT}"
[[ -f "$MAP" ]] || die "MyRoom.umap missing: ${MAP}. Run ./scripts/verify_rovertwin_myroom.sh"
[[ -x "$LAUNCH" ]] || die "Missing ${LAUNCH}"
[[ -f "${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux/libUnrealEditor-MathWorksSimulation.so" ]] || \
  die "MathWorksSimulation plugin missing. In MATLAB: setup_unreal_matlab(true)"
python3 -c "import json; d=json.load(open('${UPROJECT}')); assert any(p.get('Name')=='MathWorksSimulation' and p.get('Enabled') for p in d.get('Plugins',[])), 'MathWorksSimulation not enabled in RoverTwin.uproject'" \
  || die "Enable MathWorks plugins: ./scripts/patch_rovertwin_uproject.sh"

MW_SO="${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux/libUnrealEditor-MathWorksSimulation.so"
export ROVER_UE_ROOT="$UE_ROOT"
export MATLAB_R2024B_ROOT="$MATLAB_ROOT"
export ROVER_UE_COSIM=1
# System graphics libs MUST come before MATLAB — MATLAB bundles its own
# libvulkan.so.1, libX11.so.6, libxcb.so.1 which shadow the system ones and
# prevent Unreal from creating a Vulkan window.
SYS_GFX="/usr/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu/nvidia/xorg"
export LD_LIBRARY_PATH="${SYS_GFX}:${UE_ROOT}/Engine/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/ProceduralMeshComponent/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Runtime/SunPosition/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Experimental/ChaosVehiclesPlugin/Binaries/Linux:${UE_ROOT}/Engine/Plugins/Marketplace/Mathworks/MathWorksSimulation/Binaries/Linux:${MATLAB_ROOT}/bin/glnxa64:${MATLAB_ROOT}/extern/bin/glnxa64:${LD_LIBRARY_PATH:-}"

missing=$(ldd "$MW_SO" 2>/dev/null | grep 'not found' || true)
[[ -z "$missing" ]] || die "MathWorks plugin missing libs:${missing}"

if [[ "${CHECK_ONLY:-0}" == 1 ]]; then
  echo "[OK] UE, RoverTwin, MyRoom, MathWorksSimulation plugin, library paths"
  exit 0
fi

if pgrep -x UnrealEditor >/dev/null 2>&1; then
  echo "UnrealEditor already running ($(pgrep -x UnrealEditor)). Use that window or pkill UnrealEditor first."
  exit 0
fi

rm -f "$LOG"
echo "Launching: ${UPROJECT}"
echo "Scene:     /Game/Maps/MyRoom"
echo "Log:       ${LOG}"

if [[ "$BG" == 1 ]]; then
  nohup env ROVER_UE_COSIM=1 "$LAUNCH" "$UPROJECT" -log > "$LOG" 2>&1 &
  UE_WRAPPER_PID=$!
  echo "Started (wrapper pid ${UE_WRAPPER_PID})"
else
  env ROVER_UE_COSIM=1 "$LAUNCH" "$UPROJECT" -log > "$LOG" 2>&1 &
  UE_WRAPPER_PID=$!
fi

deadline=$((SECONDS + WAIT_SEC))
while (( SECONDS < deadline )); do
  sleep 2
  if grep -q "MathWorksSimulation.*failed to load" "$LOG" 2>/dev/null; then
    echo "MathWorksSimulation plugin failed. See log:" >&2
    grep -E 'MathWorks|dlopen|failed' "$LOG" | tail -10 >&2
    exit 1
  fi
  if grep -q "Total Editor Startup Time" "$LOG" 2>/dev/null && pgrep -x UnrealEditor >/dev/null; then
    sleep 3
    if pgrep -x UnrealEditor >/dev/null; then
      echo ""
      echo "[OK] Unreal Editor ready ($(pgrep -x UnrealEditor))"
      echo ""
      echo "Next steps:"
      echo "  1. Unreal:  confirm /Game/Maps/MyRoom is open"
      echo "  2. MATLAB:  cd('${PROJECT_ROOT}/matlab'); run_rover_unreal_cosim(false)"
      echo "  3. Unreal:  click Play when Simulink is running"
      echo "  4. Teleop:  i/k forward/back, j/l turn, space stop"
      echo ""
      exit 0
    fi
  fi
  if grep -q "Unable to create a Vulkan window" "$LOG" 2>/dev/null && ! pgrep -x UnrealEditor >/dev/null; then
    echo "Vulkan window failed and UnrealEditor exited." >&2
    tail -20 "$LOG" >&2
    exit 1
  fi
  if ! pgrep -x UnrealEditor >/dev/null && (( SECONDS > 15 )); then
    echo "UnrealEditor exited before ready. Last log lines:" >&2
    tail -25 "$LOG" >&2
    exit 1
  fi
done

echo "Timed out after ${WAIT_SEC}s (editor may still be loading shaders)." >&2
echo "Check: tail -f ${LOG}" >&2
pgrep -x UnrealEditor >/dev/null && echo "UnrealEditor is still running — you may proceed once MyRoom appears." && exit 0
exit 1
