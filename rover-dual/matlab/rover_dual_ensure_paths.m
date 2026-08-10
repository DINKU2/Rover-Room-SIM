function paths = rover_dual_ensure_paths()
%ROVER_DUAL_ENSURE_PATHS  Add dual + shared MATLAB folders (Simulink callbacks).

    dualMatlab = fileparts(mfilename('fullpath'));
    paths = rover_dual_setup_paths(dualMatlab);
end
