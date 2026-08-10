function open_rover_control()
%OPEN_ROVER_CONTROL Open or create the RoverTwin Simulink controller.
%
% Always call this from MATLAB rather than opening the .slx directly.
% It ensures the MATLAB folder is on the path so Simulink's InitFcn /
% StopFcn callbacks (rover_prepare_simulation, rover_stop_simulation,
% rover_keyboard_control) can be found regardless of the current
% working directory.

matlabFolder = fileparts(mfilename("fullpath"));
modelName    = "RoverTwinControl";
modelPath    = fullfile(matlabFolder, modelName + ".slx");

if ~any(strcmp(path, matlabFolder))
    addpath(matlabFolder);
end

% Close stale in-memory copy so disk rebuilds reload cleanly.
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

if ~isfile(modelPath)
    build_rover_control_model();
else
    load_system(modelPath);
end
rover_ensure_model(modelName);

open_system(modelPath);
set_param(modelName, "ZoomFactor", "FitSystem");
end
