function manual_align_close_figures()
%MANUAL_ALIGN_CLOSE_FIGURES  Close stale manual SLAM align UI windows.

    figs = findall(groot, 'Type', 'figure', '-regexp', 'Name', 'Manual SLAM align');
    for k = 1:numel(figs)
        fig = figs(k);
        try
            fig.WindowKeyPressFcn = '';
            fig.WindowKeyReleaseFcn = '';
            fig.KeyPressFcn = '';
            fig.CloseRequestFcn = '';
        catch
        end
        try
            delete(fig);
        catch
        end
    end
end
