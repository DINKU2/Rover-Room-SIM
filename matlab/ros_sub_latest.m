function msg = ros_sub_latest(sub)
%ROS_SUB_LATEST  Non-blocking read of subscriber LatestMessage (Simulink-safe).

    msg = ros_sub_read(sub, 0);
end
