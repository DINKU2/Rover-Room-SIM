function rover_keyboard_control(action)
%ROVER_KEYBOARD_CONTROL Keyboard controller for a running RoverTwin model.
%
% Commands: set_param on Constant blocks during simulation.
% Feedback: Gain blocks wired to Get RoverTwin (Transform Get) outputs.

persistent keyboardWindow pressedKeys keyLabel cmdLabel speedLabel posTimer
persistent linearSpeed angularSpeed

if nargin == 0
    action = "open";
end

switch string(action)
    % ------------------------------------------------------------------
    case "open"
        if ~isempty(keyboardWindow) && isvalid(keyboardWindow)
            figure(keyboardWindow);
            return
        end

        pressedKeys = strings(0);
        keyboardWindow = uifigure( ...
            "Name", "RoverTwin Keyboard Control", ...
            "Position", [100 100 480 470], ...
            "WindowKeyPressFcn", @keyPressed, ...
            "WindowKeyReleaseFcn", @keyReleased, ...
            "CloseRequestFcn", @closeWindow);

        uilabel(keyboardWindow, ...
            "Text", "Click this window, then drive:", ...
            "FontSize", 16, "FontWeight", "bold", ...
            "HorizontalAlignment", "center", ...
            "Position", [20 368 420 32]);
        uilabel(keyboardWindow, ...
            "Text", "W / S  =  forward / reverse     A / D  =  left / right", ...
            "FontSize", 13, "HorizontalAlignment", "center", ...
            "Position", [10 365 440 26]);
        uilabel(keyboardWindow, ...
            "Text", "Q / E  =  slower / faster     SPACE = stop     ESC = end sim", ...
            "FontSize", 13, "HorizontalAlignment", "center", ...
            "Position", [10 338 440 26]);

        uipanel(keyboardWindow, "BorderType", "line", ...
            "BackgroundColor", [0.7 0.7 0.7], "Position", [20 330 420 2]);

        cfg = rover_cmd_vel_config();
        linearSpeed = cfg.linear_speed_mps;
        angularSpeed = cfg.angular_speed_rps;

        uilabel(keyboardWindow, ...
            "Text", "KEYS ACTIVE", ...
            "FontSize", 11, "FontColor", [0.5 0.5 0.5], ...
            "HorizontalAlignment", "left", "Position", [24 308 160 18]);

        keyLabel = uilabel(keyboardWindow, ...
            "Text", "(none)", ...
            "FontSize", 18, "FontWeight", "bold", ...
            "FontColor", [0 0.45 0.74], ...
            "HorizontalAlignment", "left", ...
            "Position", [24 278 410 32]);

        uilabel(keyboardWindow, ...
            "Text", "COMMAND SENT TO MODEL", ...
            "FontSize", 11, "FontColor", [0.5 0.5 0.5], ...
            "HorizontalAlignment", "left", "Position", [24 260 300 18]);

        cmdLabel = uilabel(keyboardWindow, ...
            "Text", "fwd=0  rev=0  lft=0  rgt=0  stp=0", ...
            "FontSize", 13, "FontColor", [0.3 0.3 0.3], ...
            "HorizontalAlignment", "left", ...
            "Position", [24 235 410 24]);

        speedLabel = uilabel(keyboardWindow, ...
            "Text", sprintf("speed  linear.x ±%.2f m/s   angular.z ±%.2f rad/s", ...
                linearSpeed, angularSpeed), ...
            "FontSize", 12, "FontColor", [0.2 0.35 0.55], ...
            "HorizontalAlignment", "left", ...
            "Position", [24 212 410 22]);

        uipanel(keyboardWindow, "BorderType", "line", ...
            "BackgroundColor", [0.7 0.7 0.7], "Position", [20 204 420 2]);

        uilabel(keyboardWindow, ...
            "Text", "POSE  actual (Sim3D) / command (integrators)", ...
            "FontSize", 11, "FontColor", [0.5 0.5 0.5], ...
            "HorizontalAlignment", "left", "Position", [24 178 380 18]);

        posLabel = uilabel(keyboardWindow, ...
            "Text", "(simulation not running)", ...
            "FontSize", 12, "FontWeight", "bold", ...
            "FontColor", [0.13 0.55 0.13], ...
            "HorizontalAlignment", "left", ...
            "Position", [24 95 415 78]);

        uilabel(keyboardWindow, ...
            "Text", "Key events also print to the MATLAB Command Window.", ...
            "FontSize", 10, "FontColor", [0.55 0.55 0.55], ...
            "HorizontalAlignment", "center", ...
            "Position", [10 70 440 22]);

        uilabel(keyboardWindow, ...
            "Text", "Model: RoverTwinControl", ...
            "FontSize", 10, "FontColor", [0.65 0.65 0.65], ...
            "HorizontalAlignment", "center", ...
            "Position", [10 48 440 20]);

        if ~isempty(posTimer) && isvalid(posTimer)
            stop(posTimer);
            delete(posTimer);
        end
        posTimer = timer("Period", 0.2, "ExecutionMode", "fixedRate", ...
            "TimerFcn", @(~,~) roverUpdatePos(posLabel));
        start(posTimer);
        applySpeedToModel(linearSpeed, angularSpeed);

    case "reset"
        cfg = rover_cmd_vel_config();
        linearSpeed = cfg.linear_speed_mps;
        angularSpeed = cfg.angular_speed_rps;
        applySpeedToModel(linearSpeed, angularSpeed);
        setCommands(0, 0, 0, 0, 0);
        pressedKeys = strings(0);
        if ~isempty(keyLabel) && isvalid(keyLabel)
            keyLabel.Text = "(none)";
        end
        if ~isempty(cmdLabel) && isvalid(cmdLabel)
            cmdLabel.Text = "fwd=0  rev=0  lft=0  rgt=0  stp=0";
        end
        updateSpeedLabel();

    case "close"
        if ~isempty(posTimer) && isvalid(posTimer)
            stop(posTimer);
            delete(posTimer);
        end
        posTimer = [];
        setCommands(0, 0, 0, 0, 0);
        if ~isempty(keyboardWindow) && isvalid(keyboardWindow)
            delete(keyboardWindow);
        end
        keyboardWindow = [];
        pressedKeys    = strings(0);
end

    function keyPressed(~, event)
        key = lower(string(event.Key));
        if key == "escape"
            fprintf("[RoverTwin] ESC — stopping simulation\n");
            set_param("RoverTwinControl", "SimulationCommand", "stop");
            return
        end
        if key == "q"
            adjustSpeed(-1);
            return
        end
        if key == "e"
            adjustSpeed(1);
            return
        end
        if any(key == ["w", "a", "s", "d", "space"])
            pressedKeys = unique([pressedKeys, key]);
            updateCommands();
        end
    end

    function keyReleased(~, event)
        key = lower(string(event.Key));
        pressedKeys(pressedKeys == key) = [];
        updateCommands();
    end

    function closeWindow(~, ~)
        rover_keyboard_control("close");
    end

    function updateCommands()
        forward = double(any(pressedKeys == "w"));
        reverse = double(any(pressedKeys == "s"));
        left    = double(any(pressedKeys == "a"));
        right   = double(any(pressedKeys == "d"));
        stp     = double(any(pressedKeys == "space"));

        if ~isempty(keyLabel) && isvalid(keyLabel)
            if isempty(pressedKeys)
                keyLabel.Text = "(none)";
            else
                keyLabel.Text = upper(strjoin(pressedKeys, " + "));
            end
        end

        if ~isempty(cmdLabel) && isvalid(cmdLabel)
            cfg = rover_cmd_vel_config();
            cfg.linear_speed_mps = linearSpeed;
            cfg.angular_speed_rps = angularSpeed;
            cmd = rover_keyboard_to_cmd_vel(forward, reverse, left, right, stp, cfg);
            cmdLabel.Text = sprintf( ...
                "fwd=%d  rev=%d  lft=%d  rgt=%d  stp=%d  |  linear.x=%.2f  angular.z=%.2f", ...
                forward, reverse, left, right, stp, cmd.linear_x, cmd.angular_z);
        end

        setCommands(forward, reverse, left, right, stp);
    end

    function adjustSpeed(direction)
        cfg = rover_cmd_vel_config();
        factor = cfg.speed_step_factor ^ direction;
        linearSpeed = clampSpeed(linearSpeed * factor, ...
            cfg.linear_speed_min_mps, cfg.linear_speed_max_mps);
        angularSpeed = clampSpeed(angularSpeed * factor, ...
            cfg.angular_speed_min_rps, cfg.angular_speed_max_rps);
        applySpeedToModel(linearSpeed, angularSpeed);
        updateSpeedLabel();
        updateCommands();
        fprintf("[RoverTwin] Speed  linear.x=±%.2f m/s  angular.z=±%.2f rad/s\n", ...
            linearSpeed, angularSpeed);
    end

    function updateSpeedLabel()
        if ~isempty(speedLabel) && isvalid(speedLabel)
            speedLabel.Text = sprintf( ...
                "speed  linear.x ±%.2f m/s   angular.z ±%.2f rad/s  (Q slower / E faster)", ...
                linearSpeed, angularSpeed);
        end
    end

end

function val = clampSpeed(val, lo, hi)
val = min(hi, max(lo, val));
end

function applySpeedToModel(linearSpeed, angularSpeed)
modelName = "RoverTwinControl";
if ~bdIsLoaded(modelName)
    return
end
try
    set_param(modelName + "/CmdVel Linear", "Gain", num2str(linearSpeed));
    set_param(modelName + "/CmdVel Angular", "Gain", num2str(angularSpeed));
catch ME
    fprintf("[RoverTwin] applySpeedToModel ERROR: %s\n", ME.message);
end
end

function setCommands(forward, reverse, left, right, stop)
modelName = "RoverTwinControl";

if ~bdIsLoaded(modelName)
    fprintf("[RoverTwin] setCommands skipped — model '%s' is not loaded\n", modelName);
    return
end

simStatus = get_param(modelName, "SimulationStatus");
if ~strcmp(simStatus, "running")
    fprintf("[RoverTwin] setCommands skipped — sim status = '%s' (must be running)\n", simStatus);
    return
end

try
    set_param(modelName + "/Forward Value", "Value", num2str(forward));
    set_param(modelName + "/Reverse Value", "Value", num2str(reverse));
    set_param(modelName + "/Left Value",    "Value", num2str(left));
    set_param(modelName + "/Right Value",   "Value", num2str(right));
    set_param(modelName + "/Stop Value",    "Value", num2str(stop));
    if any([forward reverse left right stop])
        fprintf("[RoverTwin] CMD  fwd=%d  rev=%d  lft=%d  rgt=%d  stp=%d\n", ...
            forward, reverse, left, right, stop);
    end
catch ME
    fprintf("[RoverTwin] setCommands ERROR: %s\n", ME.message);
end
end

function roverUpdatePos(posLabel)
persistent lastDbgCmd lastDbgAct lastDbgPrintTime dbgCount

if ~isvalid(posLabel)
    return
end

modelName = "RoverTwinControl";

if isempty(lastDbgCmd)
    lastDbgCmd = [NaN NaN NaN];
    lastDbgAct = [NaN NaN NaN];
    lastDbgPrintTime = datetime("now") - seconds(10);
    dbgCount = 0;
end

if ~bdIsLoaded(modelName)
    posLabel.Text = "(run open_rover_control first)";
    return
end

try
    simStatus = get_param(modelName, "SimulationStatus");
catch
    posLabel.Text = "(cannot read sim status)";
    return
end

if ~strcmp(simStatus, "running")
    posLabel.Text = sprintf("(sim: %s)", simStatus);
    return
end

[cmdX, cmdY, cmdYaw] = readCommandedPose(modelName);
[setX, setY, setZ] = readSetTranslation(modelName);

actErr = "";
actualOk = false;
actX = NaN;
actY = NaN;
actYaw = NaN;
try
    [actX, actY, actYaw] = readActualPose(modelName);
    actualOk = true;
catch ME
    actErr = shortenMsg(ME.message);
end

dbgCount = dbgCount + 1;
cmdMoved = norm([cmdX cmdY] - lastDbgCmd(1:2)) > 0.01;
actStuck = actualOk && norm([actX actY] - lastDbgAct(1:2)) < 0.001 && cmdMoved;
now = datetime("now");

if actualOk && ~any(isnan([actX, actY, actYaw]))
    delta = norm([cmdX cmdY] - [actX actY]);
    posLabel.Text = sprintf( ...
        ["actual  X=%.3f  Y=%.3f  yaw=%.1f\xB0\n" ...
         "command X=%.3f  Y=%.3f  yaw=%.1f\xB0\n" ...
         "set->UE X=%.3f  Y=%.3f  Z=%.3f  delta=%.3f"], ...
        actX, actY, rad2deg(actYaw), cmdX, cmdY, rad2deg(cmdYaw), ...
        setX, setY, setZ, delta);
elseif ~any(isnan([cmdX, cmdY, cmdYaw]))
    posLabel.Text = sprintf( ...
        ["command X=%.3f  Y=%.3f  yaw=%.1f\xB0\n" ...
         "set->UE X=%.3f  Y=%.3f  Z=%.3f\n" ...
         "actual: %s"], ...
        cmdX, cmdY, rad2deg(cmdYaw), setX, setY, setZ, actErr);
else
    posLabel.Text = sprintf("(pose unavailable: %s)", actErr);
end

if seconds(now - lastDbgPrintTime) >= 2.0
    arch = "Transform Set/Get";
    if blockExists(modelName, "Move RoverTwin")
        arch = "OLD Static Mesh Actor (WRONG — reload model!)";
    end
    fprintf("[RoverTwin DBG #%d] arch=%s | cmd=(%.3f,%.3f) set=(%.3f,%.3f,%.3f)", ...
        dbgCount, arch, cmdX, cmdY, setX, setY, setZ);
    if actualOk
        fprintf(" actual=(%.3f,%.3f)", actX, actY);
        if actStuck && norm([cmdX cmdY]) > 0.1
            fprintf(" *** STUCK: command moved but actual pose unchanged ***");
            fprintf("\n  Likely cause: stale Simulink model OR duplicate Unreal actors.");
            fprintf("\n  Fix: stop sim, run open_rover_control, then run_audit_rover_scene.sh");
        end
    else
        fprintf(" actual=UNAVAILABLE (%s)", actErr);
    end
    fprintf("\n");
    lastDbgPrintTime = now;
end

lastDbgCmd = [cmdX cmdY rad2deg(cmdYaw)];
if actualOk
    lastDbgAct = [actX actY rad2deg(actYaw)];
end
end

function [x, y, z] = readSetTranslation(modelName)
data = readBlockOutput(modelName, "Pack Translation", 1);
x = double(data(1));
y = double(data(2));
z = double(data(3));
end

function tf = blockExists(modelName, blockName)
tf = ~isempty(find_system(modelName, "SearchDepth", 1, "Name", blockName));
end

function [x, y, yaw] = readActualPose(modelName)
% Transform Get reports the left-handed Unreal world frame. Convert back to
% the ROS right-handed frame used by the integrators (y_ros = -y_lh,
% yaw_ros = -yaw_lh) so the command/actual display agrees in one frame.
x = readPoseScalar(modelName, "Actual X", 1);
y = -readPoseScalar(modelName, "Actual Y", 1);
yaw = -rad2deg(readPoseScalar(modelName, "Actual Yaw", 1));
end

function [x, y, yaw] = readCommandedPose(modelName)
x = readPoseScalar(modelName, "X Position", 1);
y = readPoseScalar(modelName, "Y Position", 1);
yaw = readPoseScalar(modelName, "Yaw", 1);
end

function val = readPoseScalar(modelName, blockName, portIndex)
data = readBlockOutput(modelName, blockName, portIndex);
val = double(data(1));
end

function data = readBlockOutput(modelName, blockName, portIndex)
if portIndex < 1
    portIndex = 1;
end
blk = modelName + "/" + blockName;
rt = get_param(blk, "RuntimeObject");
if isempty(rt)
    error("RuntimeObject empty for %s (is simulation running?)", blk);
end

try
    data = rt.OutputPort(portIndex).Data;
catch
    ports = rt.OutputPort;
    if iscell(ports)
        data = ports{portIndex}.Data;
    elseif isstruct(ports) && numel(ports) == 1 && portIndex > 1
        data = ports.Data;
    else
        data = ports(portIndex).Data;
    end
end
data = double(data(:).');
end

function msg = shortenMsg(text)
if strlength(text) > 72
    msg = extractBefore(text, 72) + "...";
else
    msg = string(text);
end
end
