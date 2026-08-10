function stage4_timing_reset()
%STAGE4_TIMING_RESET  Clear timing stats (Simulink StartFcn).

    stage4_timing('reset');
    fprintf('[Stage4 timing] profiling ON → maps/stage4_timing.log  (setenv STAGE4_TIMING 0 to mute)\n');
end
