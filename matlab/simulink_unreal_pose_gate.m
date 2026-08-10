function y = simulink_unreal_pose_gate(u)
%SIMULINK_UNREAL_POSE_GATE  Deadband + burst/cooldown before Set_RoverTwin.

    persistent lastSent state stateEnterT initDone
    t0 = tic;

    if strcmp(getenv('STAGE4_GATE'), '0')
        y = u(:);
        stage4_timing('record', 'slx.pose_gate', toc(t0) * 1000);
        return;
    end

    [posThresh, yawThresh, burstSec, cooldownSec] = gate_thresholds();

    if isempty(initDone)
        initDone = true;
        state = 'hold';
        stateEnterT = tic;
        lastSent = [];
    end

    if numel(u) < 4 || any(~isfinite(u(1:4)))
        y = gate_fallback(lastSent);
        stage4_timing('record', 'slx.pose_gate', toc(t0) * 1000);
        return;
    end

    target = u(1:4);

    if isempty(lastSent)
        lastSent = target;
        y = target;
        gate_debug('init', target, target, 'hold');
        stage4_timing('record', 'slx.pose_gate', toc(t0) * 1000);
        return;
    end

    [posErr, yawErr] = gate_pose_error(lastSent, target);

    switch state
        case 'hold'
            if posErr > posThresh || yawErr > yawThresh
                state = 'burst';
                stateEnterT = tic;
                lastSent = target;
                y = target;
                gate_debug('burst_start', lastSent, target, state);
            else
                y = lastSent;
            end

        case 'burst'
            lastSent = target;
            y = target;
            if toc(stateEnterT) >= burstSec
                state = 'cooldown';
                stateEnterT = tic;
                gate_debug('cooldown_start', lastSent, target, state);
            end

        case 'cooldown'
            y = lastSent;
            if posErr > 2 * posThresh || yawErr > 2 * yawThresh
                state = 'burst';
                stateEnterT = tic;
                lastSent = target;
                y = target;
                gate_debug('burst_emergency', lastSent, target, state);
            elseif toc(stateEnterT) >= cooldownSec
                state = 'hold';
                stateEnterT = tic;
                gate_debug('hold', lastSent, target, state);
            end

        otherwise
            state = 'hold';
            stateEnterT = tic;
            y = lastSent;
    end
    stage4_timing('record', 'slx.pose_gate', toc(t0) * 1000);
end

function [posThresh, yawThresh, burstSec, cooldownSec] = gate_thresholds()
    posThresh = gate_env_float('STAGE4_GATE_POS_M', 0.05);
    yawThresh = gate_env_float('STAGE4_GATE_YAW_RAD', 0.08);
    burstSec = gate_env_float('STAGE4_GATE_BURST_SEC', 0.8);
    cooldownSec = gate_env_float('STAGE4_GATE_COOLDOWN_SEC', 1.5);
end

function v = gate_env_float(name, defaultVal)
    raw = getenv(name);
    if isempty(raw)
        v = defaultVal;
        return;
    end
    v = str2double(raw);
    if ~isfinite(v) || v < 0
        v = defaultVal;
    end
end

function [posErr, yawErr] = gate_pose_error(a, b)
    posErr = hypot(b(1) - a(1), b(2) - a(2));
    yawErr = abs(gate_wrap_to_pi(b(4) - a(4)));
end

function a = gate_wrap_to_pi(a)
    a = mod(a + pi, 2 * pi) - pi;
end

function y = gate_fallback(lastSent)
    if isempty(lastSent)
        setup_rover_paths();
        spawn = rover_spawn_pose();
        cfg = rover_cmd_vel_config();
        y = [spawn.sim_m(1); spawn.sim_m(2); spawn.sim_m(3); ...
            cfg.mesh_yaw_sign * deg2rad(spawn.yaw_deg + cfg.mesh_yaw_offset_deg)];
    else
        y = lastSent;
    end
end

function gate_debug(event, sent, target, stateName)
    [posErr, yawErr] = gate_pose_error(sent, target);
    simulink_stage4_debug('gate', struct( ...
        'event', event, ...
        'state', stateName, ...
        'posErr_m', posErr, ...
        'yawErr_rad', yawErr, ...
        'sent_x', sent(1), ...
        'sent_y', sent(2), ...
        'tgt_x', target(1), ...
        'tgt_y', target(2)));
end
