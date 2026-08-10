#pragma once

/**
 * ESP32-S3 WROOM + OV2640 (common Yahboom / Freenove camera module pinout).
 * See espressif/esp32-camera BOARD_ESP32S3_WROOM.
 */
#define ROVER_CAM_PIN_PWDN   (-1)
#define ROVER_CAM_PIN_RESET  (-1)
#define ROVER_CAM_PIN_XCLK   15
#define ROVER_CAM_PIN_SIOD   4
#define ROVER_CAM_PIN_SIOC   5

#define ROVER_CAM_PIN_D7     16
#define ROVER_CAM_PIN_D6     17
#define ROVER_CAM_PIN_D5     18
#define ROVER_CAM_PIN_D4     12
#define ROVER_CAM_PIN_D3     10
#define ROVER_CAM_PIN_D2     8
#define ROVER_CAM_PIN_D1     9
#define ROVER_CAM_PIN_D0     11

#define ROVER_CAM_PIN_VSYNC  6
#define ROVER_CAM_PIN_HREF   7
#define ROVER_CAM_PIN_PCLK   13
