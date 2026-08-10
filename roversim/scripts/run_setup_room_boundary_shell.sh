#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG="${PROJECT_ROOT}/RoverTwin/Saved/Logs/RoomBoundaryShell.log"

mkdir -p "$(dirname "$LOG")"
cd "${SCRIPT_DIR}/../tools/unreal-mcp"

/home/dinuk/.local/node/bin/node -e "
import { readFileSync } from 'fs';
import { RemoteExecution } from 'unreal-remote-execution';

const code = readFileSync('${SCRIPT_DIR}/setup_room_boundary_shell.py', 'utf8');
const re = new RemoteExecution();
await re.start();
const node = await re.getFirstRemoteNode(3000, 180000);
if (!node) {
  console.error('ERROR: Unreal Editor not found. Open MyRoom with Remote Execution enabled.');
  process.exit(1);
}
await re.openCommandConnection(node, true, 12000);
const r = await re.runCommand(code, true, 'ExecuteFile', 180000);
for (const x of (r.output || [])) if (x.output) process.stdout.write(x.output);
if (r.result && !r.success) console.error(r.result);
re.stop();
" 2>&1 | tee "$LOG"

grep -q "BOUNDARY_SHELL_DONE" "$LOG" && echo "OK — perimeter boundary shell placed." || exit 1
