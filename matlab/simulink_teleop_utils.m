function varargout = simulink_teleop_utils(action, varargin)
%SIMULINK_TELEOP_UTILS Shared WASD teleop state for Simulink rover models.

    if nargin < 1
        action = 'get';
    end

    switch lower(string(action))
        case "default"
            varargout{1} = defaultState();
        case "get"
            varargout{1} = getState();
        case "set"
            setState(varargin{1});
        case "press"
            onPress(varargin{1});
        case "release"
            onRelease(varargin{1});
        case "stop"
            stopMotion();
        case "clear"
            clearState();
        case "linear"
            varargout{1} = cmdLinear(getState());
        case "angular"
            varargout{1} = cmdAngular(getState());
        case "command"
            state = getState();
            varargout{1} = [cmdLinear(state), cmdAngular(state)];
        otherwise
            error('simulink_teleop_utils:UnknownAction', 'Unknown action: %s', action);
    end
end

function onPress(key)
    key = normalizeKey(key);
    if strlength(key) == 0
        return;
    end

    state = getState();

    switch key
        case 'q'
            state.linSpeed = max(state.linSpeed * 0.9, 0.05);
            state.angSpeed = max(state.angSpeed * 0.9, 0.1);
        case 'e'
            state.linSpeed = min(state.linSpeed * 1.1, 1.0);
            state.angSpeed = min(state.angSpeed * 1.1, 5.0);
        case 'space'
            state.keys = defaultKeys();
            setState(recomputeMotion(state));
            teleop_log_stop('space');
            return;
        otherwise
            if isMovementKey(key)
                state.keys.(key) = true;
            else
                return;
            end
    end

    setState(recomputeMotion(state));
    if isMovementKey(key)
        teleop_log_key('press', key);
    end
end

function onRelease(key)
    key = normalizeKey(key);
    if ~isMovementKey(key)
        return;
    end

    state = getState();
    if isfield(state.keys, key)
        state.keys.(key) = false;
    end
    setState(recomputeMotion(state));
    teleop_log_key('release', key);
end

function stopMotion()
% Stop movement without resetting the user's selected speed.
    state = getState();
    state.keys = defaultKeys();
    setState(recomputeMotion(state));
end

function state = recomputeMotion(state)
    fwd = state.keys.w || state.keys.uparrow;
    back = state.keys.s || state.keys.downarrow;
    left = state.keys.a || state.keys.leftarrow;
    right = state.keys.d || state.keys.rightarrow;

    if fwd && ~back
        state.moveX = 1;
    elseif back && ~fwd
        state.moveX = -1;
    else
        state.moveX = 0;
    end

    if left && ~right
        state.moveTh = 1;
    elseif right && ~left
        state.moveTh = -1;
    else
        state.moveTh = 0;
    end
end

function y = cmdLinear(state)
    y = state.linSpeed * state.moveX;
end

function y = cmdAngular(state)
    y = state.angSpeed * state.moveTh;
end

function state = defaultState()
    state = struct();
    state.keys = defaultKeys();
    state.moveX = 0;
    state.moveTh = 0;
    state.linSpeed = 0.2;
    state.angSpeed = 1.0;
end

function keys = defaultKeys()
    keys = struct( ...
        'w', false, 'a', false, 's', false, 'd', false, ...
        'uparrow', false, 'downarrow', false, 'leftarrow', false, 'rightarrow', false);
end

function clearState()
    global SIMULINK_ROVER_TELEOP_STATE
    SIMULINK_ROVER_TELEOP_STATE = defaultState();
end

function setState(state)
    global SIMULINK_ROVER_TELEOP_STATE
    SIMULINK_ROVER_TELEOP_STATE = state;
end

function state = getState()
    global SIMULINK_ROVER_TELEOP_STATE
    if isempty(SIMULINK_ROVER_TELEOP_STATE)
        SIMULINK_ROVER_TELEOP_STATE = defaultState();
    end
    state = SIMULINK_ROVER_TELEOP_STATE;
end

function tf = isMovementKey(k)
    tf = any(strcmp(k, {'w', 'a', 's', 'd', ...
        'uparrow', 'downarrow', 'leftarrow', 'rightarrow'}));
end

function k = normalizeKey(key)
    if isstring(key)
        key = char(key);
    end
    if isempty(key)
        k = '';
        return;
    end
    k = lower(char(string(key)));
end

function teleop_log_key(kind, key)
    if exist('teleop_timing', 'file') ~= 2
        return;
    end
    try
        teleop_timing('key', kind, key);
    catch
    end
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
