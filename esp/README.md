# ESP32 samples

Production firmware: `microros_samples/lidar_publisher/` — `/scan`, `/odom`, `/cmd_vel`.

```bash
source ./setup.bash
./scripts/flash_firmware.sh
```

Wi-Fi: `config/wifi.env`. Agent IP: `config/env`. See [docs/FIRMWARE.md](../docs/FIRMWARE.md).

Camera-only profile: `./scripts/flash_camera_firmware.sh` (camera module USB only).
