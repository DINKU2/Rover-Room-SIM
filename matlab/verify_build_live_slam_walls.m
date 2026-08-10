function [wallPts, nScans] = verify_build_live_slam_walls(slam, minScans)
%VERIFY_BUILD_LIVE_SLAM_WALLS  Occupancy walls from running lidarSLAM session.

    if nargin < 2
        minScans = 5;
    end

    wallPts = zeros(0, 2);
    nScans = 0;

    if isempty(slam) || isempty(which('buildMap'))
        return;
    end

    [scans, poses] = scansAndPoses(slam);
    nScans = numel(scans);
    if nScans < minScans
        return;
    end

    map = buildMap(scans, poses, slam.MapResolution, slam.MaxLidarRange);
    wallPts = slam_map_wall_points(map);
end
