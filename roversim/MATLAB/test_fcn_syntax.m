function test_fcn_syntax()
load_system("simulink");
model = "FcnSyntaxTest";
exprs = {
    "[u(1) u(2) u(3)]"
    "[u[0] u[1] u[2]]"
    "[u(1),u(2),u(3)]"
    "u"
    };
for k = 1:numel(exprs)
    if bdIsLoaded(model)
        close_system(model, 0);
    end
    new_system(model);
    add_block("simulink/Sources/Constant", model + "/C", ...
        "Value", "[1 2 3]", "VectorParams1D", "off", ...
        "Position", [50 50 100 80]);
    add_block("simulink/User-Defined Functions/Fcn", model + "/F", ...
        "expr", exprs{k}, "Position", [150 50 200 80]);
    add_block("simulink/Sinks/Terminator", model + "/T", "Position", [250 50 270 80]);
    add_line(model, "C/1", "F/1");
    add_line(model, "F/1", "T/1");
    try
        set_param(model, "SimulationCommand", "update");
        fprintf("PASS: %s\n", exprs{k});
    catch ME
        fprintf("FAIL: %s -> %s\n", exprs{k}, ME.message);
    end
end
close_system(model, 0);
end
