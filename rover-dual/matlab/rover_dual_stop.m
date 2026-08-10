function rover_dual_stop()
%ROVER_DUAL_STOP Reset dual-model teleop state and close helper windows.

    rover_dual_ensure_paths();

    externalTeleop = evalin('base', 'exist(''roverDualExternalTeleop'', ''var'')') ...
        && evalin('base', 'roverDualExternalTeleop');

    if ~externalTeleop
        if exist("simulink_teleop_stop", "file") == 2
            simulink_teleop_stop();
        end
        simulink_teleop_utils("clear");
        if exist("teleop_timing", "file") == 2
            teleop_timing("report");
        end
    end

    rover_dual_enable_simulink_cmdvel_publish();

    dual_mcl_verify_stop();
    dual_mcl_ros_reset();

    if evalin('base', 'exist(''roverDualExternalTeleop'', ''var'')')
        evalin('base', 'clear roverDualExternalTeleop');
    end
end

