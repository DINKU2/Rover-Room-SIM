function ctx = simulink_dual_ros_init(action)
%SIMULINK_DUAL_ROS_INIT  Shared /odom + /scan + /cmd_vel for dual control.
%
%   Same receive pattern as ros_connect (LatestMessage via ros_sub_read).
%   Callback subscribers do NOT receive micro-ROS data in this stack.
%
%   ctx = simulink_dual_ros_init()        — create or reuse singleton
%   simulink_dual_ros_init('reset')       — clear on Simulink stop

    persistent rosCtx ready

    if isempty(ready)
        ready = false;
    end

    if nargin >= 1 && strcmpi(string(action), "reset")
        rosCtx = [];
        ready = false;
        ctx = [];
        return;
    end

    if isequal(ready, true) && ~isempty(rosCtx)
        ctx = rosCtx;
        return;
    end

    setup_rover_paths();
    ros_ensure_no_bridge();

    if ~check_robot_preflight(true)
        error('simulink_dual_ros_init:Preflight', ...
            ['Robot not ready (/odom + /scan must be live).\n' ...
             'Run: ./scripts/reset_robot_ros.sh  then power-cycle ESP32']);
    end

    setup_ros_humble();
    pause(1);

    ctx = struct();
    ctx.node = ros2node('rover_dual_control');
    pause(2);

    ctx.odomSub = robot_ros_subscriber(ctx.node, '/odom', 'nav_msgs/Odometry');
    ctx.scanSub = robot_ros_subscriber(ctx.node, '/scan', 'sensor_msgs/LaserScan');
    ctx.cmdPub = ros2publisher(ctx.node, '/cmd_vel', 'geometry_msgs/Twist', ...
        'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
    pause(2);

    odom = ros_sub_read(ctx.odomSub, 15);
    scan = ros_sub_read(ctx.scanSub, 15);

    if isempty(odom)
        error('simulink_dual_ros_init:NoOdom', ...
            ['No /odom in MATLAB within 15 s (shell check passed).\n' ...
             'Close other MATLAB/Simulink sessions and retry.']);
    end

    p = odom.pose.pose.position;
    fprintf('[dual_ros] /odom live x=%.3f y=%.3f\n', p.x, p.y);

    if isempty(scan)
        fprintf('[dual_ros] WARN: no /scan in 15 s — MCL overlay will wait for lidar\n');
    else
        fprintf('[dual_ros] /scan live (%d ranges)\n', numel(scan.ranges));
    end

    rosCtx = ctx;
    ready = true;
end
