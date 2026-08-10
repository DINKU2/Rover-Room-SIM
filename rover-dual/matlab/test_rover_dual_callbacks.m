function test_rover_dual_callbacks()
%TEST_ROVER_DUAL_CALLBACKS  Verify InitFcn path bootstrap without full Unreal.

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    slxPath = fullfile(projectRoot, 'simulink', 'rover_dual_control.slx');
    dualMatlab = fileparts(mfilename('fullpath'));
    sharedMatlab = fullfile(projectRoot, 'matlab');
    simMatlab = fullfile(projectRoot, 'roversim', 'MATLAB');

    assert(isfile(slxPath), 'Missing %s — run build_rover_dual_control_model first.', slxPath);

    savedPath = path;
    cleanupPath = onCleanup(@() path(savedPath)); %#ok<NASGU>

    strip = {dualMatlab, sharedMatlab, simMatlab};
    for k = 1:numel(strip)
        while contains(path, strip{k})
            rmpath(strip{k});
        end
    end

    bdclose('all');
    load_system(slxPath);

    initFcn = get_param('rover_dual_control', 'InitFcn');
    assert(contains(initFcn, 'addpath'), 'InitFcn must bootstrap paths.');
    assert(contains(initFcn, 'rover_dual_init'), 'InitFcn must call rover_dual_init.');

    setenv('ROVER_DUAL_SKIP_UNREAL', '1');
    cleanupEnv = onCleanup(@() setenv('ROVER_DUAL_SKIP_UNREAL', '')); %#ok<NASGU>

    eval(initFcn);

    assert(exist('rover_dual_init', 'file') == 2, ...
        'InitFcn did not add rover-dual/matlab to path.');

    stopFcn = get_param('rover_dual_control', 'StopFcn');
    eval(stopFcn);

    fprintf('test_rover_dual_callbacks: PASSED\n');
end
