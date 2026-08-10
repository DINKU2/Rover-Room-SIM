function test_transform_set_step()
%TEST_TRANSFORM_SET_STEP Short sim to catch Transform Set runtime dimension errors.

matlabFolder = fileparts(mfilename("fullpath"));
addpath(matlabFolder);
model = "RoverTwinControl";

if bdIsLoaded(model)
    close_system(model, 0);
end
build_rover_control_model();
load_system(model);

initFcn = get_param(model, "InitFcn");
stopFcn = get_param(model, "StopFcn");
set_param(model, "InitFcn", "");
set_param(model, "StopFcn", "");
set_param(model, "StopTime", "0.04");

try
    fprintf("Running 0.04s sim (no InitFcn)...\n");
    sim(model, "StopTime", "0.04");
    fprintf("test_transform_set_step: PASS (no stepImpl dimension error)\n");
catch ME
    fprintf("test_transform_set_step: FAIL\n%s\n", ME.message);
    if ~isempty(ME.cause)
        for k = 1:numel(ME.cause)
            fprintf("  cause: %s\n", ME.cause{k}.message);
        end
    end
    rethrow(ME);
finally
    if bdIsLoaded(model)
        set_param(model, "InitFcn", initFcn);
        set_param(model, "StopFcn", stopFcn);
        set_param(model, "StopTime", "inf");
    end
end
end
