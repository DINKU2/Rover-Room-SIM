function wire_simulink_live_map()
%WIRE_SIMULINK_LIVE_MAP  Wire Vector Concatenate + LiveMap into rover_ros_io.slx.

    matlabDir = fileparts(mfilename('fullpath'));
    addpath(matlabDir);
    projectRoot = fileparts(matlabDir);
    modelName = 'rover_ros_io';
    slxPath = fullfile(projectRoot, 'simulink', [modelName '.slx']);

    if ~isfile(slxPath)
        error('wire_simulink_live_map:NoModel', 'Model not found: %s', slxPath);
    end

    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    load_system(slxPath);

    scanToMap = findBlock(modelName, {'ScanToMap', 'MATLAB Function'});
    if isempty(scanToMap)
        error('wire_simulink_live_map:NoScanToMap', ...
            'Add a MATLAB Function block named ScanToMap first.');
    end
    if ~endsWith(scanToMap, 'ScanToMap')
        set_param(scanToMap, 'Name', 'ScanToMap');
    end
    if isempty(findBlock(modelName, {'OdomExtract'}))
        error('wire_simulink_live_map:NoOdomExtract', 'OdomExtract not found.');
    end

    removeBlocks(modelName, {'LiveMap_Out', 'LiveMap', 'MapInputs', ...
        'Interpreted MATLAB Function'});

    clearOutportLines(modelName, 'ScanToMap', [1 2]);
    clearOutportLines(modelName, 'OdomExtract', [1 2]);

    concatPath = [modelName '/MapInputs'];
    add_block('simulink/Signal Routing/Vector Concatenate', concatPath, ...
        'Position', [820 120 850 220]);
    set_param(concatPath, 'NumInputs', '4');

    interpBlock = sprintf('simulink/User-Defined\nFunctions/Interpreted MATLAB\nFunction');
    liveMapPath = [modelName '/LiveMap'];
    add_block(interpBlock, liveMapPath, 'Position', [920 130 1040 210]);
    set_param(liveMapPath, 'MATLABFcn', 'simulink_live_map(u)');
    set_param(liveMapPath, 'OutputDimensions', '1');

    termPath = [modelName '/LiveMap_Out'];
    add_block('simulink/Sinks/Terminator', termPath, 'Position', [1100 148 1120 162]);

    add_line(modelName, 'ScanToMap/1', 'MapInputs/1', 'autorouting', 'on');
    add_line(modelName, 'ScanToMap/2', 'MapInputs/2', 'autorouting', 'on');
    add_line(modelName, 'OdomExtract/1', 'MapInputs/3', 'autorouting', 'on');
    add_line(modelName, 'OdomExtract/2', 'MapInputs/4', 'autorouting', 'on');
    add_line(modelName, 'MapInputs/1', 'LiveMap/1', 'autorouting', 'on');
    add_line(modelName, 'LiveMap/1', 'LiveMap_Out/1', 'autorouting', 'on');

    set_param(modelName, 'InitFcn', sprintf('addpath(''%s'');', matlabDir));
    set_param(modelName, 'SimulationCommand', 'update');
    save_system(modelName, slxPath);
    fprintf('Wired LiveMap in %s\n', slxPath);
end

function path = findBlock(modelName, names)
    path = '';
    for i = 1:numel(names)
        candidate = [modelName '/' names{i}];
        try
            get_param(candidate, 'Handle');
            path = candidate;
            return;
        catch
        end
    end
end

function removeBlocks(modelName, blockNames)
    for i = 1:numel(blockNames)
        path = [modelName '/' blockNames{i}];
        try
            delete_block(path);
        catch
        end
    end
end

function clearOutportLines(modelName, blockName, portNums)
    blockPath = [modelName '/' blockName];
    ph = get_param(blockPath, 'PortHandles');
    for p = portNums
        if p > numel(ph.Outport)
            continue;
        end
        lh = get_param(ph.Outport(p), 'Line');
        if lh > 0
            delete_line(lh);
        end
    end
end
