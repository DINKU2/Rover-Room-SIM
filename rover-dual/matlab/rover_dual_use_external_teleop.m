function tf = rover_dual_use_external_teleop()
%ROVER_DUAL_USE_EXTERNAL_TELEOP  True when /cmd_vel comes from run_teleop.sh.
%
%   Default ON (recommended): ./scripts/run_teleop.sh in a separate terminal.
%   MATLAB/Simulink handles MCL + Unreal only — no figure teleop, no async publish.
%
%   Disable external teleop (use MATLAB WASD figure instead):
%     setenv('STAGE4_EXTERNAL_TELEOP','0')
%
%   Enable explicitly (default):
%     setenv('STAGE4_EXTERNAL_TELEOP','1')

    raw = getenv("STAGE4_EXTERNAL_TELEOP");
    if strlength(strtrim(raw)) == 0
        tf = true;
        return;
    end
    tf = ~ismember(lower(strtrim(raw)), ["0", "false", "off", "no"]);
end
