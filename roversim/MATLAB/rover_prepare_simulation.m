function rover_prepare_simulation()
%ROVER_PREPARE_SIMULATION Launch Unreal PIE and keyboard input.

modelName = "RoverTwinControl";
if ~rover_model_ok(modelName)
    error("RoverTwin:StaleModel", ...
        ["Wrong Simulink blocks loaded (old Move RoverTwin still in memory).\n" ...
         "In the MATLAB Command Window run:\n\n" ...
         "  open_rover_control\n\n" ...
         "Then click Run again. (Do not open the .slx file directly.)"]);
end

matlabFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(matlabFolder);
launcher = fullfile(projectFolder, "scripts", "launch_rovertwin_simulink.sh");
triggerFile = fullfile(matlabFolder, ".start_rover_pie");

rover_unreal_project_alias();
setenv("MATLABROOT", matlabroot);
setenv("MATLAB_R2024B_ROOT", matlabroot);
setenv("mw_matlab_pid_for_unreal", num2str(feature("getpid")));
setenv("FASTRTPS_DEFAULT_PROFILES_FILE", "");

if exist("shareMATLABSession", "file") == 2
    try
        shareMATLABSession();
    catch
    end
end

assert(isfile(launcher), "RoverTwin:MissingLauncher", ...
    "Unreal launcher not found: %s", launcher);

[status, output] = system(sprintf('bash "%s"', launcher));
assert(status == 0, "RoverTwin:UnrealLaunchFailed", ...
    "Could not launch Unreal Editor:\n%s", output);

rover_keyboard_control("open");

trigger = fopen(triggerFile, "w");
assert(trigger ~= -1, "RoverTwin:TriggerFailed", ...
    "Could not create Unreal Play trigger: %s", triggerFile);
fclose(trigger);
end
