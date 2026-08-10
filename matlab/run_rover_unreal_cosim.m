function run_rover_unreal_cosim(launchEditor, waitSec)
%RUN_ROVER_UNREAL_COSIM Launch UE 5.3 + run rover_unreal_cosim.slx.
%
%   run_rover_unreal_cosim()           launch UE, wait 45s, sim()
%   run_rover_unreal_cosim(false)      sim() only (UE must already be open)
%   run_rover_unreal_cosim(true, 60)   custom wait before sim()
%
%   Workflow:
%     1. ./scripts/start_agent.sh  + robot on (for /odom)
%     2. run_rover_unreal_cosim()
%     3. When Simulink runs, click Play in Unreal Editor

    if nargin < 1
        launchEditor = true;
    end
    if nargin < 2
        waitSec = 90;
    end

    matlabDir = fileparts(mfilename('fullpath'));
    addpath(matlabDir);
    paths = rover_unreal_paths();

    if strlength(getenv('ROVER_UE_ROOT')) == 0
        setenv('ROVER_UE_ROOT', paths.ueRoot);
    end

    setup_ros_humble();

    slxPath = paths.simulinkCosimModel;
    if ~isfile(slxPath)
        build_rover_unreal_cosim();
    end

    if launchEditor
        fprintf('=== Step 1: launch Unreal Editor (RoverTwin MyRoom) ===\n');
        launch_unreal_editor(paths.cosimProject);
        logFile = roverCosimLogFile(paths);
        if ~waitForUnrealEditor(waitSec, logFile)
            error('rover:unreal:NotReady', ...
                ['Unreal Editor not ready after %ds.\n' ...
                 'Open RoverTwin, load /Game/Maps/MyRoom, then retry.\n' ...
                 'Log: %s'], waitSec, logFile);
        end
    else
        fprintf('Skipping UE launch — ensure RoverTwin MyRoom is open in Unreal Editor.\n');
        if ~isUnrealEditorRunning()
            warning('rover:unreal:NotRunning', ...
                'UnrealEditor process not found. Run ./scripts/start_rovertwin_cosim.sh first.');
        end
    end

    fprintf('=== Step 3: sim(''%s'') ===\n', paths.simulinkCosimModelName);
    fprintf(['When Simulink is running, click Play in Unreal Editor.\n' ...
        'Teleop keys: i/k forward/back, j/l turn, space stop.\n\n']);

    sim(paths.simulinkCosimModelName);
end

function running = isUnrealEditorRunning()
    if ispc
        [status, ~] = system('tasklist /FI "IMAGENAME eq UnrealEditor.exe" 2>nul | find /I "UnrealEditor.exe" >nul');
        running = status == 0;
    else
        [status, ~] = system('pgrep -x UnrealEditor >/dev/null 2>&1');
        running = status == 0;
    end
end

function logFile = roverCosimLogFile(paths)
    if contains(paths.cosimProject, 'RoverTwin')
        logFile = paths.roverTwinCosimLog;
    else
        logFile = paths.autoVrtlCosimLog;
    end
end

function ok = waitForUnrealEditor(maxWaitSec, logFile)
    if nargin < 2
        paths = rover_unreal_paths();
        logFile = roverCosimLogFile(paths);
    end
    ok = false;
    if isUnrealEditorRunning() && isfile(logFile)
        txt = fileread(logFile);
        if contains(txt, 'Total Editor Startup Time')
            ok = true;
            return;
        end
    end
    fprintf('=== Step 2: waiting up to %ds for editor load ===\n', maxWaitSec);
    t0 = tic;
    while toc(t0) < maxWaitSec
        if isUnrealEditorRunning()
            if isfile(logFile)
                txt = fileread(logFile);
                if contains(txt, 'Total Editor Startup Time')
                    ok = true;
                    fprintf('Unreal Editor ready (%.0fs).\n', toc(t0));
                    return;
                end
            elseif toc(t0) > 30
                ok = true;
                fprintf('UnrealEditor running (no log yet, assuming ready).\n');
                return;
            end
        end
        pause(2);
    end
end
