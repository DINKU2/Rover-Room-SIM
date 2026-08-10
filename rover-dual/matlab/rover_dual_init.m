function rover_dual_init()
%ROVER_DUAL_INIT  Simulink InitFcn — paths, alignment check, Unreal PIE.

    rover_dual_ensure_paths();
    rover_dual_prepare();
    % Must run before simulation starts (Commented cannot change while running).
    rover_dual_disable_simulink_cmdvel_publish();
end
