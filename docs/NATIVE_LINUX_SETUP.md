# Native Ubuntu 22.04 setup

## One-time

```bash
sudo ./scripts/install_deps_ubuntu22.sh
./scripts/setup_native_linux.sh
cp config/env.example config/env
cp config/wifi.env.example config/wifi.env
```

Edit `config/env` (agent IP) and `config/wifi.env` (robot Wi-Fi).

Use native `docker.io` (not Docker Desktop) for UDP 8090.

## Daily

```bash
cd ~/Desktop/project/Rover-Room-SIM
source ./setup.bash
./scripts/start_agent.sh
./scripts/check_robot.sh
```

Co-sim: see [README.md](../README.md).

## MATLAB

```bash
./scripts/matlab_r2024b.sh
```

```matlab
setup_rover_paths()
ros_test
```
