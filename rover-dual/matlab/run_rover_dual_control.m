function run_rover_dual_control()
%RUN_ROVER_DUAL_CONTROL Open and run the dual sim + real rover model (Stage 4).
%
% Shell prereqs:
%   ./scripts/start_agent.sh
%   ./scripts/check_robot.sh
%
% MATLAB prereqs:
%   maps/unreal_alignment.mat  (run_manual_align_slam after Stage 2)

open_rover_dual_control();

modelName = "rover_dual_control";
fprintf("Running Simulink model: %s\n", get_param(modelName, "FileName"));
fprintf("Stage 4: teleop drives real rover; MCL MAP pose syncs Unreal twin.\n");
fprintf("Verify overlay opens automatically (same MCL pose as twin).\n");
fprintf("  LEFT: gray map + live scan + yellow triangle (MCL pose)\n");
fprintf("  RIGHT: Unreal frame — cyan triangle = where twin should be\n");
fprintf("  Magenta dot = spawn  |  Uses maps/mcl_lidar_offset.mat + saved map\n");
fprintf("Twin: MCL pose @ 10 Hz cosim; gate 5 cm / 8 deg deadband (burst+cooldown).\n");
fprintf("Bypass gate: setenv('STAGE4_GATE','0'). Wrong pose? re-run manual align.\n");
fprintf("Debug: Command Window + maps/stage4_pose_debug.log (every 0.5 s)\n");
fprintf("Timing: maps/stage4_timing.log  (run_stage4_timing_profile to benchmark)\n");
fprintf("Pre-check: run_stage4_pose_debug(20) while driving — odom must change.\n");
if rover_dual_use_external_teleop()
    fprintf("Drive: source ./setup.bash && ./scripts/run_teleop.sh  (separate terminal)\n");
    fprintf("  i=fwd  ,=back  j/l=turn  q/z=speed  space=stop\n");
else
    fprintf("Click Simulink Rover Teleop, then WASD.\n");
end
fprintf("\n");
sim(modelName);
end

