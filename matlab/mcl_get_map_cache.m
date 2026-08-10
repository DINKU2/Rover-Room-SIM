function cache = mcl_get_map_cache(map)
%MCL_GET_MAP_CACHE  Reusable occupancy grid for fast scan scoring.

    persistent lastMapKey lastCache
    mapKey = map_cache_key(map);
    if ~isempty(lastCache) && isequal(lastMapKey, mapKey)
        cache = lastCache;
        return;
    end

    prob = occupancyMatrix(map);
    cache = struct();
    cache.map = map;
    cache.occupied = prob >= 0.65;
    cache.res = map.Resolution;
    cache.nRows = size(prob, 1);
    cache.nCols = size(prob, 2);
    cache.wallRadius = 2;
    if exist('bwdist', 'file') == 2
        cache.wallDistance = bwdist(cache.occupied) ./ cache.res;
    else
        cache.wallDistance = [];
    end
    [cache.xMin, cache.xMax, cache.yMin, cache.yMax] = map_world_limits(map);
    lastMapKey = mapKey;
    lastCache = cache;
end

function key = map_cache_key(map)
    xl = map.XWorldLimits;
    yl = map.YWorldLimits;
    key = sprintf('%.4f_%.4f_%.4f_%d', xl(1), xl(2), yl(1), map.Resolution);
end
