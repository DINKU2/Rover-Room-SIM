# Source after common.sh — bundled ESP-IDF + toolchains (no ~/esp required).
if [ -f "$REPLICA_ROOT/esp/esp-idf/export.sh" ]; then
  export IDF_PATH="$REPLICA_ROOT/esp/esp-idf"
  export IDF_TOOLS_PATH="${IDF_TOOLS_PATH:-$REPLICA_ROOT/tooling/espressif}"
  # shellcheck source=/dev/null
  . "$IDF_PATH/export.sh"
else
  echo "WARN: bundled esp-idf missing at $REPLICA_ROOT/esp/esp-idf"
  if [ -f "$HOME/esp/esp-idf/export.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/esp/esp-idf/export.sh"
  fi
fi
