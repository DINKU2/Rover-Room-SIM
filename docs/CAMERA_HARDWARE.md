# Camera on the MicroROS robot — YB-EET01 wiring

Your board matches Yahboom **YB-EET01-V2.0**. Wiring per the manual is correct.

## Your setup

| Plug | Connector on board | GPIO / function |
|------|-------------------|-----------------|
| Camera | **Custom GPIO ×2** (4-pin header) | GPIO **35** + **36** — UART to WiFi camera module |
| Servo pan/tilt | **PWM servo interface** | **S1 = GPIO8**, **S2 = GPIO21** |
| Lidar | Radar interface | GPIO 17 / 18 |
| PC USB flash/debug | **Type-C serial** (bottom-left, **Serial**) | → `/dev/ttyUSB0` |
| *(not for PC)* | **Type-C 5V OUT** (top-right) | Raspberry Pi power only |

Yahboom: **Custom GPIO ×2: UART port, can be used connect WiFi camera module.**

The camera sits on the same PCB, but the **WiFi camera module** (lens + second ESP32) talks over **UART/power on GPIO 35/36**, not as an OV2640 on the main chip.

## Two Type-C ports

| Port | Use |
|------|-----|
| **Serial** (bottom-left) | Flash main ESP → `/dev/ttyUSB0` |
| **5V OUT** (top-right) | Pi power — PC sees **no serial** |

## Why main-board camera firmware failed

`esp_camera` on the main ESP uses motor GPIOs (4,5,9,10…), not Custom GPIO 35/36. That caused probe failure and M3 wheel spin.

**Never flash camera-only firmware to `/dev/ttyUSB0`.**

## ROS topics

| Source | Topics |
|--------|--------|
| Main ESP | `/scan`, `/odom`, `/cmd_vel` |
| Camera module (Wi-Fi) | `/espRos/esp32camera` |
| Servos (main ESP, not in firmware yet) | `servo_s1`, `servo_s2` |

```bash
./scripts/check_robot_sensors.sh
./scripts/start_robot_sensors_view.sh
```

Camera Wi-Fi: Yahboom course §05, or `./scripts/setup_camera_module.sh` via module Type-C once.
