function lsOut = lidarscan_apply_offset(ls, angleOffset)
%LIDARSCAN_APPLY_OFFSET  Rotate lidarScan angles (fixes lidar-forward mismatch).

    if nargin < 2 || isempty(angleOffset) || abs(angleOffset) < 1e-9
        lsOut = ls;
        return;
    end

    angles = ls.Angles + angleOffset;
    angles = atan2(sin(angles), cos(angles));
    ranges = ls.Ranges;
    if iscolumn(ranges) && ~iscolumn(angles)
        angles = angles';
    elseif isrow(ranges) && iscolumn(angles)
        angles = angles';
    end
    lsOut = lidarScan(ranges, angles);
end
