function fix_livemap_output()
%FIX_LIVEMAP_OUTPUT  Fix LiveMap "Too many output arguments" simulation error.

    matlabDir = fileparts(mfilename('fullpath'));
    addpath(matlabDir);
    slxPath = fullfile(fileparts(matlabDir), 'simulink', 'rover_ros_io.slx');
    modelName = 'rover_ros_io';

    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    load_system(slxPath);

    liveMap = [modelName '/LiveMap'];
    assertBlockExists(liveMap);
    set_param(liveMap, 'MATLABFcn', 'simulink_live_map(u)');
    set_param(liveMap, 'OutputDimensions', '1');

    term = [modelName '/LiveMap_Out'];
    try
        get_param(term, 'Handle');
    catch
        add_block('simulink/Sinks/Terminator', term, 'Position', [1100 148 1120 162]);
    end

    ph = get_param(liveMap, 'PortHandles');
    if numel(ph.Outport) >= 1
        lh = get_param(ph.Outport(1), 'Line');
        if lh <= 0
            add_line(modelName, 'LiveMap/1', 'LiveMap_Out/1', 'autorouting', 'on');
        end
    end

    set_param(modelName, 'InitFcn', sprintf('addpath(''%s'');', matlabDir));
    set_param(modelName, 'SimulationCommand', 'update');
    save_system(modelName, slxPath);
    fprintf('Fixed LiveMap output in %s\n', slxPath);
    bdclose(modelName);
end

function assertBlockExists(path)
    try
        get_param(path, 'Handle');
    catch
        error('Missing block: %s', path);
    end
end
