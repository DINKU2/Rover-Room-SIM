function stage2_save_from_window(saveFig)
%STAGE2_SAVE_FROM_WINDOW  Save map now; update popup status text.

    if ~isgraphics(saveFig)
        return;
    end

    ud = saveFig.UserData;
    if ud.saving
        stage2_save_window_set_status(saveFig, 'Save already in progress...');
        return;
    end

    slam = ud.slam;
    [scans, ~] = scansAndPoses(slam);
    nScans = numel(scans);
    if nScans == 0
        stage2_save_window_set_status(saveFig, ...
            'No scans yet — drive the robot first, then save.');
        fprintf('[Stage 2] Save skipped: no scans yet.\n');
        return;
    end

    ud.saving = true;
    saveFig.UserData = ud;
    set(ud.saveBtn, 'Enable', 'off');

    msg = sprintf('Saving %d scans... (1–3 min, please wait)', nScans);
    stage2_save_window_set_status(saveFig, msg);
    fprintf('\n[Stage 2] Saving map from %d scans...\n', nScans);
    drawnow;

    try
        paths = stage2_save_lidar_map(slam);
        shortMat = paths.mat;
        if numel(shortMat) > 52
            shortMat = ['...' shortMat(end-48:end)];
        end
        stage2_save_window_set_status(saveFig, ...
            sprintf('SAVED (%d scans)\n%s', nScans, shortMat));
        set(ud.saveBtn, 'String', 'Saved — press 5 to save again');
    catch ME
        stage2_save_window_set_status(saveFig, ...
            sprintf('SAVE FAILED:\n%s', ME.message));
        fprintf('[Stage 2] Save failed: %s\n', ME.message);
    end

    ud = saveFig.UserData;
    ud.saving = false;
    saveFig.UserData = ud;
    if isgraphics(ud.saveBtn)
        set(ud.saveBtn, 'Enable', 'on');
    end
end
