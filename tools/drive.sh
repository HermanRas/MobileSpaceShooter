#!/usr/bin/env bash
# Run a driver scene: it plays the real game with synthetic input and exits 0 if every step
# passed. Rendered in the tools container on a virtual display, like tools/preview.sh.
#
#   tools/drive.sh res://dev_preview/drive_hangar.tscn
set -euo pipefail

SCENE="${1:?usage: tools/drive.sh res://dev_preview/<driver>.tscn [WIDTHxHEIGHT]}"
SIZE="${2:-1560x720}"

exec "$(dirname "${BASH_SOURCE[0]}")/run.sh" \
  xvfb-run -a -s "-screen 0 ${SIZE}x24" \
  /opt/godot/godot --display-driver x11 --audio-driver Dummy --rendering-driver opengl3 \
    --path game --resolution "$SIZE" "$SCENE"
