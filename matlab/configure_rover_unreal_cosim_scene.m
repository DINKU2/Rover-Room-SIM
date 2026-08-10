function info = configure_rover_unreal_cosim_scene(modelNames)
%CONFIGURE_ROVER_UNREAL_COSIM_SCENE Path 3 step 4: Simulink -> RoverTwin MyRoom.
%
%   info = configure_rover_unreal_cosim_scene()
%   info = configure_rover_unreal_cosim_scene({'rover_unreal_cosim'})
%
%   Sets Simulation 3D Scene Configuration:
%     Scene source = Unreal Editor
%     Project      = RoverSIMUunreal-Linux/RoverTwin/RoverTwin.uproject
%     Scene path   = /Game/Maps/MyRoom  (for executable mode reference)

    if nargin < 1 || isempty(modelNames)
        paths = rover_unreal_paths();
        modelNames = {paths.simulinkCosimModelName, paths.simulinkModelName};
    end

    paths = rover_unreal_paths();
    if ~isfile(paths.roverTwinProject)
        error('rover:unreal:MissingProject', 'RoverTwin project not found: %s', paths.roverTwinProject);
    end
    if ~isfile(paths.roverTwinLevelMap)
        error('rover:unreal:MissingMap', ...
            'MyRoom.umap not found: %s\nRun ./scripts/verify_rovertwin_myroom.sh', paths.roverTwinLevelMap);
    end

    info = struct('project', paths.cosimProject, 'scene', paths.roverTwinScene, ...
        'models', {{}}, 'updated', {{}});

    for i = 1:numel(modelNames)
        modelName = char(modelNames{i});
        slxPath = fullfile(paths.projectRoot, 'simulink', [modelName '.slx']);
        if ~isfile(slxPath)
            warning('rover:unreal:MissingModel', 'Skipping missing model: %s', slxPath);
            continue;
        end

        if bdIsLoaded(modelName)
            close_system(modelName, 0);
        end
        load_system(slxPath);
        blockPath = [modelName '/Scene_Configuration'];
        if ~strcmp(get_param(blockPath, 'BlockType'), 'SubSystem')
            error('rover:unreal:MissingBlock', ...
                'Scene_Configuration block not found in %s', modelName);
        end

        set_param(blockPath, ...
            'ProjectFormat', 'Unreal Editor', ...
            'UEProjPath', paths.cosimProject, ...
            'ScenePath', paths.roverTwinScene);
        set_param(modelName, 'SimulationCommand', 'update');
        save_system(modelName, slxPath);

        info.models{end+1} = modelName; %#ok<AGROW>
        info.updated{end+1} = slxPath; %#ok<AGROW>
        fprintf('Configured %s -> %s (%s)\n', modelName, paths.cosimProject, paths.roverTwinScene);
    end
end
