#!/usr/bin/env bash
set -euo pipefail

UE_ROOT="${UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/RoverTwin.uproject"
ARCHIVE="$SCRIPT_DIR/../Linux"

echo
echo "Packaging RoverTwin for Linux..."
echo "Project: $PROJECT"
echo "Output:  $ARCHIVE"
echo
echo "Close Unreal Editor before packaging."
echo

"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun \
  -project="$PROJECT" \
  -noP4 \
  -platform=Linux \
  -clientconfig=Shipping \
  -serverconfig=Shipping \
  -cook \
  -allmaps \
  -build \
  -stage \
  -pak \
  -archive \
  -archivedirectory="$ARCHIVE"

echo
echo "Packaging complete."
echo "Run the game from the Linux/ folder."
