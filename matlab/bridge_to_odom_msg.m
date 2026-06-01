function msg = bridge_to_odom_msg(raw)
%BRIDGE_TO_ODOM_MSG  Bridge JSON → struct like nav_msgs/Odometry for receive() callers.

    msg = struct();
    msg.pose = struct();
    msg.pose.pose = struct();
    msg.pose.pose.position = struct('x', raw.x, 'y', raw.y, 'z', raw.z);
    msg.pose.pose.orientation = struct('x', raw.qx, 'y', raw.qy, 'z', raw.qz, 'w', raw.qw);
end
