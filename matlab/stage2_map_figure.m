function [mapFig, ax] = stage2_map_figure()
%STAGE2_MAP_FIGURE  Optional live SLAM map plot (save uses separate popup).

    mapFig = figure('Name', 'Stage 2 lidarSLAM map', 'NumberTitle', 'off', ...
        'Position', [700 120 640 520]);
    ax = axes(mapFig);
    title(ax, 'Building map...');
    xlabel(ax, 'x [m]'); ylabel(ax, 'y [m]');
    axis(ax, 'equal'); grid(ax, 'on');
end
