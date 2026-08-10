function test_static_mesh_inputs2()
matlabFolder = fileparts(mfilename("fullpath"));
addpath(matlabFolder);
unrealProject = rover_unreal_project_alias();
load_system("simulink");
load_system("drivingsim3d");
load_system("sim3dlib");

model = "StaticMeshInputTest2";
if bdIsLoaded(model)
    close_system(model, 0);
end

function tryCase(label, makeBlocks)
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
    add_block("simulink/Sinks/Terminator", model + "/t1", "Position", [700 330 720 350]);
    add_block("simulink/Sinks/Terminator", model + "/t2", "Position", [700 380 720 400]);
    add_block("simulink/Sinks/Terminator", model + "/t3", "Position", [700 430 720 450]);
    add_line(model, "Actor/1", "t1/1");
    add_line(model, "Actor/2", "t2/1");
    add_line(model, "Actor/3", "t3/1");
    makeBlocks(model);
    try
        set_param(model, "SimulationCommand", "update");
        fprintf("PASS: %s\n", label);
    catch ME
        msg = ME.message;
        if ~isempty(ME.cause)
            msg = ME.cause{1}.message;
        end
        fprintf("FAIL: %s -> %s\n", label, msg);
    end
end

tryCase("reshape", @(m) wireReshape(m));
tryCase("matlabFcn", @(m) wireMatlabFcn(m));
tryCase("busCreator", @(m) wireBus(m));
close_system(model, 0);
end

function wireReshape(m)
vals = {"[0, 0, -1.46674649]", "[0, 0, 0]", "[1, 1, 1]"};
names = ["T", "R", "S"];
y = [40, 100, 160];
for i = 1:3
    add_block("simulink/Sources/Constant", m + "/" + names(i), ...
        "Value", vals{i}, "VectorParams1D", "off", ...
        "Position", [120 y(i) 180 y(i)+20]);
    add_block("simulink/Math Operations/Reshape", m + "/Reshape" + names(i), ...
        "OutputDimensions", "[1 3]", "Position", [240 y(i) 290 y(i)+20]);
    add_line(m, names(i) + "/1", "Reshape" + names(i) + "/1");
    add_line(m, "Reshape" + names(i) + "/1", "Actor/" + i);
end
end

function wireMatlabFcn(m)
add_block("simulink/User-Defined Functions/MATLAB Function", m + "/Pose", ...
    "Position", [180 80 320 180]);
add_block("simulink/Sources/Clock", m + "/Clock", "Position", [80 110 110 130]);
add_line(m, "Clock/1", "Pose/1");
% edit programmatically is hard; use three separate fcn blocks
for i = 1:3
    nm = ["Tr", "Ro", "Sc"];
    add_block("simulink/User-Defined Functions/MATLAB Function", m + "/" + nm(i), ...
        "Position", [180 40*i 280 40*i+30]);
end
end

function wireBus(m)
% skip if reshape works
end
