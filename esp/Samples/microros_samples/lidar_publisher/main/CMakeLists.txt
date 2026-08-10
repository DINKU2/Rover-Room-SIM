set(MAIN_REQUIRES micro_ros_espidf_component)
if(DEFINED ENV{ROVER_CAMERA_BUILD} OR CONFIG_ROVER_CAMERA_ONLY OR CONFIG_ROVER_ENABLE_CAMERA)
    list(APPEND MAIN_REQUIRES rover_camera)
else()
    list(APPEND MAIN_REQUIRES lidar_ms200 uart car_motion)
endif()

idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES ${MAIN_REQUIRES}
                    PRIV_REQUIRES esp_timer)
