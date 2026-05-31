#!/usr/bin/env python3
"""Relay /scan, /odom, /cmd_vel between ROS 2 and MATLAB over TCP."""
from __future__ import annotations

import json
import queue
import socket
import struct
import threading

import rclpy
from geometry_msgs.msg import Twist
from nav_msgs.msg import Odometry
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import LaserScan

HOST = "0.0.0.0"
PORT = 8765


def pack_msg(payload: dict) -> bytes:
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    return struct.pack("!I", len(body)) + body


def send_msg(sock: socket.socket, payload: dict) -> None:
    sock.sendall(pack_msg(payload))


def recv_exact(sock: socket.socket, n: int) -> bytes:
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("client disconnected")
        buf += chunk
    return buf


class MatlabBridge(Node):
    def __init__(self) -> None:
        super().__init__("matlab_bridge")
        scan_qos = QoSProfile(
            depth=5,
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
        )
        odom_qos = QoSProfile(
            depth=10,
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
        )
        self.create_subscription(LaserScan, "/scan", self._scan_cb, scan_qos)
        self.create_subscription(Odometry, "/odom", self._odom_cb, odom_qos)
        self.cmd_pub = self.create_publisher(Twist, "/cmd_vel", 10)
        self._tcp_peers: list[socket.socket] = []
        self._lock = threading.Lock()
        self._cmd_queue: queue.SimpleQueue[tuple[float, float]] = queue.SimpleQueue()
        self.create_timer(0.1, self._flush_cmd_queue)
        self.get_logger().info(f"TCP bridge on {HOST}:{PORT}")

    def enqueue_cmd(self, linear_x: float, angular_z: float) -> None:
        self._cmd_queue.put((float(linear_x), float(angular_z)))

    def _flush_cmd_queue(self) -> None:
        latest: tuple[float, float] | None = None
        while True:
            try:
                latest = self._cmd_queue.get_nowait()
            except queue.Empty:
                break
        if latest is None:
            return
        twist = Twist()
        twist.linear.x = latest[0]
        twist.angular.z = latest[1]
        self.cmd_pub.publish(twist)

    def add_client(self, sock: socket.socket) -> None:
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        with self._lock:
            self._tcp_peers.append(sock)
        send_msg(sock, {"type": "hello", "topics": ["/scan", "/odom", "/cmd_vel"]})

    def remove_client(self, sock: socket.socket) -> None:
        with self._lock:
            if sock in self._tcp_peers:
                self._tcp_peers.remove(sock)
        try:
            sock.close()
        except OSError:
            pass

    def broadcast(self, payload: dict) -> None:
        data = pack_msg(payload)
        with self._lock:
            dead: list[socket.socket] = []
            for sock in self._tcp_peers:
                try:
                    sock.sendall(data)
                except OSError:
                    dead.append(sock)
            for sock in dead:
                self._tcp_peers.remove(sock)
                try:
                    sock.close()
                except OSError:
                    pass

    def _scan_cb(self, msg: LaserScan) -> None:
        self.broadcast(
            {
                "type": "scan",
                "angle_min": msg.angle_min,
                "angle_max": msg.angle_max,
                "angle_increment": msg.angle_increment,
                "range_min": msg.range_min,
                "range_max": msg.range_max,
                "ranges": list(msg.ranges),
            }
        )

    def _odom_cb(self, msg: Odometry) -> None:
        p = msg.pose.pose.position
        o = msg.pose.pose.orientation
        self.broadcast(
            {
                "type": "odom",
                "x": p.x,
                "y": p.y,
                "z": p.z,
                "qx": o.x,
                "qy": o.y,
                "qz": o.z,
                "qw": o.w,
            }
        )


def client_thread(sock: socket.socket, node: MatlabBridge) -> None:
    addr = sock.getpeername()
    node.get_logger().info(f"MATLAB connected: {addr}")
    node.add_client(sock)
    try:
        while rclpy.ok():
            hdr = recv_exact(sock, 4)
            (length,) = struct.unpack("!I", hdr)
            body = recv_exact(sock, length)
            req = json.loads(body.decode("utf-8"))
            if req.get("type") == "cmd_vel":
                node.enqueue_cmd(req.get("linear_x", 0.0), req.get("angular_z", 0.0))
    except (ConnectionError, OSError, json.JSONDecodeError):
        pass
    finally:
        node.get_logger().info(f"MATLAB disconnected: {addr}")
        node.remove_client(sock)


def main() -> None:
    rclpy.init()
    node = MatlabBridge()
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(4)
    server.settimeout(1.0)

    spin_thread = threading.Thread(
        target=lambda: rclpy.spin(node), daemon=True
    )
    spin_thread.start()

    try:
        while rclpy.ok():
            try:
                client, _ = server.accept()
                client.settimeout(None)
                threading.Thread(
                    target=client_thread, args=(client, node), daemon=True
                ).start()
            except socket.timeout:
                continue
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
