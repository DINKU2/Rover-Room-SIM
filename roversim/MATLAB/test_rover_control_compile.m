function ok = test_rover_control_compile()
%TEST_ROVER_CONTROL_COMPILE Build model and verify diagram compiles.

matlabFolder = fileparts(mfilename("fullpath"));
addpath(matlabFolder);
model = "RoverTwinControl";

if bdIsLoaded(model)
    close_system(model, 0);
end
build_rover_control_model();
rover_verify_model(model);

fprintf("Updating block diagram...\n");
set_param(model, "SimulationCommand", "update");
fprintf("Update OK\n");

required = ["Pack Translation", "Translation Spec", "Pack Rotation", ...
    "Rotation Spec", "Scale Spec", "Set RoverTwin", "Get RoverTwin"];
for k = 1:numel(required)
    path = model + "/" + required(k);
    assert(~isempty(find_system(model, "SearchDepth", 1, "Name", required(k))), ...
        "Missing block %s", required(k));
    fprintf("  found %s\n", required(k));
end

assert(isempty(find_system(model, "SearchDepth", 1, "Name", "Move RoverTwin")), ...
    "Old Move RoverTwin block still present");
assert(isempty(find_system(model, "SearchDepth", 1, "Name", "Translation Row")), ...
    "Old Translation Row block still present");

ok = true;
fprintf("test_rover_control_compile: PASS\n");
end
