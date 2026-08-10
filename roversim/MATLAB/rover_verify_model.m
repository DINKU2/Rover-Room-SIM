function info = rover_verify_model(modelName)
%ROVER_VERIFY_MODEL Ensure RoverTwinControl uses Transform Set/Get architecture.
%
% Expected tags (single-actor, collision off):
%   Set RoverTwin  -> ActorTag "RoverTwin"
%   Get RoverTwin  -> ActorTag "RoverTwin"
%
% Fails loudly if the old Static Mesh Actor block is still present (that block
% spawns invisible StaticMeshActorRoverTwin ghosts in Unreal).

if nargin < 1
    modelName = "RoverTwinControl";
end

info = struct( ...
    "modelName", modelName, ...
    "ok", false, ...
    "hasSetBlock", false, ...
    "hasGetBlock", false, ...
    "hasOldMoveBlock", false, ...
    "hasOldStaticMeshBlock", false, ...
    "setActorTag", "", ...
    "getActorTag", "", ...
    "errors", strings(0, 1));

assert(bdIsLoaded(modelName), "RoverTwin:ModelNotLoaded", ...
    "Model '%s' is not loaded. Run open_rover_control first.", modelName);

allBlocks = find_system(modelName, "Type", "block");
blockNames = strings(numel(allBlocks), 1);
for k = 1:numel(allBlocks)
    blockNames(k) = string(get_param(allBlocks{k}, "Name"));
end

info.hasSetBlock = any(blockNames == "Set RoverTwin");
info.hasGetBlock = any(blockNames == "Get RoverTwin");
info.hasOldMoveBlock = any(blockNames == "Move RoverTwin");
info.hasOldStaticMeshBlock = any(contains(blockNames, "Static Mesh"));

if info.hasSetBlock
    info.setActorTag = string(get_param(modelName + "/Set RoverTwin", "ActorTag"));
end
if info.hasGetBlock
    info.getActorTag = string(get_param(modelName + "/Get RoverTwin", "ActorTag"));
end

if ~info.hasSetBlock
    info.errors(end + 1) = "Missing block 'Set RoverTwin' (Simulation 3D Actor Transform Set).";
end
if ~info.hasGetBlock
    info.errors(end + 1) = "Missing block 'Get RoverTwin' (Simulation 3D Actor Transform Get).";
end
if info.hasOldMoveBlock
    info.errors(end + 1) = ...
        "OLD block 'Move RoverTwin' still present — spawns invisible StaticMeshActorRoverTwin in Unreal.";
end
if info.hasOldStaticMeshBlock
    info.errors(end + 1) = "Static Mesh Actor block still present — must not be used for rover movement.";
end
if info.hasSetBlock && info.setActorTag ~= "RoverTwin"
    info.errors(end + 1) = "Set RoverTwin ActorTag must be 'RoverTwin', got '" + info.setActorTag + "'.";
end
if info.hasGetBlock && info.getActorTag ~= "RoverTwin"
    info.errors(end + 1) = "Get RoverTwin ActorTag must be 'RoverTwin', got '" + info.getActorTag + "'.";
end

info.ok = isempty(info.errors);

fprintf("\n=== RoverTwin model architecture check ===\n");
fprintf("  Set RoverTwin (Transform Set) : %s  ActorTag=%s\n", ...
    yesNo(info.hasSetBlock), info.setActorTag);
fprintf("  Get RoverTwin (Transform Get) : %s  ActorTag=%s  (must be RoverTwin)\n", ...
    yesNo(info.hasGetBlock), info.getActorTag);
fprintf("  OLD Move RoverTwin block      : %s  (must be NO)\n", yesNo(info.hasOldMoveBlock));
fprintf("  Static Mesh Actor block       : %s  (must be NO)\n", yesNo(info.hasOldStaticMeshBlock));

if info.ok
    fprintf("  RESULT: OK — Transform Set/Get both on RoverTwin (collision off)\n");
else
    fprintf("  RESULT: FAILED\n");
    for k = 1:numel(info.errors)
        fprintf("    - %s\n", info.errors(k));
    end
    error("RoverTwin:BadModelArchitecture", ...
        "RoverTwinControl has wrong blocks. Close Simulink, run open_rover_control, then Run again.\n%s", ...
        strjoin(info.errors, newline));
end
fprintf("==========================================\n\n");
end

function s = yesNo(tf)
if tf
    s = "YES";
else
    s = "NO";
end
end
