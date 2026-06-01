function y = simulink_teleop_lin(~)
%SIMULINK_TELEOP_LIN Return current linear command for Simulink teleop.

    state = getState();
    y = state.linSpeed * state.moveX;
end

function state = getState()
    if isappdata(groot, 'simulink_rover_teleop_state')
        state = getappdata(groot, 'simulink_rover_teleop_state');
    else
        state = struct('moveX', 0, 'moveTh', 0, 'linSpeed', 0.2, 'angSpeed', 1.0);
    end
end
