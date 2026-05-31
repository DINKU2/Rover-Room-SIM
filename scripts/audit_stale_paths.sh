#!/usr/bin/env bash
# Find stale VM paths (yahboom, old replica/, wrong toolchain) that break builds.
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

ROOT="$REPLICA_ROOT"
echo "=== Stale path audit: $ROOT ==="
echo ""

PATTERNS=(
  '/home/yahboom'
  'replica-done/replica/'
  '/home/yahboom/.espressif'
  '/home/yahboom/esp/'
)

# Directories to scan (skip huge vendored trees)
SKIP=(
  'esp/esp-idf'
  'esp/Samples/*/build'
  'esp/Samples/*/micro_ros_src/build'
  'esp/Samples/*/micro_ros_src/log'
  'esp/Samples/*/micro_ros_dev/build'
  'esp/Samples/*/micro_ros_dev/log'
  'ros/yahboomcar_ws/build'
  'ros/yahboomcar_ws/log'
  'ros/uros_ws/build'
  'ros/uros_ws/log'
  'tooling/espressif/tools'
  'tooling/espressif/dist'
)

build_skip() {
  local p
  for p in "${SKIP[@]}"; do
    case "$1" in
      *"/$p"/*|*"/$p") return 0 ;;
    esac
  done
  return 1
}

echo "--- By pattern (critical paths only — fast scan) ---"
SCAN_DIRS=(
  "$ROOT/tooling/espressif"
  "$ROOT/esp/Samples/extra_components/micro_ros_espidf_component"
  "$ROOT/esp/Samples/custom_components/micro_ros_espidf_component"
  "$ROOT/esp/Samples/microros_samples"
  "$ROOT/scripts"
  "$ROOT/config"
  "$ROOT/ros/yahboomcar_ws/install"
  "$ROOT/ros/uros_ws/install"
)
for pat in "${PATTERNS[@]}"; do
  echo ""
  echo "[$pat]"
  count=0
  for dir in "${SCAN_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    while IFS= read -r f; do
      case "$f" in
        */build/*|*/log/*|*/esp/esp-idf/*) continue ;;
      esac
      echo "  $f"
      count=$((count + 1))
      [ "$count" -ge 20 ] && break 2
    done < <(grep -rl "$pat" "$dir" 2>/dev/null | head -20 || true)
  done
  [ "$count" -eq 0 ] && echo "  (none in critical dirs)"
done

echo ""
echo "--- Critical generated artifacts (delete & regenerate) ---"
for f in \
  "$ROOT/esp/Samples/extra_components/micro_ros_espidf_component/esp32_toolchain.cmake" \
  "$ROOT/esp/Samples/custom_components/micro_ros_espidf_component/esp32_toolchain.cmake"; do
  if [ -f "$f" ]; then
    if grep -q '/home/yahboom\|replica-done/replica/' "$f" 2>/dev/null; then
      echo "  STALE: $f"
      grep -E 'yahboom|replica-done/replica' "$f" | head -4 | sed 's/^/    /'
    fi
  fi
done

echo ""
echo "--- IDF Python venv shebangs (replica/ without project/) ---"
VENV_BIN="$ROOT/tooling/espressif/python_env/idf5.1_py3.10_env/bin"
if [ -d "$VENV_BIN" ]; then
  bad="$(grep -l 'replica-done/replica/' "$VENV_BIN"/* 2>/dev/null | wc -l || echo 0)"
  echo "  broken wrappers in bin/: $bad"
  if [ "${bad:-0}" -gt 0 ]; then
    echo "  fix: ./scripts/fix_idf_python.sh"
  fi
fi

echo ""
echo "--- idf-env.json ---"
if [ -f "$ROOT/tooling/espressif/idf-env.json" ]; then
  grep -E 'yahboom|replica-done/replica' "$ROOT/tooling/espressif/idf-env.json" | sed 's/^/  /' || echo "  (clean)"
fi

echo ""
echo "--- Legacy WSL Linux FS build tree (safe to remove) ---"
LINUX="$HOME/yahboom_esp_build"
if [ -d "$LINUX" ]; then
  echo "  $LINUX exists — rm -rf ~/yahboom_esp_build if you no longer use WSL"
else
  echo "  (none)"
fi

echo ""
echo "=== Recommended fixes (in order) ==="
echo "  1. ./scripts/fix_idf_python.sh          # broken pip3 shebangs"
echo "  2. ./scripts/fix_stale_paths.sh         # idf-env.json, delete stale toolchain"
