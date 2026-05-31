#!/usr/bin/env bash
# One-time ROS 2 Humble + tools for replica (Ubuntu 22.04).
set -e

echo "Installing ROS 2 Humble packages for yahboom-replica ..."

if [ ! -f /etc/apt/sources.list.d/ros2.list ]; then
  echo "Adding ROS 2 apt repository ..."
  sudo apt update
  sudo apt install -y software-properties-common curl
  sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
    | sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null
fi

sudo apt update
sudo apt install -y \
  ros-humble-desktop \
  ros-humble-slam-toolbox \
  ros-humble-tf2-ros \
  fastdds-tools \
  python3-pip \
  python3-colcon-common-extensions

pip3 install --user matplotlib numpy 2>/dev/null || pip3 install matplotlib numpy

echo ""
echo "Install native Docker engine (required for micro-ROS UDP on LAN — not Docker Desktop alone) ..."
if ! dpkg -l docker.io 2>/dev/null | grep -q '^ii'; then
  sudo apt install -y docker.io
  sudo systemctl enable --now docker
fi

echo ""
echo "Pull micro-ROS agent image ..."
sudo docker pull microros/micro-ros-agent:humble || docker pull microros/micro-ros-agent:humble

echo ""
echo "Add your user to docker group if needed:  sudo usermod -aG docker \$USER"
echo "Log out/in or run:  newgrp docker"
echo "Then:  cp config/env.example config/env"
echo "       source ./setup.bash"
