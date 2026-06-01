function ok = ros_loopback_test()
%ROS_LOOPBACK_TEST  Same-node publisher -> subscriber.
%
%   Demonstrates receive() vs LatestMessage:
%     send-then-receive  -> FAIL (receive waits for NEW messages only)
%     receive-then-send  -> OK
%     ros_sub_read       -> OK (polls LatestMessage)

    addpath(fileparts(mfilename('fullpath')));
    setup_ros_humble();
    ok = false;

    n = ros2node('loop_one');
    pause(2);
    p = ros2publisher(n, '/matlab_loop_test', 'std_msgs/String');
    s = ros2subscriber(n, '/matlab_loop_test', 'std_msgs/String');
    pause(2);

    m = ros2message(p);
    m.data = 'loopback';
    send(p, m);
    pause(0.5);
    try
        receive(s, 2);
        fprintf('[WARN] send-then-receive unexpectedly succeeded\n');
    catch
        fprintf('[OK] send-then-receive fails as expected (use LatestMessage)\n');
    end

    r = ros_sub_read(s, 3);
    if ~isempty(r) && strcmp(r.data, 'loopback')
        fprintf('[OK] ros_sub_read after send: %s\n', r.data);
        ok = true;
    end

    p2 = ros2publisher(n, '/matlab_loop_test2', 'std_msgs/String');
    s2 = ros2subscriber(n, '/matlab_loop_test2', 'std_msgs/String');
    pause(1);
    t = timer('ExecutionMode', 'singleShot', 'StartDelay', 1, ...
        'TimerFcn', @(~,~) sendLoop(p2));
    start(t);
    try
        r2 = receive(s2, 8);
        if strcmp(r2.data, 'delayed')
            fprintf('[OK] receive-then-send: %s\n', r2.data);
            ok = true;
        end
    catch ME
        fprintf('[FAIL] receive-then-send: %s\n', ME.message);
    end
    stop(t); delete(t);
end

function sendLoop(p)
    m = ros2message(p);
    m.data = 'delayed';
    send(p, m);
end
