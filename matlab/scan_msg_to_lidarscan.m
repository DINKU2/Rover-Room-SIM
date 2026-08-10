function ls = scan_msg_to_lidarscan(scan)
%SCAN_MSG_TO_LIDARSCAN  sensor_msgs/LaserScan -> nav lidarScan (invalid removed).

    try
        ls = lidarScan(scan);
    catch
        [ranges, angles] = scan_to_ranges_angles(scan);
        ls = lidarScan(ranges, angles);
    end

    if isempty(ls.Ranges)
        error('stage2:EmptyScan', 'LaserScan has no valid ranges after filtering.');
    end

    ls = removeInvalidData(ls);
end
