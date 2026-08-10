function slxPath = build_rover_ros_io_model()
%BUILD_ROVER_ROS_IO_MODEL Create the first Simulink ROS I/O proof model.
%
%   slxPath = build_rover_ros_io_model()
%
%   Creates/updates:
%     Rover-Room-SIM/simulink/rover_ros_io.slx
%
%   Model contents:
%     - ROS 2 Subscribe /odom  -> scoped x/y debug signals
%     - ROS 2 Subscribe /scan  -> scoped range_min debug signal
%     - ROS 2 Publish /cmd_vel <- keyboard teleop command

    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    modelDir = fullfile(projectRoot, 'simulink');
    modelName = 'rover_ros_io';
    slxPath = fullfile(modelDir, [modelName '.slx']);

    if ~isfolder(modelDir)
        mkdir(modelDir);
    end

    addpath(matlabDir);
    setup_ros_humble();

    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end

    if isfile(slxPath)
        delete(slxPath);
    end

    new_system(modelName);
    open_system(modelName);

    configureModel(modelName, matlabDir);
    addBlocks(modelName);
    wireBlocks(modelName);

    set_param(modelName, 'SimulationCommand', 'update');
    save_system(modelName, slxPath);
    open_system(slxPath);

    fprintf('Created Simulink model: %s\n', slxPath);
end

function configureModel(modelName, ~)
    set_param(modelName, ...
        'SolverType', 'Fixed-step', ...
        'Solver', 'FixedStepAuto', ...
        'FixedStep', '0.1', ...
        'StopTime', 'inf', ...
        'InitFcn', ['addpath(fullfile(fileparts(fileparts(get_param(bdroot,''FileName''))),''matlab''));' newline ...
            'simulink_teleop_utils(''clear'');'], ...
        'StartFcn', 'simulink_teleop_start();', ...
        'StopFcn', 'simulink_teleop_stop();');
end

function addBlocks(modelName)
    interpFcnBlock = sprintf('simulink/User-Defined\nFunctions/Interpreted MATLAB\nFunction');

    add_block('simulink/Ports & Subsystems/In1', [modelName '/_anchor'], ...
        'Position', [10 10 40 24]);
    delete_block([modelName '/_anchor']);

    add_block('roslib/ROS 2/Subscribe', [modelName '/Subscribe_Odom'], ...
        'Position', [50 90 170 150]);
    set_param([modelName '/Subscribe_Odom'], ...
        'topicSource', 'Specify your own', ...
        'topic', '/odom', ...
        'messageType', 'nav_msgs/Odometry', ...
        'sampleTime', '0.1', ...
        'QOSReliability', 'Reliable', ...
        'QOSDurability', 'Volatile', ...
        'QOSDepth', '10');
    ros.slros2.internal.block.SubscribeBlockMask.dispatch('messageTypeEdit', [modelName '/Subscribe_Odom']);

    add_block('simulink/Sinks/Terminator', [modelName '/Odom_IsNew'], ...
        'Position', [210 102 230 118]);
    add_block('simulink/Sinks/Scope', [modelName '/Scope_Odom_IsNew'], ...
        'Position', [245 52 275 82]);

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_Pose'], ...
        'Position', [245 95 340 145]);
    set_param([modelName '/Odom_Pose'], 'OutputSignals', 'pose');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_Header'], ...
        'Position', [245 170 340 220]);
    set_param([modelName '/Odom_Header'], 'OutputSignals', 'header');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_Stamp'], ...
        'Position', [385 170 480 220]);
    set_param([modelName '/Odom_Stamp'], 'OutputSignals', 'stamp');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_Nsec'], ...
        'Position', [525 170 620 220]);
    set_param([modelName '/Odom_Nsec'], 'OutputSignals', 'nanosec');

    add_block('simulink/Sinks/Scope', [modelName '/Scope_Odom_Nsec'], ...
        'Position', [665 180 695 210]);

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_PoseInner'], ...
        'Position', [385 95 480 145]);
    set_param([modelName '/Odom_PoseInner'], 'OutputSignals', 'pose');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_Position'], ...
        'Position', [525 95 620 145]);
    set_param([modelName '/Odom_Position'], 'OutputSignals', 'position');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_XY'], ...
        'Position', [665 90 760 150]);
    set_param([modelName '/Odom_XY'], 'OutputSignals', 'x,y');

    add_block('simulink/Sinks/Scope', [modelName '/Scope_Odom_X'], ...
        'Position', [820 90 850 120]);
    add_block('simulink/Sinks/Scope', [modelName '/Scope_Odom_Y'], ...
        'Position', [820 130 850 160]);

    add_block('roslib/ROS 2/Subscribe', [modelName '/Subscribe_Scan'], ...
        'Position', [50 260 170 320]);
    set_param([modelName '/Subscribe_Scan'], ...
        'topicSource', 'Specify your own', ...
        'topic', '/scan', ...
        'messageType', 'sensor_msgs/LaserScan', ...
        'sampleTime', '0.1', ...
        'QOSReliability', 'Reliable', ...
        'QOSDurability', 'Volatile', ...
        'QOSDepth', '10');
    ros.slros2.internal.block.SubscribeBlockMask.dispatch('messageTypeEdit', [modelName '/Subscribe_Scan']);

    add_block('simulink/Sinks/Terminator', [modelName '/Scan_IsNew'], ...
        'Position', [210 272 230 288]);
    add_block('simulink/Sinks/Scope', [modelName '/Scope_Scan_IsNew'], ...
        'Position', [245 232 275 262]);

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Scan_RangeMin'], ...
        'Position', [245 265 360 315]);
    set_param([modelName '/Scan_RangeMin'], 'OutputSignals', 'range_min');

    add_block('simulink/Sinks/Scope', [modelName '/Scope_Scan_RangeMin'], ...
        'Position', [430 275 460 305]);

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Scan_Header'], ...
        'Position', [245 340 360 390]);
    set_param([modelName '/Scan_Header'], 'OutputSignals', 'header');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Scan_Stamp'], ...
        'Position', [430 340 525 390]);
    set_param([modelName '/Scan_Stamp'], 'OutputSignals', 'stamp');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Scan_Nsec'], ...
        'Position', [595 340 690 390]);
    set_param([modelName '/Scan_Nsec'], 'OutputSignals', 'nanosec');

    add_block('simulink/Sinks/Scope', [modelName '/Scope_Scan_Nsec'], ...
        'Position', [760 350 790 380]);

    add_block('simulink/Sources/Clock', [modelName '/Teleop_Tick'], ...
        'Position', [30 445 60 475]);

    add_block(interpFcnBlock, [modelName '/Teleop_Lin'], ...
        'Position', [95 425 210 455]);
    set_param([modelName '/Teleop_Lin'], 'MATLABFcn', 'simulink_teleop_lin(u)');

    add_block(interpFcnBlock, [modelName '/Teleop_Ang'], ...
        'Position', [95 470 210 500]);
    set_param([modelName '/Teleop_Ang'], 'MATLABFcn', 'simulink_teleop_ang(u)');

    add_block('simulink/Sinks/Scope', [modelName '/Scope_Cmd_Lin'], ...
        'Position', [250 420 280 450]);
    add_block('simulink/Sinks/Scope', [modelName '/Scope_Cmd_Ang'], ...
        'Position', [250 465 280 495]);

    add_block('roslib/ROS 2/Blank Message', [modelName '/CmdVel_Blank'], ...
        'Position', [320 430 455 480]);
    set_param([modelName '/CmdVel_Blank'], ...
        'messageClass', 'Message', ...
        'entityType', 'geometry_msgs/Twist', ...
        'SampleTime', '0.1');
    ros.slros2.internal.block.MessageBlockMask.dispatch('entityTypeEdit', [modelName '/CmdVel_Blank']);

    add_block('simulink/Signal Routing/Bus Assignment', [modelName '/CmdVel_Assign'], ...
        'Position', [500 420 620 490]);
    set_param([modelName '/CmdVel_Assign'], 'AssignedSignals', 'linear.x,angular.z');

    add_block('roslib/ROS 2/Publish', [modelName '/Publish_CmdVel'], ...
        'Position', [670 425 790 485]);
    set_param([modelName '/Publish_CmdVel'], ...
        'topicSource', 'Specify your own', ...
        'topic', '/cmd_vel', ...
        'messageType', 'geometry_msgs/Twist', ...
        'QOSReliability', 'Reliable', ...
        'QOSDurability', 'Volatile', ...
        'QOSDepth', '10');
    ros.slros2.internal.block.PublishBlockMask.dispatch('messageTypeEdit', [modelName '/Publish_CmdVel']);

    ann = Simulink.Annotation(modelName, ['Run the model, click Simulink Rover Teleop, hold WASD (arrows OK). ' ...
        'Q slower, E faster, Space stop.']);
    ann.Position = [40 15 880 55];
end

function wireBlocks(modelName)
    add_line(modelName, 'Subscribe_Odom/1', 'Scope_Odom_IsNew/1', 'autorouting', 'on');
    add_line(modelName, 'Subscribe_Odom/1', 'Odom_IsNew/1', 'autorouting', 'on');
    add_line(modelName, 'Subscribe_Odom/2', 'Odom_Pose/1', 'autorouting', 'on');
    add_line(modelName, 'Subscribe_Odom/2', 'Odom_Header/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Header/1', 'Odom_Stamp/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Stamp/1', 'Odom_Nsec/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Nsec/1', 'Scope_Odom_Nsec/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Pose/1', 'Odom_PoseInner/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_PoseInner/1', 'Odom_Position/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Position/1', 'Odom_XY/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_XY/1', 'Scope_Odom_X/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_XY/2', 'Scope_Odom_Y/1', 'autorouting', 'on');

    add_line(modelName, 'Subscribe_Scan/1', 'Scope_Scan_IsNew/1', 'autorouting', 'on');
    add_line(modelName, 'Subscribe_Scan/1', 'Scan_IsNew/1', 'autorouting', 'on');
    add_line(modelName, 'Subscribe_Scan/2', 'Scan_RangeMin/1', 'autorouting', 'on');
    add_line(modelName, 'Subscribe_Scan/2', 'Scan_Header/1', 'autorouting', 'on');
    add_line(modelName, 'Scan_Header/1', 'Scan_Stamp/1', 'autorouting', 'on');
    add_line(modelName, 'Scan_Stamp/1', 'Scan_Nsec/1', 'autorouting', 'on');
    add_line(modelName, 'Scan_Nsec/1', 'Scope_Scan_Nsec/1', 'autorouting', 'on');
    add_line(modelName, 'Scan_RangeMin/1', 'Scope_Scan_RangeMin/1', 'autorouting', 'on');

    add_line(modelName, 'Teleop_Tick/1', 'Teleop_Lin/1', 'autorouting', 'on');
    add_line(modelName, 'Teleop_Tick/1', 'Teleop_Ang/1', 'autorouting', 'on');
    add_line(modelName, 'Teleop_Lin/1', 'Scope_Cmd_Lin/1', 'autorouting', 'on');
    add_line(modelName, 'Teleop_Ang/1', 'Scope_Cmd_Ang/1', 'autorouting', 'on');
    add_line(modelName, 'CmdVel_Blank/1', 'CmdVel_Assign/1', 'autorouting', 'on');
    add_line(modelName, 'Teleop_Lin/1', 'CmdVel_Assign/2', 'autorouting', 'on');
    add_line(modelName, 'Teleop_Ang/1', 'CmdVel_Assign/3', 'autorouting', 'on');
    add_line(modelName, 'CmdVel_Assign/1', 'Publish_CmdVel/1', 'autorouting', 'on');
end
