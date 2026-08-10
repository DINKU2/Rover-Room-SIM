#!/usr/bin/env bash
# Install Unreal Engine 5.3.2 from Epic Linux zip into ~/UnrealEngine_5.3
# and register a desktop launcher (GNOME/KDE app menu).
#
# Usage:
#   ./scripts/install_unreal_532.sh
#   ./scripts/install_unreal_532.sh /path/to/Linux_Unreal_Engine_5.3.2.zip

set -euo pipefail

ZIP="${1:-$HOME/Downloads/Linux_Unreal_Engine_5.3.2.zip}"
UE_ROOT="${UNREAL_532_ROOT:-$HOME/UnrealEngine_5.3}"
EDITOR="$UE_ROOT/Engine/Binaries/Linux/UnrealEditor"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
ICON="$ICON_DIR/unreal-engine-532.png"

if [[ ! -f "$ZIP" ]]; then
  echo "Zip not found: $ZIP" >&2
  exit 1
fi

need_extract=true
if [[ -f "$UE_ROOT/Engine/Build/Build.version" ]]; then
  ver=$(python3 -c "import json; d=json.load(open('$UE_ROOT/Engine/Build/Build.version')); print(f\"{d['MajorVersion']}.{d['MinorVersion']}.{d['PatchVersion']}\")")
  if [[ "$ver" == "5.3.2" ]]; then
    echo "Already installed: UE $ver at $UE_ROOT"
    need_extract=false
  else
    echo "Existing install is UE $ver — re-extracting to $UE_ROOT"
  fi
fi

if $need_extract; then
  mkdir -p "$UE_ROOT"
  echo "Extracting $ZIP -> $UE_ROOT (15–30 min, ~50 GB)..."
  unzip -o "$ZIP" -d "$UE_ROOT"
fi

chmod +x "$EDITOR"
[[ -x "$EDITOR" ]] || { echo "Editor missing after extract: $EDITOR" >&2; exit 1; }

mkdir -p "$ICON_DIR" "$DESKTOP_DIR"
if [[ -f "$UE_ROOT/Engine/Content/Slate/Starship/Common/UELogo.png" ]]; then
  cp "$UE_ROOT/Engine/Content/Slate/Starship/Common/UELogo.png" "$ICON"
elif [[ -f "$HOME/UnrealEngine/Engine/Content/Slate/Starship/Common/UELogo.png" ]]; then
  cp "$HOME/UnrealEngine/Engine/Content/Slate/Starship/Common/UELogo.png" "$ICON"
fi

LAUNCHER="$HOME/Desktop/project/Rover-Room-SIM/scripts/launch_unreal_532.sh"
cat > "$DESKTOP_DIR/unreal-engine-5.3.2.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Unreal Engine 5.3.2
GenericName=Unreal Editor
Comment=Unreal Engine 5.3.2 (MATLAB R2024b compatible)
Exec=$LAUNCHER
Icon=$ICON
Terminal=false
Categories=Development;IDE;Game;
Keywords=unreal;ue;game;3d;matlab;
StartupWMClass=UnrealEditor
EOF

chmod +x "$LAUNCHER" "$DESKTOP_DIR/unreal-engine-5.3.2.desktop"
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

ver=$(python3 -c "import json; d=json.load(open('$UE_ROOT/Engine/Build/Build.version')); print(f\"{d['MajorVersion']}.{d['MinorVersion']}.{d['PatchVersion']}\")")
echo ""
echo "Done: Unreal Engine $ver at $UE_ROOT"
echo "App menu: search 'Unreal Engine 5.3.2'"
echo "CLI:      $LAUNCHER"
echo ""
echo "Rover project (set ROVER_UE_ROOT for setup scripts):"
echo "  export ROVER_UE_ROOT=$UE_ROOT"
