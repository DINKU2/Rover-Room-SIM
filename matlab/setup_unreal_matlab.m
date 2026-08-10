function info = setup_unreal_matlab(forceCopy)
%SETUP_UNREAL_MATLAB Prepare Unreal project + MathWorks UE interface.
%
%   info = setup_unreal_matlab()
%   info = setup_unreal_matlab(true)   % refresh AutoVrtlEnv project files

    if nargin < 1
        forceCopy = false;
    end

    paths = rover_unreal_paths();
    info = struct( ...
        'mathworksReady', paths.mathworksReady, ...
        'roomProjectReady', false, ...
        'autoVrtlReady', false, ...
        'messages', {{}});

    if ~isfile(paths.roomFbx)
        error('rover:unreal:MissingFbx', 'Room mesh not found: %s', paths.roomFbx);
    end

    if ~isfile(paths.uproject)
        info.messages{end+1} = 'Creating RoverRoomSIM Unreal project...';
        fprintf('%s\n', info.messages{end});
        status = system(['bash "' paths.setupScript '"']);
        if status ~= 0
            error('rover:unreal:SetupFailed', ...
                'setup_unreal_project.sh failed (exit %d). See output above.', status);
        end
    end
    info.roomProjectReady = isfile(paths.uproject);

    pluginsReady = isfolder(fullfile(paths.pluginDest, 'MathWorksSimulation'));
    projectReady = isfile(paths.autoVrtlEnvProject);

    if paths.mathworksReady
        needProjectRefresh = forceCopy || ~projectReady;
        needPluginInstall = ~pluginsReady;

        if needProjectRefresh || needPluginInstall
            if ~isfolder(paths.unrealRoot)
                mkdir(paths.unrealRoot);
            end
            patchScript = fullfile(paths.projectRoot, 'scripts', 'patch_autovrtlenv_uproject.sh');

            if needPluginInstall
                info.messages{end+1} = 'Installing MathWorks UE plugins + AutoVrtlEnv project...';
                fprintf('%s\n', info.messages{end});
                if isfolder(paths.pluginDest)
                    error('rover:unreal:PluginDirBlocked', ...
                        ['Plugin folder exists but MathWorksSimulation is missing: %s\n' ...
                        'Remove that folder or fix the install, then retry.'], paths.pluginDest);
                end
                sim3d.utils.copyExampleSim3dProject(paths.unrealRoot, ...
                    'PluginDestination', paths.pluginDest);
            elseif needProjectRefresh
                info.messages{end+1} = 'Refreshing AutoVrtlEnv project (plugins already installed)...';
                fprintf('%s\n', info.messages{end});
                rover_copy_autovrtlenv_project(paths);
            end

            if isfile(paths.autoVrtlEnvProject)
                system(['bash "' patchScript '" "' paths.autoVrtlEnvProject '"']);
            end
        else
            info.messages{end+1} = 'AutoVrtlEnv and UE plugins already present.';
            fprintf('%s\n', info.messages{end});
        end

        info.autoVrtlReady = isfile(paths.autoVrtlEnvProject);
        info.mathworksProject = paths.autoVrtlEnvProject;
        info.messages{end+1} = ...
            'MathWorks UE interface ready. Use open_unreal_room(''matlab'') or run_unreal_cosim_setup.';
    else
        info.messages{end+1} = [ ...
            'MathWorks UE interface not found. Install one of: ', ...
            'Vehicle Dynamics / Automated Driving / Aerospace / UAV ', ...
            'Interface for Unreal Engine Projects (Add-On Explorer). ', ...
            'Room preview: open_unreal_room(''preview'').'];
        fprintf('%s\n', info.messages{end});
        fprintf('Checked: %s\n', paths.mathworksSpkgRoot);
    end

    fprintf('Unreal room project: %s\n', paths.uproject);
    if info.autoVrtlReady
        fprintf('MathWorks co-sim project: %s\n', paths.autoVrtlEnvProject);
        roomFlag = fullfile(paths.autoVrtlEnvDir, '.room_mesh_imported');
        if ~isfile(roomFlag)
            fprintf('Copying room mesh assets into AutoVrtlEnv...\n');
            system(['bash "' fullfile(paths.projectRoot, 'scripts', 'setup_autovrtlenv_room.sh') '"']);
        end
    end
end
