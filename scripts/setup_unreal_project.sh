#!/usr/bin/env bash
# Create RoverRoomSIM Unreal project from the SimBlank template and import my_room.fbx.
#
# Usage:
#   ./scripts/setup_unreal_project.sh
#   ./scripts/setup_unreal_project.sh --recreate
#   ./scripts/setup_unreal_project.sh --skip-import
#
# Environment overrides:
#   ROVER_UE_ROOT=/path/to/UnrealEngine
#   ROVER_PROJECT_ROOT=/path/to/Rover-Room-SIM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${ROVER_PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
UE_ROOT="${ROVER_UE_ROOT:-/home/dinuk/UnrealEngine_5.3}"
UE_EDITOR="${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor"
UE_TEMPLATE="${UE_ROOT}/Templates/TP_SIM_BlankBP"
UE_CONTENT="${UE_ROOT}/Templates/TemplateResources/Standard/SimBlank/Content"

UNREAL_DIR="${PROJECT_ROOT}/unreal"
ROOM_DIR="${UNREAL_DIR}/RoverRoomSIM"
UPROJECT="${ROOM_DIR}/RoverRoomSIM.uproject"
ROOM_FBX="${PROJECT_ROOT}/matlab/my_room.fbx"
IMPORT_SCRIPT="${UNREAL_DIR}/Scripts/import_room_mesh.py"
IMPORT_FLAG="${ROOM_DIR}/.room_mesh_imported"
SKIP_IMPORT=0
RECREATE=0

for arg in "$@"; do
  case "$arg" in
    --recreate) RECREATE=1 ;;
    --skip-import) SKIP_IMPORT=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

die() { echo "setup_unreal_project: $*" >&2; exit 1; }

[[ -x "$UE_EDITOR" ]] || die "Unreal Editor not found: $UE_EDITOR"
[[ -d "$UE_TEMPLATE" ]] || die "SimBlank template not found: $UE_TEMPLATE"
[[ -d "$UE_CONTENT" ]] || die "SimBlank content not found: $UE_CONTENT"
[[ -f "$ROOM_FBX" ]] || die "Room FBX not found: $ROOM_FBX"
[[ -f "$IMPORT_SCRIPT" ]] || die "Import script not found: $IMPORT_SCRIPT"

echo "== Rover-Room-SIM Unreal setup =="
echo "  Project:  ${ROOM_DIR}"
echo "  UE:       ${UE_ROOT}"
echo "  Room FBX: ${ROOM_FBX}"

mkdir -p "${ROOM_DIR}/Config" "${UNREAL_DIR}/Scripts"

if [[ "$RECREATE" -eq 1 ]]; then
  echo "Removing existing project: ${ROOM_DIR}"
  pkill -f "UnrealEditor.*RoverRoomSIM" 2>/dev/null || true
  sleep 2
  rm -rf "$ROOM_DIR"
  mkdir -p "${ROOM_DIR}/Config"
fi

if [[ ! -f "$UPROJECT" ]]; then
  echo "Creating project from SimBlank template..."
  rsync -a --delete \
    --exclude 'DerivedDataCache/' \
    --exclude 'Intermediate/' \
    --exclude 'Saved/' \
    "${UE_TEMPLATE}/Config/" "${ROOM_DIR}/Config/"
  chmod -R u+w "${ROOM_DIR}/Config"

  rsync -a "${UE_CONTENT}/" "${ROOM_DIR}/Content/"
  # TemplateResources SimBlank.umap may be newer than this UE build — use TP_SIM_BlankBP level.
  if [[ -f "${UE_TEMPLATE}/Content/Levels/SimBlank.umap" ]]; then
    mkdir -p "${ROOM_DIR}/Content/Levels"
    cp "${UE_TEMPLATE}/Content/Levels/SimBlank.umap" "${ROOM_DIR}/Content/Levels/SimBlank.umap"
    chmod u+w "${ROOM_DIR}/Content/Levels/SimBlank.umap"
  fi

  cat > "$UPROJECT" <<EOF
{
	"FileVersion": 3,
	"EngineAssociation": "5.3",
	"Category": "",
	"Description": "Rover-Room-SIM room preview (SimBlank + my_room.fbx)",
	"Plugins": [
		{
			"Name": "ModelingToolsEditorMode",
			"Enabled": true,
			"TargetAllowList": [
				"Editor"
			]
		},
		{
			"Name": "SunPosition",
			"Enabled": true
		},
		{
			"Name": "GeoReferencing",
			"Enabled": true
		},
		{
			"Name": "PythonScriptPlugin",
			"Enabled": true
		}
	]
}
EOF

  # Fresh project uses RoomPreview (created by import_room_mesh.py).
  cat > "${ROOM_DIR}/Config/DefaultEngine.ini" <<'EOF'
[/Script/EngineSettings.GameMapsSettings]
EditorStartupMap=/Game/Levels/RoomPreview.RoomPreview
GlobalDefaultGameMode=/Game/Blueprints/BP_SimGameMode.BP_SimGameMode_C
GameDefaultMap=/Game/Levels/RoomPreview.RoomPreview

[/Script/Engine.RendererSettings]
r.DefaultFeature.AutoExposure.ExtendDefaultLuminanceRange=True
r.AllowStaticLighting=False
r.GenerateMeshDistanceFields=True
r.DynamicGlobalIlluminationMethod=1
r.ReflectionMethod=1

[/Script/PythonScriptPlugin.PythonScriptPluginSettings]
bRemoteExecution=True
RemoteExecutionMulticastGroupEndpoint=239.0.0.1:6766
RemoteExecutionMulticastBindAddress=0.0.0.0
EOF

  cat > "${ROOM_DIR}/Config/DefaultGame.ini" <<EOF
[/Script/EngineSettings.GeneralProjectSettings]
ProjectID=$(python3 -c 'import uuid; print(uuid.uuid4().hex.upper())')
ProjectName=RoverRoomSIM
CompanyName=Rover-Room-SIM
Description=Rover room visualization for blind navigation demo
EOF

  echo "Created ${UPROJECT}"
else
  echo "Project already exists: ${UPROJECT}"
fi

if [[ "$SKIP_IMPORT" -eq 1 ]]; then
  echo "Skipping FBX import (--skip-import)."
  exit 0
fi

if [[ -f "$IMPORT_FLAG" ]]; then
  echo "Room mesh already imported ($(cat "$IMPORT_FLAG")). Delete flag to re-import."
  exit 0
fi

echo "Importing my_room.fbx (Unreal may take several minutes on first launch)..."
mkdir -p "${ROOM_DIR}/Saved/Logs"

export ROVER_ROOM_FBX="$ROOM_FBX"
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia

set +e
"$UE_EDITOR" "$UPROJECT" \
  -ExecutePythonScript="$IMPORT_SCRIPT" \
  -Unattended \
  -nosplash \
  -DisableSourceControl \
  -log="${ROOM_DIR}/Saved/Logs/import_room_mesh.log"
import_status=$?
set -e

if [[ "$import_status" -ne 0 ]]; then
  echo "FBX import exited with status ${import_status}." >&2
  echo "You can still open the project and import manually:" >&2
  echo "  open_unreal_room('preview')" >&2
  echo "Log: ${ROOM_DIR}/Saved/Logs/import_room_mesh.log" >&2
  exit "$import_status"
fi

date -Iseconds > "$IMPORT_FLAG"
bash "${SCRIPT_DIR}/patch_rover_startup_map.sh"
echo "Room mesh import complete."
echo "Open with:  cd matlab && open_unreal_room('preview')"
echo "Package:    ./scripts/package_rover_room.sh"
