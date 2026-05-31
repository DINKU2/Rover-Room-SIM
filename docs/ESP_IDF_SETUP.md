# ESP-IDF and toolchains (bundled)

This replica includes a **full offline ESP32 dev environment** — no separate `~/esp` clone required on the new machine.

| Path | Contents |
|------|----------|
| `esp/esp-idf/` | ESP-IDF **v5.1** (~1.6 GB) |
| `tooling/espressif/` | Compilers, Python env, downloads (`~/.espressif` copy, ~2.1 GB) |
| `esp/Samples/` | All Yahboom samples **with build trees** |

## Use bundled IDF (automatic)

Flash/menuconfig scripts load it for you:

```bash
cd replica
source ./setup.bash
./scripts/flash_firmware.sh
```

Manual:

```bash
source ./setup.bash
source ./scripts/lib/esp_env.sh
cd esp/Samples/microros_samples/lidar_publisher
idf.py build
```

## Native Linux notes

- First flash may need **Linux packages**: `git`, `cmake`, `ninja-build`, `python3`, etc. (`install_deps_ubuntu22.sh` covers ROS side; for IDF run `esp/esp-idf/install.sh esp32` only if tools fail to activate).
- **USB:** plug ESP32 directly — usually `/dev/ttyUSB0` (add user to `dialout` group).
- Toolchain paths are under `tooling/espressif/` via `IDF_TOOLS_PATH` — do not delete when moving the folder.

## Optional: use system ~/esp instead

If you prefer a global install, clone esp-idf to `~/esp` as before; scripts fall back if `replica/esp/esp-idf` is missing.
