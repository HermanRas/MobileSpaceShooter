#!/usr/bin/env bash
# Screenshot a real scene, rendered in the tools container on a virtual display.
#
#   tools/preview.sh res://scenes/menu/main_menu.tscn            # phone aspect, 1560x720
#   tools/preview.sh res://scenes/menu/main_menu.tscn 1280x720
#
# Writes game/dev_preview/out/<scene name>.png (gitignored).
# 1560x720 is the 1280x720 base viewport stretched to the reference phone's 2.17:1 screen
# (PLAN.md 5.5).
set -euo pipefail

SCENE="${1:?usage: tools/preview.sh res://path/to/scene.tscn [WIDTHxHEIGHT]}"
SIZE="${2:-1560x720}"
NAME="$(basename "$SCENE" .tscn)"

exec "$(dirname "${BASH_SOURCE[0]}")/run.sh" \
  xvfb-run -a -s "-screen 0 ${SIZE}x24" \
  /opt/godot/godot --display-driver x11 --audio-driver Dummy --rendering-driver opengl3 \
    --path game --resolution "$SIZE" \
    res://dev_preview/preview.tscn -- \
    --scene="$SCENE" --out="/work/game/dev_preview/out/${NAME}_${SIZE}.png"
