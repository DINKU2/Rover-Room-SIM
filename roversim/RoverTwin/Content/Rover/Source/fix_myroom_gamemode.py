import unreal

SIM3D_GM_PATH = "/MathWorksSimulation/Blueprints/Sim3dGameMode.Sim3dGameMode_C"
MAP_PATH = "/Game/Maps/MyRoom"

editor_subsys = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem)
world = editor_subsys.get_editor_world()
if not world or MAP_PATH not in world.get_path_name():
    unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)
    world = editor_subsys.get_editor_world()

ws = world.get_world_settings()
old_gm = ws.get_editor_property("default_game_mode")
old_name = old_gm.get_path_name() if old_gm else "None"
unreal.log_warning(f"fix_myroom_gamemode: old default_game_mode={old_name}")

gm_class = unreal.load_class(None, SIM3D_GM_PATH)
if gm_class is None:
    gm_class = unreal.EditorAssetLibrary.load_blueprint_class(SIM3D_GM_PATH)
if gm_class is None:
    soft = unreal.SoftClassPath(SIM3D_GM_PATH)
    gm_class = soft.try_load()
if gm_class is None:
    raise RuntimeError(f"Could not load game mode class: {SIM3D_GM_PATH}")

ws.set_editor_property("default_game_mode", gm_class)
ws.mark_package_dirty()
new_gm = ws.get_editor_property("default_game_mode")
unreal.log_warning(f"fix_myroom_gamemode: new default_game_mode={new_gm.get_path_name()}")

unreal.EditorLevelLibrary.save_current_level()
saved = unreal.EditorLoadingAndSavingUtils.save_dirty_packages(True, True)
unreal.log_warning(f"fix_myroom_gamemode: save_dirty_packages={saved}")
