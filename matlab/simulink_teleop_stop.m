function simulink_teleop_stop()
%SIMULINK_TELEOP_STOP Reset teleop state and close the helper figure.

    if isappdata(groot, 'simulink_rover_teleop_state')
        rmappdata(groot, 'simulink_rover_teleop_state');
    end

    fig = findall(groot, 'Type', 'figure', 'Tag', 'simulink_rover_teleop');
    if ~isempty(fig)
        delete(fig);
    end
end
