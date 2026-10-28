#!/usr/bin/env bash
# Android build and deploy, all inside Docker (nothing installed on the host).
#
#   tools/android.sh export     # build/mss-debug.apk
#   tools/android.sh devices    # is the phone connected and authorised?
#   tools/android.sh install    # install (or reinstall) the APK on the phone
#   tools/android.sh run        # launch it on the phone
#   tools/android.sh deploy     # export + install + run
#   tools/android.sh logcat     # follow the game's log (Ctrl+C to stop)
#   tools/android.sh log        # print the game's log so far and exit
#   tools/android.sh perf       # the debug build's fps/frame-time log (Honor drops it from logcat)
#   tools/android.sh runs       # every performance test run kept on the phone (7.5), as JSON
#   tools/android.sh shot NAME  # screenshot the phone to build/phone_NAME.png
#   tools/android.sh adb ARGS   # any adb command, e.g. adb shell input tap 500 300
#
# The debug keystore and adb's key live in .android/ (gitignored), so the phone only has to
# authorise this machine once and reinstalls keep the same signature.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$HOME/Downloads/Godot_v4.7.1/Godot_v4.7.1-stable_linux.x86_64}"
IMAGE="mss-android:1"
PACKAGE="com.example.mss"
APK="build/mss-debug.apk"

image() {
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build -t "$IMAGE" -f "$ROOT/tools/docker/android.Dockerfile" "$ROOT/tools/docker" >&2
  fi
}

# Build steps run as the host user, so files in the repo stay owned by you.
as_user() {
  docker run --rm --init -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -e GODOT_ANDROID_KEYSTORE_DEBUG_PATH=/work/.android/debug.keystore \
    -e GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey \
    -e GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android \
    -v "$ROOT":/work -w /work -v "$GODOT":/opt/godot/godot:ro \
    "$IMAGE" bash -c "$1"
}

# adb runs as root to reach the USB device node, then hands its key files back to you.
adb_cmd() {
  mkdir -p "$ROOT/.android/adb"
  docker run --rm --init -i -u 0 \
    --device-cgroup-rule='c 189:* rmw' -v /dev/bus/usb:/dev/bus/usb \
    -v "$ROOT/.android/adb":/root/.android -v "$ROOT":/work -w /work \
    "$IMAGE" bash -c "$1; rc=\$?; chown -R $(id -u):$(id -g) /root/.android; exit \$rc"
}

do_export() {
  mkdir -p "$ROOT/.android" "$ROOT/build"
  as_user '
    set -e
    if [ ! -f .android/debug.keystore ]; then
      keytool -genkeypair -keystore .android/debug.keystore -storepass android \
        -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
    fi
    /opt/godot/godot --headless --path game --import >/dev/null 2>&1 || true
    /opt/godot/godot --headless --path game --export-debug Android ../'"$APK"'
  '
  ls -l "$ROOT/$APK"
}

image
case "${1:-}" in
  export)  do_export ;;
  devices) adb_cmd "adb devices -l" ;;
  install) adb_cmd "adb install -r $APK" ;;
  run)     adb_cmd "adb shell monkey -p $PACKAGE -c android.intent.category.LAUNCHER 1" ;;
  deploy)  do_export
           adb_cmd "adb install -r $APK && adb shell monkey -p $PACKAGE -c android.intent.category.LAUNCHER 1" ;;
  logcat)  adb_cmd "adb logcat -s godot:V" ;;
  log)     adb_cmd "adb logcat -d -s godot:V" ;;
  perf)    adb_cmd "adb shell run-as $PACKAGE cat files/perf.log" ;;
  runs)    adb_cmd "adb shell run-as $PACKAGE cat files/perf_runs.json" ;;
  shot)    adb_cmd "adb exec-out screencap -p > build/phone_${2:-shot}.png; chown $(id -u):$(id -g) build/phone_${2:-shot}.png" && ls -l "$ROOT/build/phone_${2:-shot}.png" ;;
  adb)     shift; adb_cmd "adb $(printf '%q ' "$@")" ;;
  *) sed -n '2,17p' "$0"; exit 2 ;;
esac
