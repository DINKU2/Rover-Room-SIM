function mcl = mcl_create_from_cfg(lockCfg, overrides)
%MCL_CREATE_FROM_CFG  Build monteCarloLocalization from saved lockCfg.

    if nargin < 2
        overrides = struct();
    end

    mcl = monteCarloLocalization('UseLidarScan', true);
    mcl.SensorModel = lockCfg.SensorModel;
    mcl.MotionModel = lockCfg.MotionModel;
    mcl.ParticleLimits = lockCfg.ParticleLimits;
    mcl.UpdateThresholds = lockCfg.UpdateThresholds;

    if isfield(overrides, 'GlobalLocalization')
        mcl.GlobalLocalization = overrides.GlobalLocalization;
    end
    if isfield(overrides, 'InitialPose') && ~isempty(overrides.InitialPose)
        mcl.InitialPose = overrides.InitialPose(:)';
    end
    if isfield(overrides, 'InitialCovariance') && ~isempty(overrides.InitialCovariance)
        mcl.InitialCovariance = overrides.InitialCovariance;
    end
end
