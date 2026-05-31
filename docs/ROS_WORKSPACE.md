# Yahboom ROS 2 workspace (Raspberry Pi stack)

Bundled at **`ros/yahboomcar_ws/src/`** — the packages Yahboom ships for the **Pi-based** car (bringup, nav, gmapping, keyboard, URDF, etc.).

## You are using micro-ROS on ESP32

Most of these nodes expect hardware on the **Pi**. For your setup, the **PC + ESP** stack in `replica/scripts/` replaces:

| Pi tutorial | Your replica equivalent |
|-------------|-------------------------|
| `ros2 run yahboomcar_ctrl yahboom_keyboard` | `./scripts/run_teleop.sh` |
| Driver + lidar on Pi | ESP firmware + UDP agent |
| `ros2 launch yahboomcar_nav map_gmapping_launch.py` | `./scripts/run_slam.sh --slam` (slam_toolbox) |

Keep this workspace for **reference**, URDF/TF offsets, and if you later use a Pi.

## Optional: build the workspace on PC

```bash
source /opt/ros/humble/setup.bash
cd replica/ros/yahboomcar_ws
colcon build --symlink-install
source install/setup.bash
```

Not required for the micro-ROS SLAM workflow in `scripts/run_slam.sh`.

## gmapping_ws

**`ros/gmapping_ws/`** — extra `slam_gmapping` install used on some Yahboom images. Your replica SLAM path uses **slam_toolbox** from apt instead.
