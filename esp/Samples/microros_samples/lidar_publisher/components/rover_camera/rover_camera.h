#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "esp_camera.h"

/** Initialize OV2640. Returns false if hardware missing or PSRAM unavailable. */
bool rover_camera_init(void);

/** Latest JPEG frame from the driver (caller must esp_camera_fb_return). */
camera_fb_t *rover_camera_capture(void);

bool rover_camera_is_ready(void);
