function [ranges, angles] = scan_to_ranges_angles(scan)
%SCAN_TO_RANGES_ANGLES  sensor_msgs/LaserScan -> valid ranges and angles.

    ranges = scan.ranges(:);
    n = numel(ranges);
    angles = scan.angle_min + (0:n - 1)' * scan.angle_increment;

    valid = isfinite(ranges) & ranges >= scan.range_min & ranges <= scan.range_max;
    ranges = ranges(valid);
    angles = angles(valid);
end
