#!/usr/bin/env bash
# Recreate broken ESP-IDF Python venv (0-byte python from Windows/WSL copy).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

export IDF_PATH="$REPLICA_ROOT/esp/esp-idf"
export IDF_TOOLS_PATH="$REPLICA_ROOT/tooling/espressif"

echo "Removing broken python_env..."
rm -rf "$IDF_TOOLS_PATH/python_env"

echo "Installing IDF Python environment (system python3)..."
/usr/bin/python3 "$IDF_PATH/tools/idf_tools.py" install-python-env

PY="$IDF_TOOLS_PATH/python_env/idf5.1_py3.10_env/bin/python"
file "$PY"
"$PY" -c 'print("IDF python OK")'
"$PY" "$IDF_PATH/tools/idf.py" --version
