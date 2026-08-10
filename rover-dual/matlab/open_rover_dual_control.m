function open_rover_dual_control()
%OPEN_ROVER_DUAL_CONTROL Open or create the dual sim + real rover model.

dualMatlab = fileparts(mfilename("fullpath"));
dualRoot = fileparts(dualMatlab);
modelName = "rover_dual_control";
modelPath = fullfile(dualRoot, "simulink", modelName + ".slx");

rover_dual_setup_paths(dualMatlab);

build_rover_dual_control_model();
load_system(modelPath);
open_system(modelPath);
set_param(char(modelName), "ZoomFactor", "FitSystem");
end
