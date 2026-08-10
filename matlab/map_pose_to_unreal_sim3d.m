function pose = map_pose_to_unreal_sim3d(xMap, yMap, yawMap, align)
%MAP_POSE_TO_UNREAL_SIM3D  MAP pose -> Transform Set (Y and yaw flipped).
%
%   pose = map_pose_to_unreal_sim3d(x, y, yaw)

    if nargin < 4 || isempty(align)
        ros = map_pose_to_unreal_ros(xMap, yMap, yawMap);
    else
        ros = map_pose_to_unreal_ros(xMap, yMap, yawMap, align);
    end

    spawn = rover_spawn_pose();
    pose.x = ros.x;
    pose.y = -ros.y;
    pose.z = spawn.sim_m(3);
    pose.yaw = -ros.yaw;
end
