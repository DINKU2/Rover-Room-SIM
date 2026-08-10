function paths = rover_dual_setup_paths(dualMatlab)
%ROVER_DUAL_SETUP_PATHS Add dual, shared ROS, sim, and Simulink folders.

if nargin < 1 || strlength(string(dualMatlab)) == 0
    dualMatlab = fileparts(mfilename("fullpath"));
end

paths.dualMatlab = char(dualMatlab);
paths.dualRoot = fileparts(paths.dualMatlab);
paths.projectRoot = fileparts(paths.dualRoot);
paths.sharedMatlab = fullfile(paths.projectRoot, "matlab");
paths.sharedSimulink = fullfile(paths.projectRoot, "simulink");
paths.simMatlab = fullfile(paths.projectRoot, "roversim", "MATLAB");
paths.dualSimulink = fullfile(paths.dualRoot, "simulink");

addpath(paths.dualMatlab);
addpath(paths.sharedMatlab);
addpath(paths.sharedSimulink);
addpath(paths.simMatlab);
addpath(paths.dualSimulink);
end

