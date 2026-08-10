function rover_diagnose_rotation(turnKey, runSeconds)
%ROVER_DIAGNOSE_ROTATION  Empirical check of the Transform Set/Get rotation axis.
%
%   Commands a STEADY turn (no forward/back) and logs, every sample:
%       * commanded ROS yaw  (Yaw integrator)
%       * yaw sent to Unreal (Set Yaw Flip, the -yaw half of the RH->LH map)
%       * the full 3-element rotation vector SENT  to Set RoverTwin/2
%       * the full 3-element rotation vector READ  from Get RoverTwin port 2
%
%   The point: confirm WHICH index carries the turn. Per the MathWorks
%   Transform Set reference the order is [pitch, roll, yaw] -> yaw is index 3.
%   If Unreal instead reports the motion on index 2, the mesh is ROLLING
%   (banking) rather than turning flat about Z -- the "wonky" symptom.
%
%   Usage:
%       rover_diagnose_rotation              % left turn, 6 s
%       rover_diagnose_rotation("right", 8)  % right turn, 8 s
%
%   Writes rover_rotation_log.csv next to this file and prints a verdict.

if nargin < 1 || strlength(string(turnKey)) == 0
    turnKey = "left";
end
turnKey = lower(string(turnKey));
if nargin < 2 || isempty(runSeconds)
    runSeconds = 6;
end

here = fileparts(mfilename("fullpath"));
addpath(here);
modelName = "RoverTwinControl";
csvPath = fullfile(here, "rover_rotation_log.csv");

if ~bdIsLoaded(modelName)
    load_system(fullfile(here, modelName + ".slx"));
end

% --- map the turn to the command Constant blocks ---------------------------
left  = double(turnKey == "left"  || turnKey == "a");
right = double(turnKey == "right" || turnKey == "d");
if ~left && ~right
    error("turnKey must be 'left'/'a' or 'right'/'d' (got '%s').", turnKey);
end

set_param(modelName, "StopTime", "inf");
set_param(modelName, "SimulationCommand", "start");
waitForStatus(modelName, "running", 10);

% steady turn, no translation
set_param(modelName + "/Forward Value", "Value", "0");
set_param(modelName + "/Reverse Value", "Value", "0");
set_param(modelName + "/Left Value",    "Value", num2str(left));
set_param(modelName + "/Right Value",   "Value", num2str(right));
set_param(modelName + "/Stop Value",    "Value", "0");

fprintf("\n=== ROTATION DIAGNOSTIC : steady %s turn for %g s ===\n", upper(turnKey), runSeconds);
fprintf("Expected (MathWorks ref): yaw on SENT index 3; Unreal moves on index 3.\n");
fprintf("%-7s | %-9s %-9s | %-27s | %-27s\n", ...
    "t[s]", "yawCmd", "yawSent", "SENT [idx1 idx2 idx3]", "ACTUAL [idx1 idx2 idx3]");
fprintf("%s\n", repmat('-', 1, 92));

dt = 0.25;
n  = max(1, round(runSeconds / dt));
log = nan(n, 9);   % t, yawCmd, yawSent, sent1..3, act1..3
t0 = tic;
row = 0;
gotActual = false;

for k = 1:n
    pause(dt);
    if ~strcmp(get_param(modelName, "SimulationStatus"), "running")
        break
    end
    t = toc(t0);

    yawCmd  = scalarOut(modelName, "Yaw", 1);
    yawSent = scalarOut(modelName, "Set Yaw Flip", 1);
    % Read the live Reshape output (Signal Specification blocks do not expose
    % runtime data); this is the [pitch roll yaw] vector packed for the block.
    sentVec = vecOut(modelName, "Pack Rotation", 1, 3);
    actVec  = getPortData(modelName, "Get RoverTwin", 2, 3);

    if any(abs(actVec) > 1e-9)
        gotActual = true;
    end

    row = row + 1;
    log(row, :) = [t, yawCmd, yawSent, sentVec(:).', actVec(:).'];

    fprintf("%-7.2f | %-9.4f %-9.4f | [% 7.4f % 7.4f % 7.4f] | [% 7.4f % 7.4f % 7.4f]\n", ...
        t, yawCmd, yawSent, sentVec(1), sentVec(2), sentVec(3), ...
        actVec(1), actVec(2), actVec(3));
end

set_param(modelName + "/Left Value",  "Value", "0");
set_param(modelName + "/Right Value", "Value", "0");
set_param(modelName, "SimulationCommand", "stop");

log = log(1:row, :);
writeLog(csvPath, log);

% --- verdict ---------------------------------------------------------------
fprintf("%s\n", repmat('=', 1, 92));
if row == 0
    fprintf("No samples captured. Was the model running? Try open_rover_control first.\n");
    return
end

sentRange = max(log(:,4:6), [], 1) - min(log(:,4:6), [], 1);
[~, sentIdx] = max(sentRange);
fprintf("SENT rotation: largest change on index %d (range p/r/y = [%.4f %.4f %.4f]).\n", ...
    sentIdx, sentRange(1), sentRange(2), sentRange(3));
if sentIdx == 3
    fprintf("  -> Correct: yaw is being written to the Z slot (index 3).\n");
else
    fprintf("  -> WRONG: yaw landing on index %d. Rebuild the model (open_rover_control).\n", sentIdx);
end

if ~gotActual
    fprintf(["\nACTUAL feedback is all ~0 across the whole run.\n" ...
             "  That means Unreal is NOT feeding pose back (Get RoverTwin idle).\n" ...
             "  Run this WHILE the Unreal/MyRoom 3D scene is connected and playing,\n" ...
             "  otherwise the rotation axis cannot be confirmed from the engine side.\n"]);
else
    actRange = max(log(:,7:9), [], 1) - min(log(:,7:9), [], 1);
    [~, actIdx] = max(actRange);
    fprintf("\nACTUAL rotation: largest change on index %d (range p/r/y = [%.4f %.4f %.4f]).\n", ...
        actIdx, actRange(1), actRange(2), actRange(3));
    switch actIdx
        case 3
            fprintf("  -> GOOD: Unreal is rotating about Z (yaw). Mesh turns FLAT.\n");
        case 2
            fprintf("  -> BAD: Unreal motion is on the ROLL axis -> mesh BANKS/tilts.\n");
            fprintf("     The engine wants yaw on a different slot than index 3.\n");
        case 1
            fprintf("  -> BAD: Unreal motion is on the PITCH axis -> mesh noses up/down.\n");
    end
end

fprintf("\nFull per-sample log written to:\n  %s\n", csvPath);
end

% ---------------------------------------------------------------------------
function v = scalarOut(modelName, blockName, port)
d = getPortData(modelName, blockName, port, 1);
v = d(1);
end

function v = vecOut(modelName, blockName, port, nEl)
v = getPortData(modelName, blockName, port, nEl);
end

function data = getPortData(modelName, blockName, port, nEl)
data = zeros(1, nEl);
try
    rt = get_param(modelName + "/" + blockName, "RuntimeObject");
    if isempty(rt)
        return
    end
    raw = double(rt.OutputPort(port).Data);
    raw = raw(:).';
    m = min(numel(raw), nEl);
    data(1:m) = raw(1:m);
catch
    % leave zeros (block idle / not connected)
end
end

function waitForStatus(modelName, target, timeoutSec)
t0 = tic;
while toc(t0) < timeoutSec
    if strcmp(get_param(modelName, "SimulationStatus"), target)
        return
    end
    pause(0.1);
end
end

function writeLog(csvPath, log)
hdr = ["t_s", "yaw_cmd_rad", "yaw_sent_rad", ...
       "sent_idx1_pitch", "sent_idx2_roll", "sent_idx3_yaw", ...
       "actual_idx1", "actual_idx2", "actual_idx3"];
T = array2table(log, "VariableNames", hdr);
try
    writetable(T, csvPath);
catch ME
    fprintf("(could not write CSV: %s)\n", ME.message);
end
end
