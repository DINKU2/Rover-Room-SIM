function teleop_timing_reset()
%TELEOP_TIMING_RESET  Clear teleop latency logs (Simulink StartFcn).

    teleop_timing('reset');
    fprintf('[Teleop timing] ON → maps/teleop_events.log + maps/teleop_timing.log  (setenv TELEOP_TIMING 0 to mute)\n');
end
