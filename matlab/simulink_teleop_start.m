function simulink_teleop_start()
%SIMULINK_TELEOP_START Open a small teleop figure for rover_ros_io.slx.

    fig = findall(groot, 'Type', 'figure', 'Tag', 'simulink_rover_teleop');
    if ~isempty(fig) && isvalid(fig(1))
        figure(fig(1));
        return;
    end

    state = defaultState();
    setappdata(groot, 'simulink_rover_teleop_state', state);

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
        'Position', [100 100 460 160]);

    msg = [ ...
        "Click here, then hold keys to drive:", newline, ...
        "i forward   , / s / k back   j left   l right", newline, ...
        "u o m . diagonals   space stop   q faster   w slower" ...
    ];
    uicontrol(fig, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.28 0.9 0.6], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 11, ...
        'String', msg);

    uicontrol(fig, ...
        'Style', 'text', ...
        'Tag', 'speed_label', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.08 0.9 0.12], ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'String', speedText(state));

    figure(fig);
end

function onKeyPress(fig, ev)
    state = getState();
    k = normalizeKey(ev);
    switch k
        case {'i', 'uparrow'}
            state.moveX = 1;  state.moveTh = 0;
        case {',', 's', 'k', 'downarrow'}
            state.moveX = -1; state.moveTh = 0;
        case {'j', 'leftarrow'}
            state.moveX = 0;  state.moveTh = 1;
        case {'l', 'rightarrow'}
            state.moveX = 0;  state.moveTh = -1;
        case 'u'
            state.moveX = 1;  state.moveTh = 1;
        case 'o'
            state.moveX = 1;  state.moveTh = -1;
        case 'm'
            state.moveX = -1; state.moveTh = -1;
        case '.'
            state.moveX = -1; state.moveTh = 1;
        case 'space'
            state.moveX = 0;  state.moveTh = 0;
        case 'q'
            state.linSpeed = min(state.linSpeed * 1.1, 1.0);
            state.angSpeed = min(state.angSpeed * 1.1, 5.0);
        case 'w'
            state.linSpeed = state.linSpeed * 0.9;
            state.angSpeed = state.angSpeed * 0.9;
        otherwise
            return;
    end
    setState(state);
    updateLabel(fig, state);
end

function onKeyRelease(fig, ev)
    state = getState();
    if isMovementKey(normalizeKey(ev))
        state.moveX = 0;
        state.moveTh = 0;
        setState(state);
        updateLabel(fig, state);
    end
end

function onClose(fig, ~)
    setState(defaultState());
    delete(fig);
end

function updateLabel(fig, state)
    h = findall(fig, 'Tag', 'speed_label');
    if ~isempty(h) && isgraphics(h)
        set(h, 'String', speedText(state));
    end
end

function txt = speedText(state)
    txt = sprintf('Current speed: linear %.2f m/s   angular %.2f rad/s', ...
        state.linSpeed, state.angSpeed);
end

function state = defaultState()
    state = struct('moveX', 0, 'moveTh', 0, 'linSpeed', 0.2, 'angSpeed', 1.0);
end

function tf = isMovementKey(k)
    tf = any(strcmp(k, {'i', 'j', 'l', 'u', 'o', 'm', ',', 's', 'k', '.', ...
        'uparrow', 'downarrow', 'leftarrow', 'rightarrow'}));
end

function k = normalizeKey(ev)
    k = ev.Key;
    if isempty(k) || strcmp(k, 'undefined')
        k = ev.Character;
    end
    if strcmp(k, 'comma'), k = ','; end
    if strcmp(k, 'period'), k = '.'; end
    k = lower(string(k));
    k = char(k);
end

function state = getState()
    if isappdata(groot, 'simulink_rover_teleop_state')
        state = getappdata(groot, 'simulink_rover_teleop_state');
    else
        state = defaultState();
    end
end

function setState(state)
    setappdata(groot, 'simulink_rover_teleop_state', state);
end
