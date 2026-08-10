function rel = odom_relative_xyth(prevPose, currPose)
%ODOM_RELATIVE_XYTH  Relative [dx, dy, dtheta] from prev to curr in prev frame.
%
%   Used as relPoseEst for lidarSLAM/addScan. prevPose and currPose are
%   [x, y, theta] in the odometry frame.

    dx = currPose(1) - prevPose(1);
    dy = currPose(2) - prevPose(2);
    c = cos(prevPose(3));
    s = sin(prevPose(3));

    rel = zeros(1, 3);
    rel(1) = c * dx + s * dy;
    rel(2) = -s * dx + c * dy;
    rel(3) = atan2(sin(currPose(3) - prevPose(3)), cos(currPose(3) - prevPose(3)));
end
