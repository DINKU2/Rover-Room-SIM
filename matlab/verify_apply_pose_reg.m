function poseOut = verify_apply_pose_reg(poseIn, reg)
%VERIFY_APPLY_POSE_REG  Apply live->saved map registration to [x,y,yaw].

    poseOut = poseIn(:)';
    if numel(poseOut) < 3
        poseOut = [poseOut, 0];
    end

    if nargin < 2 || isempty(reg) || ~isfield(reg, 'ready') || ~reg.ready
        return;
    end

    p = reg.R2d * poseIn(1:2)' + reg.t2d(:);
    poseOut = [p(1), p(2), verify_wrap_pi(poseIn(3) + reg.yaw_offset)];
end

function a = verify_wrap_pi(a)
    a = mod(a + pi, 2 * pi) - pi;
end
