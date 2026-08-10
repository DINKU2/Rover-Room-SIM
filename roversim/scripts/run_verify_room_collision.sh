#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG="${PROJECT_ROOT}/RoverTwin/Saved/Logs/RoomCollisionVerify.log"

mkdir -p "$(dirname "$LOG")"
cd "${SCRIPT_DIR}/../tools/unreal-mcp"

/home/dinuk/.local/node/bin/node -e "
import { readFileSync } from 'fs';
import { RemoteExecution } from 'unreal-remote-execution';

const code = readFileSync('${SCRIPT_DIR}/verify_room_collision.py', 'utf8');
const re = new RemoteExecution();
await re.start();
const node = await re.getFirstRemoteNode(3000, 12000);
if (!node) {
  console.error('ERROR: Unreal Editor not found. Open MyRoom with Remote Execution enabled.');
  process.exit(1);
}
await re.openCommandConnection(node, true, 12000);
const r = await re.runCommand(code);
for (const x of (r.output || [])) if (x.output) process.stdout.write(x.output);
if (r.result && !r.success) console.error(r.result);
re.stop();
" 2>&1 | tee "$LOG"

grep -q "ROOM_COLLISION_VERIFY_DONE|PASS" "$LOG" && echo "OK — room collision verified." || {
  grep "ROOM_COLLISION" "$LOG" || true
  exit 1
}
