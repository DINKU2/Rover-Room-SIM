function [scanX, scanY] = simulink_scan_to_map(x, y, yaw, ranges, angle_min, angle_increment, range_min, range_max)
%SIMULINK_SCAN_TO_MAP  Project lidar ranges into odom-frame XY (360 rays).
%
%   Used inside ScanToMap MATLAB Function block in rover_ros_io.slx.

    N = 360;
    scanX = nan(N, 1);
    scanY = nan(N, 1);

    c = cos(yaw);
    s = sin(yaw);

    for i = 1:N
        if i > numel(ranges)
            continue;
        end
        ri = ranges(i);
        if ~isfinite(ri) || ri <= 0 || ri < range_min || ri > range_max
            continue;
        end
        ang = angle_min + (i - 1) * angle_increment;
        lx = ri * cos(ang);
        ly = ri * sin(ang);
        scanX(i) = x + c * lx - s * ly;
        scanY(i) = y + s * lx + c * ly;
    end
end
