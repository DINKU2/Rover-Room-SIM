function spkgRoot = rover_unreal_support_package_root()
%ROVER_UNREAL_SUPPORT_PACKAGE_ROOT Locate installed MathWorks UE support package.
%
%   Support packages install under ~/Documents/MATLAB/SupportPackages/R20XXx/
%   (not under matlabroot).

    relPath = fullfile('toolbox', 'shared', 'sim3dprojects', 'spkg', 'project', 'AutoVrtlEnv');
    homeDir = rover_user_home();
    candidates = {
        fullfile(matlabroot, 'toolbox', 'shared', 'sim3dprojects', 'spkg', 'project', 'AutoVrtlEnv')
        fullfile(homeDir, 'Documents', 'MATLAB', 'SupportPackages', ...
            ['R' version('-release')], relPath)
        };

    spkgRoot = '';
    for i = 1:numel(candidates)
        if isfolder(candidates{i})
            spkgRoot = candidates{i};
            return;
        end
    end
end
