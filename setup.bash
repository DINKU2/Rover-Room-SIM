# Source from any shell:  source /path/to/project/setup.bash
REPLICA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPLICA_ROOT

if [ -f "$REPLICA_ROOT/config/env" ]; then
  set -a
  . "$REPLICA_ROOT/config/env"
  set +a
fi

if [ -f "$REPLICA_ROOT/config/wifi.env" ]; then
  set -a
  . "$REPLICA_ROOT/config/wifi.env"
  set +a
fi

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-20}"
export ROS_LOCALHOST_ONLY="${ROS_LOCALHOST_ONLY:-0}"

# Docker: prefer native engine (/var/run/docker.sock). Docker Desktop uses a user socket.
if [ -S /var/run/docker.sock ]; then
  unset DOCKER_HOST
elif [ -S "$HOME/.docker/desktop/docker.sock" ]; then
  export DOCKER_HOST="unix://${HOME}/.docker/desktop/docker.sock"
fi

if [ -f /opt/ros/humble/setup.bash ]; then
  . /opt/ros/humble/setup.bash
fi

if [ -f "$REPLICA_ROOT/ros/yahboomcar_ws/install/local_setup.bash" ]; then
  . "$REPLICA_ROOT/ros/yahboomcar_ws/install/local_setup.bash"
elif [ -f "$HOME/yahboomcar_ws/install/local_setup.bash" ]; then
  . "$HOME/yahboomcar_ws/install/local_setup.bash"
fi

# Use shell alias `project` in ~/.bashrc to cd here (no function — avoids name clash).
