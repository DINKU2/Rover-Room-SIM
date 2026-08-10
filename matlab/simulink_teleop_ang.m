function y = simulink_teleop_ang(~)
%SIMULINK_TELEOP_ANG Return current angular /cmd_vel command for Simulink teleop.

    t0 = tic;
    global SIMULINK_ROVER_TELEOP_STATE
    y = 0;
    if isempty(SIMULINK_ROVER_TELEOP_STATE) || ~isstruct(SIMULINK_ROVER_TELEOP_STATE)
        stage4_timing('record', 'slx.teleop_ang', toc(t0) * 1000);
        return;
    end
    y = SIMULINK_ROVER_TELEOP_STATE.angSpeed * SIMULINK_ROVER_TELEOP_STATE.moveTh;
    stage4_timing('record', 'slx.teleop_ang', toc(t0) * 1000);
end
