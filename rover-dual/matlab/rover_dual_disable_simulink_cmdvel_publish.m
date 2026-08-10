function rover_dual_disable_simulink_cmdvel_publish()
%ROVER_DUAL_DISABLE_SIMULINK_CMDVEL_PUBLISH  Avoid duplicate /cmd_vel with async teleop.
%
%   Simulink teleop blocks and scopes stay live; only Publish_CmdVel is commented out.

    modelName = "rover_dual_control";
    if ~bdIsLoaded(modelName)
        return;
    end

    blk = modelName + "/Publish_CmdVel";
    try
        if getSimulinkBlockHandle(char(blk)) > 0
            set_param(char(blk), "Commented", "on");
            fprintf('[rover_dual] Simulink Publish_CmdVel disabled (use run_teleop.sh or async teleop)\n');
        end
    catch ME
        warning('rover_dual:DisableCmdVel', '%s', ME.message);
    end
end
