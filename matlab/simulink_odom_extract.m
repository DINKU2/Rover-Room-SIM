function y = simulink_odom_extract(odomBus)
%SIMULINK_ODOM_EXTRACT  Odom bus -> [x; y; z; yaw] for Simulation 3D blocks.
%
%   Used in rover_unreal_cosim.slx OdomExtract block.

    x = odomBus.pose.pose.position.x;
    y = odomBus.pose.pose.position.y;
    z = odomBus.pose.pose.position.z;

    q = odomBus.pose.pose.orientation;
    yaw = atan2(2 * (q.w * q.z + q.x * q.y), 1 - 2 * (q.y^2 + q.z^2));

    y = [x; y; z; yaw];
end
