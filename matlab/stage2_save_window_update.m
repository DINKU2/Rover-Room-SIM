function stage2_save_window_update(saveFig, scanCount, mapPose)
%STAGE2_SAVE_WINDOW_UPDATE  Refresh scan count on save popup (not while saving).

    if ~isgraphics(saveFig)
        return;
    end
    ud = saveFig.UserData;
    if ud.saving
        return;
    end
    ud.scanCount = scanCount;
    saveFig.UserData = ud;

    status = sprintf(['Scans: %d\nMAP  x=%+.2f  y=%+.2f  yaw=%+.0f deg\n' ...
        'Press 5 or click Save map now'], ...
        scanCount, mapPose(1), mapPose(2), rad2deg(mapPose(3)));
    stage2_save_window_set_status(saveFig, status);
end
