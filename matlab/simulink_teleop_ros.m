function out = simulink_teleop_ros(action)
%SIMULINK_TELEOP_ROS  Async /cmd_vel publisher decoupled from Simulink steps.
%
%   Reuses simulink_dual_ros_init().cmdPub (same node as /odom + /scan MCL).
%   Does not subscribe or touch lidar — publish-only on /cmd_vel.
%
%   simulink_teleop_ros('start')        — 20 Hz timer + keypress publish_now
%   simulink_teleop_ros('stop')         — stop timer, publish zero
%   simulink_teleop_ros('publish_now')  — immediate publish from teleop state
%   tf = simulink_teleop_ros('is_running')

    persistent pubTimer odomTimer

    if nargin < 1 || strlength(string(action)) == 0
        action = "is_running";
    end

    switch lower(string(action))
        case "start"
            stopTimer(pubTimer);
            stopTimer(odomTimer);
            pubTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.05, ...
                'BusyMode', 'drop', ...
                'TimerFcn', @onTimerTick, ...
                'ErrorFcn', @(~, ~) []);
            odomTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.1, ...
                'BusyMode', 'drop', ...
                'TimerFcn', @onOdomTick, ...
                'ErrorFcn', @(~, ~) []);
            start(pubTimer);
            start(odomTimer);
            setappdata(0, 'simulinkTeleopRosTimer', pubTimer);
            setappdata(0, 'simulinkTeleopOdomTimer', odomTimer);
            fprintf('[teleop_ros] Async /cmd_vel at 20 Hz (decoupled from Simulink)\n');
            out = true;

        case "stop"
            stopTimer(pubTimer);
            stopTimer(odomTimer);
            pubTimer = [];
            odomTimer = [];
            if isappdata(0, 'simulinkTeleopRosTimer')
                rmappdata(0, 'simulinkTeleopRosTimer');
            end
            if isappdata(0, 'simulinkTeleopOdomTimer')
                rmappdata(0, 'simulinkTeleopOdomTimer');
            end
            publishZero('stop');
            out = false;

        case "publish_now"
            publishNow('key');
            out = true;

        otherwise
            if strcmpi(string(action), "is_running")
                out = ~isempty(pubTimer) && isvalid(pubTimer) ...
                    && strcmpi(pubTimer.Running, 'on');
            else
                error('simulink_teleop_ros:BadAction', 'Unknown action: %s', action);
            end
    end
end

function onTimerTick(~, ~)
    publishNow('timer');
end

function onOdomTick(~, ~)
    if exist('teleop_timing', 'file') ~= 2
        return;
    end
    persistent lastJitterLog
    try
        ctx = simulink_dual_ros_init();
        odom = ros_sub_read(ctx.odomSub, 0);
        if isempty(odom)
            return;
        end
        odomVx = odom.twist.twist.linear.x;
        odomWz = odom.twist.twist.angular.z;
        cmd = simulink_teleop_utils('command');
        teleop_timing('odom', odomVx, odomWz, cmd(1), cmd(2));
    catch ME
        if isempty(lastJitterLog) || toc(lastJitterLog) > 2
            lastJitterLog = tic;
            teleop_timing('fail', 'odom_poll', ME.message);
        end
    end
end

function publishNow(src)
    t0 = tic;
    src = char(string(src));
    try
        ctx = simulink_dual_ros_init();
        vx = simulink_teleop_utils('linear');
        wz = simulink_teleop_utils('angular');
        ros_cmd_vel(ctx, vx, wz);
        ms = toc(t0) * 1000;
        if exist('stage4_timing', 'file') == 2
            stage4_timing('record', 'teleop_ros.publish', ms);
        end
        if exist('teleop_timing', 'file') == 2
            teleop_timing('publish', vx, wz, ms, src);
        end
    catch ME
        ms = toc(t0) * 1000;
        if exist('stage4_timing', 'file') == 2
            stage4_timing('record', 'teleop_ros.publish', ms);
        end
        if exist('teleop_timing', 'file') == 2
            teleop_timing('fail', 'publish', ME.message);
        end
        persistent lastWarn
        msg = ME.message;
        if isempty(lastWarn) || ~strcmp(lastWarn, msg)
            lastWarn = msg;
            fprintf('[teleop_ros] publish skipped: %s\n', msg);
        end
    end
end

function publishZero(src)
    if nargin < 1
        src = 'stop';
    end
    t0 = tic;
    try
        ctx = simulink_dual_ros_init();
        ros_cmd_vel(ctx, 0, 0);
        ms = toc(t0) * 1000;
        if exist('teleop_timing', 'file') == 2
            teleop_timing('publish', 0, 0, ms, src);
        end
    catch ME
        if exist('teleop_timing', 'file') == 2
            teleop_timing('fail', 'publish_zero', ME.message);
        end
    end
end

function stopTimer(t)
    if ~isempty(t) && isvalid(t)
        try
            stop(t);
            delete(t);
        catch
        end
    end
    for appName = {'simulinkTeleopRosTimer', 'simulinkTeleopOdomTimer'}
        stale = getappdata(0, appName{1});
        if ~isempty(stale) && isvalid(stale)
            try
                stop(stale);
                delete(stale);
            catch
            end
            if isappdata(0, appName{1})
                rmappdata(0, appName{1});
            end
        end
    end
end
