function msg = receive_odom(node, timeoutSec)
%RECEIVE_ODOM  Read one /odom sample (reliable QoS, then best-effort).

    if nargin < 2, timeoutSec = 10; end
    addpath(fileparts(mfilename('fullpath')));

    msg = [];
    try
        sub = robot_ros_subscriber(node, '/odom', 'nav_msgs/Odometry');
        msg = ros_sub_read(sub, timeoutSec);
        if ~isempty(msg), return; end
    catch
    end
    try
        sub = ros2subscriber(node, '/odom', 'nav_msgs/Odometry', ...
            'Reliability', 'besteffort', 'Durability', 'volatile', 'Depth', 10);
        msg = ros_sub_read(sub, timeoutSec);
    catch
    end
end
