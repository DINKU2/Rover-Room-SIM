function ok = ros_odom_mock_test()
%ROS_ODOM_MOCK_TEST  Verify DDS subscribe for nav_msgs/Odometry (Humble pub).
    setenv('ROS_DOMAIN_ID', '20');
    ok = false;
    n = ros2node('odom_test');
    pause(3);
    s = ros2subscriber(n, '/odom', 'nav_msgs/Odometry', ...
        'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
    pause(3);
    t0 = tic;
    while toc(t0) < 10
        if ~isempty(s.LatestMessage)
            m = s.LatestMessage;
            fprintf('[OK] LatestMessage odom x=%.2f y=%.2f\n', ...
                m.pose.pose.position.x, m.pose.pose.position.y);
            ok = true;
            break;
        end
        pause(0.2);
    end
    if ~ok
        fprintf('[FAIL] no LatestMessage on /odom\n');
        return;
    end
    try
        r = receive(s, 5);
        fprintf('[OK] receive odom x=%.2f\n', r.pose.pose.position.x);
    catch ME
        fprintf('[WARN] receive after LatestMessage: %s\n', ME.message);
    end
end
