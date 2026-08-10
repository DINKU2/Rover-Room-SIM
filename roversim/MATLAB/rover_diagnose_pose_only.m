function rover_diagnose_pose_only()
addpath(fileparts(mfilename("fullpath")));
modelName = "RoverTwinControl";
if ~bdIsLoaded(modelName)
    load_system(fullfile(fileparts(mfilename("fullpath")), modelName + ".slx"));
end
set_param(modelName, "StopTime", "inf");
set_param(modelName, "SimulationCommand", "start");
pause(10);
rtX = get_param(modelName + "/X Position", "RuntimeObject");
rtY = get_param(modelName + "/Y Position", "RuntimeObject");
rtSet = get_param(modelName + "/Pack Translation", "RuntimeObject");
rtGet = get_param(modelName + "/Get RoverTwin", "RuntimeObject");
cmdX = double(rtX.OutputPort(1).Data(1));
cmdY = double(rtY.OutputPort(1).Data(1));
setV = double(rtSet.OutputPort(1).Data(:).');
actV = double(rtGet.OutputPort(1).Data(:).');
fprintf("SIM_POSE|command_xy=(%.4f,%.4f)|set_xyz=(%.4f,%.4f,%.4f)|actual_xyz=(%.4f,%.4f,%.4f)\n", ...
    cmdX, cmdY, setV(1), setV(2), setV(3), actV(1), actV(2), actV(3));
fprintf("SIM_DELTA|set_vs_actual=%.6f\n", norm(setV - actV));
set_param(modelName, "SimulationCommand", "stop");
end
