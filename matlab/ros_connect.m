function ctx = ros_connect(nodeName)
%ROS_CONNECT  Native ROS 2 Humble DDS (MATLAB R2024b + robot stack).
%
%   ctx = ros_connect()
%   odom = ros_receive(ctx, 'odom', 10);
%   scan = ros_receive(ctx, 'scan', 10);
%   ros_cmd_vel(ctx, 0.2, 0);
%
%   Launch with R2024b:
%     ./scripts/matlab_r2024b.sh
%   or from shell batch:
%     ./scripts/matlab_r2024b.sh -batch "cd('.../matlab'); ros_test"

    if nargin < 1 || strlength(string(nodeName)) == 0
        nodeName = "rover_room_sim";
    end

    addpath(fileparts(mfilename('fullpath')));

    if ~check_robot_preflight()
        error('ros_connect:Preflight', ...
            'Robot not ready. Run ./scripts/start_agent.sh && ./scripts/check_robot.sh');
    end

    ros_ensure_no_bridge();
    setup_ros_humble();
    pause(1);

    ctx = struct();
    ctx.mode = 'dds';
    ctx.node = ros2node(nodeName);
    pause(2);

    ctx.odomSub = robot_ros_subscriber(ctx.node, '/odom', 'nav_msgs/Odometry');
    ctx.scanSub = robot_ros_subscriber(ctx.node, '/scan', 'sensor_msgs/LaserScan');
    ctx.cmdPub = ros2publisher(ctx.node, '/cmd_vel', 'geometry_msgs/Twist', ...
        'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
    pause(2);

    odom = ros_sub_read(ctx.odomSub, 15);
    if isempty(odom)
        error('ros_connect:NoOdom', ...
            'No /odom in MATLAB within 15 s (shell check passed). Power-cycle robot or restart agent.');
    end

    p = odom.pose.pose.position;
    fprintf('ROS connected (native Humble DDS):\n');
    fprintf('  /odom  live  x=%.3f y=%.3f\n', p.x, p.y);
    fprintf('  /scan  subscribed (best-effort)\n');
    fprintf('  /cmd_vel publisher ready\n');
end
