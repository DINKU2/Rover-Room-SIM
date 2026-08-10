"""Shared RoverTwin spawn pose inside MyRoom (Unreal cm)."""
import unreal

SPAWN_UE_CM = (125.0, 80.0, -147.0)


def sim_m_from_ue_cm(ue_cm):
    return (ue_cm[0] / 100.0, ue_cm[1] / 100.0, ue_cm[2] / 100.0)


def spawn_ue_vector():
    return unreal.Vector(*SPAWN_UE_CM)
