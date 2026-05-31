#!/usr/bin/env bash
# Fix CRLF on shell files under the project (safe to re-run).
R="$(cd "$(dirname "$0")/.." && pwd)"
find "$R" -maxdepth 3 \( -name '*.sh' -o -name '*.bash' -o -name 'env' -o -name 'env.example' \) -print0 |
  while IFS= read -r -d '' f; do
    sed -i 's/\r$//' "$f"
  done
cd "$R" && unalias replica 2>/dev/null || true
cd "$R" && source ./setup.bash && echo "setup.bash OK — REPLICA_ROOT=$REPLICA_ROOT"
