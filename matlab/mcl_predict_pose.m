function predicted = mcl_predict_pose(ctx, odomPose, fallbackPose)
%MCL_PREDICT_POSE  MAP pose from odom anchor + delta.

    if isfield(ctx, 'manualPose') && ~isempty(ctx.manualPose)
        predicted = ctx.manualPose;
        return;
    end
    if isfield(ctx, 'odomAnchor') && ~isempty(ctx.odomAnchor) && ...
            ~isempty(odomPose) && all(isfinite(odomPose(1:3)))
        rel = odom_relative_xyth(ctx.odomAnchor.odom, odomPose);
        predicted = xyth_apply_rel(ctx.odomAnchor.map, rel);
        return;
    end
    predicted = fallbackPose;
end
