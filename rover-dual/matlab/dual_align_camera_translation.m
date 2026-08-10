function camStr = dual_align_camera_translation(projectRoot, spawn)
%DUAL_ALIGN_CAMERA_TRANSLATION  Camera above aligned MAP origin (Sim3D metres).

    cam = [spawn.sim_m(1), spawn.sim_m(2), spawn.sim_m(3) + 2.5];
    alignPath = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
    if isfile(alignPath)
        try
            setup_rover_paths();
            p = map_pose_to_unreal_sim3d(0, 0, 0);
            cam = [p.x, p.y, p.z + 2.5];
        catch
        end
    end
    camStr = mat2str(cam, 8);
end
