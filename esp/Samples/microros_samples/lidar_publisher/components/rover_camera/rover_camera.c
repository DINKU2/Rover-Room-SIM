#include "rover_camera.h"

#include "rover_camera_pins.h"

#include "esp_log.h"
#include "sdkconfig.h"

static const char *TAG = "ROVER_CAM";
static bool s_ready = false;

#if CONFIG_ROVER_ENABLE_CAMERA

static camera_config_t s_camera_config = {
    .pin_pwdn       = ROVER_CAM_PIN_PWDN,
    .pin_reset      = ROVER_CAM_PIN_RESET,
    .pin_xclk       = ROVER_CAM_PIN_XCLK,
    .pin_sccb_sda   = ROVER_CAM_PIN_SIOD,
    .pin_sccb_scl   = ROVER_CAM_PIN_SIOC,
    .pin_d7         = ROVER_CAM_PIN_D7,
    .pin_d6         = ROVER_CAM_PIN_D6,
    .pin_d5         = ROVER_CAM_PIN_D5,
    .pin_d4         = ROVER_CAM_PIN_D4,
    .pin_d3         = ROVER_CAM_PIN_D3,
    .pin_d2         = ROVER_CAM_PIN_D2,
    .pin_d1         = ROVER_CAM_PIN_D1,
    .pin_d0         = ROVER_CAM_PIN_D0,
    .pin_vsync      = ROVER_CAM_PIN_VSYNC,
    .pin_href       = ROVER_CAM_PIN_HREF,
    .pin_pclk       = ROVER_CAM_PIN_PCLK,
    .xclk_freq_hz   = 20000000,
    .ledc_timer     = LEDC_TIMER_0,
    .ledc_channel   = LEDC_CHANNEL_0,
    .pixel_format   = PIXFORMAT_JPEG,
    .frame_size     = FRAMESIZE_QVGA,
    .jpeg_quality   = CONFIG_ROVER_CAMERA_JPEG_QUALITY,
    .fb_count       = 2,
#if CONFIG_SPIRAM
    .fb_location    = CAMERA_FB_IN_PSRAM,
#else
    .fb_location    = CAMERA_FB_IN_DRAM,
    .fb_count       = 1,
#endif
    .grab_mode      = CAMERA_GRAB_LATEST,
};

bool rover_camera_init(void)
{
    esp_err_t err = esp_camera_init(&s_camera_config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_camera_init failed: 0x%x (PSRAM enabled? correct board?)", err);
        s_ready = false;
        return false;
    }

    sensor_t *sensor = esp_camera_sensor_get();
    if (sensor != NULL) {
        sensor->set_vflip(sensor, CONFIG_ROVER_CAMERA_VFLIP);
        sensor->set_hmirror(sensor, CONFIG_ROVER_CAMERA_MIRROR);
    }

    s_ready = true;
    ESP_LOGI(TAG, "Camera ready (QVGA JPEG, quality %d)", CONFIG_ROVER_CAMERA_JPEG_QUALITY);
    return true;
}

camera_fb_t *rover_camera_capture(void)
{
    if (!s_ready) {
        return NULL;
    }
    return esp_camera_fb_get();
}

bool rover_camera_is_ready(void)
{
    return s_ready;
}

#else

bool rover_camera_init(void)
{
    return false;
}

camera_fb_t *rover_camera_capture(void)
{
    return NULL;
}

bool rover_camera_is_ready(void)
{
    return false;
}

#endif
