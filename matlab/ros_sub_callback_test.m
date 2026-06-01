function ok = ros_sub_callback_test()
%ROS_SUB_CALLBACK_TEST  Subscribe via callback instead of receive().

    addpath(fileparts(mfilename('fullpath')));
    setup_ros_dds();
    ok = false;
    got = false;
    cb = @(~, msg) storeMsg(msg);

    function storeMsg(msg)
        assignin('base', 'ros_cb_msg', msg);
        got = true;
    end

    n = ros2node('cb_test');
    pause(1);
    s = ros2subscriber(n, '/matlab_dds_test', 'std_msgs/String', cb);
    fprintf('Waiting 12s for callback...\n');
    t0 = tic;
    while ~got && toc(t0) < 12
        pause(0.2);
    end
    if got
        m = evalin('base', 'ros_cb_msg');
        fprintf('[OK] callback data=%s\n', m.data);
        ok = true;
    else
        fprintf('[FAIL] no callback\n');
    end
end
