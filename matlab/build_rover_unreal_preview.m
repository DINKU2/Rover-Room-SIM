function slxPath = build_rover_unreal_preview()
%BUILD_ROVER_UNREAL_PREVIEW Minimal Simulink model to open UE from MATLAB.
%
%   slxPath = build_rover_unreal_preview()
%
%   Creates simulink/rover_unreal_preview.slx with one block:
%     Simulation 3D Scene Configuration  (Scene source = Unreal Editor)

    paths = rover_unreal_paths();
    setup_unreal_matlab(false);

    modelDir = fullfile(paths.projectRoot, 'simulink');
    modelName = paths.simulinkModelName;
    slxPath = paths.simulinkModel;

    if ~isfolder(modelDir)
        mkdir(modelDir);
    end

    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    if isfile(slxPath)
        delete(slxPath);
    end

    new_system(modelName);
    open_system(modelName);

    load_system('sim3dlib');
    add_block('sim3dlib/Simulation 3D Scene Configuration', ...
        [modelName '/Scene_Configuration'], ...
        'Position', [120 120 320 220]);

    set_param(modelName, ...
        'SolverType', 'Fixed-step', ...
        'Solver', 'FixedStepAuto', ...
        'FixedStep', '0.02', ...
        'StopTime', 'inf');

    set_param([modelName '/Scene_Configuration'], ...
        'ProjectFormat', 'Unreal Editor', ...
        'UEProjPath', paths.cosimProject, ...
        'ScenePath', paths.roverTwinScene);

    set_param(modelName, 'SimulationCommand', 'update');
    save_system(modelName, slxPath);
    open_system(slxPath);

    fprintf('Created Simulink preview model: %s\n', slxPath);
    fprintf('  UE project: %s\n', paths.cosimProject);
    fprintf('Next: open_unreal_room(''matlab'') or sim(''%s'')\n', modelName);
end
