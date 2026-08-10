function rover_simulink_setup_path()
%ROVER_SIMULINK_SETUP_PATH  Add matlab/ to path (call from model InitFcn).
%
%   Uses the saved .slx location: .../simulink/rover_ros_io.slx -> .../matlab/

    slxFile = get_param(bdroot, 'FileName');
    if strlength(string(slxFile)) == 0
        matlabDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'matlab');
    else
        matlabDir = fullfile(fileparts(fileparts(slxFile)), 'matlab');
    end

    if ~isfolder(matlabDir)
        error('rover_simulink_setup_path:MissingMatlab', 'Not found: %s', matlabDir);
    end
    addpath(matlabDir);
end
