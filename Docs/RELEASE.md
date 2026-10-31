# Releasing MSS

How a build gets from the repo to players (PLAN.md 8.8). Everything builds in Docker; the
release keystore never enters the repo.

## Once: the release keystore

```bash
tools/android.sh keystore ~/Keys/mss-release.keystore   # any path outside the repo
```

It asks for a password and makes a 4096-bit key with the alias `mss`. **Back up the file and
the password.** Every update must be signed with this key: without it, players have to uninstall
(and lose their pilots) to install a new version.

## Each release

1. Set the version in `game/project.godot` (`config/version`, e.g. `0.8.0`) and the matching
   `version/code` in `game/export_presets.cfg`: major × 10000 + minor × 100 + patch (`800`).
   The release command refuses a mismatch, so every release counts up.
2. Add the release's section to `CHANGELOG.md`.
3. Run the checks: `tools/test.sh`, the drives in `CLAUDE.md`, and
   `tools/run.sh python3 -I tools/licence_audit.py`.
4. Build:
   ```bash
   MSS_KEYSTORE=~/Keys/mss-release.keystore tools/android.sh release
   ```
   This makes `build/mss-0.8.0.apk`, prints the signer and the APK's SHA-256, and fails if
   the debug key signed it.
5. Install it on a phone that never had the debug build (or uninstall that first: the
   signatures differ). Play a WaveTime run and a Creative test fight.
6. Tag and publish: `git tag v0.8.0 && git push origin v0.8.0`, then the GitHub release and
   the itch.io upload below.

## GitHub release

Title: `MSS 0.8.0, public alpha`. Attach `mss-0.8.0.apk`. Body:

> The first public alpha of MSS, a free, open-source space shooter for Android where you build
> your own ship tile by tile and fly it.
>
> **Install:** download `mss-0.8.0.apk` on your Android phone (Android 7 or newer, 64-bit), open
> it, and allow installs from your browser or file manager when asked.
>
> **In this build:** the ship builder, WaveTime (survive escalating waves, bank your loot, upgrade,
> repeat) and Creative (build anything, test it at any level). Story mode comes later.
>
> What's new: see [CHANGELOG.md](CHANGELOG.md). Feedback and bug reports are welcome in Issues.
>
> SHA-256: `<from the release command>`

## itch.io page

- **Kind:** Game. **Classification:** Games. **Release status:** In development.
- **Pricing:** No payments (or "Donate" if wanted).
- **Upload:** `mss-0.8.0.apk`, marked as Android.
- **Genre:** Shooter. **Tags:** space, shipbuilding, arcade, open-source, sci-fi, mobile.
- **Cover image:** 630 × 500. A crop of the splash (`game/assets/branding/`) works, or a fresh
  Gemini canvas at that size.
- **Screenshots:** 3–5 landscape phone shots: the hangar with a built ship, a WaveTime wave with
  damage numbers, a ×5 power-up storm, the results card, and the escape pod. Take them with
  `tools/android.sh shot NAME` (unlock the phone first: a locked one shows the lock screen).

**Short description:**

> Build your ship tile by tile, then fly it into waves of enemies.

**Page text:**

> **MSS: Mobile Space Shooter** is a free, open-source space shooter for Android where the ship
> is yours to build.
>
> **Build.** Snap hull, armour, shield and hardpoint tiles together in the hangar, paint them,
> and bolt on thrusters and guns: gatlings, cannon, flak, rockets, lasers, EMP and mines. Every
> tile you add changes how your ship flies and how much it can take.
>
> **Fly.** One stick or two, auto-fire or manual. Hits tear tiles off your ship (and theirs),
> pieces break away, and losing the core is the end.
>
> **WaveTime.** Launch from the bay and survive escalating waves. Grab the loot, clear waves for
> bonus GC, and catch power-ups for up to ×5 firepower. When your ship goes, your escape pod
> brings the cargo home. Spend it on a better ship and go again. Your guns level up as they
> fight.
>
> **Creative.** Everything free: build anything and test it against fights from level 1 to 100.
>
> **Public alpha.** Story mode, stations and jobs are still to come, and the art, sound and
> balance are a first pass. Feedback is very welcome.
>
> Made with Godot. Code under the MIT licence: github.com/HermanRas/MobileSpaceShooter.
> Sound effects by Kenney (CC0).
>
> **Install:** download the APK on your phone (Android 7 or newer, 64-bit) and open it; allow
> installs from your browser when asked.
