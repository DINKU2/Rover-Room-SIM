function ros_cmd_vel(ctx, linearX, angularZ)
%ROS_CMD_VEL  Publish /cmd_vel via ROS Toolbox (DDS).

    if ~isfield(ctx, 'cmdPub')
        error('ros_cmd_vel:NoPub', 'Call ros_connect() first.');
    end
    twist = ros2message(ctx.cmdPub);
    twist.linear.x = linearX;
    twist.angular.z = angularZ;
    send(ctx.cmdPub, twist);
end
