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
#   tools/android.sh keystore PATH   # make the release keystore at PATH (outside the repo), once
#   tools/android.sh release    # build/mss-VERSION.apk, signed with the release keystore (8.8)
#
# The debug keystore and adb's key live in .android/ (gitignored), so the phone only has to
# authorise this machine once and reinstalls keep the same signature.
#
# The release keystore never enters the repo: `release` reads MSS_KEYSTORE (its path),
# MSS_KEYSTORE_ALIAS (default "mss") and MSS_KEYSTORE_PASS (asked for if unset), mounts only
# that file, read-only, and refuses one inside the repo. versionCode must match the version in
# project.godot (major*10000 + minor*100 + patch), so every release counts up.
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

# The keystore's path, made absolute; fails if it's inside the repo.
outside_repo() {
  local path
  path="$(realpath -m "$1")"
  case "$path" in
    "$ROOT"/*) echo "The release keystore must live outside the repo, not at $path" >&2; exit 1 ;;
  esac
  echo "$path"
}

do_keystore() {
  [[ -n "${1:-}" ]] || { echo "usage: tools/android.sh keystore /path/outside/the/repo/mss-release.keystore" >&2; exit 2; }
  local path
  path="$(outside_repo "$1")"
  [[ ! -e "$path" ]] || { echo "$path already exists; not overwriting it" >&2; exit 1; }
  mkdir -p "$(dirname "$path")"
  local pass pass2
  read -rsp "Keystore password (6+ characters; keep it safe, it can't be recovered): " pass; echo
  read -rsp "Again: " pass2; echo
  [[ "$pass" == "$pass2" && ${#pass} -ge 6 ]] || { echo "Passwords differ or are too short" >&2; exit 1; }
  docker run --rm --init -u "$(id -u):$(id -g)" -e HOME=/tmp -e STOREPASS="$pass" \
    -v "$(dirname "$path")":/out "$IMAGE" \
    keytool -genkeypair -keystore "/out/$(basename "$path")" -storepass:env STOREPASS -keypass:env STOREPASS \
      -alias "${MSS_KEYSTORE_ALIAS:-mss}" -keyalg RSA -keysize 4096 -validity 10000 \
      -dname "CN=${MSS_SIGNER:-MSS}, O=${MSS_SIGNER:-MSS}"
  echo "Made $path (alias ${MSS_KEYSTORE_ALIAS:-mss}). Back it up: every update must be signed with it."
}

do_release() {
  [[ -n "${MSS_KEYSTORE:-}" ]] || { echo "Set MSS_KEYSTORE to the release keystore's path (see tools/android.sh keystore)" >&2; exit 2; }
  local keystore
  keystore="$(outside_repo "$MSS_KEYSTORE")"
  [[ -f "$keystore" ]] || { echo "No keystore at $keystore" >&2; exit 1; }
  local version code want
  version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/game/project.godot")"
  code="$(sed -n 's/^version\/code=//p' "$ROOT/game/export_presets.cfg")"
  want="$(echo "$version" | awk -F. '{ print $1 * 10000 + $2 * 100 + $3 }')"
  if [[ "$code" != "$want" ]]; then
    echo "versionCode is $code but version $version wants $want: set version/code=$want in game/export_presets.cfg" >&2
    exit 1
  fi
  local pass="${MSS_KEYSTORE_PASS:-}"
  [[ -n "$pass" ]] || { read -rsp "Keystore password: " pass; echo; }
  local apk="build/mss-$version.apk"
  mkdir -p "$ROOT/build"
  docker run --rm --init -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -e GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/keystore/release.keystore \
    -e GODOT_ANDROID_KEYSTORE_RELEASE_USER="${MSS_KEYSTORE_ALIAS:-mss}" \
    -e GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$pass" \
    -v "$keystore":/keystore/release.keystore:ro \
    -v "$ROOT":/work -w /work -v "$GODOT":/opt/godot/godot:ro \
    "$IMAGE" bash -c '
      set -e
      /opt/godot/godot --headless --path game --import >/dev/null 2>&1 || true
      /opt/godot/godot --headless --path game --export-release Android ../'"$apk"'
      certs="$("$ANDROID_HOME"/build-tools/35.0.1/apksigner verify --print-certs '"$apk"')"
      echo "$certs" | grep -E "Signer #1 certificate (DN|SHA-256)"
      if echo "$certs" | grep -q "CN=Android Debug"; then echo "Signed with the DEBUG key: not a release" >&2; exit 1; fi
    '
  ls -l "$ROOT/$apk"
  sha256sum "$ROOT/$apk"
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
  keystore) do_keystore "${2:-}" ;;
  release) do_release ;;
  *) sed -n '2,24p' "$0"; exit 2 ;;
esac
