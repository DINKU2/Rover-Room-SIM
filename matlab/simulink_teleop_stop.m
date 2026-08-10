function simulink_teleop_stop()
%SIMULINK_TELEOP_STOP Reset teleop state and close the helper figure.

    if exist('simulink_teleop_ros', 'file') == 2
        try
            simulink_teleop_ros('stop');
        catch
        end
    end
    simulink_teleop_utils('clear');
    if exist('teleop_timing', 'file') == 2
        teleop_timing('flush');
    end

    fig = findall(groot, 'Type', 'figure', 'Tag', 'simulink_rover_teleop');
    for i = 1:numel(fig)
        if isvalid(fig(i))
            if isappdata(fig(i), 'simulink_rover_teleop_timer')
                t = getappdata(fig(i), 'simulink_rover_teleop_timer');
                if isa(t, 'timer') && isvalid(t)
                    try
                        stop(t);
                    catch
                    end
                    delete(t);
                end
            end
            delete(fig(i));
        end
    end
end
