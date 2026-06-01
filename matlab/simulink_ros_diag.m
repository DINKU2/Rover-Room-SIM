function simulink_ros_diag(disableInitFcn)
%SIMULINK_ROS_DIAG Diagnose whether rover_ros_io receives ROS 2 data.

    if nargin < 1
        disableInitFcn = false;
    end

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(projectRoot, 'matlab'));
    setup_ros_humble();

    load_system(fullfile(projectRoot, 'simulink', 'rover_ros_io.slx'));
    originalInitFcn = get_param('rover_ros_io', 'InitFcn');
    if disableInitFcn
        set_param('rover_ros_io', 'InitFcn', '');
    end
    set_param('rover_ros_io', 'StopTime', '1.2');

    ensureToWorkspace('rover_ros_io', 'Odom_XY/1', 'Scope_Odom_X/1', ...
        'ToWs_X', 'simOdomX', [900 90 980 120]);
    ensureToWorkspace('rover_ros_io', 'Odom_XY/2', 'Scope_Odom_Y/1', ...
        'ToWs_Y', 'simOdomY', [900 130 980 160]);
    ensureToWorkspace('rover_ros_io', 'Scan_RangeMin/1', 'Scope_Scan_RangeMin/1', ...
        'ToWs_Scan', 'simScanRangeMin', [520 275 610 305]);

    disp('Workspace taps:');
    dispBranch('rover_ros_io/ToWs_X');
    dispBranch('rover_ros_io/ToWs_Y');
    dispBranch('rover_ros_io/ToWs_Scan');

    node = ros2node('simulink_diag_pub');
    pub = ros2publisher(node, '/odom', 'nav_msgs/Odometry');

    t = timer( ...
        'ExecutionMode', 'fixedRate', ...
        'Period', 0.1, ...
        'TasksToExecute', 8, ...
        'TimerFcn', @(~, ~) publishOdom(pub));
    cleaner = onCleanup(@() cleanupTimer(t)); %#ok<NASGU>

    start(t);
    simOut = sim('rover_ros_io');
    if disableInitFcn
        set_param('rover_ros_io', 'InitFcn', originalInitFcn);
    end

    disp('SimulationOutput variables:');
    disp(who(simOut));

    if isprop(simOut, 'simOdomX') || ismember("simOdomX", string(who(simOut)))
        simOdomX = simOut.simOdomX;
    end
    if isprop(simOut, 'simOdomY') || ismember("simOdomY", string(who(simOut)))
        simOdomY = simOut.simOdomY;
    end
    if isprop(simOut, 'simScanRangeMin') || ismember("simScanRangeMin", string(who(simOut)))
        simScanRangeMin = simOut.simScanRangeMin;
    end

    if exist('simOdomX', 'var')
        disp('X timeseries present');
        disp(simOdomX.Data');
    else
        disp('No simOdomX');
    end

    if exist('simOdomY', 'var')
        disp('Y timeseries present');
        disp(simOdomY.Data');
    else
        disp('No simOdomY');
    end

    if exist('simScanRangeMin', 'var')
        disp('Scan timeseries present');
        disp(simScanRangeMin.Data');
    else
        disp('No simScanRangeMin');
    end
end

function ensureToWorkspace(modelName, srcPort, scopeDst, blockName, varName, pos)
    fullBlock = [modelName '/' blockName];
    if ~bdIsLoaded(modelName)
        error('Model %s must be loaded first.', modelName);
    end
    try
        add_block('simulink/Sinks/To Workspace', fullBlock, ...
            'VariableName', varName, ...
            'SaveFormat', 'Timeseries', ...
            'Position', pos);
    catch
    end

    try
        delete_line(modelName, srcPort, scopeDst);
    catch
    end
    try
        add_line(modelName, srcPort, scopeDst, 'autorouting', 'on');
    catch
    end
    try
        add_line(modelName, srcPort, [blockName '/1'], 'autorouting', 'on');
    catch
    end
end

function dispBranch(blockPath)
    ph = get_param(blockPath, 'PortHandles');
    lh = get_param(ph.Inport(1), 'Line');
    src = get_param(lh, 'SrcBlockHandle');
    if src ~= -1
        disp([blockPath ' <= ' getfullname(src)]);
    else
        disp([blockPath ' <= <disconnected>']);
    end
end

function publishOdom(pub)
    persistent k
    if isempty(k)
        k = 0;
    end
    k = k + 1;

    msg = ros2message(pub);
    msg.pose.pose.position.x = 0.1 * k;
    msg.pose.pose.position.y = -0.05 * k;
    msg.pose.pose.orientation.w = 1;
    send(pub, msg);
end

function cleanupTimer(t)
    if isa(t, 'timer') && isvalid(t)
        try
            stop(t);
        catch
        end
        delete(t);
    end
end
