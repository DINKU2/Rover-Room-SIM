#!/usr/bin/env bash
# Step 4 preflight: Simulink Scene Configuration points at RoverTwin MyRoom.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TWIN_PROJECT="${PROJECT_ROOT}/RoverSIMUunreal-Linux/RoverTwin/RoverTwin.uproject"
EXPECTED_SCENE="/Game/Maps/MyRoom"

cd "${PROJECT_ROOT}"
./scripts/matlab_r2024b.sh -batch "addpath('matlab'); paths=rover_unreal_paths(); load_system('simulink/rover_unreal_cosim'); fmt=get_param('rover_unreal_cosim/Scene_Configuration','ProjectFormat'); proj=get_param('rover_unreal_cosim/Scene_Configuration','UEProjPath'); scene=get_param('rover_unreal_cosim/Scene_Configuration','ScenePath'); fprintf('ProjectFormat=%s\nUEProjPath=%s\nScenePath=%s\n', fmt, proj, scene); assert(strcmp(fmt,'Unreal Editor')); assert(strcmp(proj, paths.cosimProject)); assert(strcmp(scene, paths.roverTwinScene)); fprintf('Simulink scene configuration OK.\n');"
