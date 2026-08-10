#!/usr/bin/env bash
# Install @runreal/unreal-mcp and enable UE 5.3 Python Remote Execution for Cursor MCP.
#
# Usage:
#   ./scripts/setup_unreal_mcp.sh
#   ./scripts/setup_unreal_mcp.sh --project unreal/AutoVrtlEnv/AutoVrtlEnv.uproject
#
# Environment:
#   ROVER_UE_ROOT   UE 5.3 install (default: ~/UnrealEngine_5.3)
#   ROVER_NODE_DIR  Local Node.js prefix (default: ~/.local/node)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UE_ROOT="${ROVER_UE_ROOT:-$HOME/UnrealEngine_5.3}"
NODE_DIR="${ROVER_NODE_DIR:-$HOME/.local/node}"
MCP_DIR="${PROJECT_ROOT}/tools/unreal-mcp"
DEFAULT_UPROJECT="${PROJECT_ROOT}/unreal/RoverRoomSIM/RoverRoomSIM.uproject"
UPROJECT="${DEFAULT_UPROJECT}"
NODE_VERSION="22.22.0"
NODE_TARBALL="node-v${NODE_VERSION}-linux-x64.tar.xz"

for arg in "$@"; do
  case "$arg" in
    --project=*) UPROJECT="${arg#*=}" ;;
    --project)
      shift
      UPROJECT="${1:-}"
      ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      if [[ "$arg" != "--project" ]]; then
        echo "Unknown argument: $arg" >&2
        exit 1
      fi
      ;;
  esac
done

[[ -f "$UPROJECT" ]] || {
  echo "Unreal project not found: $UPROJECT" >&2
  echo "Run ./scripts/setup_unreal_project.sh first." >&2
  exit 1
}

PROJECT_DIR="$(cd "$(dirname "$UPROJECT")" && pwd)"
ENGINE_INI="${PROJECT_DIR}/Config/DefaultEngine.ini"

echo "== Unreal MCP setup (UE 5.3) =="
echo "  Project: ${UPROJECT}"
echo "  UE:      ${UE_ROOT}"
echo "  MCP:     ${MCP_DIR}"
echo ""

install_local_node() {
  if [[ -x "${NODE_DIR}/bin/node" && -x "${NODE_DIR}/bin/npm" ]]; then
    echo "[OK] Local Node.js already installed at ${NODE_DIR}"
    return
  fi

  echo "Installing Node.js ${NODE_VERSION} to ${NODE_DIR}..."
  mkdir -p "${NODE_DIR}"
  tmp_tar="$(mktemp)"
  curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}" -o "${tmp_tar}"
  tar -xJf "${tmp_tar}" -C "${NODE_DIR}" --strip-components=1
  rm -f "${tmp_tar}"
  echo "[OK] Node $( "${NODE_DIR}/bin/node" --version ), npm $( "${NODE_DIR}/bin/npm" --version )"
}

install_mcp_server() {
  mkdir -p "${MCP_DIR}"
  if [[ ! -f "${MCP_DIR}/package.json" ]]; then
    (cd "${MCP_DIR}" && "${NODE_DIR}/bin/npm" init -y >/dev/null)
  fi
  (cd "${MCP_DIR}" && "${NODE_DIR}/bin/npm" install @runreal/unreal-mcp@0.1.4)
  echo "[OK] @runreal/unreal-mcp installed"
}

enable_python_plugin() {
  python3 - "$UPROJECT" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
plugins = data.setdefault("Plugins", [])
names = {p.get("Name") for p in plugins}
if "PythonScriptPlugin" not in names:
    plugins.append({"Name": "PythonScriptPlugin", "Enabled": True})
    path.write_text(json.dumps(data, indent="\t") + "\n")
    print("[OK] Enabled PythonScriptPlugin in .uproject")
else:
    print("[OK] PythonScriptPlugin already enabled in .uproject")
PY
}

configure_remote_execution() {
  mkdir -p "$(dirname "$ENGINE_INI")"
  touch "$ENGINE_INI"

  python3 - "$ENGINE_INI" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
section = """[/Script/PythonScriptPlugin.PythonScriptPluginSettings]
bRemoteExecution=True
RemoteExecutionMulticastGroupEndpoint=239.0.0.1:6766
RemoteExecutionMulticastBindAddress=0.0.0.0
"""
marker = "[/Script/PythonScriptPlugin.PythonScriptPluginSettings]"
if marker in text:
    print("[OK] Python Remote Execution already configured in DefaultEngine.ini")
else:
    if text and not text.endswith("\n"):
        text += "\n"
    path.write_text(text + "\n" + section)
    print("[OK] Wrote Python Remote Execution settings to DefaultEngine.ini")
PY
}

write_run_mcp_wrapper() {
  cat > "${MCP_DIR}/run-mcp.js" <<'EOF'
#!/usr/bin/env node
'use strict';

// @runreal/unreal-mcp logs connection retries to stdout, which breaks MCP stdio JSON.
console.log = (...args) => console.error(...args);

require('@runreal/unreal-mcp/dist/bin.js');
EOF
  chmod +x "${MCP_DIR}/run-mcp.js"
  echo "[OK] Wrote ${MCP_DIR}/run-mcp.js"
}

write_cursor_config() {
  local workspace_root
  workspace_root="$(cd "${PROJECT_ROOT}/.." && pwd)"
  mkdir -p "${workspace_root}/.cursor" "${PROJECT_ROOT}/.cursor"
  cat > "${workspace_root}/.cursor/mcp.json" <<EOF
{
  "mcpServers": {
    "unreal": {
      "command": "${NODE_DIR}/bin/node",
      "args": [
        "${MCP_DIR}/run-mcp.js"
      ]
    }
  }
}
EOF
  cp "${workspace_root}/.cursor/mcp.json" "${PROJECT_ROOT}/.cursor/mcp.json"
  echo "[OK] Wrote ${workspace_root}/.cursor/mcp.json"
}

install_local_node
install_mcp_server
write_run_mcp_wrapper
enable_python_plugin
configure_remote_execution
write_cursor_config

echo ""
echo "Setup complete."
echo ""
echo "Next steps:"
echo "  1. Open the Unreal Editor with this project:"
echo "       ${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor ${UPROJECT}"
echo "     Or: cd matlab && open_unreal_room('preview')"
echo "  2. Restart Cursor (or reload MCP servers in Settings -> MCP)."
echo "  3. The unreal MCP server only starts when the editor is already open."
echo ""
echo "Optional first-use tools in Cursor chat:"
echo "  - set_unreal_engine_path -> ${UE_ROOT}"
echo "  - set_unreal_project_path -> ${UPROJECT}"
