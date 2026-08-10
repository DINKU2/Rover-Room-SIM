#!/usr/bin/env bash
# Run setup_rover_sweep_complete.py in the live Unreal Editor.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG="${PROJECT_ROOT}/RoverTwin/Saved/Logs/RoverSweepSetup.log"
SCRIPT="${SCRIPT_DIR}/setup_rover_sweep_complete.py"

mkdir -p "$(dirname "$LOG")"
cd "${SCRIPT_DIR}/../tools/unreal-mcp"

/home/dinuk/.local/node/bin/node -e "
import { readFileSync } from 'fs';
import { RemoteExecution } from 'unreal-remote-execution';

const code = readFileSync('${SCRIPT}', 'utf8');
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

grep -q "ROVER_SCENE_SETUP_DONE" "$LOG" && echo "OK — rover scene ready. Run open_rover_control in MATLAB." || exit 1
