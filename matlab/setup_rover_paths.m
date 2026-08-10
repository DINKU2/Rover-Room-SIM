function setup_rover_paths()
%SETUP_ROVER_PATHS Add matlab/ and simulink/ to the MATLAB path.

    matlabDir = fileparts(mfilename('fullpath'));
    simulinkDir = fullfile(fileparts(matlabDir), 'simulink');
    roversimMatlab = fullfile(fileparts(matlabDir), 'roversim', 'MATLAB');
    dualMatlab = fullfile(fileparts(matlabDir), 'rover-dual', 'matlab');

    addpath(matlabDir);
    if isfolder(simulinkDir)
        addpath(simulinkDir);
    end
    if isfolder(roversimMatlab)
        addpath(roversimMatlab);
    end
    if isfolder(dualMatlab)
        addpath(dualMatlab);
    end
end
