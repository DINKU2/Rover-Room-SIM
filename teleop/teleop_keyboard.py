#!/usr/bin/env python3
# Same as yahboomcar_ctrl/yahboom_keyboard.py (+ arrow keys). No matplotlib.
from geometry_msgs.msg import Twist
import select
import sys
import termios
import tty

import rclpy
from rclpy.node import Node

msg = """
Keyboard teleop (same as: ros2 run yahboomcar_ctrl yahboom_keyboard)
  u    i    o        (↑ = i forward)
  j    k    l        (← = j, → = l)
  m    ,    .        (↓ = , back)

  q/z  faster/slower   w/x  linear only   e/c  turn only
  space = stop    Ctrl+C = quit
"""

moveBindings = {
    "i": (1, 0),
    "o": (1, -1),
    "j": (0, 1),
    "l": (0, -1),
    "u": (1, 1),
    ",": (-1, 0),
    ".": (-1, 1),
    "m": (-1, -1),
    "I": (1, 0),
    "O": (1, -1),
    "J": (0, 1),
    "L": (0, -1),
    "U": (1, 1),
    "M": (-1, -1),
}

speedBindings = {
    "Q": (1.1, 1.1),
    "Z": (0.9, 0.9),
    "W": (1.1, 1),
    "X": (0.9, 1),
    "E": (1, 1.1),
    "C": (1, 0.9),
    "q": (1.1, 1.1),
    "z": (0.9, 0.9),
    "w": (1.1, 1),
    "x": (0.9, 1),
    "e": (1, 1.1),
    "c": (1, 0.9),
}

# Map arrow escape to yahboom keys
_ARROW_TO_KEY = {"A": "i", "B": ",", "D": "j", "C": "l"}


class YahboomKeyboard(Node):
    def __init__(self, name):
        super().__init__(name)
        self.pub = self.create_publisher(Twist, "cmd_vel", 1000)
        self.declare_parameter("linear_speed_limit", 1.0)
        self.declare_parameter("angular_speed_limit", 5.0)
        self.linenar_speed_limit = (
            self.get_parameter("linear_speed_limit")
            .get_parameter_value()
            .double_value
        )
        self.angular_speed_limit = (
            self.get_parameter("angular_speed_limit")
            .get_parameter_value()
            .double_value
        )
        self.settings = termios.tcgetattr(sys.stdin)

    def getKey(self):
        tty.setraw(sys.stdin.fileno())
        rlist, _, _ = select.select([sys.stdin], [], [], 0.1)
        key = ""
        if rlist:
            key = sys.stdin.read(1)
            if key == "\x1b":
                if select.select([sys.stdin], [], [], 0.05)[0]:
                    k2 = sys.stdin.read(1)
                    if k2 == "[" and select.select([sys.stdin], [], [], 0.05)[0]:
                        k3 = sys.stdin.read(1)
                        key = _ARROW_TO_KEY.get(k3, "")
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, self.settings)
        return key

    def vels(self, speed, turn):
        return "currently:\tspeed %s\tturn %s " % (speed, turn)


def main():
    rclpy.init()
    kb = YahboomKeyboard("yahboom_keyboard_ctrl")
    xspeed_switch = True
    speed, turn = 0.2, 1.0
    x, th = 0, 0
    status = 0
    stop = False
    count = 0
    twist = Twist()
    try:
        print(msg)
        print(kb.vels(speed, turn))
        while True:
            key = kb.getKey()
            if key == "t" or key == "T":
                xspeed_switch = not xspeed_switch
            elif key == "s" or key == "S":
                print("stop keyboard control: {}".format(not stop))
                stop = not stop
            if key in moveBindings:
                x = moveBindings[key][0]
                th = moveBindings[key][1]
                count = 0
            elif key in speedBindings:
                speed = speed * speedBindings[key][0]
                turn = turn * speedBindings[key][1]
                count = 0
                if speed > kb.linenar_speed_limit:
                    speed = kb.linenar_speed_limit
                    print("Linear speed limit reached!")
                if turn > kb.angular_speed_limit:
                    turn = kb.angular_speed_limit
                    print("Angular speed limit reached!")
                print(kb.vels(speed, turn))
                if status == 14:
                    print(msg)
                status = (status + 1) % 15
            elif key == " ":
                x, th = 0, 0
            else:
                count = count + 1
                if count > 4:
                    x, th = 0, 0
                if key == "\x03":
                    break
            if xspeed_switch:
                twist.linear.x = speed * x
            else:
                twist.linear.y = speed * x
            twist.angular.z = turn * th
            if not stop:
                kb.pub.publish(twist)
            else:
                kb.pub.publish(Twist())
    except Exception as e:
        print(e)
    finally:
        kb.pub.publish(Twist())
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, kb.settings)
        kb.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
