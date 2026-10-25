# MSP — Mobile Space Shooter: Game & Implementation Plan

Companion to [IDEA.md](IDEA.md), which describes what we're building. This document covers
**how we build it**: the locked decisions, the numbers, the architecture, and the phase
order, broken into small chunks that can each be finished.

Written 2026-10-25. The structure and the art workflow are carried over from AOD_Mobile
(`../AOD_Mobile/PLAN.md`, `../AOD_Mobile/Docs/ART_PROMPT.md`), because that workflow worked.

> **THE RULE THIS FILE IS KEPT TO** (learned on AOD, where the plan grew to 4000 lines twice):
> this file holds **decisions, specifications and open questions**. When a row is done, note
> **what exists, where it lives, and the one thing about it that isn't obvious**. Reasoning
> belongs in the code it describes, history in `git log`, and status in this file's checkboxes. The pull
> toward writing a build diary is strongest on the phase you're currently finishing.

---

## 0. How to read this document

- **§1–§3** cover what the game is and what's decided. Read these first.
- **§4** gives the design numbers. Every value there is a *starting* value that lives in
  `game/data/` and gets tuned in play. Code never hard-codes a balance number.
- **§5–§6** cover architecture and the art pipeline.
- **§7** is the phase plan. Phase `N` contains sub-phases `N.M`, and each sub-phase is a
  checklist with a **Done when** line. A sub-phase should be about one working session.
  Anything bigger gets split.
- **§8** is the art track. It runs in parallel and never blocks code, because every
  asset has a placeholder (§5.3).
- Items marked **`[Dn]`** depend on a decision in §3. It's either answered by the owner
  (§3.1), or still open (§3.2), in which case the plan proceeds on the default shown there.
- **Milestones:** **M1** fly a ship you built · **M2** Creative mode playable · **M3**
  public alpha (WaveTime + Creative) · **M4** v1.0 (Story mode).

---

## 1. The game in one page

**A mobile 2D space shooter where the ship is the character.** You build the ship from
geometric tiles, paint it, hang thrusters and guns off it, and fly it. Enemies are built from
the same tiles, so whatever you fight shows you what you could build.

| Pillar | What it means in practice |
|---|---|
| **Build anything, fly what you built** | One ship model is shared by the player, enemies, VIPs, bosses and stations. Placement, stats and physics all come from the blueprint. |
| **Loot shapes the build** | An enemy drops materials matching what it's made of, plus a small chance of one of its guns or thrusters. You hunt the enemies that carry what you need. |
| **Three modes, one hangar** | **Creative**: unlimited building, plus test flights at any level 1–100. **WaveTime**: an arcade survival run, and everything you collect is banked. **Story**: an open hex world with stations, jobs, and a 16-tile rescue campaign. |
| **Phone first** | Landscape, touch controls with 1-stick and 2-stick schemes, short sessions, hot-seat profiles on one device. |

**Scope order.** Creative ships first because it's the hangar plus a test button. WaveTime
comes next because it reuses everything and becomes a public alpha. Story is the largest
mode and comes last.

---

## 2. Locked decisions

| Decision | Choice | Why |
|---|---|---|
| Engine | **Godot 4.7.1-stable**: `~/Downloads/Godot_v4.7.1-stable_linux.x86_64` (also the win64 builds) | Pinned. Upgrades happen deliberately at a phase boundary, with the suite green before and after. |
| Language | **GDScript**, typed (`var x: int`) everywhere | Matches AOD. Typed code catches errors at parse time. |
| Renderer | **Compatibility** (`gl_compatibility`), not Mobile | The existing stub uses Mobile. AOD measured that Vulkan-Mobile crashes on older Mali/Adreno and supports *fewer* Android devices, with no benefit in 2D. |
| Dimension | **2D**, top-down. Godot 2D physics (Jolt is 3D-only and has no effect here). | |
| Orientation | **Landscape, locked** | Twin-zone touch controls need the width. |
| Base resolution | **1280 × 720**, stretch `canvas_items` / aspect `expand` | Scales cleanly to 16:9–20:9 phones. The HUD anchors to edges and safe areas. |
| Physics tick | **60 Hz**; no networking, so no sim/server split | AOD's client–server split existed only for multiplayer, which this game doesn't have. |
| Flight model | **Physical thrust.** Each thruster pushes at its mount point, so off-centre thrusters also turn the ship. There's no hidden turning force. | Owner's call: a badly built ship should fly badly (§4.3, §4.10). |
| Repository | **git in the project folder** `[D1]` | Google Drive on this PC syncs with rsync, which is safe for git |
| World unit | **1 U = one Large tile edge = 64 px** at zoom 1 | Every size in §4 is in U. |
| Licence | **Code MIT**. AI-generated art is documented as *probably uncopyrightable* (see `GeminiCopyRight.md`, copied from AOD). Third-party assets each carry their own licence in `game/assets/LICENCES.md`. | Same position as AOD. Writing an AI asset down as "MIT" would be wrong. |
| Data-driven | Tiles, shapes, thrusters, weapons, enemies, levels, world-gen, jobs and story live in `game/data/*.json` | Balancing never requires a code change. |
| Asset seam | Gameplay code refers to `&"vis.thruster.ion"`, never to a file path (§5.3) | Art can arrive late and in any order. |
| Host machine | **Linux**. Nothing is installed on the host. Python tools, Android SDK, JDK and adb run in **Docker** (§7 Phase 0) | Owner's global rule. The host has Docker and git but no Java or adb. |
| Multiplayer | **None.** "Multiple players on one device" means hot-seat **profiles**, taking turns, with a kills vs deaths scoreboard per character in WaveTime `[D2]` | |

---

## 3. Decisions

### 3.1 Answered by the owner (locked 2026-10-25)

| # | Question | Answer | Used in |
|---|---|---|---|
| **D1** | Where does `.git` live? | **In the project folder.** Google Drive on this PC syncs with rsync, which is safe for git. (AOD's corrupted `.git` was under the Windows Google Drive client.) Still push to a remote for backup. | 0.1 |
| **D2** | "Multiple players on one device" | **Hot-seat profiles, taking turns.** Each profile has its own name, character and saves. WaveTime shows a **kills vs deaths scoreboard per character**, best at the top (8.4). | 6.2, 8.4 |
| **D3** | Art style | **Characters:** high-quality painted portraits. They appear only in menus and speech dialogs, each in **4 moods** (idle, happy, sad, angry). The player picks a **male or female base character and recolours it** (§6.5). The character references show moods and recolouring, not a target style. **UI:** painted, after the Menu Theme reference. **Ships:** clean flat tile textures (§6.2). | 6.2, A.0, A.7 |
| **D4** | WaveTime layout | **Free-roam arena**, enemies from all sides, using the same flight model and code as Story tiles. Plus arcade extras: **floating damage numbers** on hits, and ridiculous **×2–×5 bullet power-ups** that last a set time and **never carry over to the hangar** (8.3). | 8.1, 8.3 |
| **D5** | Resources | **Hull, Alloy, Crystal and Tech** (Tech drops and shows as **wires**), plus **Galactic Credits (GC)**. Every tile needs Hull: Armor adds Alloy, Shield adds Crystal, and Hardpoint adds Alloy + Tech. All four materials can be bought and sold for GC (§4.6). | 4.2, 4.6 |
| **D6** | Creative blueprint library | **Per device**, so any profile can buy a ship anyone designed. Inventories and saves stay per profile. | 7.3 |
| **D7** | What ends a ship | **A Core tile**: exactly one per ship, free, and the ship dies when it's destroyed. Tiles cut off from the Core break off as debris. | 1.2 |
| **D8** | Weapon levels | **Guns level from L1 to L999 with XP earned from kills.** A gun keeps its XP when it's dropped, uninstalled, or refitted between fixed, swivel and turret. In Story, guns found further from the centre are higher level, and you need them to be (§4.4). | 4.4, 4.8 |
| **D9** | Reading "5×5×5 ×3 = 375 stations" | **5 backdrops × 5 station exteriors × 5 colour schemes × 3 room sets** (hangar/shop/bar interiors) | 11.1, A.8 |
| **D10** | How strength grows | **Ships have no level; guns do.** A ship's strength is its design. Tile weights against thruster power decide whether it's a slow tank or a fast laser strafer, and a huge block with one small thruster barely moves. There is no Ship Rating. | 4.3, 4.8 |
| **D11** | Which world-map tiles you can see | **Story tiles, plus every tile within 5 hexes of your ship** | 9.3 |
| **D12** | When job rewards pay | **On return to a hangar.** "Save and return to hangar" pays at once, but then you have to fly all the way back out. Carrying rewards further is your own risk. | 4.9, 12.1 |
| **D13** | Thruster sizes | **Every thruster type comes in Small, Medium and Large**, and they can be mixed on one ship | 4.3 |
| **D14** | Title, package id, stores | Working title "MSP", package id `com.example.msp`, itch.io + GitHub Releases first | 15.3 |
| **D15** | Reference phone | **The same phone as AOD**: HONOR LNA-NX1, Mali-G610 (§5.5). Creative gets a performance test (7.5). | 0.9, 7.5 |
| **D16** | Status board | **None**, since this is a quick project. Status lives in this file's checkboxes. | – |
| **D17** | Selling the starter ship's parts | Shops **warn before you sell your last thruster or your last gun**, but allow it. The starter ship has 3 thrusters and 1 gun. | 4.10, 11.4 |
| **D18** | What "Save and return to hangar" does | **A real save**: it takes you to the last hangar you docked at and keeps everything. It's only available after **10 s without combat**. | 4.9, 6.5, 9.4 |
| **D19** | Visibility of story tiles | **All 16 story tiles are visible from the start.** Tiles you've seen stay revealed after you move away. | 9.3 |
| **D20** | WaveTime scoreboard order | **Kills ÷ deaths**, ties broken by kills. The best score is shown as a column. | 8.4 |
| **D21** | Do thrusters gain XP? | **No.** Thrusters stay L1–3 and are found or bought. | 4.3 |
| – | Flight model | **Physical thrust.** The minimum flyable ship has 2 rear thrusters and 1 front thruster. Releasing the stick auto-brakes (§4.3). | 3.3 |
| – | Stations in space | **Built from the same blocks as ships**, with a safe ring that docks you (§4.11) | 11.1 |
| – | Creative sharing | **Save a ship to a file and share it with friends** (7.4) | 7.4 |

### 3.2 Still open

None. New questions get added here as they come up.

---

## 4. Core design specification

### 4.1 Geometry: shapes, sizes, snapping

**Edge-snapping, not a square grid.** IDEA.md asks for hexagons next to squares and triangles,
and those can't share a square grid. They can all share edges, because a square, an
equilateral triangle and a regular hexagon have equal-length sides (Reassembly's model).

| Shape | Edges (in units of the size's edge length *e*) | Notes |
|---|---|---|
| Square | 4 × *e* | |
| Rectangle | 2 × *e*, 2 × 2*e* | A 1:2 rectangle, so its long edge has double the ports |
| Triangle | 3 × *e*, equilateral | |
| Wedge | 2 × *e* legs + a hypotenuse with **no ports** | A right-isosceles triangle. The reference ships use these for noses and fins. It's an addition, so drop it if unwanted. |
| Hexagon | 6 × *e* | |

| Size | Edge *e* | Cost and stat factor (IDEA.md: "size × base cost") |
|---|---|---|
| Small | 0.25 U | 0.25 |
| Medium | 0.5 U | 0.5 |
| Large | 1.0 U | 1.0 |

- **Ports** sit every **0.25 U** along every attachable edge, so one Large edge can take four
  Small tiles. Two tiles connect when one tile's edge sits flush on a run of the other's ports.
- **Rotation** is stored as an integer number of **15° steps**. Square and hexagon angles
  (90°/120°) combine in 30° steps, and the wedge adds 45°, so 15° covers every combination.
  The builder only offers rotations that make the snapped edge flush.
- **Overlap** is checked with `Geometry2D.intersect_polygons` and a small epsilon. Touching
  edges are allowed; overlapping areas are not.
- **All shapes are convex**, so one `CollisionPolygon2D` per tile is exact.
- ⚠️ **Balance trap:** the stat factor is linear in size, but area is quadratic. Sixteen Smalls
  fill one Large's area for 4× the cost and 4× the stats, so small tiles are stat-dense. The
  curve lives in one constant (`size_stat_curve` in `tiles.json`) and gets tuned in M2 play.
- **Build limits:** a hangar build area of 16 × 16 U, and **150 tiles** per ship (the
  performance budget, §5.5). Creative has the same caps.

### 4.2 Tile types

Starting values for a **Large** tile (multiply by the size factor). **Mass drives
acceleration** `[D10]`, so heavy armour makes a ship slow unless it carries bigger thrusters.

| Type | HP | Armor | Shield | Mass | Cost `[D5]` | Special |
|---|---|---|---|---|---|---|
| **Core** `[D7]` | 300 | 5 | – | 2.0 | free, one per ship | Death when destroyed. Its facing is the ship's **forward** (the arrow in the hangar). It has no turning force of its own. |
| **Hull** | 100 | 0 | – | 1.0 | 10 Hull | Cheapest HP |
| **Armor** | 150 | 6 | – | 2.5 | 6 Hull + 8 Alloy | Flat damage reduction per hit on this tile |
| **Shield** | 40 | 0 | +60 cap, +4/s regen | 0.8 | 6 Hull + 8 Crystal | Adds to the **ship-wide shield pool** |
| **Hardpoint** | 120 | 4 | – | 1.5 | 6 Hull + 6 Alloy + 4 Tech | Armor with mounts: thrusters/edge weapons on its edges, a turret on its face |

Each tile type has a texture (§6.2), and colour is painted per tile in the hangar.

### 4.3 Thrusters and flight

Thrusters mount on a **hardpoint edge**. They push the ship in the direction opposite their
exhaust, which points along that edge's outward normal.

Every type comes in **Small, Medium and Large** `[D13]`: a footprint of 0.25 / 0.5 / 1.0 U of
edge, with thrust, mass and cost × the size factor (§4.1). Types and sizes can be mixed on one
ship. Thrusters have levels **L1–3** and don't gain XP `[D21]`.

| Type (Large) | Behaviour | L1 | L2 | L3 | Visual |
|---|---|---|---|---|---|
| **Pulse** | An impulse every 0.5 s (a flat speed kick) | avg 40 | 45 | 50 | Small orange puff per pulse |
| **Jet** | Steady force | 70 | 80 | 90 | Red fire trail, length grows with throttle |
| **Ion** | Force **ramps while it stays on**, from 30 to its peak | ramps to 120 in 3.0 s | 140 in 2.5 s | 160 in 2.0 s | Short blue circular blowtorch, brightens with the ramp |

**Invariants, enforced by a headless test** (the IDEA.md rule "never better than ion"), for
every size: pulse Lx < jet Lx at every level, and `max(pulse L3, jet L3) < ion L1 peak`. Ion
starts *weaker* than jet (30), which is the tradeoff: commitment buys speed.

**The flight model is physical thrust** (owner, 2026-10-25). Each thruster applies its force at
its mount point. That pushes the ship, and if the thruster is off the centre of mass, it also
turns it. There's no hidden gyro or helper force. A ship turns only if its thrusters can turn
it, and **mass matters**: more blocks need bigger thrusters, so a design can be a slow tank or a
fast laser strafer.

**The minimum flyable ship has 3 thrusters**: two at the back, split either side of the centre,
and one at the front for braking and reverse. The starter ship is built this way.

How the flight controller uses whatever thrusters a ship has:

- **Stick → thrusters.** Each tick, every thruster is throttled by how much its push helps the
  requested move and how much its torque helps the turn. Thrusters that would work against it
  stay off.
- **Only forward and back thrusters:** the ship moves along one axis and steers with the split
  thrusters. Drag the stick left and forward, and the right rear thruster fires, so the ship
  moves forward while turning left.
- **Thrusters facing all 4 ways:** all 4 directions are used, so the ship can strafe sideways as
  well as turn.
- **Stick released → auto-brake.** The controller fires whichever thrusters oppose the current
  motion and spin, and brings the ship to a stop if its thrusters can. A ship with nothing
  pointing the right way can't brake, and keeps drifting (§4.10).
- An ion thruster keeps its ramp for as long as it stays on.
- Damping is very low, so momentum carries. Top speed in a direction is the push that way ÷ mass.
- The hangar shows a **thrust rose** (the maximum push in 8 local directions), the **turn
  strength** each way, and the acceleration, so problems show up before flying.

### 4.4 Weapons and mounts

| Mount | Sits on | Arc | Fire mode |
|---|---|---|---|
| **Fixed** | Hardpoint edge | Edge normal, 0° | Manual or auto (chosen at install) |
| **Swivel 45°** | Hardpoint edge | ±22.5° | Manual or auto |
| **Turret 360°** | Hardpoint face | Full circle | **Always auto** |

**Refit:** at a hangar, a gun can be refitted between the mounts its type allows, for a small
Alloy + Tech cost. It keeps its XP `[D8]`.

| Weapon | Damage type | Mounts | Role |
|---|---|---|---|
| Single gatling | Kinetic | F / S / T | Starter. High rate, low damage. |
| Multi gatling | Kinetic | F / S / T | Spin-up, then shreds |
| Flak (shotgun) | Kinetic + Explosive airburst | F / S / T | Close range, swarms, shoots down rockets |
| Cannon | Kinetic, armour-piercing | F / S / T | Slow heavy shell. IDEA.md's "mounted cannon" and "cannon turret" are the same gun on different mounts, so refitting moves it between them. |
| EMP | EMP | F / T | Area pulse. Low damage, but knocks out shields and thrusters for 2 s. |
| Rockets | Explosive | F / S / T | Homing salvo with splash |
| Laser | Energy | F / S / T | Hitscan beam with heat build-up. Shield breaker. |
| Mines | Explosive | Rear edge (F) | Dropped behind, proximity trigger |

**Gun levels, L1–L999** `[D8]`:

- Every gun is an **item** with its own XP. Its level comes from an XP curve in
  `data/weapon_xp.json`.
- **XP comes from kills.** A kill's XP (scaled by the enemy's encounter level) is split between
  your guns by the damage each one dealt to that enemy.
- Level scales the gun's main stats. The starting curve is +1% per level, so L999 is about ×11,
  and the curve is tuned in data.
- A gun keeps its XP when an enemy drops it, when it's uninstalled in the hangar, and when it's
  refitted between mounts.
- Enemy guns are around **10 × the encounter level** (§4.8), so the guns you find get better
  the further out you go, and so do the guns you need.
- Creative can set any gun to any level, and earns no XP.

Auto weapons pick the nearest target in their arc and lead it.

### 4.5 Damage model

1. A hit first drains the **ship shield pool** (the sum of shield tiles). The pool regenerates after
   3 s without a hit.
2. Once the shield is empty, the hit lands on the **tile it struck**:
   `dmg = max(raw × type_mult − tile.armor, raw × 0.2)`. The 20% floor keeps armor from making a
   ship immune.
3. A tile at 0 HP is **destroyed**: its collision and mesh are removed. A connectivity BFS from the
   Core then turns any cut-off group into **debris** (it drifts and fades). Mass, centre of mass and
   the thrust layout are recomputed.
4. **Core destroyed → ship dies.**

| Type | vs Shield | vs Armor | Notes |
|---|---|---|---|
| Kinetic | ×1.0 | full reduction | |
| Energy | ×1.5 | half reduction | Lasers |
| Explosive | ×0.75 | full reduction | Splash hits every tile in its radius |
| EMP | ×3.0 | n/a (×0.2 HP damage) | Disables shields and thrusters for 2 s |

**Combat repair (Story):** after **10 s without being hit**, damaged tiles heal over time,
paid for from the materials in your **cargo** at each tile type's cost. Destroyed tiles stay
gone, shown as ghost outlines, until a hangar restores them.

### 4.6 Resources and economy `[D5]`

| Resource | Used for | Dropped by |
|---|---|---|
| **Hull** | Every tile | Enemies, by tile count. Asteroids (common). |
| **Alloy** | Armor, Hardpoint, refits | Enemies, by armor/hardpoint count. Metallic asteroids. |
| **Crystal** | Shield | Enemies, by shield count. Crystal asteroids. |
| **Tech** | Hardpoint, refits | Enemies, by mounted part count. Beacons and derelicts. **Drops and shows as a bundle of wires.** |
| **Galactic Credits (GC)** | Buying materials, parts and ships | Selling materials, jobs, story rewards |

- **The market** buys and sells all four materials for GC. Buying costs more than selling earns
  (the spread is in data). There's a market in every Story station shop and in the WaveTime hangar.
- **Drops are derived from the enemy's own blueprint composition** × a level factor, so nobody
  writes a drop table by hand and "hunt the shield ships to get crystal" works without extra rules.
- **Part drop:** a small chance (start at 4%) to drop one of the enemy's mounted guns or
  thrusters. A dropped gun keeps its XP.
- **Removing a tile in the hangar refunds 100%** of its cost. Experimenting must be free.
- **Inventory** (per profile) holds materials, GC, guns (each one an item with its type, mount
  and XP), thrusters (type × size × level counts) and owned ships.

### 4.7 Controls

| Scheme | Left side | Right side |
|---|---|---|
| **2-stick** | Floating virtual stick: moves and steers as in §4.3. Let go to auto-brake. | **FIRE** (active manual weapon group) and **SWITCH** (pauses and lists manual weapons to choose from) |
| **1-stick** | Same stick | Nothing. Every weapon is treated as auto. |

Settings include a handedness mirror, stick size and opacity, vibration, and screen shake. Desktop
and dev builds support keyboard, mouse and gamepad through the same input actions. A true
twin-stick mode (the right stick aims) is in the v2 backlog.

### 4.8 Difficulty and progression

- **Encounter level 1–100** is the single difficulty axis. Creative's test slider picks it
  directly, WaveTime maps `wave → level`, and Story maps `ring distance → level`. Every mode calls
  the same encounter generator (5.3).
- **Ships have no level** `[D10]`. A ship's strength is its design (§4.3) and its guns.
- **Guns are L1–L999** `[D8]`. Enemy guns are about 10 × the encounter level, give or take a
  spread, so a level-40 tile has guns around L400.
- The world map's tile popup shows the tile's level and the gun levels found there.

### 4.9 Story save rules (from IDEA.md, written as rules so they can be tested)

1. A save is **committed only at a hangar**: when you dock, or through **Save and return to
   hangar** (rule 6).
2. **Death reloads the last commit.** Everything since then is lost: cargo, tile progress,
   tile states, job progress.
3. On commit, every tile touched since the last commit writes its state: visited → **grey**,
   completed → **green with a tick**, failed → **red**.
4. Restoring destroyed tiles needs a hangar. Repairing damage does not (4.5).
5. After the final station falls, the save is flagged `campaign_complete` and play continues.
6. **Save and return to hangar** (pause menu or world map) needs **10 s without combat**
   `[D18]`. It takes you to the last hangar you docked at and commits there, keeping everything
   since then: cargo, job rewards, tile states. The price is flying back out.
7. **Job rewards are paid when you return to a hangar**, by either route `[D12]`.

### 4.10 Bad builds and the way back (owner, 2026-10-25)

Building a ship that can't fly properly is allowed. There are three ways back:

1. **The map edge (Story).** A ship that can't steer or brake drifts to the edge, which opens the
   world map as usual. The world map has **Save and return to hangar** (once you've had 10 s
   without combat).
2. **The pause menu (every mode).** In Story it has the same **Save and return to hangar**. In
   WaveTime, **Return to hangar** ends the run and banks the loot as normal. In Creative it ends the
   test flight.
3. **The starter ship can always be rebuilt.** It's a Core, hull tiles, **3 pulse thrusters** (2 at
   the back, 1 at the front) and **1 single gatling** `[D17]`. Its blueprint is pinned in every
   hangar's ship list and can't be deleted. Removing tiles refunds 100% (§4.6) and parts go back to
   inventory, so stripping a ship gives back enough raw materials to build the starter ship
   again. The one exception is selling its parts, which shops warn about (`[D17]`).

The hangar **warns but never blocks**: "no forward thrust", "can't brake", "can't turn
left/right", "pulls to one side".

### 4.11 Space stations in flight (owner, 2026-10-25)

- **Stations are built from the same blocks as ships.** The station generator assembles hub,
  arm and ring modules into a station blueprint, painted in the station's colour scheme (the same
  scheme its station screen uses). The bandit HQ is a hostile station built the same way.
- **A safe ring** surrounds each station. World generation keeps it clear (no asteroids, no
  spawns), and there's no combat inside it.
- **Reaching the ring docks you**: the ship stops dead and the station menu opens.
- **Leaving the menu** turns the ship 180° to face away, with zero motion, and places it a few
  blocks (3 U) outside the ring, so the menu doesn't open again straight away. Flying back into
  the ring docks again.

---

## 5. Architecture

### 5.1 Repository layout

```
MSP/
  README.md  LICENSE  CREDITS.md  GeminiCopyRight.md  CLAUDE.md
  Docs/            IDEA.md PLAN.md ART_PROMPT.md STORY.md MOBILE_DEPLOY.md
  insperationPictures/                 # reference images, never shipped
  art_src/         Gemini masters, COMMITTED (cannot be regenerated identically)
    tiles/ parts/ ui/ icons/ portraits/ stations/ backgrounds/
  tools/                               # offline pipeline, never shipped
    docker/        py.Dockerfile  android.Dockerfile
    slice_sheets.py  key_alpha.py  stage_art.py  licence_audit.py
    run.sh                             # `tools/run.sh py tools/slice_sheets.py ...`
  game/                                # THE GODOT PROJECT (moved from mobile-space-game/)
    project.godot  export_presets.cfg
    data/          shapes tiles thrusters weapons enemies levels worldgen jobs story
                   visuals.json audio.json   # the ONLY files mapping IDs to paths
    assets/        placeholders/ tiles/ parts/ ui/ icons/ portraits/ stations/ fonts/ audio/
                   LICENCES.md
    src/
      autoload/    data.gd assets.gd settings.gd profiles.gd save.gd audio.gd router.gd
      model/       # RefCounted only, no Node types: headless-testable
                   shape.gd tile_def.gd blueprint.gd placement.gd ship_stats.gd
                   damage.gd weapon_xp.gd hexmath.gd worldgen.gd station_gen.gd
                   encounter.gd story_state.gd
      ship/        ship_body.gd ship_mesh.gd thruster.gd flight_controller.gd
      combat/      weapon.gd projectile_pool.gd beam.gd mine.gd pickup.gd
      ai/          ai_pilot.gd behaviours/
      ui/          hud/ hangar/ menus/ widgets/ touch/
      modes/       creative/ wavetime/ story/
    scenes/        boot/ menu/ hangar/ flight/ story/ station/
    tests/         run_tests.tscn  test_case.gd  model/ ship/ story/
    dev_preview/   screenshot drivers for real scenes
```

**The one boundary rule:** nothing in `src/model/` may extend `Node`, load a texture or read
input. `tests/test_model_boundary.gd` greps for violations. All the hard logic (snapping,
stats, damage, hex math, world-gen, save rules) is there, so it can be tested in milliseconds.

### 5.2 Autoloads

| Autoload | Owns |
|---|---|
| `Data` | Loads and validates every `data/*.json` at boot and fails loudly on schema errors. Typed lookups: `Data.tile(&"armor")`. |
| `Assets` | The asset seam (5.3) |
| `Settings` | Device-wide settings (`user://settings.json`) |
| `Profiles` | The profile list and the active profile |
| `Save` | Versioned JSON with atomic writes (tmp + rename), migrations, and a corrupt-file fallback |
| `Audio` | SFX pooling and music crossfade, by ID |
| `Router` | Scene changes and mode entry/exit, plus the Android back button |

### 5.3 The asset seam (from AOD)

Every visual and sound has a stable ID. `data/visuals.json` and `data/audio.json` are the
**only** files that map an ID to a path. `Assets.tex(id)` is **total**: it returns the real
art, else the declared placeholder, else a loud magenta "unknown", and never null. As a
result, every phase below can be built and played with placeholder art.

### 5.4 Data: the blueprint is the central format

The player's ships, enemies, VIPs, bosses, shop ships and station hulls are all blueprints.

```json
{
  "format": 1,
  "id": "bp_viper_mk1",
  "name": "Viper Mk I",
  "author": "profile:herman",
  "tags": ["enemy", "role:strafer", "tier:2"],
  "tiles": [
    {"id": 0, "type": "core",      "shape": "hex",    "size": "L", "pos": [0, 0],     "rot": 0, "paint": "#8a2be2"},
    {"id": 1, "type": "hardpoint", "shape": "square", "size": "M", "pos": [0.75, 0],  "rot": 0, "paint": "#3a3a3a"}
  ],
  "mounts": [
    {"tile": 1, "edge": 2, "port": 0, "part": "thruster.jet", "size": "M", "level": 1},
    {"tile": 1, "face": true,         "part": "weapon.gatling_single", "mount": "turret", "mode": "auto"}
  ]
}
```

The cost, stats and validity are always **computed** from the blueprint and never stored.
A stored number would drift out of date.

**A blueprint names part types, not gun items.** A player's built ship is a blueprint plus a
`fitted` map from each weapon mount to the inventory gun in it, which carries its own XP (§4.4).
Enemy guns get their level from the encounter (§4.8).

### 5.5 Performance budget (verified on the reference phone `[D15]` in 0.9 and 15.1)

**Reference phone** (the same one as AOD, measured there): HONOR LNA-NX1, Android 16,
MediaTek MT6858, **Mali-G610 MC2**, OpenGL ES 3.2, arm64-v8a only, 2600 × 1200 at 60 Hz. At
2.17:1, the 1280 × 720 base viewport with `expand` becomes **1560 × 720**.

| Budget | Target |
|---|---|
| Frame rate | 60 fps; 30 fps is the hard floor |
| Live ships | 40 |
| Tiles per ship | 150 (the cap) |
| Live projectiles | 600 |
| Ship rendering | **One `ArrayMesh` per ship** built from its tile polygons (one draw call), not a node per tile. Rebuilt only when a tile is destroyed. |
| Projectiles | Pooled data plus `MultiMeshInstance2D` for drawing. Hits use `intersect_ray` per projectile per tick. **No node per bullet.** |
| Hit → tile | Each tile is its own `CollisionPolygon2D`, and a shape-index → tile-id table resolves which tile was hit |

---

## 6. Art and audio pipeline (carried over from AOD's ART_PROMPT.md)

### 6.1 The Gemini canvas contract, identical for every sheet

- **1024 × 1024**. A 4 × 4 grid of 256 px cells. **The bottom-right cell stays empty**, because
  Gemini puts its watermark there, so each sheet has **15 usable cells**.
- **Flat background with no gradient, no vignette, no text, no grid lines, no borders.** Say
  "no text" twice in each prompt.
- **Background colour:** pure black `#000000` for icons. ⚠️ **Space art contains black**, so ship
  parts, station foregrounds and asteroids use flat **chroma green `#00FF00`** instead.
- **No glows in Gemini art.** A glow on a flat background can't be keyed (an AOD lesson). Every glow,
  flame, beam, shield bubble and explosion is a **shader or particle**, never a sprite.
- **Regenerate the whole sheet, never one cell.** A re-rolled cell comes back with different
  lighting, and the mismatch is worse than one weak icon.
- **One chrome piece per canvas** (panels, frames). On a shared sheet, corners never line up.
- Every prompt section in `ART_PROMPT.md` is self-contained (Gemini keeps no memory between
  prompts) and quotes the palette hex values.

### 6.2 Ship tiles are textures, not sprites

Shapes are arbitrary polygons, so Gemini paints **materials**, not shapes:

- One **greyscale, seamless detail texture per tile type** (hull panels, armour plate, shield
  emitter grid, hardpoint bolts and rails), plus a Core design.
- The ship shader samples the material in ship-local UVs (so any shape can use it), multiplies by
  the **paint colour**, adds a procedural **bevelled outline** from an edge-distance vertex
  attribute, and darkens with damage. The R channel holds detail and the G channel holds an
  "untinted trim" mask, which keeps the shield glow lines from being painted over.
- Result: crisp geometry like the reference ships, and 5 textures cover every shape × size.

### 6.3 Slicing and staging

`tools/slice_sheets.py` is ported from AOD's `slice_ui_sheets.py` and keeps its fixes:
**flood-fill keying from the border** (a threshold key punches holes in dark artwork),
**each blob assigned to a cell by its centroid** (a bbox crop cuts detached parts), and
**review composited onto the real UI frame**, not a checkerboard. Masters are committed in
`art_src/`. Sliced output is derived and gitignored, then staged into `game/assets/` as PNG.
There's never a second JPEG round-trip.

### 6.4 Audio and fonts

Gemini doesn't make audio. SFX come from **CC0 sources** (Kenney, freesound CC0) or are generated
with sfxr in a container. Music is **CC0 / CC-BY**. Fonts are OFL Google Fonts (candidates:
Orbitron for titles, Exo 2 or Rajdhani for body). `tools/licence_audit.py` fails if any file in
`game/assets/` has no row in `LICENCES.md`.

### 6.5 Character portraits `[D3]`

- Portraits appear only in menus and speech dialogs, so they get a **higher-quality painted
  style** than the rest of the game: detailed, semi-realistic, framed as a bust.
- Every speaking character has **4 moods**: idle, happy, sad and angry. All 4 moods of one
  character are generated **in one row of one sheet**, so the face stays the same. A sheet
  therefore holds 3 characters (rows 1–3), because row 4 loses its last cell to the watermark.
- **Player characters:** one male and one female base, which the player recolours. The
  recolourable regions (hair, eyes, outfit, outfit trim) are painted in distinct **key hues** that
  appear nowhere else in the portrait. A shader maps each hue band to the chosen colour while
  keeping the shading. Where a band bleeds into skin or background, a hand-painted mask PNG
  overrides it.
- Portraits use the chroma-green background, because hair and outfits contain black.

---

## 7. Phase plan

Mark items `[x]` as they're done. When a sub-phase closes, replace its checklist with a one-line
DONE note (what exists, where, the non-obvious thing).

### Phase 0: Project setup

Goal: an empty but correctly shaped project that boots on a phone, with tests, tooling and docs
in place before any gameplay code is written.

#### 0.1 Repository `[D1]`
- [ ] `git init` in the project folder `[D1]`
- [ ] `.gitignore`: `.godot/`, `game/assets/**/sliced/`, `*.apk`, `*.aab`, `.android/`, `tools/.venv/`
- [ ] `.gitattributes`: LF line endings, `*.png *.jpg *.ogg *.wav binary`
- [ ] Create the GitHub remote (the owner does this; `gh` isn't installed) and push the first commit
- **Done when:** a clean clone of the remote matches the working tree.

#### 0.2 Folder layout
- [ ] Move `mobile-space-game/` → `game/`, delete its `.godot/` cache (it regenerates)
- [ ] Create the §5.1 tree with `.gitkeep` files, and `.gdignore` in any folder Godot shouldn't import
- [ ] Keep `insperationPictures/` outside `game/` (it's reference, not an asset)
- **Done when:** the editor opens `game/project.godot` with no errors and the tree matches §5.1.

#### 0.3 Project settings
- [ ] `config/name`, renderer → `gl_compatibility` (remove the `d3d12`/Mobile lines)
- [ ] 1280×720, stretch `canvas_items` / `expand`, landscape lock, `handheld/orientation`
- [ ] Physics 60 Hz, 2D gravity 0, default linear/angular damp set for space
- [ ] Input map: `move_*`, `fire`, `switch_weapon`, `boost`, `pause`, with keyboard and gamepad bindings
- [ ] `input_devices/pointing/emulate_touch_from_mouse = true` for desktop testing
- **Done when:** the project boots to an empty scene at the right size and orientation.

#### 0.4 Licences and credits
- [ ] `LICENSE` (MIT, owner's name, 2026)
- [ ] Copy `GeminiCopyRight.md` from AOD, re-read the Google terms, and update the dates
- [ ] `CREDITS.md`, plus `game/assets/LICENCES.md` with a header and an empty table
- **Done when:** all four files exist and each one is linked from the README.

#### 0.5 Autoload skeleton and asset seam
- [ ] Stub the seven autoloads in §5.2, registered in `project.godot`
- [ ] `Data` loader with schema checks; an empty `visuals.json` / `audio.json`
- [ ] `Assets.tex()` with the placeholder → magenta fallback, plus `game/assets/placeholders/`
- [ ] Boot scene → `Router` → a placeholder main menu with one label
- **Done when:** boot reaches the menu, and a call to an unknown visual ID returns magenta instead of crashing.

#### 0.6 Test harness
- [ ] `tests/test_case.gd` (assert helpers) and `run_tests.tscn` (discovers `tests/**/test_*.gd`, exits non-zero on failure)
- [ ] `tools/test.sh`: runs `Godot_v4.7.1-stable_linux.x86_64 --headless --path game res://tests/run_tests.tscn`, plus the `--import` cache refresh
- [ ] `test_model_boundary.gd` (the §5.1 rule)
- **Done when:** `tools/test.sh` prints a passing count and exits 0. A deliberately failing test exits 1.

#### 0.7 Screenshot previews
- [ ] `dev_preview/preview.gd`: load a scene, wait N frames, save a PNG to `dev_preview/out/`
- [ ] It runs windowed on the desktop. If a display-less run is needed later, use an `xvfb` container rather than the host.
- **Done when:** one command produces a screenshot of the placeholder menu.

#### 0.8 Tools container
- [ ] `tools/docker/py.Dockerfile` (Python 3.12, Pillow, numpy) and `tools/run.sh` (mounts the repo, runs as the host uid)
- [ ] Port AOD's `slice_ui_sheets.py` → `tools/slice_sheets.py`, generalised for a per-sheet config (grid, key colour, glow list)
- [ ] `tools/licence_audit.py`
- **Done when:** slicing a test sheet in the container produces keyed PNGs and the audit passes.

#### 0.9 Android pipeline in Docker `[D15]`
- [ ] `tools/docker/android.Dockerfile`: JDK 17, Android SDK + build-tools, Godot 4.7.1 export templates
- [ ] Debug keystore generated in the container and stored in `.android/` (gitignored)
- [ ] `export_presets.cfg` (tracked, no secrets): arm64-v8a, landscape, package id per D14
- [ ] `tools/android.sh export|install|run|logcat`: adb in the container with `--device /dev/bus/usb`
- [ ] `Docs/MOBILE_DEPLOY.md` with the exact commands (pattern from AOD's)
- [ ] Run an empty scene on the reference phone (§5.5) and record its fps there
- **Done when:** the placeholder menu runs on the owner's phone from one command.

#### 0.10 Workflow docs
- [ ] `README.md` (what it is, how to run, how to test, licences)
- [ ] `CLAUDE.md` for the project: commands, the model boundary, the asset seam, "nothing on the host", "data not code"
- **Done when:** a fresh agent session can find how to build, test and deploy from `CLAUDE.md` alone.

---

### Phase 1: Ship model (pure data, headless)

Goal: blueprints load, validate and produce stats. Nothing is drawn except a debug view.

#### 1.1 Shapes
- [ ] `data/shapes.json`: unit polygons for square, rect, triangle, wedge and hex; which edges are attachable
- [ ] `model/shape.gd`: scaled polygon, edge list with port positions and outward normals, rotation in 15° steps
- [ ] Tests: edge lengths, port counts (a Large square has 16 ports), normals point outward after rotation
- **Done when:** the shape tests pass for every shape × size × 24 rotations.

#### 1.2 Tile definitions `[D7]`
- [ ] `data/tiles.json`: the §4.2 table, the size factors, and `size_stat_curve`
- [ ] `model/tile_def.gd`: typed accessors; cost as a resource dictionary
- **Done when:** `Data.tile(&"armor").stats(&"M")` returns the §4.2 values × 0.5.

#### 1.3 Blueprint format
- [ ] `model/blueprint.gd`: load/save the §5.4 JSON, a `format` version, and a migration hook
- [ ] Round-trip test: load → save → load gives identical data
- **Done when:** the round-trip test passes and a malformed file gives a readable error, not a crash.

#### 1.4 Placement rules
- [ ] `model/placement.gd`: `candidate_snaps(blueprint, tile_def, shape, size)` → valid (pos, rot) options at free ports
- [ ] Overlap test, exactly one Core, connectivity BFS over shared edges
- [ ] `validate(blueprint)` → a list of problems (`disconnected`, `overlap`, `no_core`, `over_cap`)
- **Done when:** the tests cover a snap on each shape pair, overlap rejection, and detection of a disconnected island.

#### 1.5 Stats
- [ ] `model/ship_stats.gd`: HP, armor, shield capacity and regen, mass, centre of mass, moment of inertia, cost breakdown
- [ ] Costs as multi-material totals (§4.2: Hull plus Alloy, Crystal or Tech)
- **Done when:** stats for 3 hand-made blueprints match hand-calculated values in the tests.

#### 1.6 Debug view and sample ships
- [ ] `scenes/debug/blueprint_view.tscn`: draws a blueprint with flat colours, port dots and an invalid-tile overlay
- [ ] 3 hand-written blueprints in `data/blueprints/`: `starter`, `brick` (all armor), `hexwing`
- **Done when:** a dev_preview screenshot shows all three ships drawn correctly.

---

### Phase 2: Hangar v1 (the ship builder)

Goal: building a ship on a phone with your thumbs feels good. This is the core of the game, so it
gets the most polish.

#### 2.1 Hangar scene and camera
- [ ] A grid backdrop, the ship centred, and the build-area bounds drawn
- [ ] Pinch zoom and two-finger pan; mouse wheel and middle-drag on desktop
- **Done when:** you can zoom from the whole ship down to a Small tile filling a thumb on the phone.

#### 2.2 Placing tiles
- [ ] A palette drawer: type tabs (Hull/Armor/Shield/Hardpoint), shape row, S/M/L toggle
- [ ] Drag from the palette → a ghost snaps to the nearest valid port within reach, tinted green or red
- [ ] A rotate button cycles the valid orientations at that port; release to place
- [ ] Offset the ghost above the finger so the thumb doesn't hide it
- **Done when:** a 20-tile ship can be built on the phone without a misplacement.

#### 2.3 Editing
- [ ] Tap to select, then delete, move (re-snap) and duplicate
- [ ] Undo/redo (command stack, 100 deep)
- [ ] **Mirror mode**: a symmetry axis through the Core, so every placement and delete is mirrored
- **Done when:** a symmetric ship can be built, and undo restores any state exactly.

#### 2.4 Paint
- [ ] Ship shader v0 (§6.2) using placeholder greyscale textures
- [ ] A colour picker with 12 swatches, HSV, and recent colours. Paint one tile, all tiles of a type, or the whole ship.
- **Done when:** paint persists through save and load and shows on every shape.

#### 2.5 Stats panel
- [ ] Live HP, armor, shield, mass, acceleration and cost, with the change shown on the ghost before placement ("+50 HP, −0.3 accel")
- [ ] Validation problems are listed, and invalid tiles pulse red
- **Done when:** every number matches `ship_stats.gd` and updates in under 1 frame of placement.

#### 2.6 Blueprint library UI
- [ ] Save, Save As, rename, delete, load
- [ ] Thumbnails: render the ship to a `SubViewport` → PNG cache
- **Done when:** 10 ships can be saved, browsed by thumbnail and reloaded on the phone.

---

### Phase 3: Flight → **M1**

Goal: put the ship you built into space and fly it.

#### 3.1 Ship body
- [ ] `ship/ship_body.gd`: a `RigidBody2D` built from a blueprint, one `CollisionPolygon2D` per tile, mass and CoM from stats
- [ ] `ship/ship_mesh.gd`: a single `ArrayMesh` with the ship shader (§5.5)
- [ ] The shape-index → tile-id table
- **Done when:** a 150-tile ship spawns in under 50 ms and renders in one draw call.

#### 3.2 Thruster mounting `[D13]`
- [ ] `data/thrusters.json` (§4.3: 3 types × Small/Medium/Large × L1–3)
- [ ] Hangar: a part drawer with mounts on hardpoint edges, footprint checks, exhaust direction shown
- [ ] Thrust rose and turn-strength overlay, the ship's forward arrow, and the §4.10 flight warnings (they never block saving)
- **Done when:** mounting thrusters changes the rose correctly in the tests and on screen.

#### 3.3 Flight controller
- [ ] `ship/flight_controller.gd`: stick → a throttle per thruster (§4.3), forces applied at the mount points, very low damping
- [ ] Auto-brake when the stick is released: fire whatever opposes the motion and spin, down to 0
- [ ] Pulse impulses, steady jet force, ion ramp while it stays on
- [ ] Sample ships in `data/blueprints/`: `starter` (2 rear + 1 front), `strafer` (thrusters facing 4 ways), and the deliberately bad `no_forward` and `lopsided`
- [ ] Tests: the §4.3 invariants for every size; top speed = push ÷ mass within tolerance; `starter` turns left when the right rear thruster fires and brakes with its front one; `strafer` moves sideways; a released stick brings a ship to 0 when it can; one centred rear thruster can't turn; `no_forward` drifts
- **Done when:** the invariant tests pass, the three thruster types feel distinct in the sandbox, and the bad ships fly exactly as badly as they should.

#### 3.4 Touch controls
- [ ] A floating virtual stick (appears where the thumb lands on the left half), with a dead zone
- [ ] The 2-stick layout (FIRE and SWITCH placeholders) and the 1-stick layout; switched in Settings
- [ ] The handedness mirror
- **Done when:** both schemes fly on the phone, and multi-touch (stick + fire at once) works.

#### 3.5 Camera and space
- [ ] Follow camera with velocity look-ahead and zoom that scales with ship size
- [ ] A procedural starfield shader with 3 parallax layers, and arena bounds with a soft edge warning
- **Done when:** flying fast feels fast, and the edge is clearly signalled.

#### 3.6 Thruster VFX
- [ ] Pulse: an orange puff burst per pulse. Jet: a red fire trail scaled by throttle. Ion: a short blue circular torch that brightens with the ramp.
- [ ] L2 and L3 look visibly bigger. Use `CPUParticles2D` first, then measure `GPUParticles2D` on Compatibility.
- **Done when:** the sandbox scene shows all 3 types × 3 sizes at L1 and L3, side by side (a dev_preview shot).

**M1 — fly a ship you built.** Demo on the phone: build in the hangar → Test → fly → back.

---

### Phase 4: Weapons and damage

#### 4.1 Damage model
- [ ] `model/damage.gd`: the §4.5 pipeline and type matrix; `data/damage_types.json`
- [ ] Tests: shield first, armor reduction, the 20% floor, splash across tiles, EMP disable
- **Done when:** every row of the §4.5 table has a passing test.

#### 4.2 Destruction
- [ ] Remove a destroyed tile → rebuild the mesh and collision, connectivity BFS → debris bodies that fade
- [ ] Recompute mass and envelope (losing a thruster slows you)
- [ ] Core death: explosion sequence and ship removal. Damage tint and cracks in the shader.
- **Done when:** shooting a ship in half in the sandbox leaves a drifting, fading wreck and a crippled survivor.

#### 4.3 Weapon framework
- [ ] `data/weapons.json` (§4.4), with mount types fixed, swivel and turret
- [ ] Hangar mounting: edge weapons on hardpoint edges, turrets on faces, a manual/auto toggle (turrets locked to auto)
- [ ] Auto fire control: target the nearest in arc, lead prediction, line-of-fire check against own tiles
- **Done when:** a ship with one weapon of each mount type fires correctly at a dummy target.

#### 4.4 Projectile pool
- [ ] `combat/projectile_pool.gd`: struct-of-arrays, `MultiMeshInstance2D` draw, `intersect_ray` hits per tick
- [ ] Stress scene: 600 projectiles, measured on the reference phone
- **Done when:** 600 projectiles hold 60 fps on the phone (or the budget gets revised in §5.5 with the measured number).

#### 4.5 Weapons batch A: kinetic
- [ ] Single gatling, multi gatling (spin-up), cannon (armour-piercing, on every mount, so the turret version is the "cannon turret")
- [ ] Muzzle flash, tracer and impact sparks (procedural)
- **Done when:** all three are usable from the hangar on each of their mounts.

#### 4.6 Weapons batch B: specials
- [ ] Flak (spread and airburst; can shoot down rockets), rockets (homing and splash)
- [ ] Laser (hitscan beam with a `Line2D` shader, heat bar), EMP (area pulse, disables), mines (rear drop, proximity)
- **Done when:** all five work, and each one has a sandbox target that shows what it's for.

#### 4.7 Combat HUD and weapon switch
- [ ] Shield/hull bars, hit flash, optional screen shake, vibration on taking damage
- [ ] SWITCH: pause → a list of manual weapons with icons → pick the active one → resume
- **Done when:** in 2-stick mode the fire button fires only the active manual weapon, and auto weapons keep firing on their own.

#### 4.8 Gun XP and levels `[D8]`
- [ ] `model/weapon_xp.gd`: the L1–L999 XP curve and the per-level stat scaling, from `data/weapon_xp.json`
- [ ] Guns as items (type, mount, XP); a kill's XP split between guns by the damage each dealt (§4.4)
- [ ] Hangar refit between a gun's allowed mounts for Alloy + Tech, keeping its XP
- [ ] Tests: the curve rises monotonically and reaches L999; the split adds up to the kill's XP; uninstalling and refitting keep XP
- **Done when:** the tests pass and the hangar shows each gun's level and XP bar.

---

### Phase 5: Enemies and encounters

#### 5.1 Enemy roster
- [ ] Build 12 enemy blueprints in the hangar: 4 tiers × roles (chaser, strafer, sniper, kamikaze, minelayer, brute)
- [ ] `data/enemies.json`: blueprint id, tier, role, AI behaviour, min/max level
- **Done when:** all 12 load, validate and appear in a debug gallery.

#### 5.2 AI pilot
- [ ] `ai/ai_pilot.gd`: drives the same `flight_controller` the player uses (no AI-only physics)
- [ ] Behaviours: chase, orbit and strafe, keep range, ram, lay mines, flee at low HP. Avoids friends and debris.
- **Done when:** each behaviour is recognisable in a 1v1 sandbox, and the AI never gets stuck on arena edges.

#### 5.3 Level scaling 1–100
- [ ] `data/levels.json`: a budget curve, tier mix per level band, weapon-level bands, enemy count
- [ ] `model/encounter.gd`: `generate(level, seed)` → a spawn list. Deterministic.
- [ ] Enemy guns at about 10 × the encounter level, with a spread (§4.8)
- **Done when:** a test shows the budget rising monotonically, the same seed giving the same encounter, and levels 1, 25, 50 and 100 all generating.

#### 5.4 Drops and pickups
- [ ] Material drops derived from composition (§4.6), the part-drop chance (a dropped gun keeps its XP), pickups with a magnet radius
- [ ] Run cargo (in memory), plus a HUD counter
- **Done when:** killing an all-shield enemy drops mostly Crystal (a test), and pickups fly to the ship.

#### 5.5 Spawner
- [ ] Spawn off-screen around the player, with off-screen enemy arrows at the screen edge
- [ ] An API shared by Creative test, WaveTime and Story tiles
- **Done when:** a level-30 encounter spawns, fights and can be cleared in the sandbox.

---

### Phase 6: The front door (profiles and menus)

#### 6.1 Main menu
- [ ] Buttons for Creative, WaveTime, Story (locked until Phase 9 lands), Settings, Credits and Profile, in placeholder chrome
- **Done when:** every button routes somewhere or is visibly disabled.

#### 6.2 Profiles and the character screen `[D2]`
- [ ] Create, select and delete a profile (with confirmation). Name entry uses `LineEdit`, which brings up the virtual keyboard on Android.
- [ ] Character picker `[D3]`: male or female base, recolour swatches for hair, eyes, outfit and trim (§6.5), and a preview that cycles the 4 moods
- [ ] Per-profile folder `user://profiles/<id>/`
- **Done when:** 3 profiles exist on one phone, each with separate inventories, and switching between them works.

#### 6.3 Save service
- [ ] Atomic write (tmp → rename), `format` version, migrations, keep the last good copy if the newest is corrupt
- [ ] Tests: interrupted write, corrupt file, migration from v0
- **Done when:** the tests pass, and killing the app mid-save never loses the previous save.

#### 6.4 Settings
- [ ] Control scheme, handedness, stick size and opacity, music/SFX volume, vibration, screen shake
- **Done when:** every setting persists and applies immediately.

#### 6.5 Pause and app lifecycle
- [ ] Pause menu: **Save and return to hangar** in Story (only after 10 s without combat) and **Return to hangar** in the other modes (§4.10, `[D18]`)
- [ ] The Android back button, handled per scene by `Router`
- [ ] Auto-pause when the app goes to the background. Save on quit from any hangar.
- **Done when:** switching away from the app and back mid-fight resumes paused, and the back button never quits by accident.

---

### Phase 7: Creative mode → **M2**

#### 7.1 Creative hangar
- [ ] Hangar mode `CREATIVE`: unlimited materials, every part, and guns at any level 1–999
- **Done when:** any part can be placed with no cost checks.

#### 7.2 Test flight
- [ ] A level slider 1–100 → a random empty arena + `encounter.generate(level)` → back to the hangar on death or exit
- [ ] A results card: survived, time, kills, damage taken
- **Done when:** level 1 is easy with the starter ship and level 100 is brutal.

#### 7.3 Publish to the library `[D6]`
- [ ] "Publish" makes a validated blueprint buyable in WaveTime and Story at its computed cost
- [ ] A device-wide library at `user://library/`, with the author shown
- **Done when:** a ship published by profile A appears in profile B's shop.

#### 7.4 Save ships to files and share them
- [ ] **Save ship to file**: a `.mspship` file (the blueprint JSON) to send to friends, and **Load ship from file** on their end
- [ ] On Android, save and open through the system file picker (Godot's native file dialog; confirm it works on 4.7.1 here). If it doesn't, write to the Documents folder, where any app can send the file. The Android share sheet needs a plugin, so it isn't in v1.
- [ ] A share code (compressed base64 text) as a fallback for pasting into a chat
- [ ] Dev path: save a ship from Creative into `data/enemies/` (this is how enemies get authored)
- **Done when:** a ship saved on one phone, sent to a second phone and loaded there rebuilds identically.

#### 7.5 Performance test `[D15]`
- [ ] A Creative button that runs a scripted worst case (40 ships, 600 projectiles, a large station) and reports fps and frame time
- [ ] Results are kept, so runs on the reference phone can be compared phase by phase
- **Done when:** it runs on the reference phone and the numbers are recorded in §5.5.

**M2 — Creative mode is playable end to end.**

---

### Phase 8: WaveTime → **M3**

#### 8.1 The run loop `[D4]`
- [ ] Choose an owned ship → arena → waves on a timer (the next wave comes at 60 s or when the current one is cleared, whichever is first)
- [ ] `wave → level` mapping in `data/levels.json`
- **Done when:** a run starts, escalates and ends in death.

#### 8.2 HUD
- [ ] A big timer, the score, the wave number, a live loot tally
- [ ] Score = kill value × wave multiplier, plus a survival bonus
- **Done when:** the HUD reads at arm's length on the phone (dev_preview at phone resolution).

#### 8.3 Arcade feedback and power-ups `[D4]`
- [ ] Floating damage numbers on every hit (bigger and brighter for big hits), and a score pop on each kill
- [ ] Power-up pickups dropped by enemies: ridiculous **×2–×5 bullet multipliers** (every gun fires that many shots) for a set time, with a countdown on the HUD
- [ ] Power-ups exist only inside a run: they never bank, never reach the hangar, and don't appear in Creative or Story
- [ ] Drop chance, multipliers and durations in `data/powerups.json`
- **Done when:** a ×5 power-up turns the screen into a bullet storm for its duration and then ends cleanly, and the projectile pool stays within budget (or caps without a visible glitch).

#### 8.4 End of run
- [ ] A results screen with score, kills, loot and best wave. **Loot banks into the profile inventory** (death doesn't lose it in WaveTime).
- [ ] **Scoreboard** `[D2]` `[D20]`: kills, deaths, kills ÷ deaths and best score for every character on the device, best at the top
- **Done when:** resources appear in the hangar after a run.

#### 8.5 Inventory and owned hangar
- [ ] Hangar mode `OWNED`: placing spends materials, removing refunds 100%, parts come from inventory
- [ ] Can't-afford states are greyed out with the shortfall shown
- **Done when:** a ship can be upgraded only with what the profile owns.

#### 8.6 Shops `[D5]`
- [ ] A ship shop: library blueprints priced at their computed cost
- [ ] A market: buy and sell materials for GC, and buy L1 guns and thrusters (§4.6)
- **Done when:** a blueprint can be bought, then flown in the next run.

#### 8.7 New-player curve
- [ ] Starter ship (§4.10): Core, hull tiles and 3 hardpoints carrying 3 pulse thrusters (2 rear, 1 front) and 1 single gatling
- [ ] Tune so run 1 lasts ~1–2 min and every run banks enough to visibly upgrade
- **Done when:** a fresh profile's first 10 runs each show progress (playtest notes in the PR).

#### 8.8 Alpha release
- [ ] Release APK in Docker, signed with the owner's keystore (kept outside the repo)
- [ ] An itch.io page, GitHub release, `CHANGELOG.md`
- **Done when:** a stranger can install from itch and play WaveTime and Creative.

**M3 — public alpha.**

---

### Phase 9: Story, the world map

#### 9.1 Hex math
- [ ] `model/hexmath.gd`: axial coordinates, neighbours, rings, distance, hex ↔ pixel
- **Done when:** the tests cover every function, including ring counts (ring *n* has 6*n* hexes).

#### 9.2 World generator
- [ ] `data/worldgen.json`: radius (start at 20), `ring → level`, a kind mix per ring band, void density
- [ ] `model/worldgen.gd`: seeded. Start station at the centre, stations spaced so one is always within 4 hexes, voids for an organic shape (like the Map reference), 16 story slots on increasing rings, the bandit HQ on the outer story ring.
- **Done when:** the tests show determinism, every tile reachable, station spacing held, and the story slots in order outward.

#### 9.3 World map UI `[D11]`
- [ ] A pan/zoom hex view with icons (asteroids, beacon, station, job, story, skull)
- [ ] State backgrounds: unvisited (none), visited (grey), completed (green with a tick), failed (red). A "you are here" marker.
- [ ] Visibility `[D11]` `[D19]`: story tiles, plus every tile within 5 hexes of your ship
- [ ] A tile info popup: kind, level, and the gun levels found there
- **Done when:** a generated world renders with every state and icon (a dev_preview shot).

#### 9.4 Travel
- [ ] Each hex is a local arena generated from the tile seed
- [ ] Fly to the arena edge → the world map opens → pick **any** adjacent hex → jump transition → load
- [ ] The world map's **Save and return to hangar** button, available after 10 s without combat (§4.9, `[D18]`)
- **Done when:** you can fly across 5 tiles, and returning to a tile regenerates it identically.

#### 9.5 Save rules (§4.9)
- [ ] `model/story_state.gd`: the committed state vs the live session; commit on hangar; death reloads
- [ ] One test per §4.9 rule
- **Done when:** all 7 rule tests pass.

#### 9.6 Cargo and combat repair
- [ ] Carried materials, 10 s without a hit → heal over time paid from cargo; ghost outlines for destroyed tiles
- **Done when:** repair stops instantly when hit, and stops when the cargo runs out.

---

### Phase 10: Story, tile content

#### 10.1 Blank tiles
- [ ] Ambient-only space (drifting debris, a nebula layer)
- **Done when:** a blank tile is a calm fly-through.

#### 10.2 Asteroid belts
- [ ] A procedural field. Asteroids split when shot (L → M → S), with material by asteroid kind.
- **Done when:** mining a belt fills cargo, and the belt counts as completed when cleared.

#### 10.3 Distress beacons
- [ ] Level = ring level ±5. Variants: ambush (clear waves), derelict (salvage loot), rescue (escort a damaged ship out).
- **Done when:** each variant can complete and fail, and the state shows on the map after the next hangar commit.

#### 10.4 Completion rules
- [ ] A completion/failure definition per tile kind in `data/worldgen.json`
- **Done when:** every kind has a test for its complete and fail paths.

---

### Phase 11: Stations

#### 11.1 Station generator `[D9]`
- [ ] Seed → a subset of services (hangar/shop/bar; not all stations have all three), layer picks, colour scheme
- [ ] `model/station_gen.gd`: the station in space, built from blocks (hub, arms, rings) as a blueprint in its colour scheme (§4.11)
- [ ] The safe ring: kept clear by world-gen. Reaching it stops the ship and opens the station menu. Leaving turns the ship 180°, with zero motion, 3 U outside the ring.
- **Done when:** 20 seeds give visibly different stations with varied services, and leaving the menu never reopens it straight away.

#### 11.2 Station screen
- [ ] Scrolling parallax: backdrop, mid layer, station foreground, hue-shift shader for the colour scheme
- [ ] Room buttons shown only for services this station has
- **Done when:** it scrolls smoothly on the phone with placeholder layers.

#### 11.3 Hangar room
- [ ] Docking = **save commit** (§4.9). Bank cargo, restore destroyed tiles (cost), repair, build, swap owned ship.
- **Done when:** dock → die → reload returns you to this dock with this state.

#### 11.4 Shop room
- [ ] Stock from the station seed and ring level: guns near the ring's level, thrusters, library ships, and the materials market, all in GC. Warns before you sell your last thruster or gun `[D17]`.
- **Done when:** prices scale with ring, and the stock is stable for a given station.

#### 11.5 Bar room
- [ ] A bartender portrait and dialogue box (with expressions), the job board entry point, rumour lines
- **Done when:** dialogue plays with expression changes and can be skipped.

#### 11.6 New story start
- [ ] Start at the centre station → intro dialogue → buy the first weak ship (1 gun) → launch
- **Done when:** a new profile can start Story and reach the first tile.

---

### Phase 12: Jobs

#### 12.1 Job generator `[D12]`
- [ ] At a bar: pick a job → convert an empty tile within **radius 6** of the station into the job tile. If there's no free tile: "No work here, try another station."
- [ ] Rewards by level. Backstory from a template grammar in `data/jobs.json` (client, target, place, twist).
- **Done when:** 50 generated jobs read as varied, and jobs never land on non-empty tiles.

#### 12.2 Kill HVT
- [ ] A boss-tier blueprint with escorts; complete on kill
- **Done when:** completing it pays out and turns the tile green on commit.

#### 12.3 Protect VIP
- [ ] A VIP ship (AI) flies a route; waves target it; fail if it dies
- **Done when:** both the success and fail paths work.

#### 12.4 Mine XYZ
- [ ] Collect N of a material from a generated belt on that tile
- **Done when:** the progress HUD shows N/M, and it completes at M.

#### 12.5 Hold the zone
- [ ] Stay inside the zone for X s while waves come. Leaving for 5 s fails it.
- **Done when:** the timer pauses outside the zone and the fail grace works.

#### 12.6 Job log
- [ ] Max 3 active jobs, map markers, abandon (that tile fails), reward banking per D12
- **Done when:** the job state survives commit and reload correctly.

---

### Phase 13: The Story campaign → **M4**

#### 13.1 Story bible
- [ ] `Docs/STORY.md`: premise (your wife was captured by space bandits), cast (protagonist = your chosen portrait, wife, bandit leader, 2–3 allies), 16 beats from the centre outward, the ending, post-game hooks
- **Done when:** the owner signs off on STORY.md.

#### 13.2 Story beat framework
- [ ] `data/story.json`: per beat, the tile slot, the encounter, pre and post dialogue, and the reveal of the next beat
- [ ] A story log screen
- **Done when:** a placeholder 16-beat campaign plays start to finish with stub encounters.

#### 13.3–13.5 Beats 1–5, 6–10, 11–15
- [ ] Authored encounters (custom blueprints and set pieces), dialogue and portraits; difficulty matched to ring level
- **Done when (each):** the beats play through on the phone and their tiles show the story icon and state correctly.

#### 13.6 Beat 16: the bandit HQ
- [ ] The station as a giant blueprint with turrets and shield generators: phased fight, then the rescue, the ending, and the `campaign_complete` flag
- **Done when:** the game can be completed, and free roam continues afterward.

#### 13.7 Difficulty pass
- [ ] The gun levels found on each ring vs the gun levels needed to beat it; adjust `worldgen.json` and `weapon_xp.json`
- **Done when:** a playtest from start to finish has no wall where grinding stops being fun.

**M4 — v1.0.**

---

### Phase 14: Audio and feel

#### 14.1 SFX
- [ ] Weapons, thruster loops (pitch follows throttle), explosions, pickups, UI, by ID through the seam
- **Done when:** every action has a sound and the licence audit passes.

#### 14.2 Music
- [ ] Menu, hangar, combat, station and boss tracks with crossfade
- **Done when:** music changes with context and no track hard-cuts.

#### 14.3 Juice
- [ ] Hit-stop on big kills, camera kick, haptics, a loot vacuum effect, a wave-start banner
- **Done when:** the owner says it "feels good" on the phone.

---

### Phase 15: Release

#### 15.1 Performance pass
- [ ] Profile worst cases (40 ships, 600 bullets, a big station) on the reference phone; fix to budget
- **Done when:** §5.5 holds on the device and the measurements are recorded.

#### 15.2 Onboarding
- [ ] A first-run controls overlay, hangar hints, a WaveTime tips card, and a short Story tutorial in beat 1
- **Done when:** a new player builds and flies with no outside help.

#### 15.3 Store and distribution `[D14]`
- [ ] Final title, icon, screenshots, trailer GIF; itch.io, GitHub; optionally F-Droid and Play
- **Done when:** v1.0 is published.

#### 15.4 Release builds
- [ ] Versioning (`config/version` + `versionCode`), a release AAB/APK built in Docker, desktop builds (Linux/Windows)
- **Done when:** one script builds every target.

#### 15.5 Bug bash
- [ ] `BUGS.md` triage, then fix the blockers
- **Done when:** no blocker or major bugs remain open.

---

## 8. Art track (parallel; never blocks code)

Prompts are written into `Docs/ART_PROMPT.md` (one `##` section per sheet, following the §6.1
contract). The owner generates in Gemini, and then we review, slice and stage.

| # | Item | Sheets / canvases | Needed by |
|---|---|---|---|
| A.0 | **Art direction** `[D3]`: palette (hex values quoted in every prompt), style sentence, ART_PROMPT.md header with the contract | – | before A.1 |
| A.1 | Tile materials: Hull, Armor, Shield, Hardpoint (greyscale and seamless) + Core design | 1 sheet (5 cells + 2 variants each) | 2.4 |
| A.2 | Thrusters: pulse, jet and ion nozzles × Small/Medium/Large, top-down, on chroma green. L1–3 shown by a trim colour in the shader. | 1 sheet (9 cells) | 3.6 |
| A.3 | Weapons: turret **base and barrel as separate cells** (so barrels can rotate), 8 types; level tiers shown by a trim colour | 2–3 sheets | 4.5 |
| A.4 | Icons: 5 resources (Tech drawn as wires, plus GC), 5 tile types, 8 weapon icons, 3 thruster icons, HUD buttons (fire, switch, pause, boost), WaveTime power-ups | 2 sheets | 4.7, 8.3 |
| A.5 | UI chrome after the Menu Theme reference: panel, button (normal/pressed/disabled × orange/green/red), header bar, frame, progress bars | one canvas per chrome piece + 1 widget sheet | 6.1 |
| A.6 | Map icons: asteroid, beacon, station, shop, bar, hangar, 4 job types, story, skull, tick, you-are-here | 1 sheet | 9.3 |
| A.7 | Portraits `[D3]` (§6.5), high-quality painted, **4 moods each, one row per character**: the male and female player bases (painted in recolour key hues), then NPCs (bartender ×3, job givers, wife, bandit boss, allies) | ~4 sheets | 6.2, 11.5 |
| A.8 | Stations `[D9]`: 5 backdrops (wide, horizontally seamless), 5 exteriors (chroma green), interiors for hangar, shop and bar × 5 | 1 canvas each (~25) | 11.2 |
| A.9 | Arena space backgrounds: nebula layers, tileable | 5 canvases | 3.5 (procedural first) |
| A.10 | Asteroids: 3 kinds × 3 sizes + fragments, on chroma green | 1 sheet | 10.2 |
| A.11 | Splash, app icon, title art (the logo text is set in a font, because text is Gemini's worst failure) | 3 canvases | 8.8 |
| A.12 | SFX and music (CC0/CC-BY, not Gemini) | – | 14 |
| A.13 | Fonts (OFL) | – | 6.1 |

Enemies, bosses, VIPs and the bandit HQ need **no sprites**: they're blueprints built from A.1 tiles
and A.2/A.3 parts.

---

## 9. v2 backlog (noted so v1 doesn't design itself into a corner)

- **Factions and reputation**: station ownership, prices that rise or fall with rep, factions turning
  hostile. Hooks for v1: every station and enemy blueprint carries a `faction` field (defaulting to
  `neutral`), and shop prices go through one `price(item, station)` function.
- More player bases, and a layered customiser (hairstyles, outfits) on top of v1's recolouring
- True twin-stick aiming
- More thrusters and weapons, plus weapon mods
- Online blueprint sharing, and the Android share sheet (ship files and share codes in 7.4 are the bridge)
- Achievements, localisation, procedural ship names

---

## 10. Risks

| Risk | Mitigation |
|---|---|
| Building on a phone is fiddly (small tiles, thumbs) | Phase 2 is polished first and tested on the device every sub-phase. The ghost is offset above the finger. Mirror mode. |
| Physics cost of 150-shape bodies × 40 ships | Measured in 3.1 and 4.4 on the device. Fallback: merge interior tiles' shapes into one convex hull per cluster for distant ships. |
| Balancing levels 1–100 across three modes | One encounter generator, enemy gun levels tied to encounter level, all numbers in data; a tuning pass is a sub-phase in 8.7 and 13.7. |
| Gemini consistency across sheets | Palette and style sentence quoted in every prompt; regenerate whole sheets; group items that share a screen into one sheet. |
| Story scope is half the game | It ships last, after a public alpha. Each beat is its own sub-phase and can be cut or merged. |
| Players build ships that can't fly | Allowed by design. Hangar warnings, three ways back, and a starter ship that can always be rebuilt (§4.10). |
| Docker USB passthrough for adb | Proven in 0.9 before any gameplay. Fallback: sideload the APK by hand from the export folder. |

---

## 11. Immediate next actions

1. Owner: review the still-open defaults in §3.2 and change any that are wrong.
2. Phase **0.1 → 0.10** in order. 0.9 (the Android pipeline) is the riskiest, so it isn't left
   for later.
3. In parallel: **A.0** (art direction and palette) so A.1's tile materials are ready by 2.4.
