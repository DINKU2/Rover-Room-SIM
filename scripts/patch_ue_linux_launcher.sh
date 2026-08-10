#!/usr/bin/env bash
# Inject NVIDIA Vulkan env into a UE-generated Linux .sh game launcher.
#
# Usage:
#   ./scripts/patch_ue_linux_launcher.sh /path/to/RoverTwin.sh

set -euo pipefail

LAUNCHER="${1:-}"
[[ -f "$LAUNCHER" ]] || { echo "Launcher not found: $LAUNCHER" >&2; exit 1; }

MARKER="# Rover-Room-SIM NVIDIA Vulkan env"
if grep -q "$MARKER" "$LAUNCHER" 2>/dev/null; then
  exit 0
fi

TMP="$(mktemp)"
{
  echo "#!/bin/sh"
  echo "$MARKER"
  echo 'export __NV_PRIME_RENDER_OFFLOAD=1'
  echo 'export __GLX_VENDOR_LIBRARY_NAME=nvidia'
  echo 'export __VK_LAYER_NV_optimus=NVIDIA_only'
  echo 'export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/nvidia_icd.json}"'
  echo 'if [ "${XDG_SESSION_TYPE:-}" = "wayland" ] && [ -z "${GDK_BACKEND:-}" ]; then export GDK_BACKEND=x11; fi'
  echo
  # Skip shebang from original; keep UE launcher body.
  tail -n +2 "$LAUNCHER"
} > "$TMP"
chmod +x "$TMP"
mv "$TMP" "$LAUNCHER"
