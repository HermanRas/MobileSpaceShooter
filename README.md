# MSS — Mobile Space Shooter

A free, open-source 2D space shooter for Android, made with Godot 4.7.1. Build your ship from
geometric tiles (hull, armor, shield, hardpoint), paint it, bolt on thrusters and guns, and fly
it in three modes:

- **Creative**: unlimited building, plus test flights at any level from 1 to 100
- **WaveTime**: arcade survival; everything you collect is banked
- **Story**: an open hex-tile world with stations, jobs and a 16-tile rescue campaign

Status: **Phase 0, project setup.** See [Docs/PLAN.md](Docs/PLAN.md) for the full plan and
[Docs/IDEA.md](Docs/IDEA.md) for the original brief.

## Run it

Open `game/project.godot` in Godot **4.7.1-stable** (pinned), or from a terminal:

```bash
~/Downloads/Godot_v4.7.1/Godot_v4.7.1-stable_linux.x86_64 --path game
```

## Test it

```bash
tools/test.sh        # headless; exit code 0 = all passed
```

## Layout

| Path | What |
|---|---|
| `game/` | The Godot project |
| `game/src/model/` | Pure logic, no Nodes, tested headless |
| `game/data/` | Every balance number and content table |
| `art_src/` | Gemini master images (committed; they can't be regenerated identically) |
| `tools/` | Offline scripts; anything that needs installing runs in Docker |
| `Docs/` | Idea, plan, art prompts |

## Licences

- Code: **MIT**, see [LICENSE](LICENSE).
- AI-generated art: see [GeminiCopyRight.md](GeminiCopyRight.md).
- Every asset file is listed in [game/assets/LICENCES.md](game/assets/LICENCES.md).
- Credits: [CREDITS.md](CREDITS.md).
