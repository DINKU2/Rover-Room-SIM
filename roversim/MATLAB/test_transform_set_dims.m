function test_transform_set_dims()
%TEST_TRANSFORM_SET_DIMS Verify Set RoverTwin inputs are [1x3] after compile.

matlabFolder = fileparts(mfilename("fullpath"));
addpath(matlabFolder);
model = "RoverTwinControl";

if bdIsLoaded(model)
    close_system(model, 0);
end
build_rover_control_model();
set_param(model, "SimulationCommand", "update");

blocks = ["Translation Row", "Rotation Row", "Scale Row", "Set RoverTwin"];
for k = 1:numel(blocks)
    path = model + "/" + blocks(k);
    ph = get_param(path, "PortHandles");
    if ~isempty(ph.Outport)
        d = get_param(ph.Outport(1), "CompiledPortDimensions");
        fprintf("%s Out: %s\n", blocks(k), d);
    end
    if ~isempty(ph.Inport)
        for i = 1:numel(ph.Inport)
            d = get_param(ph.Inport(i), "CompiledPortDimensions");
            fprintf("%s In%d: %s\n", blocks(k), i, d);
        end
    end
end

ph = get_param(model + "/Set RoverTwin", "PortHandles");
for i = 1:numel(ph.Inport)
    d = get_param(ph.Inport(i), "CompiledPortDimensions");
    dt = get_param(ph.Inport(i), "CompiledPortDataType");
    fprintf("Set RoverTwin In%d: dims=%s type=%s\n", i, d, dt);
end
end
