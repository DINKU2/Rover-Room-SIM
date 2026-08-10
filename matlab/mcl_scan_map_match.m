function result = mcl_scan_map_match(map, ls, pose)
%MCL_SCAN_MAP_MATCH  Scan-vs-wall match (score + plot points).

    result = struct('score', 0, 'wx', [], 'wy', [], 'onWall', []);
    cache = mcl_get_map_cache(map);
    [wx, wy, ranges] = lidarscan_to_worldxy(ls, pose);
    if isempty(wx)
        return;
    end

    step = max(1, floor(numel(wx) / 120));
    wx = wx(1:step:end);
    wy = wy(1:step:end);
    ranges = ranges(1:step:end);

    onWall = mcl_points_on_wall_cached(cache, wx, wy);
    score = mcl_weighted_wall_score(onWall, ranges);

    result.score = score;
    result.wx = wx;
    result.wy = wy;
    result.onWall = onWall;
end

function score = mcl_weighted_wall_score(onWall, ranges)
    wallW = 1 ./ max(min(max(ranges, 0.4), 6.0), 0.4);
    if sum(wallW) > 0
        score = sum(onWall .* wallW) / sum(wallW);
    else
        score = mean(onWall);
    end
end

function onWall = mcl_points_on_wall_cached(cache, wx, wy)
    [rows, cols, inBounds] = map_world_to_grid_indices(cache.map, wx, wy);
    radius = 2;
    if isfield(cache, 'wallRadius') && cache.wallRadius >= 1
        radius = cache.wallRadius;
    end

    onWall = false(size(wx));
    occ = cache.occupied;
    for k = 1:numel(wx)
        if ~inBounds(k)
            continue;
        end
        r = rows(k);
        c = cols(k);
        if occ(r, c)
            onWall(k) = true;
        else
            onWall(k) = mcl_neighbor_occupied(occ, r, c, radius);
        end
    end
end

function hit = mcl_neighbor_occupied(occ, r, c, radius)
    hit = false;
    nr = size(occ, 1);
    nc = size(occ, 2);
    for dr = -radius:radius
        for dc = -radius:radius
            rr = r + dr;
            cc = c + dc;
            if rr >= 1 && rr <= nr && cc >= 1 && cc <= nc && occ(rr, cc)
                hit = true;
                return;
            end
        end
    end
end
