function matlab_connect_bridge()
%MATLAB_CONNECT_BRIDGE  Robot via TCP bridge (port 8765).

    cfg = prepare_robot_assets();
    fprintf('Robot preflight...\n');
    if ~check_robot_preflight()
        error('matlab_connect:Preflight', ...
            ['Robot not ready.\n' ...
             '  ./scripts/start_agent.sh && ./scripts/check_robot.sh']);
    end

    port = 8765;
    fprintf('Connecting to MATLAB bridge 127.0.0.1:%d ...\n', port);
    try
        client = tcpclient('127.0.0.1', port, 'Timeout', 10);
    catch
        error('matlab_connect:Bridge', ...
            'Bridge not running. Run: ./scripts/start_matlab_bridge.sh');
    end

    hello = bridge_recv(client, 15);
    if ~isfield(hello, 'type') || ~strcmp(hello.type, 'hello')
        error('matlab_connect:Bridge', 'Unexpected bridge handshake');
    end
    fprintf('Bridge connected.\n');

    oldDir = pwd;
    cleanupObj = onCleanup(@() cleanup(client, oldDir)); %#ok<NASGU>
    cd(cfg.matlabDir);

    fprintf('Loading URDF: %s\n', cfg.urdfPath);
    robot = importrobot(cfg.urdfPath);
    robot.DataFormat = 'row';

    fprintf('Waiting for live odom from bridge...\n');
    odom = waitBridgeOdom(client, 30);
    yaw = quat2yaw(struct('w', odom.qw, 'x', odom.qx, 'y', odom.qy, 'z', odom.qz));
    fprintf('Connected (x=%.2f y=%.2f).\n', odom.x, odom.y);

    fig = figure('Name', 'Yahboom micro-ROS - MATLAB bridge', 'NumberTitle', 'off');
    axMap = subplot(1, 2, 1);
    title(axMap, 'Map view (odom + lidar)');
    xlabel(axMap, 'x [m]'); ylabel(axMap, 'y [m]');
    axis(axMap, 'equal'); grid(axMap, 'on'); hold(axMap, 'on');

    axRobot = subplot(1, 2, 2);
    title(axRobot, 'URDF model');
    show(robot, homeConfiguration(robot), 'Parent', axRobot, 'Frames', 'off');
    view(axRobot, 3); axis(axRobot, 'equal'); grid(axRobot, 'on');

    helpStr = ['Keys:  i=fwd  ,=back  j/l=turn  uom.=diag  ' ...
        'hold to drive, release to stop  q/w=speed  z=quit'];
    annotation(fig, 'textbox', [0.02 0.01 0.96 0.04], ...
        'String', helpStr, 'EdgeColor', 'none', 'HorizontalAlignment', 'left', ...
        'FitBoxToText', 'off', 'HitTest', 'off');

    linSpeed = 0.2;
    angSpeed = 1.0;
    moveX = 0;
    moveTh = 0;
    running = true;
    latestScan = [];
    latestOdom = odom;
    lastSentMoving = false;
    viewTick = 0;

    fig.WindowKeyPressFcn = @onKey;
    fig.WindowKeyReleaseFcn = @onKeyRelease;
    fig.CloseRequestFcn = @(~, ~) stopAndClose();
    set(fig, 'MenuBar', 'none', 'ToolBar', 'none');

    scanLine = plot(axMap, nan, nan, 'b.', 'MarkerSize', 6);
    poseLine = plot(axMap, nan, nan, 'r-', 'LineWidth', 1.5);
    posePt = plot(axMap, odom.x, odom.y, 'ro', 'MarkerFaceColor', 'r');
    trailX = odom.x;
    trailY = odom.y;

    timerObj = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, ...
        'TimerFcn', @(~, ~) controlLoop());
    start(timerObj);

    figure(fig);
    drawnow;

    fprintf('%s\n', helpStr);
    fprintf('Click the map figure, hold i/j/l/, to drive (release to stop).\n');
    while running && ishandle(fig)
        pause(0.05);
    end
    stopAndClose();

    function controlLoop()
        if ~running || ~ishandle(fig), return; end
        while client.NumBytesAvailable > 0
            msg = bridge_recv(client, 1);
            if isempty(msg), break; end
            if strcmp(msg.type, 'odom')
                latestOdom = msg;
            elseif strcmp(msg.type, 'scan')
                latestScan = msg;
            end
        end
        if isempty(latestOdom), return; end
        px = latestOdom.x;
        py = latestOdom.y;
        yawNow = quat2yaw(struct('w', latestOdom.qw, 'x', latestOdom.qx, ...
            'y', latestOdom.qy, 'z', latestOdom.qz));
        trailX(end+1) = px; %#ok<AGROW>
        trailY(end+1) = py; %#ok<AGROW>
        if numel(trailX) > 500
            trailX = trailX(end-499:end);
            trailY = trailY(end-499:end);
        end
        set(poseLine, 'XData', trailX, 'YData', trailY);
        set(posePt, 'XData', px, 'YData', py);
        if ~isempty(latestScan)
            [lx, ly] = bridgeScanToXY(latestScan, px, py, yawNow);
            set(scanLine, 'XData', lx, 'YData', ly);
        end
        viewTick = viewTick + 1;
        if mod(viewTick, 5) == 0
            updateRobotView(axRobot, robot, yawNow);
        end

        moving = (moveX ~= 0) || (moveTh ~= 0);
        cmdLin = linSpeed * moveX;
        cmdAng = angSpeed * moveTh;
        if moving || (lastSentMoving && ~moving)
            bridge_send_cmd(client, cmdLin, cmdAng);
        end
        if moving
            title(axMap, sprintf('Map  DRIVING  lin=%.2f  ang=%.2f', cmdLin, cmdAng));
        else
            title(axMap, 'Map view (odom + lidar)');
        end
        lastSentMoving = moving;
    end

    function onKeyRelease(~, ev)
        k = ev.Key;
        if isempty(k) || strcmp(k, 'undefined')
            k = ev.Character;
        end
        if isMovementKey(k)
            moveX = 0;
            moveTh = 0;
        end
    end

    function onKey(~, ev)
        k = ev.Key;
        if isempty(k) || strcmp(k, 'undefined')
            k = ev.Character;
        end
        if isMovementKey(k)
            figure(fig);
            applyMovementKey(k);
            return;
        end
        switch k
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

    function tf = isMovementKey(k)
        tf = any(strcmp(k, {'i', 'j', 'l', 'u', 'o', 'm', ...
            ',', 'comma', '.', 'period', ...
            'uparrow', 'downarrow', 'leftarrow', 'rightarrow'}));
    end

    function applyMovementKey(k)
        switch k
            case {'i', 'uparrow'}
                moveX = 1;  moveTh = 0;
            case {',', 'comma', 'downarrow'}
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
            case {'.', 'period'}
                moveX = -1; moveTh = 1;
        end
    end

    function stopAndClose()
        running = false;
        if exist('timerObj', 'var') && isvalid(timerObj)
            stop(timerObj);
            delete(timerObj);
        end
        try
            bridge_send_cmd(client, 0, 0);
        catch
        end
        if ishandle(fig)
            delete(fig);
        end
    end
end

function odom = waitBridgeOdom(client, timeoutSec)
    t0 = tic;
    while toc(t0) < timeoutSec
        if client.NumBytesAvailable > 0
            msg = bridge_recv(client, 2);
            if isstruct(msg) && isfield(msg, 'type') && strcmp(msg.type, 'odom')
                odom = msg;
                return;
            end
        end
        pause(0.05);
    end
    error('matlab_connect:Timeout', 'No odom from bridge within %d s', timeoutSec);
end

function cleanup(client, oldDir)
    try
        clear client
    catch
    end
    try
        cd(oldDir);
    catch
    end
end

function [x, y] = bridgeScanToXY(scan, ox, oy, yaw)
    ranges = scan.ranges;
    if isempty(ranges), x = []; y = []; return; end
    angMin = scan.angle_min;
    angInc = scan.angle_increment;
    rmin = scan.range_min;
    rmax = scan.range_max;
    idx = isfinite(ranges) & ranges >= rmin & ranges <= rmax;
    k = find(idx);
    if isempty(k), x = []; y = []; return; end
    ang = angMin + (k - 1) * angInc;
    lx = ranges(k) .* cos(ang);
    ly = ranges(k) .* sin(ang);
    c = cos(yaw); s = sin(yaw);
    x = ox + c * lx - s * ly;
    y = oy + s * lx + c * ly;
end

function yaw = quat2yaw(q)
    siny = 2 * (q.w * q.z + q.x * q.y);
    cosy = 1 - 2 * (q.y * q.y + q.z * q.z);
    yaw = atan2(siny, cosy);
end

function updateRobotView(ax, robot, yaw)
    cla(ax);
    show(robot, homeConfiguration(robot), 'Parent', ax, 'Frames', 'off');
    view(ax, 3);
    axis(ax, 'equal');
    grid(ax, 'on');
    title(ax, sprintf('URDF (yaw=%.1f deg)', rad2deg(yaw)));
end
