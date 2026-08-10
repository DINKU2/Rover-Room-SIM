"""Convert rover STL parts to OBJ for Unreal import (local copies only)."""
import math
import os
import xml.etree.ElementTree as ET

import trimesh

SRC = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(SRC, "..", "Import")
URDF = os.path.join(SRC, "MicroROS.urdf")


def rpy_to_matrix(rpy):
    roll, pitch, yaw = rpy
    cr, sr = math.cos(roll), math.sin(roll)
    cp, sp = math.cos(pitch), math.sin(pitch)
    cy, sy = math.cos(yaw), math.sin(yaw)
    return [
        [cy * cp, cy * sp * sr - sy * cr, cy * sp * cr + sy * sr],
        [sy * cp, sy * sp * sr + cy * cr, sy * sp * cr - cy * sr],
        [-sp, cp * sr, cp * cr],
    ]


def transform_from_origin(xyz, rpy):
    m = rpy_to_matrix(rpy)
    mat = [
        [m[0][0], m[0][1], m[0][2], xyz[0]],
        [m[1][0], m[1][1], m[1][2], xyz[1]],
        [m[2][0], m[2][1], m[2][2], xyz[2]],
        [0.0, 0.0, 0.0, 1.0],
    ]
    return mat


def parse_xyz(text):
    parts = [float(v) for v in text.split()]
    return parts[:3]


def parse_rpy(text):
    parts = [float(v) for v in text.split()]
    return parts[:3]


def load_urdf(path):
    tree = ET.parse(path)
    root = tree.getroot()
    links = {}
    joints = []
    for link in root.findall("link"):
        name = link.attrib["name"]
        mesh_name = None
        visual = link.find("visual")
        if visual is not None:
            geom = visual.find("geometry/mesh")
            if geom is not None:
                mesh_name = os.path.basename(geom.attrib["filename"])
        links[name] = {"mesh": mesh_name}
    for joint in root.findall("joint"):
        origin = joint.find("origin")
        xyz = parse_xyz(origin.attrib.get("xyz", "0 0 0"))
        rpy = parse_rpy(origin.attrib.get("rpy", "0 0 0"))
        joints.append(
            {
                "name": joint.attrib["name"],
                "parent": joint.find("parent").attrib["link"],
                "child": joint.find("child").attrib["link"],
                "xyz": xyz,
                "rpy": rpy,
            }
        )
    return links, joints


def main():
    os.makedirs(OUT, exist_ok=True)
    links, joints = load_urdf(URDF)
    children = {}
    joint_by_child = {}
    for j in joints:
        children.setdefault(j["parent"], []).append(j["child"])
        joint_by_child[j["child"]] = j

    world = {}

    def visit(link_name, parent_mat):
        world[link_name] = parent_mat
        for child in children.get(link_name, []):
            j = joint_by_child[child]
            local = transform_from_origin(j["xyz"], j["rpy"])
            child_mat = trimesh.transformations.concatenate_matrices(parent_mat, local)
            visit(child, child_mat)

    visit("base_link", trimesh.transformations.identity_matrix())

    # URDF uses meters; Unreal uses centimeters.
    meter_to_cm = trimesh.transformations.scale_matrix(100.0)

    exported = []
    for link_name, mat in world.items():
        mesh_file = links[link_name]["mesh"]
        if not mesh_file:
            continue
        stl_path = os.path.join(SRC, mesh_file)
        if not os.path.isfile(stl_path):
            print(f"Missing: {stl_path}")
            continue
        mesh = trimesh.load(stl_path, force="mesh")
        mesh.apply_transform(mat)
        mesh.apply_transform(meter_to_cm)
        out_name = f"SM_{link_name}.obj"
        out_path = os.path.join(OUT, out_name)
        mesh.export(out_path)
        exported.append(out_path)
        print(f"Exported {out_path}")

    # Combined preview mesh for quick placement checks.
    parts = []
    for link_name, mat in world.items():
        mesh_file = links[link_name]["mesh"]
        if not mesh_file:
            continue
        stl_path = os.path.join(SRC, mesh_file)
        if not os.path.isfile(stl_path):
            continue
        mesh = trimesh.load(stl_path, force="mesh")
        mesh.apply_transform(mat)
        mesh.apply_transform(meter_to_cm)
        parts.append(mesh)
    if parts:
        combined = trimesh.util.concatenate(parts)
        combined_path = os.path.join(OUT, "SM_Rover_Combined.obj")
        combined.export(combined_path)
        exported.append(combined_path)
        print(f"Exported {combined_path}")

    print(f"Done: {len(exported)} files")


if __name__ == "__main__":
    main()
