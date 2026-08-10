function test_concat_dims()
load_system("simulink");
model = "ConcatTest";
if bdIsLoaded(model)
    close_system(model, 0);
end
new_system(model);
open_system(model);

add_block("simulink/Sources/Constant", model + "/a", "Value", "1", "Position", [50 50 80 70]);
add_block("simulink/Sources/Constant", model + "/b", "Value", "2", "Position", [50 100 80 120]);
add_block("simulink/Sources/Constant", model + "/c", "Value", "3", "Position", [50 150 80 170]);

add_block("simulink/Signal Routing/Vector Concatenate", model + "/vc", ...
    "NumInputs", "3", "Mode", "Vector", "ConcatenateDimension", "2", ...
    "Position", [150 80 200 140]);
add_line(model, "a/1", "vc/1");
add_line(model, "b/1", "vc/2");
add_line(model, "c/1", "vc/3");

add_block("simulink/Sinks/Terminator", model + "/term", "Position", [250 100 270 120]);
add_line(model, "vc/1", "term/1");

set_param(model, "SimulationCommand", "update");
ph = get_param(model + "/vc", "PortHandles");
d = get_param(ph.Outport(1), "CompiledPortDimensions");
fprintf("VectorConcat dim2 output: %s\n", d);

% Constant [1 1 1] test
add_block("simulink/Sources/Constant", model + "/ones", ...
    "Value", "[1 1 1]", "VectorParams1D", "off", "Position", [50 220 100 250]);
add_block("simulink/Sinks/Terminator", model + "/term2", "Position", [150 220 170 240]);
add_line(model, "ones/1", "term2/1");
set_param(model, "SimulationCommand", "update");
ph2 = get_param(model + "/ones", "PortHandles");
d2 = get_param(ph2.Outport(1), "CompiledPortDimensions");
fprintf("Constant [1 1 1] VectorParams1D off: %s\n", d2);

add_block("simulink/Sources/Constant", model + "/ones2", ...
    "Value", "[1,1,1]", "VectorParams1D", "on", "Position", [50 280 100 310]);
add_block("simulink/Sinks/Terminator", model + "/term3", "Position", [150 280 170 300]);
add_line(model, "ones2/1", "term3/1");
set_param(model, "SimulationCommand", "update");
ph3 = get_param(model + "/ones2", "PortHandles");
d3 = get_param(ph3.Outport(1), "CompiledPortDimensions");
fprintf("Constant [1,1,1] VectorParams1D on: %s\n", d3);

close_system(model, 0);
end
