#!/usr/bin/env bash
# Reload rover_sweep_runtime.py in the live Unreal Editor (picks up Python fixes without restart).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG="${PROJECT_ROOT}/RoverTwin/Saved/Logs/ReloadRoverSweep.log"
RUNTIME="${PROJECT_ROOT}/RoverTwin/Content/Python/rover_sweep_runtime.py"

mkdir -p "$(dirname "$LOG")"
cd "${SCRIPT_DIR}/../tools/unreal-mcp"

/home/dinuk/.local/node/bin/node -e "
import { readFileSync } from 'fs';
import { RemoteExecution } from 'unreal-remote-execution';

const code = readFileSync('${RUNTIME}', 'utf8');
const re = new RemoteExecution();
await re.start();
const node = await re.getFirstRemoteNode(3000, 12000);
if (!node) {
  console.error('ERROR: Unreal Editor not found. Open MyRoom with Remote Execution enabled.');
  process.exit(1);
}
await re.openCommandConnection(node, true, 12000);
const r = await re.runCommand(code, true, 'ExecuteFile', 120000);
for (const x of (r.output || [])) if (x.output) process.stdout.write(x.output);
if (r.result && !r.success) console.error(r.result);
re.stop();
" 2>&1 | tee "$LOG"

grep -q "ROVER_SWEEP_TICK|registered" "$LOG" && echo "OK — sweep runtime reloaded. Stop PIE and Play again." || exit 1
