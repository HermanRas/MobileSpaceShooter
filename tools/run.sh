#!/usr/bin/env bash
# Run a command inside the tools container, with the repo mounted at /work and the pinned
# Godot binary at /opt/godot/godot. Nothing gets installed on the host.
#
#   tools/run.sh python3 tools/licence_audit.py
#   tools/run.sh --rebuild true      # rebuild the image, then run `true`
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$HOME/Downloads/Godot_v4.7.1/Godot_v4.7.1-stable_linux.x86_64}"
IMAGE="mss-tools:1"

if [[ "${1:-}" == "--rebuild" ]]; then
  shift
  docker rmi -f "$IMAGE" >/dev/null 2>&1 || true
fi
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker build -t "$IMAGE" -f "$ROOT/tools/docker/tools.Dockerfile" "$ROOT/tools/docker" >&2
fi

# --init: without a real PID 1, xvfb-run never receives Xvfb's ready signal and hangs forever.
exec docker run --rm --init \
  -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$ROOT":/work -w /work \
  -v "$GODOT":/opt/godot/godot:ro \
  "$IMAGE" "$@"
