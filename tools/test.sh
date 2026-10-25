#!/usr/bin/env bash
# Runs the headless test suite. Exit code 0 = all passed.
#
#   tools/test.sh            refresh the import/class cache, then run every test
#   GODOT=/path/to/godot tools/test.sh
#
# The --import pass is what keeps a renamed or new `class_name` from failing with
# "Identifier not declared" (an AOD lesson), so it always runs first.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$HOME/Downloads/Godot_v4.7.1/Godot_v4.7.1-stable_linux.x86_64}"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot not found at $GODOT (set GODOT=...)" >&2
  exit 2
fi

"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
exec "$GODOT" --headless --path "$ROOT/game" res://tests/run_tests.tscn
