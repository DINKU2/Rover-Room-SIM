function rover_dual_start()
%ROVER_DUAL_START  Simulink StartFcn — MCL verify overlay + optional MATLAB teleop.

    rover_dual_ensure_paths();
    clear simulink_mcl_map_pose dual_mcl_ros_update;
    simulink_stage4_debug_reset();
    stage4_timing_reset();

    % Shared ROS node (/odom + /scan for MCL). /cmd_vel publish is external or async.
    try
        simulink_dual_ros_init();
    catch ME
        warning('rover_dual_start:RosInit', '%s', ME.message);
    end

    dual_mcl_verify_start();
    rover_dual_disable_simulink_cmdvel_publish();

    if rover_dual_use_external_teleop()
        fprintf(['[rover_dual] External teleop ON — drive in another terminal:\n' ...
            '  cd %s\n' ...
            '  source ./setup.bash && ./scripts/run_teleop.sh\n'], ...
            rover_dual_repo_root());
        assignin('base', 'roverDualExternalTeleop', true);
    else
        teleop_timing_reset();
        simulink_teleop_start(true);
        assignin('base', 'roverDualExternalTeleop', false);
        fprintf('[rover_dual] MATLAB teleop ON — click Simulink Rover Teleop, then WASD\n');
    end
end

function root = rover_dual_repo_root()
    dualRoot = fileparts(fileparts(mfilename('fullpath')));
    root = fileparts(dualRoot);
end
