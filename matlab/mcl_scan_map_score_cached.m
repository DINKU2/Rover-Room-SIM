function score = mcl_scan_map_score_cached(cache, ls, pose)
%MCL_SCAN_MAP_SCORE_CACHED  Fast score using pre-built map cache (init search).

    [wx, wy, ranges] = lidarscan_to_worldxy(ls, pose);
    if isempty(wx)
        score = 0;
        return;
    end
    step = max(1, floor(numel(wx) / 120));
    wx = wx(1:step:end);
    wy = wy(1:step:end);
    ranges = ranges(1:step:end);

    if isfield(cache, 'wallDistance') && ~isempty(cache.wallDistance)
        score = likelihood_field_score(cache, wx, wy, ranges);
    else
        onWall = mcl_points_on_wall_cached(cache, wx, wy);
        score = mcl_weighted_wall_score(onWall, ranges);
    end
end

function score = likelihood_field_score(cache, wx, wy, ranges)
    [rows, cols, inBounds] = map_world_to_grid_indices(cache.map, wx, wy);
    d = 1.5 * ones(size(wx));
    idx = sub2ind([cache.nRows, cache.nCols], rows(inBounds), cols(inBounds));
    d(inBounds) = cache.wallDistance(idx);

    % Standard likelihood-field endpoint model. Equal beam weighting prevents
    % one nearby chair or wall fragment from overpowering the room geometry.
    sigma = 0.20;
    beamLikelihood = 0.08 + 0.92 .* exp(-0.5 .* (d ./ sigma).^2);
    valid = isfinite(ranges) & ranges >= 0.15 & ranges <= 7.5;
    if ~any(valid)
        score = 0;
        return;
    end
    score = mean(beamLikelihood(valid));
end

function score = mcl_weighted_wall_score(onWall, ranges)
    wallW = ones(size(ranges));
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
