function [xMin, xMax, yMin, yMax] = map_world_limits(map)
%MAP_WORLD_LIMITS  Axis-aligned world bounds for occupancyMap.

    xMin = map.XWorldLimits(1);
    xMax = map.XWorldLimits(2);
    yMin = map.YWorldLimits(1);
    yMax = map.YWorldLimits(2);
end
