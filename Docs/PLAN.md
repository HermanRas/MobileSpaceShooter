# MSS — Mobile Space Shooter: Game & Implementation Plan

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
| Engine | **Godot 4.7.1-stable**: `~/Downloads/Godot_v4.7.1/Godot_v4.7.1-stable_linux.x86_64` (the win64 builds sit beside it) | Pinned. Upgrades happen deliberately at a phase boundary, with the suite green before and after. |
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
| **D14** | Title, package id, stores | Working title "MSS", package id `com.example.mss`, itch.io + GitHub Releases first | 15.3 |
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
**Armor doesn't scale with size**: it's a per-hit reduction (thickness), not an amount. Base
costs are multiples of 4, so a Small tile still costs whole units; the loader enforces this.

| Type | HP | Armor | Shield | Mass | Cost `[D5]` | Special |
|---|---|---|---|---|---|---|
| **Core** `[D7]` | 300 | 5 | – | 2.0 | free, one per ship | Death when destroyed. Its facing is the ship's **forward** (the arrow in the hangar). It has no turning force of its own. |
| **Hull** | 100 | 0 | – | 1.0 | 120 Hull | Cheapest HP |
| **Armor** | 150 | 6 | – | 2.5 | 80 Hull + 120 Alloy | Flat damage reduction per hit on this tile |
| **Shield** | 40 | 0 | +60 cap, +4/s regen | 0.8 | 80 Hull + 120 Crystal | Adds to the **ship-wide shield pool** |
| **Hardpoint** | 120 | 4 | – | 1.5 | 80 Hull + 80 Alloy + 40 Tech | Armor with mounts: thrusters/edge weapons on its edges, a turret on its face |

Costs are ×10 the first pass (owner, 2026-10-26: "about 10× too cheap, you need to work for
your upgrades"), and so are gun and thruster prices. At market prices (§4.6) a Large hull tile
is worth 240 GC, an armor tile 760, a hardpoint 1040, and the starter ship about 6,000 GC.

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
- Damping is low, so momentum carries. Top speed in a direction is the push that way ÷ (mass ×
  `linear_damp`), with `linear_damp` 0.5 in `data/flight.json`. The starter tops out around 12 U/s.
- The hangar shows a **thrust rose** (the maximum push in 8 local directions), the **turn
  strength** each way, and the acceleration, so problems show up before flying.

### 4.4 Weapons and mounts

| Mount | Sits on | Arc | Fire mode |
|---|---|---|---|
| **Fixed** | Hardpoint edge | Edge normal, 0° | Manual or auto (chosen at install) |
| **Swivel 45°** | Hardpoint edge | ±22.5° | Manual or auto |
| **Turret 360°** | Hardpoint face | Full circle | **Always auto** |

**Refit:** at a hangar, a gun can be refitted between the mounts its type allows, for a small
Alloy + Tech cost. It keeps its XP `[D8]`. A gun taken off the ship remembers its mount type;
reinstalling it from the Inventory tab on another type is the refit (4.8a).

| Weapon | Damage type | Mounts | Role |
|---|---|---|---|
| Single gatling | Kinetic | F / S / T | Starter. High rate, low damage. |
| Multi gatling | Kinetic | F / S / T | Spin-up, then shreds |
| Flak (shotgun) | Kinetic + Explosive airburst | F / S / T | Close range, swarms, shoots down rockets |
| Cannon | Kinetic, armour-piercing | F / S / T | Slow heavy shell. IDEA.md's "mounted cannon" and "cannon turret" are the same gun on different mounts, so refitting moves it between them. |
| EMP | EMP | F / T | Area pulse. Low damage, but knocks out shields and thrusters for 2 s. |
| Rockets | Explosive | F / S / T | Four launchers (owner, 2026-10-26): **Seeker** (homing) or **Rocket** (fire and forget, faster), each with an **HE** warhead (big splash) or **AP** (concentrated, armour-piercing hit, small splash). Flak can shoot them down. |
| Laser | Energy | F / S / T | Hitscan beam with heat build-up. Shield breaker. |
| Mines | Explosive | Rear edge (F) | Dropped behind, proximity trigger |

**Gun levels, L1–L999** `[D8]`:

- Every gun is an **item** with its own XP. Its level comes from an XP curve in
  `data/weapon_xp.json`.
- **XP comes from kills.** A kill's XP (scaled by the enemy's encounter level) is split between
  your guns by the damage each one dealt to that enemy.
- Level scales the gun's main stats. The starting curve is +1% per level, so L999 is about ×11,
  and the curve is tuned in data.
- **Level brings accuracy** (owner, 2026-10-26): a gun's scatter narrows from `spread_deg[0]` at
  L1 to `spread_deg[1]` at the top level on a log curve, so the early levels count most. The
  gatling goes from ±5° to ±0.5° (±2° at L100).
- A gun keeps its XP when an enemy drops it, when it's uninstalled in the hangar, and when it's
  refitted between mounts.
- Enemy guns are around **10 × the encounter level** (§4.8), so the guns you find get better
  the further out you go, and so do the guns you need.
- Creative can set any gun to any level, and earns no XP.

Auto weapons pick the nearest target in their arc and lead it. Rules set in 4.3:

- **Side-mounted guns (fixed, swivel) can't fire through their own ship; top-mounted ones
  (turrets) fire over it** (owner, 2026-10-26). `over_hull` per mount type in `weapons.json`.
  The hangar shows a gun's clear arc (green) and blocked directions (red).
- A **manual swivel** still tracks a target in its arc, but fires only on FIRE. A manual fixed
  gun fires straight ahead while FIRE is held.
- An **auto fixed gun** fires when a target's lead point is within `fire_within_deg` (3°) of
  straight ahead, so the pilot aims it with the ship.
- **Shots carry the ship's velocity**, and the lead allows for it.

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
  (the spread is in data). Starting prices, GC a unit, buy / sell: Hull 2 / 1, Alloy 5 / 3,
  Crystal 6 / 4, Tech 12 / 8. There's a market in every Story station shop and in the WaveTime hangar.
- **Drops are derived from the enemy's own blueprint composition** × a level factor, so nobody
  writes a drop table by hand and "hunt the shield ships to get crystal" works without extra rules.
- **Part drop:** a small chance (start at 4%) to drop one of the enemy's mounted guns or
  thrusters. A dropped gun keeps its XP.
- **Removing a tile in the hangar refunds 100%** of its cost. Experimenting must be free.
- **Inventory** (per profile) holds materials, GC, guns (each one an item with its type, mount
  and XP), thrusters (type × size × level counts) and owned ships.
- **Building in the hangar (owner, 2026-10-26).** Outside Creative, every palette tab is a
  shop: placing a tile pays its materials, and placing a gun or thruster pays its GC price.
  Removing a tile (Hull, Armor, Shield, Hardpoint) gives its materials back 1:1. Removing or
  picking up a gun or thruster puts it in the **Inventory** tab (after Weapons), and placing it
  from there just reinstalls it, free. The Delete button becomes **Remove**, and **Sell** sells
  a gun or thruster (on the ship or in the Inventory tab) for **75% of its price, rounded
  down**. Creative has no inventory, no costs, and keeps Delete.
  - *v2, factions:* the sell rate rises above the flat 75% with your reputation with the
    station's faction.

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
MSS/
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

**A blueprint names part types, not gun items.** On a player's ship, a weapon mount also
carries `"gun": "<item id>"`, the inventory gun in it, which holds its own XP (§4.4). Publishing
or sharing a ship (7.3, 7.4) strips those ids. Enemy guns get their level from the encounter
(§4.8).

### 5.5 Performance budget (verified on the reference phone `[D15]` in 0.9 and 15.1)

**Reference phone** (the same one as AOD, measured there): HONOR LNA-NX1, Android 16,
MediaTek MT6858, **Mali-G610 MC2**, OpenGL ES 3.2, arm64-v8a only, 2600 × 1200 at 60 Hz. At
2.17:1, the 1280 × 720 base viewport with `expand` becomes **1560 × 720**.

| Budget | Target |
|---|---|
| Frame rate | 60 fps; 30 fps is the hard floor |
| Live ships | 40 |
| Tiles per ship | 150 (the cap) |
| Live projectiles | 600 (measured 2026-10-26: 60 fps on the phone, pool ~5 ms a frame; 900 also holds) |
| Ship rendering | **One `ArrayMesh` per ship** built from its tile polygons (one draw call), not a node per tile. Rebuilt only when a tile is destroyed. |
| Projectiles | Pooled data plus `MultiMeshInstance2D` for drawing. Hits use `intersect_ray` per projectile per tick. **No node per bullet.** |
| Hit → tile | Each tile is its own `CollisionPolygon2D`, and a shape-index → tile-id table resolves which tile was hit |
| Hangar edit refresh | **≤ ~18 ms on a 150-tile ship** (one dropped frame at the cap). The owner accepted this on the phone, 2026-10-25 |

**Measured on the phone (2026-10-25, debug build):** the menu and the hangar both hold a steady
60 fps (the display can do 120 Hz; the game runs at 60). The hangar draws in 66 calls, and the
app uses about 40 MB. A scene change costs one ~150 ms frame. A 150-tile edit refresh takes
15–18 ms (analyze ~9, mesh ~3.5, stats ~3). The phone is **~3.5× slower than the dev PC** at
GDScript, so a PC timing × 3.5 is a fair guess before deploying. Read these numbers with
`tools/android.sh perf` (the debug-only `Perf` autoload).

**Android's bottom gesture strip** (130 px on this phone, ~78 canvas px) sends the game home
on any drag that starts there, even in immersive mode. Only taps belong in that strip; no drag
may start there.

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
- **Framing (owner, 2026-10-27):** elbow height, turned three-quarters to the right, after
  visual-novel dialog screens. In a story-mode conversation the whole picture stands on the
  bottom edge of the screen with the dialog box over its lower body: the player on the left, the
  other speaker mirrored on the right. Menus and the HUD show a fixed head crop, so every mood
  keeps the head in the same place.
- **Player characters:** one male (heavily muscled) and one female (curvy) base, each in two
  outfits, a **flight jacket** and a **space suit** (helmet off), which the player recolours. Menus
  and the profile screens show the **jacket**; story mode shows the **suit** during missions (owner,
  2026-10-27), so the outfit isn't the player's choice. One
  sheet per base per outfit, its 4 moods in a 2×2 grid; the suit sheets are image edits of the
  jacket picks, so face, pose and crop match. The
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
✅ 2026-10-25. git in the project folder, branch `main`. `insperationPictures/` is **gitignored**,
because some of the images are third-party screenshots and the repo will be public.
- [x] Owner: create the GitHub remote (`gh` isn't installed), then `git remote add origin … && git push -u origin main` (done: `HermanRas/MobileSpaceShooter`, v0.0.5 pushed 2026-10-26)

#### 0.2 Folder layout
✅ 2026-10-25. `mobile-space-game/` → `game/`, with the §5.1 tree. Empty folders hold `.gitkeep`;
`game/dev_preview/out/` has a `.gdignore`.

#### 0.3 Project settings
✅ 2026-10-25. `game/project.godot`: Compatibility renderer, 1280×720 `canvas_items`/`expand`,
landscape, zero gravity and damping (ships set their own), touch emulated from the mouse,
`quit_on_go_back=false`. **Input actions are registered in code** (`Settings._register_inputs()`),
not in project.godot, so the bindings are readable in one place. There's no `boost` action:
under §4.3 the ion ramp follows thruster on-time, not a button.

#### 0.4 Licences and credits
✅ 2026-10-25. `LICENSE` (MIT), `CREDITS.md`, `game/assets/LICENCES.md`, and `GeminiCopyRight.md`
(condensed from AOD's). ⚠️ Its Google quotes still carry AOD's 2026-09-04 reading. The re-read is
due before the first public release (8.8).

#### 0.5 Autoload skeleton and asset seam
✅ 2026-10-25. Seven autoloads in `game/src/autoload/`, with `Save` loading first because
`Settings` reads its file in `_ready`. `Data` rejects any table without a `format` field.
`Assets.tex()` falls back to the placeholder, then to a magenta square. Boot → `Router` →
placeholder main menu, which shows a red count if any data file failed to load.

#### 0.6 Test harness
✅ 2026-10-25. `tools/test.sh`, using AOD's runner and `TestCase` (`game/tests/run_tests.gd`,
`case.gd`). It catches script errors that silently cut a test short through a `Logger`, and it
fails an empty suite or a test with no assertions. Verified: 9 tests pass, and a deliberately
failing test exits 1.

#### 0.7 Screenshot previews
✅ 2026-10-25. `tools/preview.sh res://…tscn [WxH]` → `game/dev_preview/out/<scene>_<size>.png`,
at the phone's 1560×720 by default. It renders **in the tools container on Xvfb with Mesa
llvmpipe**, so no window opens on the desktop. ⚠️ `docker run` needs `--init`, or `xvfb-run`
(as PID 1) never gets Xvfb's ready signal and hangs. The first screenshot caught an
off-centre menu.

#### 0.8 Tools container
✅ 2026-10-25. One image, `mss-tools:1` (`tools/docker/tools.Dockerfile`: Ubuntu 24.04,
Pillow, numpy, Xvfb, Mesa), serves both the art pipeline and the screenshots. `tools/run.sh`
builds it on first use, mounts the repo at `/work` and Godot at `/opt/godot/godot`, and runs as
the host uid. `tools/licence_audit.py` checks for missing and stale rows (exit 1 on either).
**The slicer port moved to A.1:** AOD's ~800-line slicer is tuned sheet by sheet, so it gets
ported against MSS's first real Gemini sheet rather than a made-up one.

#### 0.9 Android pipeline in Docker `[D15]`
✅ 2026-10-25. Runs on the reference phone from one `tools/android.sh deploy`; fps is in §5.5.
`tools/android.sh export|devices|install|run|deploy|logcat|log|perf|shot|adb` uses the `mss-android:1` image
(JDK 17, SDK platform 35 + build-tools 35.0.1, Android export templates only; 1.8 GB). Building
the image accepts the Android SDK licence. `tools/android.sh export` produces a signed
28 MB `build/mss-debug.apk` containing `data/*.json` and no tests. adb runs in the container
as root to reach USB, then hands its key files back to the host user. Commands and gotchas
are in [MOBILE_DEPLOY.md](MOBILE_DEPLOY.md). ⚠️ Android export needs
`import_etc2_astc=true`, and JSON only ships because the preset's include filter names it.
⚠️ Honor drops app output from logcat, so `Perf` also writes `user://perf.log`.

#### 0.10 Workflow docs
✅ 2026-10-25. `README.md`, plus the project `CLAUDE.md` (every command: test, screenshot,
audit, Android; and the rules: model boundary, asset seam, data not code, nothing on the host).
There's no board (D16).

---

### Phase 1: Ship model (pure data, headless)

Goal: blueprints load, validate and produce stats. Nothing is drawn except a debug view.

#### 1.1 Shapes
✅ 2026-10-25. `data/shapes.json` → `ShapeLib` / `Shape` (`src/model/`), tested in
`tests/model/test_shapes.gd` across every shape × size × 24 rotations. **The S/M/L edge lengths
live in `shapes.json`**, because they're geometry; `tiles.json` (1.2) holds only the stat
curve. Regular shapes are generated from a side count, with edge 0 flat along the bottom, so
every edge angle lands on the 15° grid (that's tested too). Loading rejects any attachable edge
that isn't a whole number of 0.25 U ports. ⚠️ Sorting `StringName`s orders them by pointer,
not alphabetically.

#### 1.2 Tile definitions `[D7]`
✅ 2026-10-25. `data/tiles.json` → `TileLib` / `TileDef` (`src/model/`), tested in
`tests/model/test_tiles.gd`. Cost and stats scale separately (`size_cost_factor`,
`size_stat_factor`), so the §4.1 balance trap can be tuned without touching prices. The loader
rejects fractional costs at any size, unknown materials, zero mass, and anything other than
exactly one `unique` tile (the core).

#### 1.3 Blueprint format
✅ 2026-10-25. `src/model/blueprint.gd`, tested in `tests/model/test_blueprint.gd`. The
check here is structural only; whether a design is buildable is 1.4. `migrate()` refuses a
newer `format` with "update the game". ⚠️ **JSON turns every number into a float**, so the
round-trip test goes through text. Mounts stay untyped until 3.2/4.3, and until then
whole-number floats in them are turned back into ints, or they'd drift on every save.

#### 1.4 Placement rules
✅ 2026-10-25. `src/model/placement.gd`, tested in `tests/model/test_placement.gd`: every
shape pair at S and L (1,670 snapped placements, each validated), overlaps, corner contact,
islands, core count, unknown names, and the 16 U / 150-tile caps (now in `tiles.json` →
`build`). **"Connected" means sharing a port**: same spot, opposite-facing edges. It's found
with a spatial hash, not by comparing every pair of edges. Snaps slide along the target edge one
port at a time, and identical footprints are deduped (a hex turned 60° is the same hex).
Measured on the desktop, a 150-tile ship validates in ~11 ms, and a snap search near the
finger takes ~4 ms. ⚠️ A phone may be 5–10× slower, so 2.5 may need incremental validation.

#### 1.5 Stats
✅ 2026-10-25. `src/model/ship_stats.gd`, checked in `tests/model/test_ship_stats.gd` against
three ships worked out by hand. Each tile's mass is spread over its real polygon, so the centre of
mass and the inertia (about that centre) are exact for every shape. Armor is reported HP-weighted
(`armor_avg`). Units are U; Phase 3.1 converts to pixels.

#### 1.6 Debug view and sample ships
✅ 2026-10-25. `tools/preview.sh res://scenes/debug/blueprint_view.tscn` draws every
`data/blueprints/*.json` with its stats. It shows **only free ports**, so a seam with dots on it
isn't really connected, which makes connectivity checkable by eye. `starter` (3 hardpoints
laid out for the §4.3 minimum: rear-left, rear-right, front), `brick` and `hexwing` all
validate (`tests/model/test_sample_blueprints.gd`). Forward is **+x**, Godot's angle 0. New
`Data.json_dir()` loads a folder of JSON files.

---

### Phase 2: Hangar v1 (the ship builder)

Goal: building a ship on a phone with your thumbs feels good. This is the core of the game, so it
gets the most polish.

**The hangar's input is checked by a driver**, not just screenshots:
`tools/drive.sh res://dev_preview/drive_hangar.tscn` feeds real touch events into the scene
(drag from the palette, tap, delete, undo, move, pinch, pan) and exits non-zero on any failure.
It caught the first bug in 2.2.

#### 2.1 Hangar scene and camera
✅ 2026-10-25. The owner confirmed zooming in and out on the phone. `scenes/hangar/hangar.tscn` →
`src/ui/hangar/`: `hangar.gd` (input and controller), `HangarCamera` (zoom 0.5–12 around the
pinch point), `ShipView` (grid, 16 U build area, ship mesh, overlays). Reached from the
placeholder main menu's **Hangar** button.

#### 2.2 Placing tiles
✅ 2026-10-25. The owner built ships on the phone, including mirror, paint and every tile type.
It was "hard at first" but easy once learned, so the hangar hints in 15.2 should
cover the lifted ghost and snapping. `HangarPalette`: type tabs, shape
swatches, S/M/L. Dragging a swatch carries a ghost **90 px above the finger** that snaps to the
nearest valid spot within 1 U, green or red. The snap search runs at most once per frame. Free
ports show while carrying. **Rotate works on the selected tile** (a second finger can't press a
button mid-drag on Android), cycling its valid orientations in place; the chosen rotation sticks
for the next drop. `R` rotates mid-drag on desktop. ⚠️ **The carry's release must not be marked
handled**, or the GUI keeps touch focus on the palette swatch and the next tap never reaches
the ship. ⚠️ **The tabs sit below the shapes** so that no drag starts in Android's bottom gesture
strip (§5.5); with the shapes at the bottom, the first drag on the phone sent the game home.
A real drag from the palette onto the core works on the phone.

#### 2.3 Editing
✅ 2026-10-25. `src/model/hangar_editor.gd`: place, remove, move, paint, undo/redo (100 deep,
whole-blueprint snapshots, so undo is exact by construction), and **mirror** across the
forward axis through the core. Mirror finds a tile's image by reflecting its outline and trying
every rotation, so the asymmetric wedge works. Mirror mode builds the starter ship in 5 drops.
Tested in `tests/model/test_hangar_editor.gd`. Tap selects, dragging a selected tile moves it,
and the toolbar has Rotate, Duplicate (next free spot beside it), Delete, Undo, Redo and Mirror.
Desktop keys: Ctrl+Z/Y, Del, R, D, M.

#### 2.4 Paint
✅ 2026-10-25. **Renderer:** `ShipMesh` (`src/ship/ship_mesh.gd`) builds one `ArrayMesh` per
ship, with each tile as a triangle fan. `ship.gdshader` samples the material atlas in ship
space, multiplies by the paint, keeps trim untinted, and bevels and outlines each edge, using a
per-triangle distance-to-edge carried in vertex alpha. The placeholder atlas comes from
`tools/make_placeholders.py` (project-made, MIT). ⚠️ The atlas cell and the ship-local x are
packed together in UV.x, so local coordinates are shifted positive (`LOCAL_OFFSET`); without
that, tiles left of the core used the previous cell's texture. The extra half repeat lines the
texture up with Large tiles. **Panel:** `PaintPanel` has 12 swatches, 6 recent colours
(device-wide, in Settings), a full HSV picker, and a Tile / Type / Ship scope; while it's open, a
tap paints. Paint round-trips with the blueprint (1.3), and `drive_hangar` checks the tap
painting.

#### 2.5 Stats panel
✅ 2026-10-25. `StatsPanel` shows tiles, HP,
armor, shield, mass and cost, and while a tile is carried it shows what that tile adds ("+100
HP"), read from the tile definition so it's cheap during a drag. Acceleration reads "no
thrusters" until 3.2. Problems are listed (the first 3), and their tiles pulse red. **Speed:** a
150-tile refresh went from 37.9 ms to **8.8 ms** on the desktop through three changes:
`Placement.analyze()` (validate and free ports from one port index), a per-tile geometry cache,
and an allocation-free port search with the grid offset so regular ports never sit on a cell
boundary. `drive_hangar` checks the panel matches `ShipStats` and the refresh time. ⚠️
`drive_hangar` also has a script-error watcher: before it, a step that crashed half-way still
reported PASS. **On the phone** it was 29 ms (analyze alone 21) and is now 15–18 ms,
which the owner accepted as the budget (§5.5). That came from matching each port once into
linked-list buckets, union-find for connectivity, per-tile cached ports and cell keys,
memoized `TileDef.stats/cost`, and a stamp on each tile so a cache hit skips the string key.
The desktop median is 5 ms. `dev_preview/bench_analyze.tscn` times each part.

#### 2.6 Blueprint library UI
✅ 2026-10-25. Load, Save and thumbnails also checked on the phone. `BlueprintLibrary`
(`src/ship/blueprint_library.gd`) keeps the **device-wide** library `[D6]` in
`user://library/<id>.json` with a `<id>.png` thumbnail beside each, and writes through `Save`
(atomic, with `.bak`). `ThumbnailRenderer` draws one frame of a private `SubViewport` per save.
`LibraryPanel` (the **Ships** button) has a card grid plus New, Save, Save As, Load, Rename and
Delete (with confirmation); names are typed in a `LineEdit`, so Android shows its keyboard.
Save As keeps the undo history and carries on editing the copy. `drive_hangar` saves 10 ships,
checks each thumbnail actually contains the ship, reloads one byte-for-byte, renames and
deletes. ⚠️ `set_anchors_preset()` leaves the old offsets in place: use
`set_anchors_and_offsets_preset()` for a full-screen panel. 7.3's "Publish" will mark a library
ship as buyable rather than add a second store.

---

### Phase 3: Flight → **M1**

Goal: put the ship you built into space and fly it.

#### 3.1 Ship body
✅ 2026-10-25. `ShipBody` (`src/ship/ship_body.gd`) is a `RigidBody2D` with one
`ConvexPolygonShape2D` per tile. These are **shape owners on the body, not a
`CollisionPolygon2D` node per tile**, so 150 tiles don't cost 150 nodes. It has the `ShipMesh`
(one draw call, measured), and mass, centre of mass and inertia from `ShipStats` in pixels.
`tile_at_shape()` maps a hit's shape index to its tile. On the phone, a 150-tile spawn takes
**9 ms**. The hangar's **Fly** button opens `FlightSandbox` (`src/flight/`) **on top of the
hangar**, so edits and undo survive the flight; tapping the ship there highlights the tile a
physics query hit. Tested in `tests/ship/test_ship_body.gd` (each shape has its own tile's
outline) and `dev_preview/drive_flight.tscn` (taps and rays hit the right tile, 1 draw call, two
ships collide, back keeps the hangar). ⚠️ A GDScript lambda captures a local bool by value; use
an array for a flag set from a signal.

#### 3.2 Thruster mounting `[D13]`
✅ 2026-10-25. `data/thrusters.json` → `ThrusterLib` (type × S/M/L × L1–3; thrust, mass and
GC price scale with size). `Mounting` (`src/model/mounting.gd`): a thruster covers 1/2/4 ports
of a hardpoint edge and sticks out half its length. Its footprint is an **obstacle in
`Placement`**, so tiles can't snap onto it, and a thruster blocked by a later edit becomes a
red `mount` problem. Thrusters add point mass at their mounts in `ShipStats`. `ThrustEnvelope`
computes the 8-way rose, turn strength each way (**+y is the ship's right; positive torque
turns right**) and the §4.10 warnings (no forward thrust, can't brake, can't turn left/right,
pulls to one side), shown in amber and never blocking. Hangar: a **Thrusters** palette tab
(Pulse/Jet/Ion, L1–3, S/M/L), drag onto green slot markers, tap to select, drag to move (one
undo step), Delete, mirror mode. The rose and turn arcs are drawn at the centre of mass.
Nozzles are drawn in the ship mesh (a `thruster` atlas cell tinted per type from
`visuals.json`), so the ship is still one draw call. The starter now carries its 3 Large pulse
thrusters. Tested in `tests/model/test_thrusters.gd` (21 tests, including the §4.3
invariants), and `drive_hangar` places and deletes thrusters by touch. ⚠️ The stats panel
must ignore touches, or once it grew wider it swallowed pans that started under it.

#### 3.3 Flight controller
✅ 2026-10-25. `FlightModel` (`src/model/flight_model.gd`):
the stick is **world-space and says where to go**. The ship turns toward it (planning its spin
so it can stop in time) and pushes that way. Throttle per thruster = how much its push helps
the move + how much its torque helps the turn, clamped 0..1, so stick up-left on an up-facing
starter fires the right rear thruster. Released, it auto-brakes, asking for a deceleration
proportional to speed. Pulse kicks, steady jets and ion ramps (cooling twice as fast as they
build) are all handled. `FlightController` (`src/ship/`) applies it to `ShipBody` each physics
tick, and tuning is in `data/flight.json`. Samples: `strafer`, `no_forward` and `lopsided` in
`data/blueprints/`. `FlightSim` integrates like Godot for headless tests
(`tests/model/test_flight.gd`, 11 tests, covering every §4.3 behaviour listed in the old
checklist), and `drive_flight` flies the starter with real touches: forward, quarter turn,
brake to 0.01 U/s. ⚠️ **All pulse thrusters share one clock**: out of step, each kick is a
one-sided shove and the ship yaws back and forth. A pulse's share of the *feedback* (turning,
braking) is scaled to one interval's worth, or a kick overshoots. `dev_preview/trace_flight.tscn`
prints a frame-by-frame trace.
Owner, on the phone, 2026-10-25: "tested and working" (flew their own 36-tile swan and three of the samples).

#### 3.4 Touch controls
✅ 2026-10-25; the owner confirmed both schemes, left-handed and stick + FIRE on the phone. `FlightControls`
(`src/ui/controls/`) lays out from Settings:
- **2-stick:** a floating `TouchStick` in the left 40%, with `TouchButton` FIRE and SWITCH
  bottom-right (above the gesture strip).
- **1-stick:** the stick only.
- **`left_handed`:** swaps the sides. `stick_size` and `stick_opacity` scale everything.

`ControlsPanel` (the flight screen's **Controls** button; later part of 6.4) edits them and
rebuilds from Settings each time it opens. FIRE and SWITCH are placeholders until Phase 4.
`drive_flight` checks two fingers at once (stick + FIRE), that 1-stick hides the buttons, and
that left-handed moves the stick. ⚠️ **Godot's Button only hears the first finger** (the one
emulated as a mouse), so on-screen game buttons are `TouchButton`, which reads
`InputEventScreenTouch` per finger.

#### 3.5 Camera and space
✅ 2026-10-25; the owner confirmed speed feels fast and the edge is clear on the phone.
- **`FollowCamera`** (`src/flight/`): rests with the ship's longest side at 22% of the screen
  height, leads by 0.45 s of velocity, zooms out with speed down to 45% (deepened from 60% on
  2026-10-26 so a fast ship sees further), and snaps on jumps longer than a screen.
- **Player zoom** (owner, 2026-10-26): pinch with two fingers on open space, the mouse wheel or
  `+`/`-` scale all of that by 0.35–2.5×, saved as `view_zoom` in Settings (also a slider in
  the Controls panel, which now lists every hotkey from `Settings.hotkeys()`). A pinch saves
  once, when the fingers lift. The carrier gets an `EdgeMarkers` mark at the screen edge when
  it's off screen: an arrow that shrinks with distance, and a full-size dot just before it
  comes into view (`flight.json` `edge_markers`).
- **`Starfield`:** a screen-space shader, three hashed star layers at 10/30/60% parallax with
  twinkle; no textures.
- **`Arena`** (`src/model/arena.gd`, tested): a 240 U square with a 25 U warning margin. The
  sandbox draws its red edge, glows the screen border red and says "leaving the area", and
  past the edge pushes back at 3 U/s² per U of depth. Story replaces the push with the world
  map (4.10).

Tuning is in `flight.json` (`camera`, `arena`). `drive_flight` checks the lead, the zoom-out,
the warning and the push back. ⚠️ Teleport a RigidBody2D through `PhysicsServer2D.body_set_state`:
setting `global_position` on an awake body is overwritten by the next physics step.

#### 3.6 Thruster VFX
✅ 2026-10-25. `ThrusterFx` (`src/ship/thruster_fx.gd`), one per thruster, fed by
`ThrusterFxSet` from the FlightController:
- **Pulse:** an orange puff on each kick (the controller's `kicked` signal).
- **Jet:** a fire trail whose length follows the throttle.
- **Ion:** a long tapered blue plume (a code-made texture, layered deep blue to white-hot)
  that grows and brightens with its ramp.

Size follows the thruster's width, and L2/L3 are ×1.3/×1.6 (`vis.fx.thrusters` in
`visuals.json`, with the colours). It uses CPUParticles2D with a soft dot generated in code (no
asset files), additive, drawn **under** the hull. `scenes/debug/thruster_fx_showcase.tscn`
shows 3 types × 3 sizes at L1 and L3 (`tools/preview.sh … 1560x720 --frames=45`). ⚠️ **Pulse
puffs use local coordinates.** In world space they were left behind and slid off-screen within
a fraction of a second at cruise, because the camera leads the ship. Jet trails stay in world
space so they bend on a turn. GPUParticles2D hasn't been measured yet; revisit if particles
cost too much with 40 ships (15.1).

**M1 — fly a ship you built.** Demo on the phone: build in the hangar → Test → fly → back.

---

### Phase 4: Weapons and damage

#### 4.1 Damage model
✅ 2026-10-25. `DamageTable` (`model/damage_table.gd`, from `data/damage_types.json`) holds the
rules; `ShipDamage` (`model/ship_damage.gd`) is one ship's fight state: HP per tile, the shield
pool, regen, the EMP knock-out and core death. `hit()` / `splash()` return a `Result` (shield
drained, HP lost, tiles destroyed). `test_damage.gd` covers every row of the §4.5 table. Rules
the table left open:
- What the pool can't hold carries on to the tile as raw damage (a 60 energy hit on a 60 pool
  drains it and still deals 20).
- A splash drains the pool once, then hits each tile in reach, from ×1 at the centre to
  `splash_edge_share` (×0.5) at the rim.
- An EMP'd shield soaks nothing and doesn't regen for 2 s, but keeps its points.
- Weapons can carry `pierce` (0–1, the share of armor ignored) for the cannon.

#### 4.2 Destruction
✅ 2026-10-25. `ShipBody.enable_damage()` gives a ship a `ShipDamage`; `take_hit()` /
`take_splash()` feed it.
- **Breaking off:** `ShipDamage.break_off()` floods from the core through living tiles. Each
  cut-off group leaves as a wreck: a `ShipBody` built from `Blueprint.subset()`, on its own
  physics layer (collides with nothing), drifting away and fading out.
- **The survivor** rebuilds its shapes, mesh, mass and envelope, then emits `rebuilt`. The
  FlightController and ThrusterFxSet follow it, so losing a hardpoint loses its thruster. An
  EMP zeroes the throttles.
- **Core death:** the rest splits into chunks of ≤3 tiles (`split()`) flung outward, plus an
  `Explosion` (flash, ring, sparks; `vis.fx.explosion`).
- **Wear:** 4 steps, packed into UV.y in thousands (`ShipMesh.wear_step`). The shader scorches,
  then cracks with a Voronoi network that glows near the end. The mesh is rebuilt only when a
  tile's step changes.

The wreck numbers are in `damage_types.json` → `wreck`.

The sandbox parks `data/enemies/target_barge.json` (9×2) ahead of the ship; a tap hits a tile
for `test_hit` until guns arrive, and destroyed ships respawn. `drive_flight` checks:
- cutting the barge in half leaves 1 wreck of 7 tiles and a lighter survivor;
- destroying the core leaves an explosion and chunks, and the target respawns;
- losing a thruster updates the pilot and the exhaust.

⚠️ The sandbox takes touches only. Mouse clicks also arrive as touches
(`emulate_touch_from_mouse`), and taking both hit twice.

#### 4.3 Weapon framework
✅ 2026-10-26. `data/weapons.json` → `WeaponLib` (mount types fixed / swivel ±22.5° / turret 360°
auto-only, and the single gatling). `Mounting` takes guns: an edge gun covers `edge_u` of a
hardpoint edge and its barrel blocks `length_u` like a thruster; a turret sits on a hardpoint's
**face** (`{"tile", "face": true, …}`), one per tile, if a circle of `turret_radius_u` fits
(so not on an S tile). `GunLayout` (`model/gun_layout.gd`) gives each gun its pivot, facing, arc
and, for side-mounted guns, **blocked directions**: each other tile's angular span seen from
the pivot, merged (turrets fire over the hull).
`Gunnery` (`model/gunnery.gd`) picks, leads, turns and fires per tick (§4.4 rules), keeping aim
by gun key when tiles are lost. Flight: `WeaponController` and `GunView` on the ship, with shots
in the 4.4 pool. **Hulls sit on a physics layer per team** (`ShipBody.TEAM_LAYER << team`), so a
shot's ray never sees its own side and needs no exclusion list. Hangar: a **Weapons** tab (gun,
mount type, mode); drag onto slot markers; a selected gun shows **Mode** in place of
Rotate/Duplicate, and its arc fan. Samples: the starter now carries its nose turret; `gunboat`
has one gun of each mount type. Tested in `tests/model/test_weapons.gd` (23 tests). `drive_flight`
flies the gunboat: auto guns hit the barge alone, the manual nose gun waits for FIRE, no shot
touches our ship, and with the target abeam the swivels stop while both turrets fire. ⚠️ Lead from the
**muzzle**, not the pivot: half a unit of barrel was enough to miss.
Accuracy by level (§4.4) came in from the owner's first test. A Creative ship's guns share
`ShipBody.gun_level`, which the sandbox's **Guns L1** button steps through `gun_levels` in
`flight.json`; a stocked ship's guns have their own levels (4.8b).
Owner, on the phone, 2026-10-26: guns "look and feel good"; spread by level "feels good".

#### 4.4 Projectile pool
✅ 2026-10-26. `ProjectilePool` (`src/combat/projectile_pool.gd`, built in 4.3): packed arrays,
1024 slots, one `MultiMeshInstance2D` of additive streaks, one `intersect_ray` per shot per
tick, masked by team layer. **On the phone, 600 shots hold 60 fps** (pool physics 3.0 ms avg /
5.4 max, draw 1.9 ms), and so do 900. The debug menu's **Shot stress test**
(`scenes/debug/shot_stress.tscn`) ramps 150/300/600/900 at a ring of barges and writes a
`stress:` line per stage to the Perf log; `tools/drive.sh res://dev_preview/drive_shots.tscn`
runs one ramp on the PC. Hits in the test are on undamageable barges, so the cost of
`ShipDamage` per hit isn't in these numbers.

#### 4.5 Weapons batch A: kinetic
✅ 2026-10-26. `weapons.json` adds the **multi gatling** (`rate_start` 4 → `rate` 24 shots/s over
`spin_up_s` 1.5, winding down over `spin_down_s`; `Gunnery.spins`) and the **cannon** (60 a shell
at 0.8/s, `pierce` 0.6, slower shells). All three kinetic guns go on all three mounts.
- **Effects, all procedural:** tracers fade from tail to a bright head (a gradient texture on
  the pool's MultiMesh). `GunView` flashes the muzzle per shot and draws per-weapon barrels.
  `ImpactFx` (`src/combat/`) throws sparks back from each hit, in one more MultiMesh.
- **Looks:** `vis.weapons.guns`, `vis.fx.projectiles` and `vis.fx.impacts`.
- **Samples:** the gunboat now carries a manual nose cannon, auto multi-gatling swivels and
  gatling turrets.
- **Tests:** `tests/model/test_kinetic_guns.gd` mounts and fires every gun on every mount, and
  checks the spin-up and that the cannon is the armour breaker.

⚠️ The suite only loads the scripts a test touches, so an effect's parse error got through until
a drive ran. `tests/core/test_scripts_compile.gd` now compiles everything in `src/` and
`dev_preview/`.

#### 4.6a Rockets and flak
✅ 2026-10-26. `weapons.json` adds flak and the four rockets, with new optional fields:
`pellets`, `splash_u`/`splash_damage`/`splash_type`, `airburst`, `homing_deg_s`, `rocket`
(can be shot down) and `anti_missile`.
- **Fire control:** `Gunnery` fires `pellets` shots per trigger and sets an airburst fuse to the
  target's intercept time. An anti-missile gun also targets enemy rockets (`step(…, missiles)`).
  `Gunnery.steer()` turns a seeker no faster than its rate.
- **The pool:** keeps each weapon's shot rules once (`_specs`). It steers homing shots,
  explodes splash shots on a hit (and airbursts when their fuse runs out) with a circle query,
  and destroys enemy rockets inside a blast. `ImpactFx.blast/pop` draw the explosions.
- **Sandbox:** a **Target** button cycles `targets` in `flight.json`. The new `rocket_pod`
  shoots seekers back.
- **Samples:** `skirmisher` has a manual AP rocket, Seeker HE swivels and flak turrets.
- **Tests:** `tests/model/test_rockets_and_flak.gd` covers the four-rocket matrix, flak pellets
  and fuses, anti-missile targeting, the homing turn rate, and that every sandbox target is a
  valid ship. `drive_flight` checks splash hurting several barge tiles, and flak shooting down
  the pod's seekers.

⚠️ The skirmisher can kill the pod mid-check and a new one respawns, so the drive counts shots
from whichever pod is alive.

#### 4.6b Laser, EMP, mines
✅ 2026-10-26. Three new guns in `weapons.json`:
- **Laser** (`beam`): no projectile. Each tick `WeaponController` casts a ray down every beam
  that's on (`beam_ends`, which `GunView` draws as glow plus core), and each pulse (`damage` at
  `rate`) hurts what the ray hit. It heats over `heat_s` of firing, then overheats until it has
  cooled to `heat_resume`; `GunView` shows heat as an arc round its base.
- **EMP:** a slow orb with an airburst pulse of type `emp`. It goes on fixed and turret mounts
  only.
- **Mines:** `rear_only`, so the slots offer only rear-facing edges and `Mounting.problems`
  flags any other. A mine drops behind the ship, slows by `drag`, waits `life_s`, and goes off
  within `proximity_u` of an enemy. Explosions can destroy it. On auto, a layer drops while an
  enemy is within `range_u`.
- **Hangar:** the Weapons palette steps through `family` groups (Guns / Rockets / Special) with
  one button.
- **Sandbox and samples:** a `shield_block` target; a `specialist` sample with nose and swivel
  lasers, EMP turrets and a rear mine layer.
- **Tests:** `tests/model/test_specials.gd`. `drive_flight` checks the laser pulses landing, the
  EMP knocking the block out, and a mine going off.

⚠️ Beam damage comes in pulses because a per-frame sliver (1 HP) is cut to the 20% floor by
any armour. The rare shot extras (homing, drag, proximity) are bit flags, so a plain bullet's
step never reads its spec dictionary: that kept 600 shots at 1.1 ms on the PC.
- [x] Owner, on the phone: skirmisher vs barge and rocket pod; specialist vs shield block (confirmed with the weapon test ships, 2026-10-26)

#### 4.7 Combat HUD and weapon switch
✅ 2026-10-26.
- **FIRE and SWITCH:** manual guns group by weapon type. `Gunnery.active` is the one FIRE fires,
  and every manual gun of that type fires together; auto guns don't change. If the active
  group's guns are lost, the next group takes over. `WeaponPicker` (`src/ui/controls/`) is
  SWITCH: it pauses the tree (it runs with process mode ALWAYS), shows a card per manual weapon
  with icon and count, and a pick resumes. Q on a keyboard cycles without pausing.
- **HUD:** `CombatHud` (`src/ui/hud/`) shows shield and hull bars (hull is a share of the tiles
  still attached) and "FIRE: <weapon> ×n". `ShipBody.damaged` drives a screen-edge flash (red
  for hull, blue for shield), a `FollowCamera.shake()` and `Input.vibrate_handheld`.
- **Settings and tuning:** vibration and shake are toggles in the Controls panel; the numbers
  are in `flight.json` → `combat_hud`.
- **Weapon test ships:** one per weapon (`test_<weapon>`, "<Gun> test"), and the library seeds
  every `data/blueprints` ship into the phone's Ships list (`BlueprintLibrary.seed_samples`).
  Each is copied once, and again only when the game changes it; a deleted one stays gone.
- **Tests:** `tests/model/test_weapon_switch.gd` and `tests/ship/test_sample_seeding.gd`.
  `drive_flight` checks the done-when, the pause, the pick and the hit flash.

⚠️ The sandbox unpauses in `close()` and `_exit_tree()`, so leaving mid-SWITCH can't strand the
game paused.
- [x] Owner, on the phone: the weapon test ships; SWITCH between manual weapons; hit feedback (confirmed 2026-10-26)

#### 4.8a Inventory and the stocked hangar (owner, 2026-10-26; §4.6)
✅ 2026-10-26.
- **Model:** `Inventory` (`src/model/inventory.gd`) holds the wallet, every gun item (fitted
  or loose) and the loose thruster counts. A fitted gun is named by its mount's `"gun"` id.
  `Economy` holds the prices: tiles cost their materials, parts their `price_gc`, Sell pays
  `sell_rate` (75%, rounded down), and the refit cost is in `data/economy.json`.
- **Editor:** `HangarEditor.stock` turns the costs on; Creative leaves it null. After each edit,
  `_settle()` diffs the blueprint against the last undo checkpoint and pays or refunds the
  difference. New parts come from the shop or the inventory (a mirror twin with no spare left is
  left off). An edit that can't be paid for is undone, with the reason in `refusal`. Undo
  snapshots hold the stock too.
- **Hangar:** an Inventory tab (gun cards with level, XP bar and mount type; thrusters with a
  count; a "Mount:" button for refits) and a wallet line. Delete becomes Remove, and Sell
  appears (tap it, or drop a part on it). A part dragged off the ship onto the palette goes in
  the inventory. Shop swatches show their GC price.
- **Dev profile:** the main menu's debug **Hangar (stocked)** opens `user://profiles/dev/hangar.json`
  (`StockStore`), and a debug **Reset** starts it over from `economy.json` → `new_pilot` (6.1).
  The library is hidden while stocked; buying ships comes with shops (7.3).
- **Tests:** `tests/model/test_inventory.gd`, and `dev_preview/drive_stocked.tscn` plays it with
  touches.

⚠️ Sell is offered for guns and thrusters only: Remove already refunds a tile 100%, so selling
one for 75% would never make sense. Settling diffs whole blueprints, so any new kind of edit is
paid for without extra code.
- [x] Owner, on the phone: Hangar (stocked): build, Remove, Sell, the Inventory tab, refit (confirmed 2026-10-26)

#### 4.8b Gun XP and levels `[D8]`
✅ 2026-10-26.
- **Curve and kills:** `WeaponXp` (`src/model/weapon_xp.gd`, from `data/weapon_xp.json`, which
  now owns `max_level`). XP to reach level L is 10 × (L − 1)²; damage and splash damage gain
  +1% per level. A kill is worth tiles × encounter level², split by damage with
  largest-remainder rounding (`split`).
- **Levels in play:** `GunLayout.compute(bp, placement, level, levels)` puts a fitted gun at its
  item's level. A shot's source is part of the pool's per-weapon spec key, so tagging costs
  nothing per shot. `ShipBody.damage_by` tallies the damage each item deals, and on a kill the
  sandbox awards the XP (`flight.json` → `sandbox.encounter_level` 3 until Phase 5). The HUD
  shows "+N XP · Gatling L5!", and the guns step up mid-flight.
- **Creative** keeps the Guns L button; a stocked ship hides it.
- **Tests:** `tests/model/test_weapon_xp.gd`; drive_stocked checks the whole path, from turret
  hits to the save.

⚠️ Undo keeps the XP guns have now: XP is earned in flight, so an undo snapshot taken before a
flight must not take it back.
- [x] Owner, on the phone: kill practice targets with a stocked ship and see the guns level (confirmed 2026-10-26: every playtest flew from the stocked hangar)

#### 4.8c Market, kill pay and the price pass (owner, 2026-10-26)
✅ 2026-10-26.
- **Market:** tapping the stocked hangar's wallet opens `MarketPanel`
  (`src/ui/hangar/market_panel.gd`). It buys and sells each material in lots of 10 and 100 at
  `economy.json` → `market`. Each trade is an undo step (`HangarEditor.trade`).
- **Kills pay:** `Economy.kill_loot` pays a share of the materials the enemy's tiles cost, plus
  GC per tile, both rising with encounter level (`economy.json` → `drops`). The sandbox banks it
  straight into the wallet until there are pickups (5.4). A 20-tile barge at level 3 pays about
  300 GC's worth.
- **Prices:** tile costs and part prices are ×10 the first pass (§4.2). The dev profile now
  starts with about 4,400 GC's worth: a couple of armor tiles, or most of a cannon.
- **Tests:** market and loot tests are in `test_inventory.gd`; drive_stocked trades through the
  panel and checks a kill's pay is saved.

⚠️ Landing in the stocked hangar clears undo: an undo from before the flight would take back
what it earned. An old dev profile on a device keeps its old wallet until **Reset stocked
hangar**.
- [x] Owner, on the phone: does building feel earned now? Prices, market spread and kill pay are all in `economy.json` (yes, 2026-10-26: four runs at level 1 to afford two more gatlings; the market may want tuning later, 8.7)

---

### Phase 5: Enemies and encounters

#### 5.1 Enemy roster
✅ 2026-10-26. 17 ships in `data/enemies/`, listed in `data/enemies.json` (tier, role, behaviour,
levels, faction, boss, `flee_below`) and loaded by `EnemyRoster` (`src/model/enemy_roster.gd`).

| Tier (levels) | Ships | Boss (Kill HVT) |
|---|---|---|
| 1 (L1–30) | Gnat chaser, Dart kamikaze, Wasp strafer | Marauder, 21 tiles |
| 2 (L15–55) | Hornet chaser, Spinner minelayer, Lance sniper | Gorgon, 31 tiles |
| 3 (L35–80) | Bulwark brute, Harrier strafer, Longbow sniper | Tyrant, 45 tiles |
| 4 (L60–100) | Mauler brute, Widow minelayer, Meteor kamikaze | Leviathan, 67 tiles |

- **Carrier:** Pike, a 9 U armoured spine with three turrets. It is the **ally** the player
  escorts and keeps alive (owner, 2026-10-26; 12.3), not an enemy. It flies its route
  (`convoy`), and enemies go for it.
- **Authoring:** the ships are drawn as ASCII grids in `dev_preview/make_enemies.gd`, which
  writes the blueprints and refuses any ship with a placement problem, a thrust warning or a
  blocked gun. Edit a ship there, not in the JSON.
- **Gallery:** the main menu's debug **Enemy gallery** (`scenes/debug/enemy_gallery.tscn`).
- **Sandbox:** everything on the roster can be spawned (5.2's Spawn button).
- **Tests:** `tests/model/test_enemy_roster.gd` checks the counts, validity, roles' weapons,
  the carrier's shape (and that it's never an enemy), bosses outgrowing their tier, and that
  every level 1–100 has enemies.

⚠️ Big ships brake weakly (0.2–0.6 U/s² back against 4–6 forward), and most have little side
thrust. The owner accepted this for the MVP (2026-10-26). The AI (5.2) turns and burns rather
than counting on reverse thrust; more variety in brakes and side thrusters comes with the v2
faction rosters (§9).
- [x] Owner: look over the gallery (and spawn the bosses in the sandbox) (done 2026-10-26)

#### 5.2 AI pilot
✅ 2026-10-26.
- **Brain:** `AiBrain` (`src/model/ai_brain.gd`, tuned in `data/ai.json`) turns where the ship,
  its target, its friends, its charge and the arena are into a stick. That's the same
  world-space stick the player's thumb moves, so the ship flies through the same
  `FlightModel`, with no AI-only physics.
- **Behaviours:** each picks a velocity it wants, and the stick steers toward it:
  - **chase:** close in to a stand-off distance, nose on the lead point.
  - **strafe:** circle the target.
  - **keep_range:** hold a band of its gun range.
  - **ram:** full speed at the intercept point.
  - **lay_mines:** circle inside mine range.
  - **escort:** an enemy guarding a ship (a boss's guards, 12.2) holds a post beside it; with
    a raider near, the post moves between the two.
  - **convoy:** the carrier flies its waypoints whatever attacks it; its turrets fight back.
  - **flee:** below `flee_below` of its hull, it runs.
- **Always on:** friends push each other apart, and the arena edge pulls ships back in.
- **Pilot node:** `AiPilot` (`src/ai/ai_pilot.gd`) feeds the brain each physics tick, before the
  `FlightController`.
- **Sandbox Spawn button** (owner, 2026-10-26), replacing Target: it pauses and lists every
  ship with its picture (`SpawnPicker`, `src/ui/controls/`): practice targets, the roster by
  tier, the carrier, and the player's own library ships.
  - **A tap spawns it.** An enemy appears a few tiles ahead, facing you, stepped aside from
    anything already there. A roster ship flies itself; one of your own ships flies as a chaser
    (if it has fixed guns) or a strafer.
  - **The carrier** appears beside you and starts `carrier_route`, laid out from your heading.
  - **Enemies go for** whichever of you and the carrier is nearer, the carrier's distance
    counted at `carrier_bias` (0.6).
  - **Several enemies** can be out at once (`FlightSandbox.enemies`); killed ones don't respawn.
- **Tests:** `tests/model/test_ai_pilot.gd` flies each behaviour headless in `FlightSim` with
  real roster ships, including a chaser on a circling target and six ships at an arena corner
  with the player past the edge. drive_flight checks Wasp and Marauder fly themselves in the
  game.

⚠️ The flight model won't turn a ship toward a stick held straight behind it (the thrusters
that would turn it push against the stick), and most enemies brake weakly. So the brain turns
first: it holds the stick at most 90° off the nose. A ship closing too fast while nose-on lets
go of the stick instead, so the auto-brake slows it without turning. Debris avoidance is left
to physics, since wrecks fade in seconds.
- [x] Owner, on the phone: Spawn → fight Wasp (strafe), the bosses and your own ships; spawn the Pike carrier and keep it alive (confirmed 2026-10-26: the AI feels good; the Spinner's mines suit groups). Bosses hit hard at L1 (the Marauder is about 500 dmg/s against the starter's 1,160 HP); enemy gun levels and the balance come with 5.3

#### 5.3 Level scaling 1–100
✅ 2026-10-26.
- **Generator:** `Encounter` (`src/model/encounter.gd`) reads `data/levels.json`.
  `Encounter.generate(rules, roster, level, seed, hvt)` gives the same spawn list for the same
  seed.
- **Budget:** counted in enemy tiles (a ship costs its tile count): 8 + 1.6 × level^1.15. That's
  10 tiles at L1 and about 320 at L100.
- **Six level bands** set:
  - the **tier mix**: tier 1 only up to L10, mostly tiers 3–4 by L86;
  - the **count**: 1–3 enemies at the start, 5–8 at the top;
  - the **enemy damage share**, from 50% at L1–10 to 100% at L86–100. This keeps early fights
    from melting a starter ship.
- **Enemy guns:** 10 × the level, ±20%, within 1–999 (§4.8).
- **Kill HVT:** an HVT encounter is led by the boss whose levels fit.
- **Damage share in play:** `GunLayout.compute(…, damage_share)` and `ShipBody.gun_damage`
  apply it; `ShipBody.level` is what a kill pays XP and loot at.
- **Sandbox:**
  - A single spawn comes at `flight.json` → `encounter_level`.
  - The Spawn list has **Level 1/10/25/50/75/100** and **Boss L15/40/65/90** buttons that
    spawn a generated fight.
  - Spawns appear 16 U ahead, twice the first gap (owner, 2026-10-26).
- **Tests:** `tests/model/test_encounter.gd` checks the rising budget, same seed same fight, and
  L1/25/50/100 within their band's count and budget. It also checks gun levels, the tier mix,
  HVT bosses and the damage share. drive_flight presses the encounter and boss buttons.

⚠️ drive_flight keeps the old 6 U spawn gap in memory: its gun checks assume targets inside a
laser's 18 U reach.
- [x] Owner, on the phone: Spawn → Level 1/10/25 with the starter, and a boss fight; is the damage share right? (played 2026-10-26; the notes are in 8.7)

#### 5.4 Drops and pickups
✅ 2026-10-26.
- **Model** (`Economy`, tested in `tests/model/test_drops.gd`): `kill_loot` drops 2% of the
  enemy's tile materials, plus 1 Tech for each mounted part and GC by tile count, all scaled by
  level. `loot_pieces` splits each resource into at most 3 pickups. `part_drop` gives a 4%
  chance of one of the enemy's guns (with the XP of the level it fought at) or thrusters.
  `Inventory.bank()` moves cargo into the stock, giving found guns new ids.
- **`PickupField`** (`src/flight/`): every pickup lives in arrays and is drawn in one
  `_draw`. Pickups scatter from the wreck and drift to a stop. Within 8 U of the hull they fly
  in at 14 U/s plus the ship's speed; touching the ship collects them. They vanish after 45 s,
  blinking first. Placeholder shapes: Hull a pentagon scrap, Alloy a hexagon, Crystal a shard,
  Tech a wire bundle, GC a coin, a part a crate.
- **Sandbox:** every enemy destroyed drops loot, whoever killed it, in Creative too. XP still
  needs the player's guns. The pickups go into `cargo`, which shows on the HUD with a
  "Found a …" note for parts. `hangar.land()` banks the cargo into the stock and saves it
  (Creative's is only for show).
- `drive_stocked` checks the drop, the magnet, the HUD counter, a found gun's XP, and the
  banking on landing.

The kill no longer pays straight into the wallet (4.8c did); anything left floating when you
land is lost. Loot scatters from the tiles left on the wreck, flung harder the bigger the
blast, which is sized by what was left of the ship (owner, 2026-10-26). A nearly whole ship
throws it wide; a stub drops it close.

#### 5.5 Spawner
✅ 2026-10-26.
- **`Spawner`** (`src/flight/spawner.gd`): the API that Creative's test flight, WaveTime and
  Story tiles share. It owns the enemies and the carrier: it builds, arms and pilots them,
  picks whom each one hunts, and emits `enemy_destroyed`, `cleared` and `carrier_lost`.
  - `spawn_encounter(level, hvt)` brings in a whole fight off screen round the player.
  - `spawn_ship(…, AHEAD|AROUND)` brings in one ship, ahead for the sandbox's Spawn cards.
  - `spawn_carrier(bp, entry, route)` brings in the escort carrier.
  - The mode supplies the player (`player`) and the view (`view_half_u`), and handles loot, XP
    and the HUD. The sandbox is now one such client.
- **`SpawnRing`** (`src/model/spawn_ring.gd`, tested in `test_spawn_ring.gd`): ships come in
  groups of up to 3, each group from its own side, lined up abreast just beyond the view's
  corner and at least 10 U inside the arena. A group turns to find room near a wall. Every
  ship faces the player. Tuning is in `flight.json` `spawner`.
- **Edge dots for enemies you've seen** (owner, 2026-10-26): an enemy that has been on screen
  gets a solid, fixed-size dot at the screen's edge while it's off screen and within
  `sight_range_u` (60 U, `edge_markers`). Beyond that it's forgotten until seen again. Being hit
  doesn't spot the shooter. The carrier's arrow is in 3.5; radar (v2) marks the rest.
- `drive_flight` checks the "done when": a level-30 fight spawns off screen inside the
  arena, opens fire, and once every ship is down the HUD says "level 30 cleared!" and their
  loot floats where they fell.

⚠️ Ships are spaced by `Spawner.reach_u`, their reach from the core, not half their length:
the core needn't sit in the middle.

⚠️ `FlightController` skips its first tick. Until a body has had one physics step, Godot
divides an impulse by mass 1, so a pulse ship kicking on its first tick was flung at about 80
U/s.

⚠️ `Spawner.clear()` also clears team 1's shots: a reset left high-level cannon rounds in
flight.

---

### Phase 6: The front door (profiles and menus)

#### 6.1 Main menu
✅ 2026-10-26. `scenes/menu/` → `src/ui/menus/`, in placeholder chrome (`MenuKit`) over a
drifting Starfield (`MenuBackdrop`). Top to bottom:
- **Title**, then the **profile card** (`ProfileCard`, owner's layout). The card is as wide as
  the mode tiles. Its left 30% is a square portrait (a helmet until the character builder,
  6.2). On the right: the pilot's name over the best WaveTime with kills / deaths, and Story
  % / jobs. It reads `Profiles.summary()` from `profile.json`; editing waits for 6.2.
- **Creative** opens the free hangar. **WaveTime** opens the stocked hangar on the `dev`
  profile until 6.2. **Story** is locked.
- **Tutorials** (as wide as two buttons) has the WaveTime and Story tutorials, locked until
  15.2, and the enemy gallery, whose back returns to Tutorials.
- **Settings** holds the Controls panel (6.4 fills it out). **Credits** reads
  `data/credits.json`, then Godot's licence and its third-party notices from the engine.

The debug-only shortcuts left the menu. The shot stress test needs a special build. Resetting
the WaveTime stock is a two-tap **Reset** beside Undo in a debug WaveTime hangar, which wipes
the save and goes to the menu for a clean load. `drive_menu` presses every button.

⚠️ A drive can't live in a scene that `Router` replaces: `drive_menu` loads the menu as a
scene of its own.

#### 6.2 Profiles and the character screen `[D2]`
✅ 2026-10-26.
- **`ProfileRecord`** (`src/model/`, tested) holds the id, name, character and stats. Names
  are cleaned (16 characters at most), ids are folder-safe and unique, and bad fields fall back
  to defaults.
- **The `Profiles` autoload** lists, creates, selects, saves and deletes pilots, each in
  `user://profiles/<id>/` (`profile.json` plus the stock's `hangar.json`). `index.json`
  remembers the last selection. The pre-profiles `dev` stock is adopted as the pilot "Pilot".
  `selected_id` is the chosen pilot; `active_id` is the stock the hangar builds from.
- **Screens:**
  - **Pilots** (`profiles.tscn`): a card each with Select, Edit and Delete, where Delete asks
    first; and a New pilot card.
  - **Character** (`character.tscn`): a `LineEdit` name, male or female base, and hair, eyes,
    outfit and trim swatches from `data/characters.json`, with a preview cycling the 4 moods.
  - **Main menu:** the card shows the selected pilot, and its Pilots button opens the list.
    WaveTime with no pilot goes to the character screen first.
- **`PortraitView`** shows the painted portrait (A.7) recoloured in the chosen colours, as a head
  crop on the cards and whole on the character screen; without the art it draws a placeholder
  bust. With no pilot it shows a helmet.
- New pilots start from `economy.json` → `new_pilot`. `drive_profiles` makes 3 pilots, checks
  each one's stock is separate, switches between them, and deletes one after the confirmation.

⚠️ Drives point `Profiles.root` at a scratch folder and call `reload()`: the real pilots live
in the same `user://` as the PC build.

#### 6.3 Save service
✅ 2026-10-26. The `Save` autoload writes `.tmp`, renames the old file to `.bak`, then renames
`.tmp` into place.
- **Reading** takes the newest complete copy: a finished `.tmp` first (one is left behind only
  if a write was killed between its renames), then the main file, then the `.bak`. A
  half-written `.tmp` doesn't parse, so it's skipped.
- **`read_versioned(path, current, steps)`** migrates one step at a time, and a file without a
  `format` counts as version 0. A file from a newer build reads as nothing, so it isn't
  overwritten as if it were ours.
- **Tests** (`tests/core/test_save.gd`): a write killed mid-write, one killed between its
  renames, a corrupt file, and a migration from v0.

#### 6.4 Settings
✅ 2026-10-26. `ControlsPanel` (main menu → Settings, and the flight sandbox's Controls) has
three columns:
- **Controls:** scheme, handedness, stick size and opacity.
- **Sound & feel:** music and SFX volume, vibration, screen shake, view zoom.
- **Hotkeys.**

The `Audio` autoload makes **Music** and **SFX** buses and sets them from Settings; 0 mutes a
bus. A slider applies at every step (`Settings.preview_value`) and saves once it has been still
for 0.4 s. Toggles save at once. `drive_menu` checks that the volume applies at once, is saved,
and mutes at 0, and that a toggle is saved. The panel fits a 1280-wide PC window.

#### 6.5 Pause and app lifecycle
✅ 2026-10-26.
- **`PauseMenu`** (`src/ui/hud/`) has Resume, Settings (the controls panel, which comes back to
  the menu) and Return to hangar. The flight opens it from its Pause button (in place of
  Controls), the pause key (P, Start), the back button, or the app losing focus or going to the
  background.
- **One way back** (owner, 2026-10-26): no screen or panel has a Back, Close or Done button. The
  back gesture, or Esc on a keyboard (`Router`'s `back` action), closes what's open, pauses a
  flight, or leaves the screen. Dialogs keep their Cancel. Story's "Save and return to hangar" (only
  after 10 s without combat, D18) comes with Story.
- **The back button**, through `Router` → each scene's `on_back()`:
  - In flight it closes an open panel first, then pauses or resumes. It never lands straight
    away.
  - On the main menu it asks "Quit MSS?" (`ConfirmPanel`, shared with deleting a pilot).
  - Elsewhere it goes back a screen.
- **Saving:** a WaveTime hangar saves its stock on `WM_CLOSE_REQUEST` and `APPLICATION_PAUSED`,
  as well as on every change. A Creative ship is kept only by saving it in Ships (as before).
- **Orientation** is sensor landscape (project setting 4), so turning the phone over turns the
  game.
- `drive_flight` checks the pause button and key, back, focus loss (the ship stands still),
  Settings and back, and Return to hangar. `drive_menu` checks the quit confirmation.

⚠️ A Control under a CanvasLayer needs `set_anchors_and_offsets_preset`; anchors alone leave it
at zero size.

---

### Phase 7: Creative mode → **M2**

#### 7.1 Creative hangar
✅ 2026-10-27. Creative is the hangar with no stock (the main menu's Creative tile): nothing costs
anything, every part is in the palette. Each Creative gun carries its own `level` on its mount,
from a log-scale slider (L1 to the XP curve's top) in the Weapons tab that sets new guns and the
selected one (`HangarEditor.set_gun_level`, mirrored, one undo step per drag). Only Creative flight
reads it (`GunLayout.compute(..., own_levels)`): an enemy built from the ship fights at its
encounter level, and a pilot's guns level by XP. The sandbox's Guns button now starts at "own" and
overrides every gun. Tested in `tests/model/test_creative.gd`; `drive_hangar` drags the slider.
⚠️ A selected *mount* never refreshed its label after an edit, so undo left "L1" showing.

#### 7.2 Test flight
✅ 2026-10-27. In Creative, Fly opens a `LaunchPanel`: free flight as before, or a **test fight**
at a level from its slider (1 to the top of `levels.json`). `FlightSandbox.test_level` drops the
practice target, the Spawn and Guns buttons and the respawn, and brings in a generated fight; a
`TestFlight` (`src/model/`) records time, kills and damage taken, and `TestResults` shows them when
the fight is cleared or the ship is destroyed, with Fly again and Return to hangar (or the back
gesture). Measured by `drive_testflight` with the starter sitting still, every gun on auto: **L1 is
cleared in about 50 s** taking ~630 of 1,160 HP; **L100 destroys it in about 1 s**. ⚠️ Enemies spawn
just off screen (~18 U) inside every long gun's range (24–32 U), so a high level opens fire before
anything is on screen: brutal, but no ship can react. Flagged for the tuning pass (8.7): a spawn
grace before they fire, or spawning beyond range.

#### 7.3 Publish to the library `[D6]`
- [ ] "Publish" makes a validated blueprint buyable in WaveTime and Story at its computed cost
- [ ] A device-wide library at `user://library/`, with the author shown
- **Done when:** a ship published by profile A appears in profile B's shop.

#### 7.4 Save ships to files and share them
- [ ] **Save ship to file**: a `.mssship` file (the blueprint JSON) to send to friends, and **Load ship from file** on their end
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
- [ ] Fly out and fly back (owner, 2026-10-26): a short launch from the hangar bay into the arena,
  and a return-and-dock screen when the run ends, so leaving and coming home read as moments
- **Done when:** a run starts, escalates and ends in death.

#### 8.2 HUD
- [ ] A big timer, the score, the wave number, a live loot tally
- [ ] Make pickups noticeable (owner, 2026-10-26: the sandbox's "Found a …" note was easy to
  miss). The cargo counter flashes and counts up as resources come in. A found part gets a
  banner. Pickups glint or pulse so they stand out from the debris.
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
- [ ] A market: buy and sell materials for GC (the hangar's `MarketPanel`, 4.8c), and buy L1 guns and thrusters (§4.6)
- **Done when:** a blueprint can be bought, then flown in the next run.

#### 8.7 New-player curve
- [ ] Spawn fairness (from 7.2): at L100 the off-screen spawn ring sits inside the enemies' gun
  range, and the starter dies in about a second, unseen. Give enemies a grace before they fire
  (until seen, or a second or two), or spawn them beyond their range.
- [ ] Starter ship (§4.10): Core, hull tiles and 3 hardpoints carrying 3 pulse thrusters (2 rear, 1 front) and 1 single gatling
- [ ] Tune so run 1 lasts ~1–2 min and every run banks enough to visibly upgrade
- [ ] Owner's sandbox playtest, 2026-10-26: a level-1 Starter with 3 gatlings barely survived
  Level 10; Level 25 took 4 respawns; Boss L15 (the Marauder) was almost an instant kill. In
  about 14 kills it dropped 2 guns and 1 thruster at the 4% part chance, maybe too often (keep
  for now). A found L265 gatling was a huge, satisfying upgrade. The Spinner's mines rarely land
  against a lone player, but that's fine: it's meant to fly with a boss or a group.
- [ ] Keep dying part of the loop (owner, 2026-10-26): with the L265 gatling the Marauder took 2
  tries. An early loss should steer the player to add armour and shields and try again, in
  WaveTime and Story alike. Don't tune deaths away.
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
- [ ] A VIP ship (AI) flies a route; waves target it; fail if it dies. The VIP is the Pike carrier (5.1), flown by the `convoy` behaviour (5.2).
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
- [ ] A first-run controls overlay, hangar hints (the lifted ghost, snapping; see 2.2), a WaveTime tips card, and a short Story tutorial in beat 1
- [ ] Show **Return to hangar** early (owner, 2026-10-26): landing is what banks the cargo and
  lets you spend it on upgrades.
- **Done when:** a new player builds and flies with no outside help.

#### 15.3 Store and distribution `[D14]`
- [x] Icon and splash (owner's art, 2026-10-25): `tools/make_branding.py` builds
  `game/assets/branding/` from `art_src/`. The adaptive icon is shrunk to survive a round mask;
  the splash is cropped to 2.17:1 above its baked-in loading bar. Both are Gemini art.
- [ ] **Regenerate the splash with in-game ships** (owner, 2026-10-25). The current one has two
  fighters that look like X-wings, and the game stays clear of copyrighted designs. Do it once
  enough real tile-built ships exist to pose (after M2), feeding Gemini screenshots of them.
- [ ] Final title, screenshots, trailer GIF; itch.io, GitHub; optionally F-Droid and Play
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

**Owed on the phone** (owner, 2026-10-27: the phone is only free in the evenings; tick each one
off, or note what broke). Everything here passed on the PC in previews and drives:
- [ ] `tools/android.sh deploy` (from main: v0.0.6 plus 7.1, 7.2 and the chrome)
- [ ] A.1 tiles in the hangar and in flight: materials, the core, the shield glow, all four damage steps
- [ ] The texture sampling (mipmaps on the tile, gun and icon art): no shimmer or seams when zooming
- [ ] A.2 nozzles on every side, and the trim colour at L1, L2 and L3
- [ ] A.3 guns: turret, fixed and swivel easy to tell apart in the hangar; heads turn smoothly
- [ ] A.4 icons: FIRE, SWITCH and Pause big enough under a thumb; loot pickups readable
- [ ] Mines in space read as mines (A.3d: 0.8 U, blinking), and the blink isn't too much
- [ ] A.5 chrome: crisp, not soft (the 2× art through a size override); the chosen hangar tab stands out; buttons still easy to hit
- [ ] 7.1/7.2: the Creative gun-level slider drags smoothly; a test fight and its results card
- [ ] `tools/android.sh perf` in a busy fight: guns are now textured quads (one canvas item per ship), so check the frame time against §5.5

| # | Item | Sheets / canvases | Needed by |
|---|---|---|---|
| A.0 | ✅ 2026-10-26. **Art direction** `[D3]`: the style sentence, four tiers (world, chrome and icons, portraits, backdrops), the palette (chrome sampled from Menu Theme) and the portrait key hues, all in `Docs/ART_PROMPT.md`'s header with the canvas contract and house rules | – | before A.1 |
| A.1 | Tile materials: Hull, Armor, Shield, Hardpoint (greyscale and seamless) + Core design. **First sheet, so it also carries the slicer port**: AOD's `slice_ui_sheets.py` → `tools/slice_sheets.py` with a per-sheet config (grid, key colour, glow list), proven on this sheet. ⚠️ Materials are sampled in ship space (one repeat per U), so a Large hex core shows the canopy several times; the **core design needs tile-local UVs**, unlike the seamless materials. ✅ 2026-10-26: `tools/slice_sheets.py` (flood-fill key, cut inside the gutters, seams evened) packs `art_src/sheets.json`'s cells into `assets/tiles/tile_atlas.png` (a column per type, 3 variants, padded for mipmaps) and `tile_damage.png` (an overlay per wear step, in place of the procedural cracks). The core is textured in its own box, so its cockpit appears once. Gemini ignored a 15-item list but followed one kind per row. | 1 sheet (5 cells + 2 variants each) | 2.4 |
| A.2 | ✅ 2026-10-27. **Thrusters**: one Gemini sheet, one type per row (`ART_PROMPT.md` `parts_thrusters`). The slicer's `part` kind keys chroma green, takes the grey from R and B (the spill is all in G) and stretches the art over the cell; its cut-out goes in the atlas's B (1 = cut out, so the placeholder stays solid). The thruster column holds pulse, jet and ion in its three rows. `ShipMesh._add_part` draws a nozzle as its whole footprint box in the nozzle's own frame, so one picture serves every size and side, and the shader cuts it to the art's silhouette with no bevel. The trim band shows the level (L1–3 bronze, silver, gold; visuals.json). No S/M/L cells: a nozzle is the same shape at every size. ⚠️ A canvas_item fragment can't `return`, and the headless tests never compile the shader, so a shader change needs a preview. | 1 sheet (12 cells) | 3.6 |
| A.3 | ✅ 2026-10-27. **Weapons**: one painted **gun head** per type (housing and barrels, pointing right) from three runs of `ART_PROMPT.md` `parts_guns`, turning as a whole about the housing's centre on every mount. The slicer's `gun` kind finds the housing from the art's left edge and fits each gun so its barrel tip lands at a fixed x; `GunView._draw_head` scales it so the tip meets the data's muzzle, and tints the trim band (HE red, AP amber). The code-drawn guns stay as the fallback when the atlas is missing. Spare designs are catalogued for v2's factions. ⚠️ Fit by the tip, not the housing: Gemini's barrels run short, and a flash floating off the end looks broken. Flak and seeker were re-rolled as A.3b (`parts_guns_flak_seeker`). **A.3c, side guns** (owner, 2026-10-27, so mounts read at a glance in the hangar): an image edit of the turrets in use (`ref_turrets.png`) swapped each round base for a hull bracket; the atlas has a row per mount type (turret, fixed, swivel) and `GunView` picks by `mount_type`. ⚠️ To get a variant of existing art, give Gemini the art and ask for one change: describing "side-mounted" from scratch got side views of handheld guns, five times. | 1 sheet, run ×3 | 4.5 |
| A.4 | ✅ 2026-10-27. **Icons**: one sheet (`ART_PROMPT.md` `icons_main`, run 2 of 3): resources and GC, the HUD symbols (fire, switch, pause, boost) and the ×2–×5 power-up badges, one 128 px PNG each in `assets/icons/` (the slicer's `sprite` kind and `files` layout), as `vis.icon.<id>`. In use: pickups in flight, FIRE, SWITCH and Pause; boost and the badges wait for 8.3. **Tile-type, weapon and thruster icons reuse the part art** instead of their own sheet. ⚠️ The flood-fill key keeps enclosed black on purpose (a badge's centre); a crosshair's or coil's hole needs `holes`. | 1 sheet, run ×3 | 4.7, 8.3 |
| A.5 | ✅ 2026-10-27. **Flashy arcade chrome** (`ART_PROMPT.md` A.5: panel run 2, header run 3, frame run 2, buttons run 1): 18 RGBA PNGs in `assets/ui/` (the slicer's `chrome` kind, cut tight at 2× the drawn size), as `vis.ui.<id>` with their 9-slice `slice`/`content` margins in screen units. `UiTheme` (`src/ui/ui_theme.gd`) makes them StyleBoxTextures: gold Buttons everywhere, `GoButton`/`DangerButton` (Fly, Test fight, Fly again / confirm), `ChromePanel` for the dialogs and pickers, `HeaderPanel`, `FramePanel`, sliders and progress bars. Preview: `dev_preview/art_chrome.tscn`. ⚠️ Assets merges it into `ThemeDB.get_default_theme()`, because a theme on the root window doesn't reach past a CanvasLayer; and the art draws through `ImageTexture.set_size_override`, so 2× pixels sit in 1× margins. The LED rims tile (`tile`), since stretching smears the dots. Header and frame are in the theme but not yet on a screen. | 3 canvases + 1 sheet, run ×3 | 6.1 |
| A.6 | Map icons: asteroid, beacon, station, shop, bar, hangar, 4 job types, story, skull, tick, you-are-here | 1 sheet | 9.3 |
| A.7 | ✅ players and stand-ins 2026-10-27; NPCs to come. **Portraits** `[D3]` (§6.5), elbow height, 4 moods each: the male and female bases in a jacket and a space suit, and a generic villain and ally (`ART_PROMPT.md` A.7, one run each; the suits are image edits of the jackets). 512 px cells in `assets/portraits/` (the slicer's `portrait` kind keeps the whole cell, so `vis.portraits` gives one head crop per sheet), and for the players recolour masks in `masks/` (R hair, G eyes, B outfit, A trim, from hue bands). `PortraitView` draws them through `portrait_recolour.gdshader`, which takes each region's hue from the chosen colour and scales its value by the paint's over the region's mean (`ref_v`, reported by the slicer); `outfit` picks jacket or suit, `framing` the head crop or the whole picture, and `{"npc": id}` a stand-in. Preview: `dev_preview/art_portraits.tscn`. ⚠️ The masks' `.import` must keep `fix_alpha_border=false` (`tests/ui/test_portraits.gd`). The irises are only looked for in an eye box per sheet, because the suit's cyan rim light is their hue. White hair keeps a faint warm edge on the woman's left strands; a hand mask if it shows. Then NPCs (bartender ×3, job givers, wife, bandit boss, allies) | 6 sheets, then ~3 | 6.2, 11.5 |
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
  - **Rep sets the rates** (owner, 2026-10-26): the 75% part sell rate rises with your reputation
    with the station's faction, and so does the **market exchange rate** (buy and sell prices
    for materials).
  - **Each faction has its own look and arsenal** (owner, 2026-10-26), so a ship is recognisable
    at a glance. For example: **green**, pointed mono-hull fronts; **blue**, catamaran twin hulls;
    **purple**, round ships; **orange**, U-shaped hulls. Weapon preferences differ too, e.g. lasers
    and shields for one, armour and cannons for another. Flight handling should vary as well:
    more brake and side thrusters on some designs (v1's enemies have little of either). v1's
    roster stays `neutral`; v2 adds a
    roster per faction in the same `enemies.json` format, and the encounter generator (5.3)
    picks by faction.
- **Attack groups and formations** (owner, 2026-10-26): 3+ enemy ships that fly and fight
  together (a wedge of chasers, strafers screening a sniper, escorts round a boss). Hooks for v1:
  the AI pilot (5.2) takes its goal from outside (a target, a point, a ship to guard), so a group
  leader can hand out slots; the encounter generator (5.3) spawns ships in clusters.
- **Radar tech** (owner, 2026-10-26): a ship part or upgrade that marks enemies beyond sight
  range and ones never seen, the way the carrier is marked (`EdgeMarkers`: an arrow that shrinks
  with distance, a dot just before it comes into view). Without radar, only enemies you've
  seen get a fixed dot, within sight range (5.5). **Long-range radar** is an end-game upgrade adding a **ping**
  menu that reports each enemy's level and distance. Hook for v1: `EdgeMarkers.point_at()`
  takes any list of positions and colours.
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
