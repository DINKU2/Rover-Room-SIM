function run_simulink_ros(modelName)
%RUN_SIMULINK_ROS  Prepare ROS env and run a Simulink model.
%
%   run_simulink_ros()              % default: rover_ros_io
%   run_simulink_ros('rover_ros_io')
%
%   Prereq (shell):
%     ./scripts/start_agent.sh
%     ./scripts/check_robot.sh

    if nargin < 1 || strlength(string(modelName)) == 0
        modelName = 'rover_ros_io';
    end

    setup_rover_paths();
    setup_ros_humble();

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    slxPath = fullfile(projectRoot, 'simulink', [modelName '.slx']);

    if ~isfile(slxPath)
        error('run_simulink_ros:NoModel', 'Model not found: %s', slxPath);
    end

    if strcmp(modelName, 'rover_ros_io')
        patch_rover_ros_io_callbacks(modelName);
    end

    if ~bdIsLoaded(modelName)
        load_system(slxPath);
    end

    fprintf('Running Simulink model: %s\n', slxPath);
    simulink_teleop_utils('clear');
    fprintf(['Teleop: click "Simulink Rover Teleop", hold W/A/S/D (arrows OK).\n' ...
        'Q slower, E faster, Space stop.\n\n']);

    sim(modelName);
end
