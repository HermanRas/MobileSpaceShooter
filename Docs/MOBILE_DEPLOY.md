# Mobile deploy

Everything Android runs in Docker (`msp-android:1`, built from `tools/docker/android.Dockerfile`
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

The APK lands in `build/msp-debug.apk`. To sideload it by hand instead, copy that file to the
phone.

## What's where

| Thing | Where | Notes |
|---|---|---|
| Package id | `com.example.msp` | Placeholder until a title is chosen (D14) |
| Export preset | `game/export_presets.cfg` | Tracked; it holds no secrets. arm64 only, sensor landscape, internet off, vibrate on. |
| Debug keystore | `.android/debug.keystore` | Gitignored. Created on the first export, and kept so reinstalls keep the same signature. |
| adb key | `.android/adb/` | Gitignored |
| Release keystore | not in the repo | The owner keeps it. Needed at 8.8. |

## Gotchas

- **Export needs `rendering/textures/vram_compression/import_etc2_astc=true`**, or Godot refuses
  to export for Android. It's set in `project.godot`.
- **Non-resource files only ship if the include filter names them.** The preset includes
  `*.json`, so `game/data/` is in the APK. Check after adding any new kind of data file.
- "Could not find version of build tools that matches Target SDK, using 35.0.1" is a warning,
  not an error.
- "cannot connect to daemon at tcp:5037" during export is the editor polling for devices.
  It's harmless.
- If `devices` shows nothing with the phone plugged in, try another cable or port, and set the
  phone's USB mode to "File transfer". Some charge-only cables carry no data.
