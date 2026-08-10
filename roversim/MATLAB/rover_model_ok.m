function ok = rover_model_ok(modelName)
%ROVER_MODEL_OK True if model uses Transform Set/Get on RoverTwin (collision off).

if nargin < 1
    modelName = "RoverTwinControl";
end

if ~bdIsLoaded(modelName)
    ok = false;
    return
end

blkList = find_system(modelName, "Type", "block");
names = strings(numel(blkList), 1);
for k = 1:numel(blkList)
    names(k) = string(get_param(blkList{k}, "Name"));
end

ok = any(names == "Set RoverTwin") ...
    && any(names == "Get RoverTwin") ...
    && ~any(names == "Move RoverTwin") ...
    && ~any(contains(names, "Static Mesh"));

if ~ok
    return
end

ok = string(get_param(modelName + "/Set RoverTwin", "ActorTag")) == "RoverTwin" ...
    && string(get_param(modelName + "/Get RoverTwin", "ActorTag")) == "RoverTwin";

if ~ok
    return
end

if any(names == "RoverTwin Lidar")
    ok = string(get_param(modelName + "/RoverTwin Lidar", "vehTag")) == "RoverTwin";
end
end
