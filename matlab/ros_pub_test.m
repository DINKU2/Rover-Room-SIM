function ok = ros_pub_test()
%ROS_PUB_TEST  Can MATLAB publish to system ROS 2?

    addpath(fileparts(mfilename('fullpath')));
    setup_ros_dds();
    ok = false;
    try
        n = ros2node('pub_test');
        pause(1);
        p = ros2publisher(n, '/matlab_pub_test', 'std_msgs/String');
        m = ros2message(p);
        m.data = 'hello_from_matlab';
        send(p, m);
        fprintf('[OK] sent one message on /matlab_pub_test\n');
        ok = true;
    catch ME
        fprintf('[FAIL] publish: %s\n', ME.message);
    end
end
