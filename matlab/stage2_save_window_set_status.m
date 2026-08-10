function stage2_save_window_set_status(saveFig, msg)
%STAGE2_SAVE_WINDOW_SET_STATUS  Update popup status label.

    if ~isgraphics(saveFig)
        return;
    end
    ud = saveFig.UserData;
    if isfield(ud, 'statusText') && isgraphics(ud.statusText)
        set(ud.statusText, 'String', msg);
    end
    drawnow limitrate;
end
