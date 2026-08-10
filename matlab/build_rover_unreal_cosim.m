function slxPath = build_rover_unreal_cosim()
%BUILD_ROVER_UNREAL_COSIM  ROS I/O + Unreal co-simulation model.
%
%   slxPath = build_rover_unreal_cosim()
%
%   Creates simulink/rover_unreal_cosim.slx:
%     - Simulation 3D Scene Configuration -> RoverTwin /Game/Maps/MyRoom
%     - ROS 2 Subscribe /odom -> x, y, yaw
%     - Simulation 3D Vehicle With Ground Following (Automated Driving)
%     - ROS 2 Publish /cmd_vel <- keyboard teleop (same as rover_ros_io)

    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    modelDir = fullfile(projectRoot, 'simulink');
    modelName = 'rover_unreal_cosim';
    slxPath = fullfile(modelDir, [modelName '.slx']);

    addpath(matlabDir);
    paths = rover_unreal_paths();
    setup_unreal_matlab(false);
    setup_ros_humble();

    vehicleBlock = pickVehicleBlock();
    if isempty(vehicleBlock)
        error('rover:unreal:NoVehicleBlock', ...
            ['No Simulation 3D vehicle block found. Install Automated Driving or ' ...
             'Vehicle Dynamics Interface for Unreal Engine Projects.']);
    end

    if ~isfolder(modelDir)
        mkdir(modelDir);
    end
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    if isfile(slxPath)
        delete(slxPath);
    end

    new_system(modelName);
    open_system(modelName);

    load_system('sim3dlib');
    add_block('sim3dlib/Simulation 3D Scene Configuration', ...
        [modelName '/Scene_Configuration'], ...
        'Position', [40 40 240 140]);
    set_param([modelName '/Scene_Configuration'], ...
        'ProjectFormat', 'Unreal Editor', ...
        'UEProjPath', paths.cosimProject, ...
        'ScenePath', paths.roverTwinScene);

    add_block('roslib/ROS 2/Subscribe', [modelName '/Subscribe_Odom'], ...
        'Position', [40 200 160 260]);
    set_param([modelName '/Subscribe_Odom'], ...
        'topicSource', 'Specify your own', ...
        'topic', '/odom', ...
        'messageType', 'nav_msgs/Odometry', ...
        'sampleTime', '0.02', ...
        'QOSReliability', 'Reliable', ...
        'QOSDurability', 'Volatile', ...
        'QOSDepth', '10');
    ros.slros2.internal.block.SubscribeBlockMask.dispatch('messageTypeEdit', ...
        [modelName '/Subscribe_Odom']);

    addOdomPoseBlocks(modelName);

    add_block(vehicleBlock, [modelName '/Vehicle_UE'], ...
        'Position', [440 180 580 280]);
    set_param([modelName '/Vehicle_UE'], ...
        'MeshPath', '/MathWorksAutomotiveContent/Vehicles/SmallCar/Meshes/SK_SmallCar.SK_SmallCar', ...
        'VehColor', 'Blue', ...
        'TrackWidth', '0.28', ...
        'WheelBase', '0.22', ...
        'WheelRadius', '0.05');

    addTeleopAndCmdVel(modelName);

    set_param(modelName, ...
        'SolverType', 'Fixed-step', ...
        'Solver', 'FixedStepAuto', ...
        'FixedStep', '0.02', ...
        'StopTime', 'inf', ...
        'InitFcn', sprintf('addpath(''%s''); setup_ros_humble();', matlabDir), ...
        'StartFcn', 'simulink_teleop_start();', ...
        'StopFcn', 'simulink_teleop_stop();');

    add_line(modelName, 'Subscribe_Odom/2', 'Odom_Pose/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Pose/1', 'Odom_PoseInner/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_PoseInner/1', 'Odom_Position/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_PoseInner/1', 'Odom_Orient/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Position/1', 'Odom_XY/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Orient/1', 'Orient_W/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Orient/1', 'Orient_X/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Orient/1', 'Orient_Y/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_Orient/1', 'Orient_Z/1', 'autorouting', 'on');
    add_line(modelName, 'Orient_W/1', 'Orient_Mux/1', 'autorouting', 'on');
    add_line(modelName, 'Orient_X/1', 'Orient_Mux/2', 'autorouting', 'on');
    add_line(modelName, 'Orient_Y/1', 'Orient_Mux/3', 'autorouting', 'on');
    add_line(modelName, 'Orient_Z/1', 'Orient_Mux/4', 'autorouting', 'on');
    add_line(modelName, 'Orient_Mux/1', 'Yaw_From_Quat/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_XY/1', 'Vehicle_UE/1', 'autorouting', 'on');
    add_line(modelName, 'Odom_XY/2', 'Vehicle_UE/2', 'autorouting', 'on');
    add_line(modelName, 'Yaw_From_Quat/1', 'Vehicle_UE/3', 'autorouting', 'on');

    set_param(modelName, 'SimulationCommand', 'update');
    save_system(modelName, slxPath);
    open_system(slxPath);

    fprintf('Created Simulink co-sim model: %s\n', slxPath);
    fprintf('  UE project: %s\n', paths.cosimProject);
    fprintf('  Vehicle block: %s\n', vehicleBlock);
    fprintf('Next: run_rover_unreal_cosim()  OR  launch_unreal_editor + sim(''%s'')\n', modelName);
end

function blockPath = pickVehicleBlock()
    candidates = {
        'drivingsim3d/Simulation 3D Vehicle with Ground Following'
        'vehdynlibsim3d/Simulation 3D Vehicle with Ground Following'
        'vehdynlibsim3d/Simulation 3D Vehicle'
        'drivingsim3d/Simulation 3D Vehicle with Ground Following'
        };
    for i = 1:numel(candidates)
        try
            load_system(strtok(candidates{i}, '/'));
            get_param(candidates{i}, 'BlockType');
            blockPath = candidates{i};
            return;
        catch
        end
    end
    blockPath = '';
end

function addOdomPoseBlocks(modelName)
    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_Pose'], ...
        'Position', [210 205 305 255]);
    set_param([modelName '/Odom_Pose'], 'OutputSignals', 'pose');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_PoseInner'], ...
        'Position', [350 205 445 255]);
    set_param([modelName '/Odom_PoseInner'], 'OutputSignals', 'pose');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_Position'], ...
        'Position', [490 190 585 230]);
    set_param([modelName '/Odom_Position'], 'OutputSignals', 'position');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_XY'], ...
        'Position', [630 185 725 235]);
    set_param([modelName '/Odom_XY'], 'OutputSignals', 'x,y');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Odom_Orient'], ...
        'Position', [490 250 585 310]);
    set_param([modelName '/Odom_Orient'], 'OutputSignals', 'orientation');

    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Orient_W'], ...
        'Position', [630 250 725 270]);
    set_param([modelName '/Orient_W'], 'OutputSignals', 'w');
    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Orient_X'], ...
        'Position', [630 275 725 295]);
    set_param([modelName '/Orient_X'], 'OutputSignals', 'x');
    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Orient_Y'], ...
        'Position', [630 300 725 320]);
    set_param([modelName '/Orient_Y'], 'OutputSignals', 'y');
    add_block('simulink/Signal Routing/Bus Selector', [modelName '/Orient_Z'], ...
        'Position', [630 325 725 345]);
    set_param([modelName '/Orient_Z'], 'OutputSignals', 'z');

    add_block('simulink/Signal Routing/Mux', [modelName '/Orient_Mux'], ...
        'Position', [770 285 775 335], 'Inputs', '4');

    add_block('simulink/User-Defined Functions/Fcn', [modelName '/Yaw_From_Quat'], ...
        'Position', [820 285 920 325]);
    set_param([modelName '/Yaw_From_Quat'], ...
        'Expr', 'atan2(2*(u[1]*u[4]+u[2]*u[3]), 1-2*(u[3]^2+u[4]^2))');
end

function addTeleopAndCmdVel(modelName)
    interpBlock = sprintf('simulink/User-Defined\nFunctions/Interpreted MATLAB\nFunction');
    add_block('simulink/Sources/Clock', [modelName '/Teleop_Tick'], ...
        'Position', [40 360 70 390]);

    add_block(interpBlock, [modelName '/Teleop_Lin'], ...
        'Position', [110 340 220 370]);
    set_param([modelName '/Teleop_Lin'], 'MATLABFcn', 'simulink_teleop_lin(u)');

    add_block(interpBlock, [modelName '/Teleop_Ang'], ...
        'Position', [110 385 220 415]);
    set_param([modelName '/Teleop_Ang'], 'MATLABFcn', 'simulink_teleop_ang(u)');

    add_block('roslib/ROS 2/Blank Message', [modelName '/CmdVel_Blank'], ...
        'Position', [280 345 410 395]);
    set_param([modelName '/CmdVel_Blank'], ...
        'messageClass', 'Message', ...
        'entityType', 'geometry_msgs/Twist', ...
        'SampleTime', '0.02');
    ros.slros2.internal.block.MessageBlockMask.dispatch('entityTypeEdit', ...
        [modelName '/CmdVel_Blank']);

    add_block('simulink/Signal Routing/Bus Assignment', [modelName '/CmdVel_Assign'], ...
        'Position', [450 335 570 405]);
    set_param([modelName '/CmdVel_Assign'], 'AssignedSignals', 'linear.x,angular.z');

    add_block('roslib/ROS 2/Publish', [modelName '/Publish_CmdVel'], ...
        'Position', [620 340 740 400]);
    set_param([modelName '/Publish_CmdVel'], ...
        'topicSource', 'Specify your own', ...
        'topic', '/cmd_vel', ...
        'messageType', 'geometry_msgs/Twist', ...
        'QOSReliability', 'Reliable', ...
        'QOSDurability', 'Volatile', ...
        'QOSDepth', '10');
    ros.slros2.internal.block.PublishBlockMask.dispatch('messageTypeEdit', ...
        [modelName '/Publish_CmdVel']);

    add_line(modelName, 'Teleop_Tick/1', 'Teleop_Lin/1', 'autorouting', 'on');
    add_line(modelName, 'Teleop_Tick/1', 'Teleop_Ang/1', 'autorouting', 'on');
    add_line(modelName, 'CmdVel_Blank/1', 'CmdVel_Assign/1', 'autorouting', 'on');
    add_line(modelName, 'Teleop_Lin/1', 'CmdVel_Assign/2', 'autorouting', 'on');
    add_line(modelName, 'Teleop_Ang/1', 'CmdVel_Assign/3', 'autorouting', 'on');
    add_line(modelName, 'CmdVel_Assign/1', 'Publish_CmdVel/1', 'autorouting', 'on');
end
