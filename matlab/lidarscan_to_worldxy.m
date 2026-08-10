function [wx, wy, ranges] = lidarscan_to_worldxy(ls, pose)
%LIDARSCAN_TO_WORLDXY  lidarScan endpoints in world (MAP) frame.
%
%   [wx, wy] = lidarscan_to_worldxy(ls, pose)
%   [wx, wy, ranges] = lidarscan_to_worldxy(ls, pose)

    ranges = ls.Ranges;
    angles = ls.Angles;
    if iscolumn(ranges)
        ranges = ranges';
    end
    if iscolumn(angles)
        angles = angles';
    end

    valid = isfinite(ranges) & ranges >= 0.1 & ranges <= 8.0;
    r = ranges(valid);
    a = angles(valid);
    if isempty(r)
        wx = [];
        wy = [];
        ranges = [];
        return;
    end

    lx = r .* cos(a);
    ly = r .* sin(a);
    c = cos(pose(3));
    s = sin(pose(3));
    wx = pose(1) + c * lx - s * ly;
    wy = pose(2) + s * lx + c * ly;
    ranges = r;
end
