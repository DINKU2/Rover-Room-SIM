function results = ros_receive_sweep()
%ROS_RECEIVE_SWEEP  Exhaustive receive() diagnostics (loopback + shell pub).

    addpath(fileparts(mfilename('fullpath')));
    results = struct('name', {}, 'ok', {}, 'detail', {});

    tests = {
        @() test_bare_loopback()
        @() test_loopback_cyclonedds()
        @() test_loopback_besteffort()
        @() test_loopback_reliable()
        @() test_latest_message()
        @() test_callback()
        @() test_setup_ros_dds_loopback()
    };

    for i = 1:numel(tests)
        [name, ok, detail] = tests{i}();
        results(end+1) = struct('name', name, 'ok', ok, 'detail', detail); %#ok<AGROW>
        tag = ternary(ok, '[OK]', '[FAIL]');
        fprintf('%s %s — %s\n', tag, name, detail);
    end

    nok = sum([results.ok]);
    fprintf('\nSummary: %d/%d passed\n', nok, numel(results));
end

function [name, ok, detail] = test_bare_loopback()
    name = 'bare_loopback_fastrtps';
    ok = false;
    detail = '';
    setenv('ROS_DOMAIN_ID', '20');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    unsetenv('CYCLONEDDS_URI');
    setenv('RMW_IMPLEMENTATION', 'rmw_fastrtps_cpp');
    try
        n = ros2node('bare_loop');
        pause(2);
        p = ros2publisher(n, '/bare_loop', 'std_msgs/String');
        s = ros2subscriber(n, '/bare_loop', 'std_msgs/String');
        pause(2);
        m = ros2message(p);
        m.data = 'hi';
        send(p, m);
        pause(1);
        r = receive(s, 8);
        ok = ~isempty(r) && strcmp(r.data, 'hi');
        detail = char(r.data);
    catch ME
        detail = ME.message;
    end
end

function [name, ok, detail] = test_loopback_cyclonedds()
    name = 'loopback_cyclonedds';
    ok = false;
    detail = '';
    setenv('ROS_DOMAIN_ID', '20');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    unsetenv('CYCLONEDDS_URI');
    setenv('RMW_IMPLEMENTATION', 'rmw_cyclonedds_cpp');
    try
        rmw = ros.internal.ros2.RMWEnvironment();
        rmw.RMWImplementation = 'rmw_cyclonedds_cpp';
        rmw.saveRMWEnvironment();
    catch
    end
    try
        n = ros2node('cyc_loop', 'RMWImplementation', 'rmw_cyclonedds_cpp');
        pause(2);
        p = ros2publisher(n, '/cyc_loop', 'std_msgs/String', ...
            'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
        s = ros2subscriber(n, '/cyc_loop', 'std_msgs/String', ...
            'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
        pause(2);
        m = ros2message(p);
        m.data = 'cyc';
        send(p, m);
        pause(1);
        r = receive(s, 8);
        ok = ~isempty(r) && strcmp(r.data, 'cyc');
        detail = char(r.data);
    catch ME
        detail = ME.message;
    end
end

function [name, ok, detail] = test_loopback_besteffort()
    name = 'loopback_besteffort';
    ok = false;
    detail = '';
    setenv('ROS_DOMAIN_ID', '20');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    try
        n = ros2node('be_loop');
        pause(2);
        p = ros2publisher(n, '/be_loop', 'std_msgs/String', ...
            'Reliability', 'besteffort', 'Durability', 'volatile', 'Depth', 10);
        s = ros2subscriber(n, '/be_loop', 'std_msgs/String', ...
            'Reliability', 'besteffort', 'Durability', 'volatile', 'Depth', 10);
        pause(2);
        m = ros2message(p);
        m.data = 'be';
        send(p, m);
        pause(1);
        r = receive(s, 8);
        ok = ~isempty(r) && strcmp(r.data, 'be');
        detail = char(r.data);
    catch ME
        detail = ME.message;
    end
end

function [name, ok, detail] = test_loopback_reliable()
    name = 'loopback_reliable_explicit';
    ok = false;
    detail = '';
    setenv('ROS_DOMAIN_ID', '20');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    try
        n = ros2node('rel_loop');
        pause(2);
        p = ros2publisher(n, '/rel_loop', 'std_msgs/String', ...
            'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
        s = ros2subscriber(n, '/rel_loop', 'std_msgs/String', ...
            'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
        pause(2);
        for k = 1:5
            m = ros2message(p);
            m.data = sprintf('rel%d', k);
            send(p, m);
            pause(0.3);
        end
        r = receive(s, 8);
        ok = ~isempty(r);
        detail = char(r.data);
    catch ME
        detail = ME.message;
    end
end

function [name, ok, detail] = test_latest_message()
    name = 'latest_message_property';
    ok = false;
    detail = '';
    setenv('ROS_DOMAIN_ID', '20');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    try
        n = ros2node('lm_loop');
        pause(2);
        p = ros2publisher(n, '/lm_loop', 'std_msgs/String');
        s = ros2subscriber(n, '/lm_loop', 'std_msgs/String');
        pause(2);
        m = ros2message(p);
        m.data = 'lm';
        send(p, m);
        pause(3);
        if isprop(s, 'LatestMessage') && ~isempty(s.LatestMessage)
            ok = strcmp(s.LatestMessage.data, 'lm');
            detail = char(s.LatestMessage.data);
        else
            detail = 'LatestMessage empty or missing';
        end
    catch ME
        detail = ME.message;
    end
end

function [name, ok, detail] = test_callback()
    name = 'callback_subscriber';
    ok = false;
    detail = '';
    setenv('ROS_DOMAIN_ID', '20');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    got = false;
    cb = @(msg) assignin('base', 'sweep_cb_got', msg.data);
    try
        n = ros2node('cb_loop');
        pause(2);
        p = ros2publisher(n, '/cb_loop', 'std_msgs/String');
        s = ros2subscriber(n, '/cb_loop', 'std_msgs/String', @cb);
        pause(2);
        m = ros2message(p);
        m.data = 'cb';
        send(p, m);
        pause(5);
        if evalin('base', 'exist(''sweep_cb_got'',''var'')')
            v = evalin('base', 'sweep_cb_got');
            ok = strcmp(v, 'cb');
            detail = char(v);
        else
            detail = 'callback never fired';
        end
    catch ME
        detail = ME.message;
    end
end

function [name, ok, detail] = test_setup_ros_dds_loopback()
    name = 'setup_ros_dds_loopback';
    ok = false;
    detail = '';
    setup_ros_dds();
    try
        n = ros2node('xml_loop');
        pause(2);
        p = ros2publisher(n, '/xml_loop', 'std_msgs/String');
        s = ros2subscriber(n, '/xml_loop', 'std_msgs/String');
        pause(2);
        m = ros2message(p);
        m.data = 'xml';
        send(p, m);
        pause(1);
        r = receive(s, 8);
        ok = ~isempty(r) && strcmp(r.data, 'xml');
        detail = char(r.data);
    catch ME
        detail = ME.message;
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
