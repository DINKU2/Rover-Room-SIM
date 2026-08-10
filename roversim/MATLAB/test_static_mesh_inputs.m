function test_static_mesh_inputs()
% Minimal model to learn exact input dimensions for Static Mesh Actor block.

matlabFolder = fileparts(mfilename("fullpath"));
addpath(matlabFolder);
unrealProject = rover_unreal_project_alias();

load_system("simulink");
load_system("drivingsim3d");
load_system("sim3dlib");

model = "StaticMeshInputTest";
if bdIsLoaded(model)
    close_system(model, 0);
end
new_system(model);

add_block("drivingsim3d/Simulation 3D Scene Configuration", model + "/Scene", ...
    "ProjectFormat", "Unreal Editor", ...
    "UEProjPath", unrealProject, ...
    "ScenePath", "/Game/Maps/MyRoom", ...
    "Ts", "0.02", ...
    "Position", [400 30 640 170]);

add_block("sim3dlib/Simulation 3D Static Mesh Actor", model + "/Actor", ...
    "ActorTag", "RoverTwin", ...
    "ActorControl", "on", ...
    "ControlledActor", "RoverTwin", ...
    "Mobility", "Moveable", ...
    "InitialPos", "[0, 0, -1.46674649]", ...
    "InitialRot", "[0, 0, 0]", ...
    "InitialScale", "[1, 1, 1]", ...
    "SampleTime", "0.02", ...
    "Position", [400 320 640 490]);

cases = {
    "row_bracket",   "[0, 0, -1.46674649]", "[0, 0, 0]", "[1, 1, 1]", "off"
    "row_space",     "[0 0 -1.46674649]",   "[0 0 0]",   "[1 1 1]",   "off"
    "row_1x3",       "zeros(1,3)",          "zeros(1,3)", "ones(1,3)", "off"
    };

for i = 1:size(cases, 1)
    name = cases{i, 1};
    if bdIsLoaded(model)
        close_system(model, 0);
    end
    new_system(model);
    add_block("drivingsim3d/Simulation 3D Scene Configuration", model + "/Scene", ...
        "ProjectFormat", "Unreal Editor", "UEProjPath", unrealProject, ...
        "ScenePath", "/Game/Maps/MyRoom", "Ts", "0.02", "Position", [400 30 640 170]);
    add_block("sim3dlib/Simulation 3D Static Mesh Actor", model + "/Actor", ...
        "ActorTag", "RoverTwin", "ActorControl", "on", "ControlledActor", "RoverTwin", ...
        "Mobility", "Moveable", "InitialPos", "[0, 0, -1.46674649]", ...
        "InitialRot", "[0, 0, 0]", "InitialScale", "[1, 1, 1]", ...
        "SampleTime", "0.02", "Position", [400 320 640 490]);

    add_block("simulink/Sources/Constant", model + "/T", "Value", cases{i, 2}, ...
        "VectorParams1D", cases{i, 5}, "Position", [200 40 280 60]);
    add_block("simulink/Sources/Constant", model + "/R", "Value", cases{i, 3}, ...
        "VectorParams1D", cases{i, 5}, "Position", [200 100 280 120]);
    add_block("simulink/Sources/Constant", model + "/S", "Value", cases{i, 4}, ...
        "VectorParams1D", cases{i, 5}, "Position", [200 160 280 180]);
    add_block("simulink/Sinks/Terminator", model + "/t1", "Position", [700 330 720 350]);
    add_block("simulink/Sinks/Terminator", model + "/t2", "Position", [700 380 720 400]);
    add_block("simulink/Sinks/Terminator", model + "/t3", "Position", [700 430 720 450]);
    add_line(model, "T/1", "Actor/1");
    add_line(model, "R/1", "Actor/2");
    add_line(model, "S/1", "Actor/3");
    add_line(model, "Actor/1", "t1/1");
    add_line(model, "Actor/2", "t2/1");
    add_line(model, "Actor/3", "t3/1");

    try
        set_param(model, "SimulationCommand", "update");
        fprintf("PASS update: %s\n", name);
    catch ME
        fprintf("FAIL update: %s -> %s\n", name, ME.message);
        if ~isempty(ME.cause)
            fprintf("   %s\n", ME.cause{1}.message);
        end
    end
end
close_system(model, 0);
end
