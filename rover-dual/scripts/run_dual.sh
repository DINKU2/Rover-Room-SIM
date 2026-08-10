#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dual_root="$(cd "${script_dir}/.." && pwd)"
repo_root="$(cd "${dual_root}/.." && pwd)"

cd "${repo_root}"

if [[ -f "${repo_root}/scripts/start_agent.sh" ]]; then
  "${repo_root}/scripts/start_agent.sh"
fi

matlab_bin="${MATLAB_BIN:-matlab}"
exec "${matlab_bin}" -batch "addpath('${dual_root}/matlab'); run_rover_dual_control"

