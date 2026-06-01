function run_simulink_ros(modelName)
%RUN_SIMULINK_ROS  Prepare ROS env and run a Simulink model.
%
%   run_simulink_ros()              % default: rover_ros_io
%   run_simulink_ros('rover_ros_io')
%
%   Prereq (shell):
%     ./scripts/start_agent.sh
%     ./scripts/check_robot.sh
%
%   Create the model first — see docs/SIMULINK_ROS_BLUEPRINT.md

    if nargin < 1 || strlength(string(modelName)) == 0
        modelName = 'rover_ros_io';
    end

    addpath(fileparts(mfilename('fullpath')));
    setup_ros_humble();

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    slxPath = fullfile(projectRoot, 'simulink', [modelName '.slx']);

    if ~isfile(slxPath)
        error('run_simulink_ros:NoModel', ...
            'Model not found: %s\nCreate it per docs/SIMULINK_ROS_BLUEPRINT.md', slxPath);
    end

    fprintf('Running Simulink model: %s\n', slxPath);
    load_system(slxPath);
    sim(modelName);
end
