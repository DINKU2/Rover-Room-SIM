#!/usr/bin/env bash
# Point RoverRoomSIM startup map at RoomPreview after reimport.
set -euo pipefail
INI="${1:-$(cd "$(dirname "$0")/.." && pwd)/unreal/RoverRoomSIM/Config/DefaultEngine.ini}"
if [[ ! -f "$INI" ]]; then exit 0; fi
if grep -q 'RoomPreview.RoomPreview' "$INI"; then exit 0; fi
sed -i 's|EditorStartupMap=/Game/Levels/SimBlank.SimBlank|EditorStartupMap=/Game/Levels/RoomPreview.RoomPreview|g' "$INI"
sed -i 's|GameDefaultMap=/Game/Levels/SimBlank.SimBlank|GameDefaultMap=/Game/Levels/RoomPreview.RoomPreview|g' "$INI"
echo "Updated DefaultEngine.ini -> RoomPreview"
