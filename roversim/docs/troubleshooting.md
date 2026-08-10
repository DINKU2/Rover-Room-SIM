# Troubleshooting

## Keyboard shows movement but rover is frozen in Unreal

**Diagnosis:** Simulink integrators update (`command` line in keyboard UI) but `actual` line does not, or visible mesh does not move.

**Cause:** Duplicate rover actors — Simulink drives one actor; you see another.

**Fix:**

```bash
bash scripts/run_audit_rover_scene.sh
```

Then restart Simulink Run. Verify outliner: exactly one `RoverTwin`.

Do **not** run `fix_rover_all`, `setup_rover_physics`, or `remove_sim3d_rover`.

---

## Rover spawns outside the room

**Cause:** Spawn at UE origin `(0,0)` while floor mesh is offset.

**Fix:**

1. Edit `MATLAB/rover_spawn_pose.m` and `scripts/rover_spawn_pose.py`
2. `build_rover_control_model` in MATLAB
3. `bash scripts/run_audit_rover_scene.sh`

---

## Unreal Editor opens then immediately closes

**Cause:** Launcher passed `-ExecutePythonScript` (script runs then `QUIT_EDITOR`).

**Fix:** Simulink must use `scripts/launch_rovertwin_simulink.sh` only — it does not pass that flag. Audit/repair runs separately via `run_audit_rover_scene.sh`.

---

## MathWorksSimulation plugin failed to load

**Log:** `libUnrealEditor-ChaosVehicles.so: cannot open shared object file`

**Fix:** Run scripts with full `LD_LIBRARY_PATH` as in `run_audit_rover_scene.sh` / `launch_rovertwin_editor.sh` (includes ChaosVehiclesPlugin).

---

## PIE does not start automatically

**Check:** `RoverTwin/Saved/Logs/SimulinkEditorLaunch.log`

- `SIMULINK_PIE_STARTED` — OK
- `SIMULINK_PIE_SHORTCUT_TIMEOUT` — watcher could not find window or trigger

**Manual workaround:** After Simulink Run, click Unreal viewport and press **Alt+P**.

Requirements for auto-PIE: `xdotool`, window title `RoverTwin - Unreal Editor`, trigger file `MATLAB/.start_rover_pie`.

---

## `setCommands skipped — sim status = stopped`

Keyboard commands only apply while simulation is **running**. Click **Run** in Simulink first, then focus the keyboard window.

---

## Actual pose unavailable in keyboard UI

**Cause:** `Move RoverTwin` RuntimeObject not ready or model not running.

**Check:** Model loaded as `RoverTwinControl`; block path is `Move RoverTwin` (rebuild model if renamed).

---

## MCP: `No command channel open`

Unreal MCP needs editor running with Python remote execution. Open project in editor; ensure `.cursor/mcp.json` unreal server is started.

---

## Path with spaces issues

Simulink uses `/tmp/RoverTwinUnrealProject` symlink created by `rover_unreal_project_alias.m`. If co-sim fails to find project, delete `/tmp/RoverTwinUnrealProject` and re-run simulation.

---

## Related docs

- [Verification checklist](verification-checklist.md)
- [Scripts reference](scripts-reference.md)
