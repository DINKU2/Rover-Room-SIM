function pose = odom_to_xyth(odom)
%ODOM_TO_XYTH  nav_msgs/Odometry -> [x, y, theta] (metres, radians).

    p = odom.pose.pose.position;
    q = odom.pose.pose.orientation;
    pose = [p.x, p.y, quat_to_yaw(q)];
end

function yaw = quat_to_yaw(q)
    siny = 2 * (q.w * q.z + q.x * q.y);
    cosy = 1 - 2 * (q.y * q.y + q.z * q.z);
    yaw = atan2(siny, cosy);
end
