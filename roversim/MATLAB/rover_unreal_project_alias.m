function unrealProject = rover_unreal_project_alias()
%ROVER_UNREAL_PROJECT_ALIAS Return a no-space path to the Unreal project.

matlabFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(matlabFolder);
aliasRoot = fullfile(tempdir, "RoverTwinUnrealProject");
unrealProject = fullfile(aliasRoot, "RoverTwin", "RoverTwin.uproject");

system(sprintf('rm -f "%s"', aliasRoot));

[status, output] = system(sprintf('ln -s "%s" "%s"', projectFolder, aliasRoot));
assert(status == 0, "RoverTwin:AliasFailed", ...
    "Could not create the no-space Unreal project path:\n%s", output);
assert(isfile(unrealProject), "RoverTwin:MissingProject", ...
    "Unreal project not found: %s", unrealProject);
end
