function verify_rover_ros_io_wiring()
    matlabDir = fileparts(mfilename('fullpath'));
    addpath(matlabDir);
    projectRoot = fileparts(matlabDir);
    modelName = 'rover_ros_io';
    slxPath = fullfile(projectRoot, 'simulink', [modelName '.slx']);
    load_system(slxPath);

    required = {'OdomExtract', 'ScanExtract', 'ScanToMap', ...
        'MapInputs', 'LiveMap'};
    for i = 1:numel(required)
        path = [modelName '/' required{i}];
        assertBlockExists(path);
        fprintf('[OK] %s\n', required{i});
    end

    assertBlockExists([modelName '/LiveMap']);
    fcn = get_param([modelName '/LiveMap'], 'MATLABFcn');
    assert(strcmp(fcn, 'simulink_live_map(u)'), 'LiveMap fcn mismatch: %s', fcn);
    fprintf('[OK] LiveMap MATLABFcn = simulink_live_map(u)\n');

    set_param(modelName, 'SimulationCommand', 'update');
    fprintf('[OK] Model update succeeded\n');
    bdclose(modelName);
end

function assertBlockExists(path)
    try
        get_param(path, 'Handle');
    catch
        error('Missing block: %s', path);
    end
end
