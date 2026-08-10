function test_rover_model_dims()
%TEST_ROVER_MODEL_DIMS Compile RoverTwinControl and print port dimensions.

matlabFolder = fileparts(mfilename("fullpath"));
addpath(matlabFolder);
model = "RoverTwinControl";
slx = fullfile(matlabFolder, model + ".slx");

if bdIsLoaded(model)
    close_system(model, 0);
end
if ~isfile(slx)
    build_rover_control_model();
else
    load_system(slx);
end

fprintf("=== Block parameters ===\n");
for blk = ["Translation", "Rotation", "Move RoverTwin"]
    path = model + "/" + blk;
    try
        bt = get_param(path, "BlockType");
        mt = get_param(path, "MaskType");
        fprintf("%s: BlockType=%s MaskType=%s\n", blk, bt, mt);
        if blk == "Translation" || blk == "Rotation"
            fn = fieldnames(get_param(path));
            for p = ["Mode", "ConcatenateDimension", "NumInputs"]
                try
                    fprintf("  %s = %s\n", p, get_param(path, p));
                catch
                end
            end
        end
    catch ME
        fprintf("%s: %s\n", blk, ME.message);
    end
end

fprintf("\n=== Compiling (update diagram) ===\n");
try
    set_param(model, "SimulationCommand", "update");
    fprintf("Update OK\n");
catch ME
    fprintf("Update FAILED: %s\n", ME.message);
    if ~isempty(ME.cause)
        for k = 1:numel(ME.cause)
            fprintf("  Cause: %s\n", ME.cause{k}.message);
        end
    end
end

fprintf("\n=== Port dimensions after update ===\n");
reportPort(model + "/Translation", "Out");
reportPort(model + "/Rotation", "Out");
reportPort(model + "/Move RoverTwin", "In");

fprintf("\n=== Attempt short simulation (0.04s) ===\n");
try
    set_param(model, "StopTime", "0.04");
    simOut = sim(model, "StopTime", "0.04");
    fprintf("Sim OK\n");
catch ME
    fprintf("Sim FAILED: %s\n", ME.message);
    if ~isempty(ME.cause)
        for k = 1:numel(ME.cause)
            fprintf("  Cause: %s\n", ME.cause{k}.message);
        end
    end
end
end

function reportPort(path, dir)
try
    ph = get_param(path, "PortHandles");
    if dir == "Out"
        ports = ph.Outport;
        label = "Out";
    else
        ports = ph.Inport;
        label = "In";
    end
    for i = 1:numel(ports)
        try
            d = get_param(ports(i), "CompiledPortDimensions");
            dt = get_param(ports(i), "CompiledPortDataType");
            fprintf("%s %s%d: dims=%s type=%s\n", path, label, i, d, dt);
        catch ME
            fprintf("%s %s%d: (no compiled info) %s\n", path, label, i, ME.message);
        end
    end
catch ME
    fprintf("%s: %s\n", path, ME.message);
end
end
