function test_row3_pack()
load_system("simulink");
model = "Row3PackTest";
if bdIsLoaded(model)
    close_system(model, 0);
end
new_system(model);

add_block("simulink/Sources/Constant", model + "/a", "Value", "1", "Position", [40 40 70 60]);
add_block("simulink/Sources/Constant", model + "/b", "Value", "2", "Position", [40 80 70 100]);
add_block("simulink/Sources/Constant", model + "/c", "Value", "3", "Position", [40 120 70 140]);
add_block("simulink/Signal Routing/Vector Concatenate", model + "/vc", ...
    "NumInputs", "3", "Mode", "Vector", "ConcatenateDimension", "2", ...
    "Position", [120 70 170 130]);

dims = {"[1 3]", "1-by-3", "[1,3]"};
for k = 1:numel(dims)
    if k > 1
        delete_block(model + "/rs");
        delete_line(model, "vc/1", "rs/1");
        delete_line(model, "rs/1", "term/1");
    end
    add_block("simulink/Math Operations/Reshape", model + "/rs", ...
        "OutputDimensions", dims{k}, "Position", [220 85 270 115]);
    if k == 1
        add_block("simulink/Sinks/Terminator", model + "/term", "Position", [300 90 320 110]);
        add_line(model, "a/1", "vc/1");
        add_line(model, "b/1", "vc/2");
        add_line(model, "c/1", "vc/3");
    end
    add_line(model, "vc/1", "rs/1");
    add_line(model, "rs/1", "term/1");
    try
        set_param(model, "SimulationCommand", "update");
        fprintf("Reshape %s: PASS update\n", dims{k});
    catch ME
        fprintf("Reshape %s: FAIL %s\n", dims{k}, ME.message);
    end
end

% Fcn pass-through after concat
delete_block(model + "/rs");
delete_line(model, "vc/1", "rs/1");
add_block("simulink/User-Defined Functions/Fcn", model + "/F", ...
    "expr", "u", "Position", [220 85 260 115]);
add_line(model, "vc/1", "F/1");
add_line(model, "F/1", "term/1");
try
    set_param(model, "SimulationCommand", "update");
    fprintf("Fcn u pass-through: PASS update\n");
catch ME
    fprintf("Fcn u pass-through: FAIL %s\n", ME.message);
end

close_system(model, 0);
end
