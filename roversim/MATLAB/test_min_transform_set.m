function test_min_transform_set()
%TEST_MIN_TRANSFORM_SET Find input format that Transform Set accepts at runtime.

load_system("simulink");
load_system("sim3dlib");
model = "TestTransformSet";
if bdIsLoaded(model)
    close_system(model, 0);
end
new_system(model);
open_system(model);
set_param(model, "Solver", "FixedStepDiscrete", "FixedStep", "0.02", "StopTime", "0.04");

add_block("sim3dlib/Simulation 3D Actor Transform Set", model + "/Set", ...
    "ActorTag", "RoverTwin", "NumberOfParts", "1", "Ts", "0.02", ...
    "Position", [300 100 500 200]);

cases = {
    "row_const",     "[1.25 -0.8 -1.47]", "[0 0 0]", "[1 1 1]", "off"
    "row_comma",     "[1.25, -0.8, -1.47]", "[0, 0, 0]", "[1, 1, 1]", "off"
    "col_const",     "[1.25; -0.8; -1.47]", "[0; 0; 0]", "[1; 1; 1]", "off"
    "row_1d_on",     "[1.25 -0.8 -1.47]", "[0 0 0]", "[1 1 1]", "on"
};

for c = 1:size(cases, 1)
    name = cases{c, 1};
    fprintf("\n--- Case %s ---\n", name);
    if bdIsLoaded(model)
        close_system(model, 0);
    end
    new_system(model);
    add_block("sim3dlib/Simulation 3D Actor Transform Set", model + "/Set", ...
        "ActorTag", "RoverTwin", "NumberOfParts", "1", "Ts", "0.02", ...
        "Position", [300 100 500 200]);
    add_block("simulink/Sources/Constant", model + "/T", ...
        "Value", cases{c, 2}, "VectorParams1D", cases{c, 5}, ...
        "Position", [120 60 200 90]);
    add_block("simulink/Sources/Constant", model + "/R", ...
        "Value", cases{c, 3}, "VectorParams1D", cases{c, 5}, ...
        "Position", [120 110 200 140]);
    add_block("simulink/Sources/Constant", model + "/S", ...
        "Value", cases{c, 4}, "VectorParams1D", cases{c, 5}, ...
        "Position", [120 160 200 190]);
    add_line(model, "T/1", "Set/1");
    add_line(model, "R/1", "Set/2");
    add_line(model, "S/1", "Set/3");
    try
        set_param(model, "SimulationCommand", "update");
        ph = get_param(model + "/Set", "PortHandles");
        for i = 1:3
            d = get_param(ph.Inport(i), "CompiledPortDimensions");
            fprintf("  In%d dims=%s\n", i, d);
        end
        % Runtime check via compiled model step without Unreal
        rt = sldebug(model);
        fprintf("  update OK\n");
    catch ME
        fprintf("  update FAIL: %s\n", ME.message);
    end
end
close_system(model, 0);
end
