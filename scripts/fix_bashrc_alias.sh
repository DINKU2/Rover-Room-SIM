#!/usr/bin/env bash
# Replace old 'replica' alias with 'project' in ~/.bashrc.
set -e
BRC="$HOME/.bashrc"
[ -f "$BRC" ] || exit 0
sed -i \
  -e "s/alias replica=/alias project=/" \
  -e '/^alias replica=/d' \
  "$BRC"
unalias replica 2>/dev/null || true
echo "Updated $BRC — use:  project   or   source setup.bash"
