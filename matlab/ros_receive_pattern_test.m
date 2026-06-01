function ok = ros_receive_pattern_test()
%ROS_RECEIVE_PATTERN_TEST  Distinguish receive() timing vs delivery failure.
%
%   Run shell publisher first:
%     source /opt/ros/humble/setup.bash
%     export ROS_DOMAIN_ID=20
%     ros2 topic pub /matlab_dds_test std_msgs/msg/String "{data: ping}" -r 10

    addpath(fileparts(mfilename('fullpath')));
    setenv('ROS_DOMAIN_ID', '20');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    setenv('RMW_IMPLEMENTATION', 'rmw_fastrtps_cpp');

    ok = false;
    fprintf('=== Pattern 1: receive() BEFORE send (loopback) ===\n');
    try
        n = ros2node('pat1');
        pause(2);
        p = ros2publisher(n, '/pat1', 'std_msgs/String');
        s = ros2subscriber(n, '/pat1', 'std_msgs/String');
        pause(2);
        % Start receive in background via timer-like loop: send AFTER receive starts
        t = timer('ExecutionMode', 'singleShot', 'StartDelay', 1, ...
            'TimerFcn', @(~,~) sendOne(p));
        start(t);
        try
            r = receive(s, 10);
            fprintf('[OK] receive-after-send-started: %s\n', r.data);
            ok = true;
        catch ME
            fprintf('[FAIL] receive: %s\n', ME.message);
            if isprop(s, 'LatestMessage') && ~isempty(s.LatestMessage)
                fprintf('  but LatestMessage=%s\n', s.LatestMessage.data);
            end
        end
        stop(t); delete(t);
    catch ME
        fprintf('[FAIL] setup: %s\n', ME.message);
    end

    fprintf('\n=== Pattern 2: LatestMessage poll (external /matlab_dds_test) ===\n');
    try
        n2 = ros2node('pat2');
        pause(2);
        s2 = ros2subscriber(n2, '/matlab_dds_test', 'std_msgs/String', ...
            'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
        pause(3);
        t0 = tic;
        got = '';
        while toc(t0) < 12
            if isprop(s2, 'LatestMessage') && ~isempty(s2.LatestMessage)
                got = char(s2.LatestMessage.data);
                break;
            end
            pause(0.2);
        end
        if ~isempty(got)
            fprintf('[OK] LatestMessage from external pub: %s\n', got);
            ok = true;
        else
            fprintf('[FAIL] LatestMessage empty after 12s (external pub may be off)\n');
        end
    catch ME
        fprintf('[FAIL] external LatestMessage: %s\n', ME.message);
    end

    fprintf('\n=== Pattern 3: receive() while external pub running ===\n');
    try
        n3 = ros2node('pat3');
        pause(2);
        s3 = ros2subscriber(n3, '/matlab_dds_test', 'std_msgs/String', ...
            'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
        pause(3);
        try
            r3 = receive(s3, 12);
            fprintf('[OK] receive from external: %s\n', r3.data);
            ok = true;
        catch ME
            fprintf('[FAIL] receive external: %s\n', ME.message);
            if isprop(s3, 'LatestMessage') && ~isempty(s3.LatestMessage)
                fprintf('  but LatestMessage=%s\n', s3.LatestMessage.data);
            end
        end
    catch ME
        fprintf('[FAIL] setup: %s\n', ME.message);
    end
end

function sendOne(p)
    m = ros2message(p);
    m.data = 'delayed';
    send(p, m);
end
