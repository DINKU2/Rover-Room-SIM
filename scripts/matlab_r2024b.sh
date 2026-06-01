#!/usr/bin/env bash
# Launch MATLAB R2024b (bundled ROS 2 Humble — matches Ubuntu 22.04 stack).
MATLAB_ROOT="${MATLAB_R2024B_ROOT:-/home/dinuk/MATLAB/R2024b}"
exec "${MATLAB_ROOT}/bin/matlab" "$@"
