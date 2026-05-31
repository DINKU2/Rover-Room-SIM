#!/usr/bin/env python3
"""
PC-side SLAM launch for Yahboom micro-ROS ESP32.

Starts slam_toolbox, static TFs (base_footprint -> base_link -> laser_frame), RViz.

Prerequisites (other terminals):
  ./scripts/start_agent.sh
  ./scripts/run_teleop.sh
"""

import os

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    replica_root = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    config_dir = os.path.join(replica_root, "config")
    params_file = os.path.join(config_dir, "slam_params.yaml")
    rviz_config = os.path.join(config_dir, "slam_rviz.rviz")

    use_sim_time = LaunchConfiguration("use_sim_time", default="false")

    slam_node = Node(
        package="slam_toolbox",
        executable="async_slam_toolbox_node",
        name="slam_toolbox",
        output="screen",
        parameters=[params_file, {"use_sim_time": use_sim_time}],
    )

    tf_foot_to_base = Node(
        package="tf2_ros",
        executable="static_transform_publisher",
        name="tf_footprint_to_base",
        arguments=["0", "0", "0.05", "0", "0", "0", "base_footprint", "base_link"],
    )

    tf_base_to_laser = Node(
        package="tf2_ros",
        executable="static_transform_publisher",
        name="tf_base_to_laser",
        arguments=["-0.0046", "0", "0.094", "0", "0", "0", "base_link", "laser_frame"],
    )

    rviz_node = Node(
        package="rviz2",
        executable="rviz2",
        name="rviz2",
        output="screen",
        arguments=["-d", rviz_config],
    )

    return LaunchDescription([
        DeclareLaunchArgument("use_sim_time", default_value="false"),
        tf_foot_to_base,
        tf_base_to_laser,
        slam_node,
        rviz_node,
    ])
