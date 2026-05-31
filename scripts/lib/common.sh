# Shared setup for all replica scripts. Do not run directly.
REPLICA_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPLICA_ROOT="$(cd "$REPLICA_SCRIPTS/.." && pwd)"
export REPLICA_ROOT REPLICA_SCRIPTS
export REPLICA_ESP_SAMPLES="$REPLICA_ROOT/esp/Samples"
export REPLICA_FIRMWARE_DEFAULT="$REPLICA_ESP_SAMPLES/microros_samples/lidar_publisher"
export REPLICA_ROS_WS="$REPLICA_ROOT/ros/yahboomcar_ws"

if [ -f "$REPLICA_ROOT/config/env" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$REPLICA_ROOT/config/env"
  set +a
fi

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-20}"

if [ -S /var/run/docker.sock ]; then
  unset DOCKER_HOST
elif [ -S "$HOME/.docker/desktop/docker.sock" ]; then
  export DOCKER_HOST="unix://${HOME}/.docker/desktop/docker.sock"
fi

if [ -f /opt/ros/humble/setup.bash ]; then
  # shellcheck source=/dev/null
  . /opt/ros/humble/setup.bash
fi

if [ -f "$REPLICA_ROS_WS/install/local_setup.bash" ]; then
  # shellcheck source=/dev/null
  . "$REPLICA_ROS_WS/install/local_setup.bash"
elif [ -f "$HOME/yahboomcar_ws/install/local_setup.bash" ]; then
  # shellcheck source=/dev/null
  . "$HOME/yahboomcar_ws/install/local_setup.bash"
fi
