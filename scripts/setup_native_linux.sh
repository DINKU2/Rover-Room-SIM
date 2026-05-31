#!/usr/bin/env bash
# One-time setup for native Ubuntu 22.04 (not WSL).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

echo "=== Native Linux setup: $REPLICA_ROOT ==="
echo ""

LAN_IP="$(hostname -I | awk '{print $1}')"
echo "Detected LAN IP: ${LAN_IP:-unknown}"

if [ ! -f "$REPLICA_ROOT/config/env" ]; then
  cp "$REPLICA_ROOT/config/env.example" "$REPLICA_ROOT/config/env"
fi

if ! grep -q "MICRO_ROS_AGENT_IP=${LAN_IP}" "$REPLICA_ROOT/config/env" 2>/dev/null; then
  if [ -n "$LAN_IP" ] && grep -q '^export MICRO_ROS_AGENT_IP=' "$REPLICA_ROOT/config/env"; then
    sed -i "s/^export MICRO_ROS_AGENT_IP=.*/export MICRO_ROS_AGENT_IP=${LAN_IP}/" "$REPLICA_ROOT/config/env"
    echo "Updated config/env MICRO_ROS_AGENT_IP=$LAN_IP"
  fi
fi

if [ ! -f /opt/ros/humble/setup.bash ]; then
  echo "ROS 2 Humble not found — run:"
  echo "  sudo ./scripts/install_deps_ubuntu22.sh"
  exit 1
fi

if ! groups "$USER" | grep -q docker; then
  echo "Adding $USER to docker group (log out/in or: newgrp docker)..."
  sudo usermod -aG docker "$USER"
fi

BRC="$HOME/.bashrc"
MARK="# yahboom project"
if ! grep -q "$MARK" "$BRC" 2>/dev/null; then
  cat >>"$BRC" <<EOF

$MARK
alias project='cd "$REPLICA_ROOT"'
export ROS_DOMAIN_ID=20
EOF
  echo "Added project alias to ~/.bashrc"
fi

echo ""
echo "=== Done ==="
echo "1. Log out/in (or: newgrp docker) if docker group was added"
echo "2. source ./setup.bash"
echo "3. ./scripts/start_agent.sh          # micro-ROS UDP agent"
echo "4. Power robot, then ./scripts/check_robot.sh"
echo "5. MATLAB: ./scripts/start_matlab_bridge.sh && matlab_connect_bridge"
echo ""
echo "If robot was flashed for an old IP, reflash:"
echo "  ./scripts/flash_firmware.sh"
