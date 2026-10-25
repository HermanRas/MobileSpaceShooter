# MSS: instructions for agents

Read [Docs/PLAN.md](Docs/PLAN.md) first. It's the source of truth for decisions (§2–§3),
the design numbers (§4), the architecture (§5) and what to build next (§7). Status lives in
its checkboxes; there's no board.

## Commands

```bash
tools/test.sh                     # the headless suite; run before calling anything done
GODOT=~/Downloads/Godot_v4.7.1/Godot_v4.7.1-stable_linux.x86_64
$GODOT --path game                # run the game
$GODOT --headless --path game --import   # refresh the class cache after adding a class_name

tools/preview.sh res://scenes/debug/blueprint_view.tscn   # screenshot a scene (Docker, no window)
                                  # -> game/dev_preview/out/; open the PNG to check it
tools/drive.sh res://dev_preview/drive_hangar.tscn       # play the hangar with fake touches; exit 0 = pass
tools/drive.sh res://dev_preview/drive_flight.tscn       # hangar -> Fly -> hits, draw calls, collisions -> back
tools/run.sh python3 -I tools/licence_audit.py            # every asset declared?
tools/android.sh export|devices|deploy|logcat             # see Docs/MOBILE_DEPLOY.md
tools/android.sh perf                                     # phone fps / frame time / refresh (debug builds)
tools/android.sh shot NAME                                # phone screenshot -> build/phone_NAME.png
tools/android.sh adb shell input tap X Y                  # drive the phone (screen px, landscape)
```

## Rules

- **Godot 4.7.1-stable is pinned.** Typed GDScript everywhere. Renderer is Compatibility.
- **`game/src/model/` is pure logic**: no Node types, no textures, no input, no scene tree.
  `tests/test_model_boundary.gd` enforces it. Put hard logic there so it can be tested.
- **Data, not code.** Balance numbers and content live in `game/data/*.json` (each with a
  `format` field). Never hard-code a balance number.
- **The asset seam.** Gameplay asks `Assets.tex(&"vis.some_id")`; only `data/visuals.json`
  maps IDs to files. Every visual has a placeholder, so code never waits on art.
- **Every asset file needs a row in `game/assets/LICENCES.md`.**
- **Nothing gets installed on the host.** Python tools, the Android SDK, JDK and adb run in
  Docker (`tools/docker/`). Write only inside this repo or the session scratchpad.
- **Tests:** files named `test_*.gd` extending `TestCase` (`game/tests/case.gd`), methods named
  `test_*`. A test with no assertions, or one cut short by a script error, fails.
- **Plan upkeep:** when a sub-phase is done, replace its checklist with a one-line DONE note
  (what exists, where, and the one non-obvious thing). Don't write a build diary.
- Commits end with the co-author line from the session's instructions.
