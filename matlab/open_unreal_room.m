function open_unreal_room(mode)
%OPEN_UNREAL_ROOM Launch Unreal with the Rover-Room-SIM room mesh.
%
%   open_unreal_room()           Open via sim3d.Editor (or direct fallback)
%   open_unreal_room('preview')  Open editor directly (no Simulink Run)
%   open_unreal_room('executable') Launch packaged Linux build if present
%   open_unreal_room('rovertwin')  Open RoverTwin editor (room + rover)
%   open_unreal_room('rovertwin_exe') Launch packaged RoverTwin Linux build
%   open_unreal_room('matlab')   Open via sim3d.Editor (MathWorks path)
%   open_unreal_room('simulink') Build/open preview Simulink model
%
%   RoverRoomSIM modes create unreal/RoverRoomSIM on first use.
%   RoverTwin modes use buildrover/ only (no RoverRoomSIM setup).

    if nargin < 1
        mode = 'auto';
    end
    mode = lower(mode);

    paths = rover_unreal_paths();

    switch mode
        case {'rovertwin_exe', 'rovertwin-executable'}
            run_rovertwin_executable(paths);

        case 'rovertwin'
            ensure_rovertwin_ready(paths);
            launch_rovertwin_editor(paths);

        case 'executable'
            if ~room_package_ready(paths)
                ensure_room_project_ready(paths);
            end
            run_room_executable(paths);

        case 'preview'
            ensure_room_project_ready(paths);
            launch_unreal_direct(paths);

        case 'simulink'
            info = setup_unreal_matlab(false);
            slxPath = build_rover_unreal_cosim();
            open_system(slxPath);
            fprintf(['Simulink co-sim model ready.\n' ...
                '  run_rover_unreal_cosim()   % launches UE + sim()\n' ...
                '  run_rover_unreal_cosim(false)  % sim only (UE already open)\n']);

        case {'matlab', 'auto'}
            info = setup_unreal_matlab(false);
            if info.autoVrtlReady
                build_rover_unreal_preview();
                launch_unreal_editor(paths.cosimProject);
                print_post_open_help('matlab');
            else
                fprintf('MathWorks UE add-on not installed — using direct editor launch.\n');
                ensure_room_project_ready(paths);
                launch_unreal_direct(paths);
            end

        otherwise
            error('rover:unreal:BadMode', ...
                'Unknown mode "%s". Use preview, executable, rovertwin, rovertwin_exe, matlab, simulink, or auto.', mode);
    end
end

function ensure_room_project_ready(paths)
    if ~isfile(paths.roomFbx)
        error('rover:unreal:MissingFbx', 'Room mesh not found: %s', paths.roomFbx);
    end
    if isfile(paths.uproject)
        return;
    end
    fprintf('Creating RoverRoomSIM Unreal project...\n');
    status = system(['bash "' paths.setupScript '"']);
    if status ~= 0
        error('rover:unreal:SetupFailed', ...
            'setup_unreal_project.sh failed (exit %d). See output above.', status);
    end
end

function ensure_rovertwin_ready(paths)
    if ~isfile(paths.roomFbx)
        error('rover:unreal:MissingFbx', 'Room mesh not found: %s', paths.roomFbx);
    end
    if ~isfile(paths.roverTwinProject)
        error('rover:unreal:MissingProject', ...
            'RoverTwin project not found: %s', paths.roverTwinProject);
    end
    if isfile(paths.roverTwinImportFlag) && isfile(paths.roverTwinLevelMap)
        return;
    end
    fprintf('Importing RoverTwin scene (my_room.fbx + rover meshes)...\n');
    status = system(['bash "' paths.setupRoverTwinScript '"']);
    if status ~= 0
        error('rover:unreal:SetupFailed', ...
            'setup_rovertwin.sh failed (exit %d). See output above.', status);
    end
end

function tf = room_package_ready(paths)
    candidates = {
        fullfile(paths.roomProjectDir, 'Packaged', 'Linux', 'RoverRoomSIM.sh')
        fullfile(paths.roomProjectDir, 'Packaged', 'Linux', 'RoverRoomSIM', 'RoverRoomSIM.sh')
    };
    tf = any(cellfun(@isfile, candidates));
end

function launch_unreal_direct(paths)
    if ~isfile(paths.uproject)
        error('rover:unreal:MissingProject', 'Unreal project not found: %s', paths.uproject);
    end
    setenv('ROVER_UE_COSIM', '0');
    cmd = sprintf('bash "%s" "%s"', paths.launchScript, paths.uproject);
    fprintf('Launching: %s\n', cmd);
    status = system([cmd ' &']);
    if status ~= 0
        error('rover:unreal:LaunchFailed', 'Failed to launch Unreal (exit %d).', status);
    end
    print_post_open_help('preview');
end

function launch_rovertwin_editor(paths)
    if ~isfile(paths.roverTwinProject)
        error('rover:unreal:MissingProject', ...
            ['RoverTwin not found: %s\nRun: ./scripts/setup_rovertwin.sh'], paths.roverTwinProject);
    end
    setenv('ROVER_UE_COSIM', '0');
    cmd = sprintf('bash "%s" "%s"', paths.launchScript, paths.roverTwinProject);
    fprintf('Launching RoverTwin editor: %s\n', cmd);
    status = system([cmd ' &']);
    if status ~= 0
        error('rover:unreal:LaunchFailed', 'Failed to launch RoverTwin (exit %d).', status);
    end
    print_post_open_help('rovertwin');
end

function run_rovertwin_executable(paths)
    if ~isfile(paths.launchRoverTwinExeScript)
        error('rover:unreal:MissingLauncher', ...
            'Launch script not found: %s', paths.launchRoverTwinExeScript);
    end
    setenv('ROVER_UE_COSIM', '0');
    cmd = sprintf('bash "%s" &', paths.launchRoverTwinExeScript);
    fprintf('Launching packaged RoverTwin (NVIDIA Vulkan): %s\n', paths.launchRoverTwinExeScript);
    status = system(cmd);
    if status ~= 0
        error('rover:unreal:LaunchFailed', 'Failed to launch RoverTwin package (exit %d).', status);
    end
    print_post_open_help('rovertwin_exe');
end

function run_room_executable(paths)
    candidates = {
        fullfile(paths.roomProjectDir, 'Packaged', 'Linux', 'RoverRoomSIM.sh')
        fullfile(paths.roomProjectDir, 'Packaged', 'Linux', 'RoverRoomSIM', 'RoverRoomSIM.sh')
    };
    packaged = '';
    for i = 1:numel(candidates)
        if isfile(candidates{i})
            packaged = candidates{i};
            break;
        end
    end
    if packaged == ""
        error('rover:unreal:NoPackage', ...
            ['Packaged build not found under %s/Packaged/Linux/\n' ...
             'Run: ./scripts/package_rover_room.sh'], paths.roomProjectDir);
    end
    setenv('ROVER_UE_COSIM', '0');
    cmd = sprintf('bash "%s" &', packaged);
    fprintf('Launching packaged room viewer: %s\n', packaged);
    status = system(cmd);
    if status ~= 0
        error('rover:unreal:LaunchFailed', 'Failed to launch packaged build (exit %d).', status);
    end
    print_post_open_help('executable');
end

function print_post_open_help(launchMode)
    fprintf('\n--- Unreal room preview ---\n');
    fprintf('Room mesh source: matlab/my_room.fbx\n');
    if strcmp(launchMode, 'matlab')
        fprintf(['Co-simulation: sim(''rover_unreal_preview''), then Play in Unreal Editor.\n']);
        fprintf('Import room into AutoVrtlEnv level: Content Browser -> import my_room.fbx\n');
    elseif any(strcmp(launchMode, {'rovertwin', 'rovertwin_exe'}))
        fprintf('RoverTwin uses matlab/my_room.fbx + buildrover rover OBJ meshes.\n');
        fprintf('Editor: open_unreal_room(''rovertwin''). Package: PackageRoverTwin_Linux.sh\n');
    else
        fprintf('Look for SM_MyRoom under Content/Room after import completes.\n');
        fprintf('Standalone build: ./scripts/package_rover_room.sh\n');
    end
    if ~any(strcmp(launchMode, {'executable', 'rovertwin_exe'}))
        fprintf('Packaged viewer: open_unreal_room(''executable'') or open_unreal_room(''rovertwin_exe'')\n');
    end
end
