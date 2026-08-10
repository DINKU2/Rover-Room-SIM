function y = simulink_teleop_lin(~)
%SIMULINK_TELEOP_LIN Return current linear /cmd_vel command for Simulink teleop.

    t0 = tic;
    global SIMULINK_ROVER_TELEOP_STATE
    y = 0;
    if isempty(SIMULINK_ROVER_TELEOP_STATE) || ~isstruct(SIMULINK_ROVER_TELEOP_STATE)
        stage4_timing('record', 'slx.teleop_lin', toc(t0) * 1000);
        return;
    end
    y = SIMULINK_ROVER_TELEOP_STATE.linSpeed * SIMULINK_ROVER_TELEOP_STATE.moveX;
    stage4_timing('record', 'slx.teleop_lin', toc(t0) * 1000);
end
