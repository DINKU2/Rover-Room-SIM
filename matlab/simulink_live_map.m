function y = simulink_live_map(u)
%SIMULINK_LIVE_MAP  Live 2D map for rover_ros_io (scan dots + odom trail).
%
%   Called from Interpreted MATLAB Function block with one concatenated input:
%     u(1:360)       scanX
%     u(361:720)     scanY
%     u(257)         robot x
%     u(258)         robot y

    N = 360;
    scanX = u(1:N);
    scanY = u(N+1:2*N);
    x = u(2*N+1);
    y = u(2*N+2);

    persistent fig ax hScan hTrail hRobot trailX trailY

    if isempty(fig) || ~isvalid(fig)
        fig = figure('Name', 'Simulink Live Map', 'NumberTitle', 'off');
        ax = axes(fig);
        hold(ax, 'on');
        axis(ax, 'equal');
        grid(ax, 'on');
        xlabel(ax, 'x [m]');
        ylabel(ax, 'y [m]');
        title(ax, 'Simulink live map (scan + odom)');
        hScan = plot(ax, nan, nan, 'b.', 'MarkerSize', 8);
        hTrail = plot(ax, nan, nan, 'r-', 'LineWidth', 1.5);
        hRobot = plot(ax, nan, nan, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
        trailX = x;
        trailY = y;
    end

    trailX(end+1) = x;
    trailY(end+1) = y;
    if numel(trailX) > 500
        trailX = trailX(end-499:end);
        trailY = trailY(end-499:end);
    end

    set(hScan, 'XData', scanX, 'YData', scanY);
    set(hTrail, 'XData', trailX, 'YData', trailY);
    set(hRobot, 'XData', x, 'YData', y);
    drawnow limitrate;

    y = 0;
end
