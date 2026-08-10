function rover_dual_enable_simulink_cmdvel_publish()
%ROVER_DUAL_ENABLE_SIMULINK_CMDVEL_PUBLISH  Restore Simulink /cmd_vel publish block.

    modelName = "rover_dual_control";
    if ~bdIsLoaded(modelName)
        return;
    end

    blk = modelName + "/Publish_CmdVel";
    try
        if getSimulinkBlockHandle(char(blk)) > 0
            set_param(char(blk), "Commented", "off");
        end
    catch
    end
end
