function rover_diagnose_spawn_check()
%ROVER_DIAGNOSE_SPAWN_CHECK Read-only spawn alignment diagnostic (no fixes).

matlabFolder = fileparts(mfilename("fullpath"));
addpath(matlabFolder);
modelName = "RoverTwinControl";

fprintf("\n=== ROVER SPAWN DIAGNOSTIC ===\n");

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if ~isfile(fullfile(matlabFolder, modelName + ".slx"))
    error("Model missing. Run build_rover_control_model first.");
end
load_system(modelName);
rover_ensure_model(modelName);

spawn = rover_spawn_pose();
icX = get_param(modelName + "/X Position", "InitialCondition");
icY = get_param(modelName + "/Y Position", "InitialCondition");
zVal = get_param(modelName + "/Z Position", "Value");
setTrans = get_param(modelName + "/Set RoverTwin", "Translation");

fprintf("SPAWN_POSE|ue_cm=%s|sim_m=%s\n", mat2str(spawn.ue_cm), mat2str(spawn.sim_m, 8));
fprintf("MODEL_INIT|X_IC=%s|Y_IC=%s|Z_const=%s\n", icX, icY, zVal);
fprintf("MODEL_SET_BLOCK|Translation_param=%s\n", setTrans);

if blockExists(modelName, "Move RoverTwin")
    fprintf("MODEL_ARCH|STALE=1|reason=Move_RoverTwin_block_present\n");
else
    fprintf("MODEL_ARCH|STALE=0|reason=Transform_Set_Get\n");
end

fprintf("\nStarting co-simulation (12s sample window)...\n");
set_param(modelName, "StopTime", "inf");
set_param(modelName, "SimulationCommand", "start");
pause(12);

try
    [cmdX, cmdY, cmdYaw] = readCommanded(modelName);
    [setX, setY, setZ] = readSetTranslation(modelName);
    [actX, actY, actZ] = readActual(modelName);
    fprintf("SIM_POSE|command_xy=(%.4f,%.4f)|set_xyz=(%.4f,%.4f,%.4f)|actual_xyz=(%.4f,%.4f,%.4f)\n", ...
        cmdX, cmdY, setX, setY, setZ, actX, actY, actZ);
    fprintf("SIM_YAW|command_deg=%.2f\n", rad2deg(cmdYaw));
    delta = norm([cmdX cmdY setZ] - [actX actY actZ]);
    fprintf("SIM_DELTA|set_vs_actual_xyz=%.4f\n", delta);
catch ME
    fprintf("SIM_POSE|UNAVAILABLE|%s\n", ME.message);
end

if ~strcmp(get_param(modelName, "SimulationStatus"), "stopped")
    set_param(modelName, "SimulationCommand", "stop");
    pause(1);
end

fprintf("=== DIAGNOSTIC DONE ===\n");
end

function tf = blockExists(modelName, blockName)
tf = ~isempty(find_system(modelName, "SearchDepth", 1, "Name", blockName));
end

function [x, y, yaw] = readCommanded(modelName)
x = readScalar(modelName, "X Position", 1);
y = readScalar(modelName, "Y Position", 1);
yaw = readScalar(modelName, "Yaw", 1);
end

function [x, y, z] = readSetTranslation(modelName)
data = readPort(modelName, "Pack Translation", 1);
x = data(1); y = data(2); z = data(3);
end

function [x, y, z] = readActual(modelName)
data = readPort(modelName, "Get RoverTwin", 1);
x = data(1); y = data(2); z = data(3);
end

function val = readScalar(modelName, blockName, portIndex)
val = readPort(modelName, blockName, portIndex);
val = double(val(1));
end

function data = readPort(modelName, blockName, portIndex)
rt = get_param(modelName + "/" + blockName, "RuntimeObject");
if isempty(rt)
    error("RuntimeObject empty for %s", blockName);
end
try
    data = double(rt.OutputPort(portIndex).Data(:).');
catch
    ports = rt.OutputPort;
    if iscell(ports)
        data = double(ports{portIndex}.Data(:).');
    else
        data = double(ports(portIndex).Data(:).');
    end
end
end
