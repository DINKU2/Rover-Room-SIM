function y = simulink_map_pose_to_unreal(u)
%SIMULINK_MAP_POSE_TO_UNREAL  MAP pose -> Sim3D Set_RoverTwin [x;y;z;yaw].

    persistent spawnPose
    t0 = tic;

    if isempty(spawnPose)
        setup_rover_paths();
        spawn = rover_spawn_pose();
        cfg = rover_cmd_vel_config();
        spawnPose = [spawn.sim_m(1); spawn.sim_m(2); spawn.sim_m(3); ...
            cfg.mesh_yaw_sign * deg2rad(spawn.yaw_deg + cfg.mesh_yaw_offset_deg)];
    end

    if numel(u) < 4 || u(4) < 0.5
        y = spawnPose;
        stage4_timing('record', 'slx.map_to_unreal', toc(t0) * 1000);
        return;
    end

    pose = map_pose_to_unreal_sim3d(u(1), u(2), u(3));
    y = [pose.x; pose.y; pose.z; pose.yaw];

    if ~simulink_pose_in_room(y(1), y(2))
        simulink_stage4_debug('unreal_clamp', struct( ...
            'map', u(1:3)', 'unreal', y, 'reason', 'out_of_room'));
        y = spawnPose;
    end

    simulink_stage4_debug('unreal', struct( ...
        'map', u(1:3)', 'valid_in', u(4), 'unreal_x', y(1), ...
        'unreal_y', y(2), 'unreal_yaw', y(4)));
    stage4_timing('record', 'slx.map_to_unreal', toc(t0) * 1000);
end

function tf = simulink_pose_in_room(x, y)
    tf = x >= -6.0 && x <= 6.0 && y >= -5.0 && y <= 6.0;
end
