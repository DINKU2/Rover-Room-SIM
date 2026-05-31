function msg = receive_odom(node, timeoutSec)
%RECEIVE_ODOM  Receive one /odom sample (reliable, then best-effort).

    msg = [];
    try
        sub = robot_ros_subscriber(node, '/odom', 'nav_msgs/Odometry');
        msg = receive(sub, timeoutSec);
        if ~isempty(msg), return; end
    catch
    end
    try
        sub = ros2subscriber(node, '/odom', 'nav_msgs/Odometry', ...
            'Reliability', 'besteffort', 'Durability', 'volatile', 'Depth', 10);
        msg = receive(sub, timeoutSec);
    catch
    end
end
