function pose = xyth_apply_rel(pose, rel)
%XYTH_APPLY_REL  Apply relative [dx, dy, dtheta] in the current pose frame.
%
%   pose = xyth_apply_rel(pose, rel)
%
%   Inverse of odom_relative_xyth when chaining odometry deltas onto a MAP pose.

    pose = pose(:)';
    rel = rel(:)';
    c = cos(pose(3));
    s = sin(pose(3));
    pose(1) = pose(1) + c * rel(1) - s * rel(2);
    pose(2) = pose(2) + s * rel(1) + c * rel(2);
    pose(3) = atan2(sin(pose(3) + rel(3)), cos(pose(3) + rel(3)));
end
