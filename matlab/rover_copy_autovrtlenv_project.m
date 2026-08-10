function rover_copy_autovrtlenv_project(paths)
%ROVER_COPY_AUTOVRTLENV_PROJECT Copy AutoVrtlEnv project files only (not UE plugins).
    if nargin < 1
        paths = rover_unreal_paths();
    end

    src = paths.mathworksSpkgRoot;
    dest = paths.autoVrtlEnvDir;
    if ~isfolder(src)
        error('rover:unreal:MissingSpkg', 'Support package not found: %s', src);
    end
    if ~isfolder(paths.unrealRoot)
        mkdir(paths.unrealRoot);
    end

    cmd = sprintf('rsync -a --delete "%s/" "%s/"', src, dest);
    status = system(cmd);
    if status ~= 0
        error('rover:unreal:CopyFailed', 'rsync AutoVrtlEnv failed (exit %d).', status);
    end
    system(sprintf('chmod -R u+w "%s"', dest));
    fprintf('Copied AutoVrtlEnv project to %s\n', dest);
end
