# Mobile deploy

Everything Android runs in Docker (`mss-android:1`, built from `tools/docker/android.Dockerfile`
on first use). Nothing is installed on the host.

## Deploy to the phone

1. On the phone: enable **Developer options → USB debugging**, then plug it in.
2. Check it's visible and authorised:

   ```bash
   tools/android.sh devices
   ```

   It must say `device`. If it says `unauthorized`, accept the prompt on the phone and run it
   again. adb's key is kept in `.android/adb/`, so the phone only asks once.
3. Build, install and launch:

   ```bash
   tools/android.sh deploy        # = export + install + run
   tools/android.sh logcat        # follow the game's log; Ctrl+C to stop
   ```

4. Check it from the PC, without touching the phone:

   ```bash
   tools/android.sh perf                     # fps, worst frame, draw calls, MB, hangar refresh
   tools/android.sh shot hangar              # screenshot -> build/phone_hangar.png
   tools/android.sh adb shell input tap 1300 702               # tap (screen px, landscape)
   tools/android.sh adb shell input swipe 329 996 1462 750 1200   # one-finger drag over 1.2 s
   ```

   adb can't pinch; that one needs a hand on the phone.

The APK lands in `build/mss-debug.apk`. To sideload it by hand instead, copy that file to the
phone.

## What's where

| Thing | Where | Notes |
|---|---|---|
| Package id | `za.co.dragoon.mss` | Chosen by the owner for 0.8.0 (D14); never change it once released |
| Export preset | `game/export_presets.cfg` | Tracked; it holds no secrets. arm64 only, sensor landscape, internet off, vibrate on. |
| Debug keystore | `.android/debug.keystore` | Gitignored. Created on the first export, and kept so reinstalls keep the same signature. |
| adb key | `.android/adb/` | Gitignored |
| Release keystore | not in the repo | The owner keeps it: `tools/android.sh keystore PATH` makes it, `MSS_KEYSTORE=PATH tools/android.sh release` signs with it. See [RELEASE.md](RELEASE.md). |

## Gotchas

- **Export needs `rendering/textures/vram_compression/import_etc2_astc=true`**, or Godot refuses
  to export for Android. It's set in `project.godot`.
- **Non-resource files only ship if the include filter names them.** The preset includes
  `*.json`, so `game/data/` is in the APK. Check after adding any new kind of data file.
- "Could not find version of build tools that matches Target SDK, using 35.0.1" is a warning,
  not an error.
- "cannot connect to daemon at tcp:5037" during export is the editor polling for devices.
  It's harmless.
- **Honor phones drop app output from logcat**, so `print()` never shows in `log`/`logcat`.
  Debug builds also write `Perf` lines to `user://perf.log`, which `tools/android.sh perf` reads.
- **Android owns the bottom ~130 px for its home gesture**, even in immersive mode. A drag
  starting there (including an adb swipe) sends the game to the background. It didn't crash;
  tap the app icon to resume.
- If `devices` shows nothing with the phone plugged in, try another cable or port, and set the
  phone's USB mode to "File transfer". Some charge-only cables carry no data.
