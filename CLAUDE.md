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
tools/drive.sh res://dev_preview/drive_menu.tscn         # every main-menu button and screen, and back
tools/drive.sh res://dev_preview/drive_profiles.tscn     # 3 pilots, separate stock, switch, delete
tools/drive.sh res://dev_preview/drive_stocked.tscn      # the stocked hangar: wallet, sell, inventory, market
tools/drive.sh res://dev_preview/drive_testflight.tscn   # Creative test fights: L1 easy, L100 brutal, results card
tools/drive.sh res://dev_preview/drive_shop.tscn         # pilot A publishes a ship, pilot B buys it in the shop
tools/drive.sh res://dev_preview/drive_share.tscn        # ships to and from a file and a share code, and Save as enemy
$GODOT --headless --path game res://dev_preview/trace_flight.tscn -- --ship=starter --stick=0,-1 --seconds=6
                                  # frame-by-frame flight trace (add --from=4.0 for every frame)
tools/run.sh python3 -I tools/licence_audit.py            # every asset declared?
tools/run.sh python3 -I tools/make_branding.py            # icon + splash from art_src/ -> game/assets/branding/
tools/run.sh python3 -I tools/slice_sheets.py             # Gemini sheets in art_src/ -> atlases (art_src/sheets.json)
tools/preview.sh res://dev_preview/art_tiles.tscn 1800x700 --ship=gunboat --zoom=2.2   # tile art, wear 0-4
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
