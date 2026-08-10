function rover_dual_wait_for_pie(timeoutSec)
%ROVER_DUAL_WAIT_FOR_PIE  Block until Unreal Editor PIE session is running.

    if nargin < 1 || isempty(timeoutSec)
        timeoutSec = 120;
    end

    dualMatlab = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(fileparts(dualMatlab));
    logFile = fullfile(projectRoot, 'roversim', 'RoverTwin', 'Saved', 'Logs', ...
        'SimulinkEditorLaunch.log');

    fprintf('[Stage 4] Waiting for Unreal Play (PIE) — auto Alt+P or click Play...\n');
    t0 = tic;
    while toc(t0) < timeoutSec
        if isfile(logFile)
            txt = fileread(logFile);
            if contains(txt, 'SIMULINK_PIE_STARTED') || contains(txt, 'New page: PIE session:')
                fprintf('[Stage 4] Unreal PIE ready (%.0f s).\n', toc(t0));
                pause(2);
                return;
            end
            if contains(txt, 'SIMULINK_PIE_SHORTCUT_FAILED')
                break;
            end
        end
        pause(1);
    end

    warning('RoverDual:PIETimeout', ...
        ['Unreal PIE not detected within %d s.\n' ...
        'In Unreal Editor click Play, wait for the scene, then Run Simulink again.'], ...
        timeoutSec);
end
