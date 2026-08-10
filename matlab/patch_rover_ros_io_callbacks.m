function patch_rover_ros_io_callbacks(modelName)
%PATCH_ROVER_ROS_IO_CALLBACKS  Fix model callbacks so teleop works when Run is pressed.

    if nargin < 1 || strlength(string(modelName)) == 0
        modelName = 'rover_ros_io';
    end
    modelName = char(modelName);

    matlabDir = fileparts(mfilename('fullpath'));
    addpath(matlabDir);
    projectRoot = fileparts(matlabDir);
    slxPath = fullfile(projectRoot, 'simulink', [modelName '.slx']);

    if ~isfile(slxPath)
        error('patch_rover_ros_io_callbacks:NoModel', 'Missing %s', slxPath);
    end

    wasLoaded = bdIsLoaded(modelName);
    if ~wasLoaded
        load_system(slxPath);
    end

    % InitFcn must add matlab/ to path before StartFcn/StopFcn run.
    % Inline addpath works even when nothing from matlab/ is on the path yet.
    initPath = ['addpath(fullfile(fileparts(fileparts(get_param(bdroot,''FileName''))),''matlab''));' newline ...
        'simulink_teleop_utils(''clear'');'];
    currentInit = strtrim(get_param(modelName, 'InitFcn'));
    if ~contains(currentInit, 'simulink_teleop_utils(''clear'')')
        set_param(modelName, 'InitFcn', initPath);
    elseif ~contains(currentInit, 'addpath(fullfile(fileparts(fileparts(get_param(bdroot')
        set_param(modelName, 'InitFcn', [initPath newline currentInit]);
    end

    set_param(modelName, 'StartFcn', 'simulink_teleop_start();');
    set_param(modelName, 'StopFcn', 'simulink_teleop_stop();');

    save_system(modelName, slxPath);
    fprintf('Patched %s callbacks (InitFcn adds matlab/ to path).\n', slxPath);

    if ~wasLoaded
        bdclose(modelName);
    end
end
