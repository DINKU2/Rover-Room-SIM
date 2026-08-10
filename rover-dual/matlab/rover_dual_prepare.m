function rover_dual_prepare()
%ROVER_DUAL_PREPARE Prepare MATLAB path, ROS 2, Unreal, and teleop state.

dualMatlab = fileparts(mfilename("fullpath"));
paths = rover_dual_setup_paths(dualMatlab);

setup_ros_humble();
setup_rover_paths();
simulink_teleop_utils("clear");
manual_align_close_figures();

    alignPath = fullfile(paths.projectRoot, "maps", "unreal_alignment.mat");
    assert(isfile(alignPath), "RoverDual:NoAlignment", ...
        ["Stage 4 needs maps/unreal_alignment.mat (Stage 3)." newline ...
        "Run: run_manual_align_slam  or  run_align_slam_to_unreal" newline ...
        "  %s"], alignPath);
    fprintf("[Stage 4] Using alignment: %s\n", alignPath);

    if is_skip_unreal()
        fprintf("[Stage 4] ROVER_DUAL_SKIP_UNREAL=1 — skipping Unreal launch.\n");
        return;
    end

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

launcher = fullfile(paths.projectRoot, "roversim", "scripts", "launch_rovertwin_simulink.sh");
triggerFile = fullfile(paths.projectRoot, "roversim", "MATLAB", ".start_rover_pie");

assert(isfile(launcher), "RoverDual:MissingLauncher", ...
    "Unreal launcher not found: %s", launcher);

[status, output] = system(sprintf('bash "%s"', launcher));
assert(status == 0, "RoverDual:UnrealLaunchFailed", ...
    "Could not launch Unreal Editor:\n%s", output);

trigger = fopen(triggerFile, "w");
assert(trigger ~= -1, "RoverDual:TriggerFailed", ...
    "Could not create Unreal Play trigger: %s", triggerFile);
fclose(trigger);

rover_dual_wait_for_pie(120);
end

function tf = is_skip_unreal()
    tf = strcmp(getenv("ROVER_DUAL_SKIP_UNREAL"), "1");
end
