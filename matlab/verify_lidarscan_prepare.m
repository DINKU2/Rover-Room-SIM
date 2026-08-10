function ls = verify_lidarscan_prepare(lsRaw, ctx)
%VERIFY_LIDARSCAN_PREPARE  Apply mirror + angle offset for MCL / overlay.

    ls = lsRaw;
    if nargin < 2 || isempty(ctx)
        return;
    end

    if isfield(ctx, 'lidarMirror') && ctx.lidarMirror
        angles = -ls.Angles;
        ranges = ls.Ranges;
        if iscolumn(ranges) && ~iscolumn(angles)
            angles = angles';
        elseif isrow(ranges) && iscolumn(angles)
            angles = angles';
        end
        ls = lidarScan(ranges, angles);
    end

    if isfield(ctx, 'lidarAngleOffset') && abs(ctx.lidarAngleOffset) > 1e-9
        ls = lidarscan_apply_offset(ls, ctx.lidarAngleOffset);
    end
end
