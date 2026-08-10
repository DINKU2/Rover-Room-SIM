function simulink_teleop_start(asyncRos)
%SIMULINK_TELEOP_START Open WASD teleop figure for rover_ros_io.
%
%   simulink_teleop_start()       — keyboard only (Simulink publishes /cmd_vel)
%   simulink_teleop_start(true)   — async /cmd_vel at 20 Hz (rover_dual_control)

    if nargin < 1
        asyncRos = false;
    end

    fig = findall(groot, 'Type', 'figure', 'Tag', 'simulink_rover_teleop');
    if ~isempty(fig) && isvalid(fig(1))
        figure(fig(1));
        % Never carry pressed-key state across model restarts.
        simulink_teleop_utils('clear');
        setappdata(fig(1), 'simulink_rover_teleop_async_ros', logical(asyncRos));
        if asyncRos && ~simulink_teleop_ros('is_running')
            simulink_teleop_ros('start');
        elseif ~asyncRos && simulink_teleop_ros('is_running')
            simulink_teleop_ros('stop');
        end
        publishIfAsync(fig(1));
        refreshUi(fig(1));
        return;
    end

    simulink_teleop_utils('clear');

    fig = figure( ...
        'Name', 'Simulink Rover Teleop', ...
        'Tag', 'simulink_rover_teleop', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'HandleVisibility', 'callback', ...
        'CloseRequestFcn', @onClose, ...
        'WindowKeyPressFcn', @onKeyPress, ...
        'WindowKeyReleaseFcn', @onKeyRelease, ...
        'Position', [100 100 500 190]);
    if isprop(fig, 'WindowFocusLostFcn')
        set(fig, 'WindowFocusLostFcn', @onFocusLost);
    end

    msg = [ ...
        "Click this window and keep it focused while driving:", newline, ...
        "W forward   S back   A turn left   D turn right", newline, ...
        "Arrow keys same as WASD   Space stop", newline, ...
        "Q slower   E faster" ...
    ];
    uicontrol(fig, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.30 0.9 0.55], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 11, ...
        'Enable', 'inactive', ...
        'String', msg);

    uicontrol(fig, ...
        'Style', 'text', ...
        'Tag', 'speed_label', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.08 0.9 0.14], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Enable', 'inactive', ...
        'String', speedText(simulink_teleop_utils('get')));

    uicontrol(fig, ...
        'Style', 'text', ...
        'Tag', 'cmd_label', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.01 0.9 0.08], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Enable', 'inactive', ...
        'String', cmdText());

    refreshTimer = timer( ...
        'ExecutionMode', 'fixedRate', ...
        'Period', 0.05, ...
        'BusyMode', 'drop', ...
        'TimerFcn', @(~, ~) refreshUi(fig), ...
        'ErrorFcn', @(~, ~) []);
    start(refreshTimer);
    setappdata(fig, 'simulink_rover_teleop_timer', refreshTimer);
    setappdata(fig, 'simulink_rover_teleop_async_ros', logical(asyncRos));

    if asyncRos
        simulink_teleop_ros('start');
    end

    figure(fig);
end

function onKeyPress(fig, ev)
    key = normalizeEventKey(ev);
    if strlength(key) == 0
        return;
    end
    simulink_teleop_utils('press', key);
    publishIfAsync(fig);
    refreshUi(fig);
end

function onKeyRelease(fig, ev)
    key = normalizeEventKey(ev);
    if strlength(key) == 0
        return;
    end
    simulink_teleop_utils('release', key);
    publishIfAsync(fig);
    refreshUi(fig);
end

function onFocusLost(fig, ~)
    stopAndPublish(fig, 'focus_lost');
end

function onClose(fig, ~)
    stopAndPublish(fig, 'close');
    stopTeleopTimer(fig);
    if isAsyncRos(fig)
        simulink_teleop_ros('stop');
    end
    simulink_teleop_utils('clear');
    delete(fig);
end

function publishIfAsync(fig)
    if isAsyncRos(fig)
        simulink_teleop_ros('publish_now');
    end
end

function tf = isAsyncRos(fig)
    tf = ishandle(fig) ...
        && isappdata(fig, 'simulink_rover_teleop_async_ros') ...
        && logical(getappdata(fig, 'simulink_rover_teleop_async_ros'));
end

function refreshUi(fig)
    if ~ishandle(fig)
        return;
    end
    state = simulink_teleop_utils('get');
    speedH = findall(fig, 'Tag', 'speed_label');
    if ~isempty(speedH) && isgraphics(speedH(1))
        set(speedH(1), 'String', speedText(state));
    end
    cmdH = findall(fig, 'Tag', 'cmd_label');
    if ~isempty(cmdH) && isgraphics(cmdH(1))
        set(cmdH(1), 'String', cmdText());
    end
end

function stopAndPublish(fig, reason)
    if nargin < 2
        reason = 'manual';
    end
    simulink_teleop_utils('stop');
    teleop_log_stop(reason);
    publishIfAsync(fig);
end

function teleop_log_stop(reason)
    if exist('teleop_timing', 'file') ~= 2
        return;
    end
    try
        teleop_timing('stop', reason);
    catch
    end
end

function stopTeleopTimer(fig)
    if ishandle(fig) && isappdata(fig, 'simulink_rover_teleop_timer')
        t = getappdata(fig, 'simulink_rover_teleop_timer');
        if isa(t, 'timer') && isvalid(t)
            try
                stop(t);
            catch
            end
            delete(t);
        end
        rmappdata(fig, 'simulink_rover_teleop_timer');
    end
end

function txt = speedText(state)
    txt = sprintf('Speed: linear %.2f m/s   angular %.2f rad/s', ...
        state.linSpeed, state.angSpeed);
end

function txt = cmdText()
    txt = sprintf('Command: vx=%+.2f   wz=%+.2f', ...
        simulink_teleop_utils('linear'), simulink_teleop_utils('angular'));
end

function k = normalizeEventKey(ev)
    k = ev.Key;
    if isempty(k) || strcmp(k, 'undefined')
        k = ev.Character;
    end
    k = char(string(k));
end
