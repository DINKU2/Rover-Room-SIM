#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include "math.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_timer.h"

#include <uros_network_interfaces.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <std_msgs/msg/int32.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>
#include <rmw_microros/rmw_microros.h>
#include <sensor_msgs/msg/laser_scan.h>
#include <geometry_msgs/msg/twist.h>
#include <nav_msgs/msg/odometry.h>
#include <micro_ros_utilities/string_utilities.h>

#include "car_motion.h"
#include "lidar_ms200.h"
#include "ms200.h"
#include "uart1.h"


#define RCCHECK(fn)                                                                      \
    {                                                                                    \
        rcl_ret_t temp_rc = fn;                                                          \
        if ((temp_rc != RCL_RET_OK))                                                     \
        {                                                                                \
            printf("Failed status on line %d: %d. Aborting.\n", __LINE__, (int)temp_rc); \
            vTaskDelete(NULL);                                                           \
        }                                                                                \
    }
#define RCSOFTCHECK(fn)                                                                    \
    {                                                                                      \
        rcl_ret_t temp_rc = fn;                                                            \
        if ((temp_rc != RCL_RET_OK))                                                       \
        {                                                                                  \
            printf("Failed status on line %d: %d. Continuing.\n", __LINE__, (int)temp_rc); \
        }                                                                                  \
    }


#define ROS_NAMESPACE      CONFIG_MICRO_ROS_NAMESPACE
#define ROS_DOMAIN_ID      CONFIG_MICRO_ROS_DOMAIN_ID
#define ROS_AGENT_IP       CONFIG_MICRO_ROS_AGENT_IP
#define ROS_AGENT_PORT     CONFIG_MICRO_ROS_AGENT_PORT

/* Max ranges for best-effort /scan (XRCE MTU 1024 after colcon.meta rebuild).
 * At default 512 B MTU, 90 pts is the max; odom needs STREAM_HISTORY*MTU >= ~750 B. */
#define LIDAR_SCAN_POINTS  90

/* Set 0 to bring up odom/cmd_vel only if scan still crashes the agent. */
/* Set 0 if /scan crashes the agent (NotEnoughMemoryException over Wi-Fi). */
#define ENABLE_LIDAR_PUBLISH 1
#define ENABLE_ODOM_PUBLISH  1



static const char *TAG = "MAIN";

/* forward declarations */
unsigned long get_millisecond(void);
struct timespec get_timespec(void);

rcl_publisher_t publisher_lidar;
sensor_msgs__msg__LaserScan msg_lidar;
rcl_timer_t timer_lidar;

rcl_publisher_t publisher_odom;
nav_msgs__msg__Odometry msg_odom;
rcl_timer_t timer_odom;

rcl_subscription_t twist_subscriber;
geometry_msgs__msg__Twist twist_msg;

unsigned long long time_offset = 0;
unsigned long prev_odom_update = 0;

float x_pos_ = 0.0f;
float y_pos_ = 0.0f;
float heading_ = 0.0f;

car_motion_t car_motion;

void odom_ros_init(void)
{
    msg_odom.header.frame_id =
        micro_ros_string_utilities_set(msg_odom.header.frame_id, "odom");
    msg_odom.child_frame_id =
        micro_ros_string_utilities_set(msg_odom.child_frame_id, "base_footprint");
}

static void odom_euler_to_quat(float yaw, float *q)
{
    float cy = cosf(yaw * 0.5f);
    float sy = sinf(yaw * 0.5f);
    q[0] = cy;   /* w */
    q[1] = 0.0f; /* x */
    q[2] = 0.0f; /* y */
    q[3] = sy;   /* z */
}

static void odom_update(float vel_dt, float linear_vel_x, float angular_vel_z)
{
    float delta_heading = angular_vel_z * vel_dt;
    float delta_x = linear_vel_x * cosf(heading_) * vel_dt;
    float delta_y = linear_vel_x * sinf(heading_) * vel_dt;

    x_pos_   += delta_x;
    y_pos_   += delta_y;
    heading_ += delta_heading;

    float q[4];
    odom_euler_to_quat(heading_, q);

    msg_odom.pose.pose.position.x = x_pos_;
    msg_odom.pose.pose.position.y = y_pos_;
    msg_odom.pose.pose.position.z = 0.0;

    msg_odom.pose.pose.orientation.w = (double)q[0];
    msg_odom.pose.pose.orientation.x = (double)q[1];
    msg_odom.pose.pose.orientation.y = (double)q[2];
    msg_odom.pose.pose.orientation.z = (double)q[3];

    msg_odom.pose.covariance[0]  = 0.001;
    msg_odom.pose.covariance[7]  = 0.001;
    msg_odom.pose.covariance[35] = 0.001;

    msg_odom.twist.twist.linear.x  = linear_vel_x;
    msg_odom.twist.twist.angular.z = angular_vel_z;

    msg_odom.twist.covariance[0]  = 0.0001;
    msg_odom.twist.covariance[7]  = 0.0001;
    msg_odom.twist.covariance[35] = 0.0001;
}

void timer_odom_callback(rcl_timer_t *timer, int64_t last_call_time)
{
    RCLC_UNUSED(last_call_time);
    if (timer != NULL)
    {
        struct timespec time_stamp = get_timespec();
        unsigned long now = get_millisecond();
        float vel_dt = (now - prev_odom_update) / 1000.0f;
        if (vel_dt <= 0.0f || vel_dt > 1.0f) vel_dt = 0.05f;
        prev_odom_update = now;

        Motion_Get_Speed(&car_motion);
        odom_update(vel_dt, car_motion.Vx, car_motion.Wz);

        msg_odom.header.stamp.sec     = time_stamp.tv_sec;
        msg_odom.header.stamp.nanosec = time_stamp.tv_nsec;
        RCSOFTCHECK(rcl_publish(&publisher_odom, &msg_odom, NULL));
    }
}

// 初始化激光雷达的ROS话题信息
// Initializes the ROS topic information for lidar
void lidar_ros_init(void)
{
    int i;

    memset(&msg_lidar, 0, sizeof(msg_lidar));

    msg_lidar.angle_min = -180*M_PI/180.0;
    msg_lidar.angle_max = 180*M_PI/180.0;

    msg_lidar.angle_increment = (360.0 / LIDAR_SCAN_POINTS) * M_PI / 180.0;
    msg_lidar.range_min = 0.12;
    msg_lidar.range_max = 8.0;

    msg_lidar.ranges.data = (float *)malloc(LIDAR_SCAN_POINTS * sizeof(float));
    msg_lidar.ranges.size = LIDAR_SCAN_POINTS;
    msg_lidar.ranges.capacity = LIDAR_SCAN_POINTS;
    for (i = 0; i < msg_lidar.ranges.size; i++)
    {
        msg_lidar.ranges.data[i] = 0;
    }

    /* Empty intensities — smaller XRCE payload; agent fails on full 360+360 scan. */
    msg_lidar.intensities.data = NULL;
    msg_lidar.intensities.size = 0;
    msg_lidar.intensities.capacity = 0;

    char* content_frame_id = "laser_frame";
    int len_namespace = strlen(ROS_NAMESPACE);
    int len_frame_id_max = len_namespace + strlen(content_frame_id) + 2;
    // ESP_LOGI(TAG, "lidar frame len:%d", len_frame_id_max);
    char* frame_id = malloc(len_frame_id_max);
    if (len_namespace == 0)
    {
        // ROS命名空间为空字符
        // The ROS namespace is empty characters
        sprintf(frame_id, "%s", content_frame_id);
    }
    else
    {
        // 拼接命名空间和frame id
        // Concatenate the namespace and frame id
        sprintf(frame_id, "%s/%s", ROS_NAMESPACE, content_frame_id);
    }
    msg_lidar.header.frame_id = micro_ros_string_utilities_set(msg_lidar.header.frame_id, frame_id);
    free(frame_id);
}

// 激光雷达更新数据任务
// lidar update data task
void lidar_update_data_task(void *arg)
{
    uint16_t distance_mm[MS200_POINT_MAX] = {0};
    uint16_t index = 0;
    int i = 0;
    int step = MS200_POINT_MAX / LIDAR_SCAN_POINTS;
    while (1)
    {
        for (i = 0; i < MS200_POINT_MAX; i++)
        {
            distance_mm[i] = Lidar_Ms200_Get_Distance(i);
        }
        for (i = 0; i < LIDAR_SCAN_POINTS; i++)
        {
            index = (MS200_POINT_MAX - (i * step)) % MS200_POINT_MAX;
            if (index >= 180)
            {
                index = (index - 180) % MS200_POINT_MAX;
            }
            else
            {
                index = (index + 180) % MS200_POINT_MAX;
            }
            msg_lidar.ranges.data[i] = (float)(distance_mm[index] / 1000.0);
        }
        
        vTaskDelay(pdMS_TO_TICKS(20));
    }

    vTaskDelete(NULL);
}


// 获取从开机到现在的秒数
// Gets the number of seconds since boot
unsigned long get_millisecond(void)
{
    return (unsigned long) (esp_timer_get_time() / 1000ULL);
}

// 计算microROS代理与MCU的时间差
// Calculate the time difference between the microROS agent and the MCU
static void sync_time(void)
{
    unsigned long now = get_millisecond();
    RCSOFTCHECK(rmw_uros_sync_session(10));
    unsigned long long ros_time_ms = rmw_uros_epoch_millis();
    time_offset = ros_time_ms - now;
}

// 获取时间戳
// Get timestamp
struct timespec get_timespec(void)
{
    struct timespec tp = {0};
    // 同步时间 deviation of synchronous time
    unsigned long long now = get_millisecond() + time_offset;
    tp.tv_sec = now / 1000;
    tp.tv_nsec = (now % 1000) * 1000000;
    return tp;
}


// 定时器回调函数
// Timer callback function
void twist_callback(const void *msgin)
{
    const geometry_msgs__msg__Twist *msg = (const geometry_msgs__msg__Twist *)msgin;
    if (msg == NULL) {
        return;
    }
    Motion_Ctrl(msg->linear.x, 0, msg->angular.z);
}

void timer_lidar_callback(rcl_timer_t *timer, int64_t last_call_time)
{
    RCLC_UNUSED(last_call_time);
    if (timer != NULL)
    {
        struct timespec time_stamp = get_timespec();
        msg_lidar.header.stamp.sec = time_stamp.tv_sec;
        msg_lidar.header.stamp.nanosec = time_stamp.tv_nsec;
        RCSOFTCHECK(rcl_publish(&publisher_lidar, &msg_lidar, NULL));
    }
}

// micro_ros处理任务 
// micro ros processes tasks
void micro_ros_task(void *arg)
{
    rcl_allocator_t allocator = rcl_get_default_allocator();
    rclc_support_t support;

    // 创建rcl初始化选项
    // Create init_options.
    rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
    RCCHECK(rcl_init_options_init(&init_options, allocator));
    // 修改ROS域ID
    // change ros domain id
    RCCHECK(rcl_init_options_set_domain_id(&init_options, ROS_DOMAIN_ID));

    rmw_init_options_t *rmw_options = rcl_init_options_get_rmw_init_options(&init_options);
    RCCHECK(rmw_uros_options_set_udp_address(ROS_AGENT_IP, ROS_AGENT_PORT, rmw_options));

    int state_agent = 0;
    while (1)
    {
        ESP_LOGI(TAG, "Connecting agent: %s:%s", ROS_AGENT_IP, ROS_AGENT_PORT);
        state_agent = rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator);
        if (state_agent == RCL_RET_OK)
        {
            ESP_LOGI(TAG, "Connected agent: %s:%s", ROS_AGENT_IP, ROS_AGENT_PORT);
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
    
    // 创建ROS2节点
    // create ROS2 node
    rcl_node_t node;
    RCCHECK(rclc_node_init_default(&node, "lidar_publisher", ROS_NAMESPACE, &support));

    memset(&twist_msg, 0, sizeof(twist_msg));
    RCCHECK(rclc_subscription_init_default(
        &twist_subscriber,
        &node,
        ROSIDL_GET_MSG_TYPE_SUPPORT(geometry_msgs, msg, Twist),
        "cmd_vel"));

    // odom + cmd_vel first (small payloads — stable agent connect)
#if ENABLE_ODOM_PUBLISH
    RCCHECK(rclc_publisher_init_default(
        &publisher_odom,
        &node,
        ROSIDL_GET_MSG_TYPE_SUPPORT(nav_msgs, msg, Odometry),
        "odom"));

    const unsigned int odom_timeout = 50;
    prev_odom_update = get_millisecond();
    RCCHECK(rclc_timer_init_default(
        &timer_odom,
        &support,
        RCL_MS_TO_NS(odom_timeout),
        timer_odom_callback));
#else
    ESP_LOGW(TAG, "Odom publish disabled (ENABLE_ODOM_PUBLISH=0)");
#endif

#if ENABLE_LIDAR_PUBLISH
    vTaskDelay(pdMS_TO_TICKS(3000));
    RCCHECK(rclc_publisher_init_best_effort(
        &publisher_lidar,
        &node,
        ROSIDL_GET_MSG_TYPE_SUPPORT(sensor_msgs, msg, LaserScan),
        "scan"));

    const unsigned int timer_timeout = 90; /* ~11 Hz */
    RCCHECK(rclc_timer_init_default(
        &timer_lidar,
        &support,
        RCL_MS_TO_NS(timer_timeout),
        timer_lidar_callback));
#else
    ESP_LOGW(TAG, "Lidar publish disabled (ENABLE_LIDAR_PUBLISH=0)");
#endif

    // executor: 1 subscription + timers
    rclc_executor_t executor;
#if ENABLE_LIDAR_PUBLISH && ENABLE_ODOM_PUBLISH
    int handle_num = 3;
#elif ENABLE_LIDAR_PUBLISH || ENABLE_ODOM_PUBLISH
    int handle_num = 2;
#else
    int handle_num = 1;
#endif
    RCCHECK(rclc_executor_init(&executor, &support.context, handle_num, &allocator));

    RCCHECK(rclc_executor_add_subscription(
        &executor,
        &twist_subscriber,
        &twist_msg,
        &twist_callback,
        ON_NEW_DATA));

#if ENABLE_LIDAR_PUBLISH
    RCCHECK(rclc_executor_add_timer(&executor, &timer_lidar));
#endif
#if ENABLE_ODOM_PUBLISH
    RCCHECK(rclc_executor_add_timer(&executor, &timer_odom));
#endif

    // sync_time(); /* optional — skip if agent throws NotEnoughMemoryException */

    // 循环执行microROS任务
    // Loop the microROS task
    while (1)
    {
        rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100));
        usleep(1000);
    }

    // 释放资源
    // free resources
    RCCHECK(rcl_subscription_fini(&twist_subscriber, &node));
#if ENABLE_LIDAR_PUBLISH
    RCCHECK(rcl_publisher_fini(&publisher_lidar, &node));
#endif
#if ENABLE_ODOM_PUBLISH
    RCCHECK(rcl_publisher_fini(&publisher_odom, &node));
#endif
    RCCHECK(rcl_node_fini(&node));

    vTaskDelete(NULL);
}

void app_main(void)
{
    Motor_Init();

    // 初始化串口1
    // Initialize serial port 1
    Uart1_Init();

    // 初始化激光雷达
    // Initialize the Lidar
    Lidar_Ms200_Init();

    ESP_ERROR_CHECK(uros_network_interface_initialize());

    lidar_ros_init();
    odom_ros_init();

    // 开启microROS任务
    // Start microROS tasks
    xTaskCreate(micro_ros_task,
                "micro_ros_task",
                CONFIG_MICRO_ROS_APP_STACK,
                NULL,
                CONFIG_MICRO_ROS_APP_TASK_PRIO,
                NULL);

    // 开启激光雷达更新数据任务
    // Start lidar tasks
    xTaskCreatePinnedToCore(lidar_update_data_task,
                "lidar_update_data_task",
                CONFIG_MICRO_ROS_APP_STACK,
                NULL,
                CONFIG_MICRO_ROS_APP_TASK_PRIO,
                NULL, 1);
}
