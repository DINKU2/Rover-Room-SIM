function info = rover_ensure_model(modelName)
%ROVER_ENSURE_MODEL Load correct Transform Set/Get model; rebuild if stale.

if nargin < 1
    modelName = "RoverTwinControl";
end

matlabFolder = fileparts(mfilename("fullpath"));
modelPath = fullfile(matlabFolder, modelName + ".slx");

if ~any(strcmp(path, matlabFolder))
    addpath(matlabFolder);
end

if ~bdIsLoaded(modelName)
    if ~isfile(modelPath)
        build_rover_control_model();
    else
        load_system(modelPath);
    end
end

if rover_model_ok(modelName)
    rover_verify_model(modelName);
    info = struct("ok", true);
    return
end

fprintf("[RoverTwin] Stale model (wrong blocks or ActorTag) — rebuilding...\n");
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
build_rover_control_model();
load_system(modelPath);
rover_verify_model(modelName);
info = struct("ok", true);
fprintf("[RoverTwin] Model rebuilt and verified OK.\n");
end
