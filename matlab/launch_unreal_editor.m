function ok = launch_unreal_editor(projectPath)
%LAUNCH_UNREAL_EDITOR Open Unreal Editor for Simulink co-simulation.
%
%   ok = launch_unreal_editor()
%   ok = launch_unreal_editor(uprojectPath)
%
%   R2024b on Linux: sim3d.Editor is unavailable — launches UE 5.3 directly
%   via scripts/launch_unreal_532.sh (AutoVrtlEnv by default).

    if nargin < 1 || strlength(string(projectPath)) == 0
        paths = rover_unreal_paths();
        projectPath = paths.cosimProject;
    end

    if ~isfile(projectPath)
        error('rover:unreal:MissingProject', 'Unreal project not found: %s', projectPath);
    end

    paths = rover_unreal_paths();
    ok = false;

    if exist('sim3d.Editor', 'file') == 2 && usejava('desktop')
        try
            setenv('MATLABROOT', matlabroot);
            editor = sim3d.Editor(projectPath);
            ok = open(editor);
            if ok ~= 0
                fprintf('Opened Unreal via sim3d.Editor: %s\n', projectPath);
                return;
            end
            fprintf('sim3d.Editor returned 0 — falling back to direct launch.\n');
        catch ME
            fprintf('sim3d.Editor failed (%s) — falling back to direct launch.\n', ME.message);
        end
    end

    if ~isfile(paths.ueEditor)
        error('rover:unreal:MissingEditor', ...
            'Unreal Editor not found: %s\nSet ROVER_UE_ROOT to UE 5.3 install.', paths.ueEditor);
    end

    if isfile(paths.startRoverTwinCosimScript) && contains(projectPath, 'RoverTwin')
        cmd = sprintf('env ROVER_UE_ROOT=%s MATLAB_R2024B_ROOT=%s bash "%s" --bg', ...
            paths.ueRoot, matlabroot, paths.startRoverTwinCosimScript);
        fprintf('Launching RoverTwin co-sim editor (wait for ready):\n  %s\n', cmd);
        status = system(cmd);
        ok = status == 0;
        if ~ok
            error('rover:unreal:LaunchFailed', ...
                ['RoverTwin launch failed (exit %d). Run in terminal:\n  %s\n' ...
                 'Log: %s'], status, paths.startRoverTwinCosimScript, paths.roverTwinCosimLog);
        end
        return;
    end

    if isfile(paths.startAutoVrtlCosimScript) && contains(projectPath, 'AutoVrtlEnv')
        cmd = sprintf('env ROVER_UE_ROOT=%s MATLAB_R2024B_ROOT=%s bash "%s" --bg', ...
            paths.ueRoot, matlabroot, paths.startAutoVrtlCosimScript);
        fprintf('Launching Unreal Editor (wait for ready):\n  %s\n', cmd);
        status = system(cmd);
        ok = status == 0;
        if ~ok
            error('rover:unreal:LaunchFailed', ...
                ['Unreal launch failed (exit %d). Run in terminal:\n  %s\n' ...
                 'Log: %s'], status, paths.startAutoVrtlCosimScript, paths.autoVrtlCosimLog);
        end
        return;
    end

    cmd = sprintf('env ROVER_UE_ROOT=%s MATLAB_R2024B_ROOT=%s ROVER_UE_COSIM=1 bash "%s" "%s"', ...
        paths.ueRoot, matlabroot, paths.launchScript, projectPath);
    fprintf('Launching Unreal Editor (background):\n  %s\n', cmd);
    status = system([cmd ' &']);
    ok = status == 0;
    if ~ok
        error('rover:unreal:LaunchFailed', 'Failed to launch Unreal (exit %d).', status);
    end

    fprintf(['Unreal Editor starting. Wait for the project to finish loading, ' ...
        'then click Play after sim() begins.\n']);
end
