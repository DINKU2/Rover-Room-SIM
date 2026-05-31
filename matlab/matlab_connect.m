function matlab_connect()
%MATLAB_CONNECT  Live Yahboom micro-ROS robot in MATLAB (native Linux DDS).
%
% Controls (same as ./scripts/run_teleop.sh):
%   i / ,     forward / back
%   j / l     turn left / right
%   u o m .   diagonals
%   space     stop
%   q / z     faster / slower
%   Q         quit
%
% Prereq: ./scripts/start_agent.sh  &&  ./scripts/check_robot.sh OK
% Do not run ./scripts/run_teleop.sh while MATLAB publishes /cmd_vel.

    cfg = prepare_robot_assets();
    setup_ros_dds();

    fprintf('Robot preflight (shell)...\n');
    if ~check_robot_preflight()
        error('matlab_connect:Preflight', ...
            ['Robot not ready.\n' ...
             '  source ./setup.bash\n' ...
             '  ./scripts/start_agent.sh\n' ...
             '  power-cycle robot, ./scripts/check_robot.sh']);
    end

    oldDir = pwd;
    cleanupObj = onCleanup(@() cd(oldDir)); %#ok<NASGU>
    cd(cfg.matlabDir);

    % Connect DDS before URDF — same order as matlab_ros_test (which works).
    node = ros2node('matlab_yahboom');
    fprintf('Waiting for live /odom in MATLAB (DDS)...\n');
    pause(2);
    try
        wait_for_odom_dds(node, 45);
    catch ME
        error('matlab_connect:DdsTimeout', ...
            ['MATLAB cannot receive /odom (shell check passed).\n' ...
             '  1. Agent may have crashed on /scan — docker logs micro_ros_udp_agent\n' ...
             '  2. ./scripts/start_agent.sh  then power-cycle robot\n' ...
             '  3. matlab_ros_test must pass before matlab_connect\n' ...
             'Original: %s'], ME.message);
    end

    fprintf('Loading URDF: %s\n', cfg.urdfPath);
    robot = importrobot(cfg.urdfPath);
    robot.DataFormat = 'row';

    odomSub = robot_ros_subscriber(node, '/odom', 'nav_msgs/Odometry');
    scanSub = robot_ros_subscriber(node, '/scan', 'sensor_msgs/LaserScan');
    if ~waitForTopicOptional(scanSub, 10)
        fprintf('[WARN] No /scan yet — map may be empty; teleop still works.\n');
    end
    fprintf('Connected.\n');

    cmdPub = ros2publisher(node, '/cmd_vel', 'geometry_msgs/Twist', ...
        'Reliability', 'reliable', 'Depth', 10);

    fig = figure('Name', 'Yahboom micro-ROS - MATLAB', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none');
    axMap = subplot(1, 2, 1);
    title(axMap, 'Map view (odom + lidar)');
    xlabel(axMap, 'x [m]'); ylabel(axMap, 'y [m]');
    axis(axMap, 'equal'); grid(axMap, 'on'); hold(axMap, 'on');

    axRobot = subplot(1, 2, 2);
    title(axRobot, 'URDF model');
    show(robot, homeConfiguration(robot), 'Parent', axRobot, 'Frames', 'off');
    view(axRobot, 3); axis(axRobot, 'equal'); grid(axRobot, 'on');

    helpStr = ['Keys (teleop):  i=fwd  ,=back  j/l=turn  uom.=diag  ' ...
        'space=stop  q/w=speed up/down  z=quit'];
    uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.02 0.01 0.96 0.04], ...
        'String', helpStr, 'HorizontalAlignment', 'left', 'BackgroundColor', get(fig, 'Color'));

    scanLine = plot(axMap, nan, nan, 'b.', 'MarkerSize', 4);
    poseLine = plot(axMap, nan, nan, 'r-', 'LineWidth', 1.5);
    posePt   = plot(axMap, 0, 0, 'ro', 'MarkerFaceColor', 'r');
    trailX = [];
    trailY = [];

    % Teleop state (matches teleop/teleop_keyboard.py defaults)
    linSpeed = 0.2;
    angSpeed = 1.0;
    moveX = 0;
    moveTh = 0;
    running = true;
    lastScan = [];
    lastOdom = [];
    lastYaw = 0;
    lastSentMoving = false;

    fig.WindowKeyPressFcn = @onKey;
    fig.WindowKeyReleaseFcn = @onKeyRelease;
    fig.CloseRequestFcn = @(~, ~) stopAndClose();

    timerObj = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, ...
        'TimerFcn', @(~, ~) controlLoop());
    start(timerObj);

    fprintf('%s\n', helpStr);
    fprintf('Click the figure window, then press i/j/k/l to drive.\n');
    while running && ishandle(fig)
        pause(0.05);
    end
    stopAndClose();

    function controlLoop()
        if ~running || ~ishandle(fig), return; end

        scan = pullScan();
        odom = pullOdom();
        if ~isempty(scan), lastScan = scan; end
        if ~isempty(odom)
            lastOdom = odom;
            lastYaw = quat2yaw(odom.pose.pose.orientation);
            px = odom.pose.pose.position.x;
            py = odom.pose.pose.position.y;
            trailX(end+1) = px; %#ok<AGROW>
            trailY(end+1) = py; %#ok<AGROW>
            if numel(trailX) > 500
                trailX = trailX(end-499:end);
                trailY = trailY(end-499:end);
            end
            set(poseLine, 'XData', trailX, 'YData', trailY);
            set(posePt, 'XData', px, 'YData', py);
        end

        if ~isempty(lastScan) && ~isempty(lastOdom)
            px = lastOdom.pose.pose.position.x;
            py = lastOdom.pose.pose.position.y;
            [lx, ly] = laserScanToXY(lastScan, px, py, lastYaw);
            set(scanLine, 'XData', lx, 'YData', ly);
        end

        moving = (moveX ~= 0) || (moveTh ~= 0);
        if moving || (lastSentMoving && ~moving)
            twist = ros2message(cmdPub);
            twist.linear.x = linSpeed * moveX;
            twist.angular.z = angSpeed * moveTh;
            send(cmdPub, twist);
        end
        lastSentMoving = moving;
    end

    function onKeyRelease(~, ev)
        switch ev.Key
            case {'i', ',', 'j', 'l', 'u', 'o', 'm', '.', ...
                    'uparrow', 'downarrow', 'leftarrow', 'rightarrow'}
                moveX = 0;
                moveTh = 0;
        end
    end

    function onKey(~, ev)
        k = ev.Key;
        switch k
            case {'i', 'uparrow'}
                moveX = 1;  moveTh = 0;
            case {',', 'downarrow'}
                moveX = -1; moveTh = 0;
            case {'j', 'leftarrow'}
                moveX = 0;  moveTh = 1;
            case {'l', 'rightarrow'}
                moveX = 0;  moveTh = -1;
            case 'u'
                moveX = 1;  moveTh = 1;
            case 'o'
                moveX = 1;  moveTh = -1;
            case 'm'
                moveX = -1; moveTh = -1;
            case '.'
                moveX = -1; moveTh = 1;
            case 'space'
                moveX = 0;  moveTh = 0;
            case 'q'
                linSpeed = min(linSpeed * 1.1, 1.0);
                angSpeed = min(angSpeed * 1.1, 5.0);
                fprintf('Speed: linear=%.2f  angular=%.2f\n', linSpeed, angSpeed);
            case 'w'
                linSpeed = linSpeed * 0.9;
                angSpeed = angSpeed * 0.9;
                fprintf('Speed: linear=%.2f  angular=%.2f\n', linSpeed, angSpeed);
            case 'z'
                running = false;
            otherwise
                return;
        end
    end

    function stopAndClose()
        running = false;
        if exist('timerObj', 'var') && isvalid(timerObj)
            stop(timerObj);
            delete(timerObj);
        end
        try
            twist = ros2message(cmdPub);
            send(cmdPub, twist);
        catch
        end
        if ishandle(fig)
            delete(fig);
        end
    end

    function msg = pullScan()
        msg = tryReceive(scanSub, 0.02);
        if isempty(msg)
            msg = tryLatestMessage(scanSub);
        end
    end

    function msg = pullOdom()
        msg = tryReceive(odomSub, 0.02);
        if isempty(msg)
            msg = tryLatestMessage(odomSub);
        end
    end
end

function ok = waitForTopicOptional(sub, timeoutSec)
    t0 = tic;
    while toc(t0) < timeoutSec
        if ~isempty(tryReceive(sub, 0.5))
            ok = true;
            return;
        end
        pause(0.1);
    end
    ok = false;
end

function waitForTopic(sub, timeoutSec)
    t0 = tic;
    while toc(t0) < timeoutSec
        if ~isempty(tryReceive(sub, 0.5)), return; end
        pause(0.1);
    end
    error('matlab_connect:Timeout', ...
        'No live data on %s within %d s.', sub.TopicName, timeoutSec);
end

function msg = tryReceive(sub, timeoutSec)
    msg = [];
    try
        msg = receive(sub, timeoutSec);
    catch
    end
end

function msg = tryLatestMessage(sub)
    msg = [];
    try
        if isprop(sub, 'LatestMessage')
            msg = sub.LatestMessage;
            if isempty(msg), msg = []; end
        end
    catch
    end
end

function yaw = quat2yaw(q)
    yaw = atan2(2*(q.w*q.z + q.x*q.y), 1 - 2*(q.y*q.y + q.z*q.z));
end

function [x, y] = laserScanToXY(scan, ox, oy, yaw)
    r = scan.ranges;
    if isempty(r), x = []; y = []; return; end
    if isrow(r), r = r(:); end
    idx = isfinite(r) & r >= scan.range_min & r <= scan.range_max;
    k = find(idx);
    if isempty(k), x = []; y = []; return; end
    ang = scan.angle_min + (k - 1) * scan.angle_increment;
    c = cos(yaw); s = sin(yaw);
    lx = r(k) .* cos(ang);
    ly = r(k) .* sin(ang);
    x = ox + c * lx - s * ly;
    y = oy + s * lx + c * ly;
end
