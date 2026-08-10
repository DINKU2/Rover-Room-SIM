function info = run_unreal_cosim_setup(openEditor)
%RUN_UNREAL_COSIM_SETUP Full MathWorks UE co-simulation setup (steps 2-5).
%
%   info = run_unreal_cosim_setup()       copy, build model, import room
%   info = run_unreal_cosim_setup(true)   also open sim3d.Editor (GUI)

    if nargin < 1
        openEditor = true;
    end

    fprintf('=== Step 2: copyExampleSim3dProject ===\n');
    info = setup_unreal_matlab(true);
    if ~info.autoVrtlReady
        error('rover:unreal:SetupFailed', ...
            'AutoVrtlEnv not ready after copy. mathworksReady=%d', info.mathworksReady);
    end

    paths = rover_unreal_paths();
    fprintf('=== Step 3: build_rover_unreal_preview + rover_unreal_cosim ===\n');
    build_rover_unreal_preview();
    build_rover_unreal_cosim();

    fprintf('=== Step 4: import my_room.fbx into AutoVrtlEnv ===\n');
    status = system(['bash "' fullfile(paths.projectRoot, 'scripts', 'setup_autovrtlenv_room.sh') '"']);
    if status ~= 0
        warning('rover:unreal:ImportFailed', ...
            'AutoVrtlEnv room import exited with status %d. Import manually in UE if needed.', status);
    end

    if openEditor
        fprintf('=== Step 3b: launch Unreal Editor ===\n');
        launch_unreal_editor(paths.autoVrtlEnvProject);
        fprintf(['Editor launch requested for %s\n' ...
            'Step 5: run_rover_unreal_cosim(false)  OR  sim(''rover_unreal_cosim''), then Play in UE.\n'], ...
            paths.autoVrtlEnvProject);
    else
        fprintf(['Step 5 (manual): sim(''rover_unreal_preview''), then Play in Unreal Editor.\n']);
    end

    info.cosimModel = paths.simulinkModel;
    info.autoVrtlProject = paths.autoVrtlEnvProject;
end
