# ART_PROMPT.md: MSS art, batched into Gemini sheets

The Gemini prompts for MSS's art (PLAN.md §6 and the art track, §8). One `##` section per sheet.
The owner generates each one in Gemini (the consumer tier; see `GeminiCopyRight.md`) and saves it
into `art_src/<folder>/<section heading>.png`. Then we review it together, slice it
(`tools/slice_sheets.py`, which A.1 builds), stage it into `game/assets/` and give every file a
row in `game/assets/LICENCES.md`.

This top part is **A.0, the art direction**: the style, the palette and the rules every prompt
below repeats. Approved by the owner 2026-10-26.

---

## How to use this file

1. Copy one section's fenced prompt block, the whole block. Each block is self-contained,
   because Gemini keeps nothing between prompts.
2. Save Gemini's output as `art_src/<folder>/<section heading>.png` (the folder is in the
   section's first line). Keep the PNG Gemini gives you; never re-save it as JPEG.
3. We review it against "After a sheet comes back" (at the end), then slice.

**Regenerate the whole sheet, never one cell.** A re-rolled cell comes back in a slightly
different light, and a sheet with one cell lit differently is worse than a sheet with one weak
cell.

**Batches (owner, 2026-10-27).** Gemini Pro runs up to 5 generations at once with no daily
limit, so a section can say "run ×3". Save the runs as `<section>_1`, `<section>_2`, and so
on, and we review them together. We pick the best **whole** sheet and borrow a cell from
another run only when it clearly matches that sheet's light and line weight.

### The canvas contract, identical for every sheet

- **1024 × 1024 px**: a 4 × 4 grid of 256 px cells.
- **The bottom-right cell stays empty** (flat background, no artwork). Gemini stamps its
  watermark there, so a sheet has **15 usable cells**.
- **A flat background**: no gradient, no vignette, no texture, no grid lines, no borders.
  - **Pure black `#000000`** for icons and UI chrome.
  - **Chroma green `#00FF00`** for anything that may contain black: ship parts, station
    exteriors, asteroids and portraits.
- **No text anywhere.** Every prompt says so twice, because Gemini labels anything that looks
  like a chart.
- **No glows, flames, beams, shield bubbles or explosions.** A glow on a flat background can't be
  keyed out cleanly. The game draws all of those itself with shaders and particles.
- **One chrome piece per canvas** (panels, frames). On a shared sheet the corners never line up
  with the edges.

---

## The style (A.0)

> **MSS is a clean, readable space shooter: flat top-down ships built from crisp panelled tiles
> fly over deep blue space, framed by glossy gold-and-orange painted chrome on dark riveted
> steel, all lit from the upper left. Anything that glows is drawn by the game, never painted.**

It comes from the owner's references (`insperationPictures/`, kept out of the repo): "Menu
Theme" for the chrome, "Ship" and "Hangar" for the ships, and "Character styles" for how moods
and recolouring work (not for the portrait style).

The art comes in four tiers. Each prompt says which tier it belongs to.

| Tier | What | How it looks |
|---|---|---|
| **World** | Tile materials, thrusters, weapons, asteroids | Strictly top-down and orthographic. Clean, flat-shaded panels with crisp edges and a little bevel. Readable at 32 px on a phone. No perspective, no cast shadows. |
| **Chrome and icons** | Panels, buttons, frames, bars, icons, map icons | **Flashy arcade** (owner, 2026-10-27): a rich, glossy painted mobile-game finish, like "Menu Theme". Bold saturated gold and orange rims with hot highlights, chunky bevels, chamfered corners, rows of small LED dots in the rims, dark warm fields, riveted steel brackets, light from the upper left. Loud, not tasteful. **NOT** pixel art, **NOT** flat vector. |
| **Portraits** | The player bases and the NPCs | The highest quality in the game: detailed, semi-realistic painted busts, head and shoulders, soft rim light. They appear only in menus and dialogs. |
| **Backdrops** | Arena backgrounds, station backdrops and interiors, the splash | Painted, darker and lower in contrast than everything on top of them, so ships and UI always read against them. |

### House rules, in every prompt that could break them

- **Original designs only.** No ship, station, logo, emblem or character that resembles a film,
  TV or game franchise: no X-wings, TIE fighters, Star Destroyers, the Enterprise, Vipers or
  Halo-style armour. The first splash broke this rule and has to be regenerated (A.11).
- **No green in artwork on a chroma-green sheet**, because it would be keyed out with the
  background. Lights and trims on those sheets use cyan or amber instead.
- **World art faces right.** A ship's forward is +X in the game, so a core's canopy, a gun's
  barrel and a thruster's nozzle-out direction are described for each sheet in those terms.
- **World materials are greyscale.** The game tints them with the player's paint colour, so
  colour painted into them would fight the paint.

---

## Palette, quoted in every prompt

The chrome colours were sampled from "Menu Theme"; the gameplay accents are what the running
game already draws with (`data/visuals.json`, `pickup_field.gd`).

### Chrome

| Role | Hex |
|---|---|
| Gold highlight | `#F3CD37` |
| Gold mid | `#EAA50D` |
| Orange shadow | `#A76711` |
| Bronze deep | `#5F3514` |
| Panel field (dark warm) | `#24100A` |
| Steel light | `#C3CAD2` |
| Steel mid | `#7A838D` |
| Steel dark | `#343B44` |
| Text cream | `#FFF1D0` |

### Action buttons

| Role | Highlight | Dark |
|---|---|---|
| Go / confirm (green) | `#8FC03E` | `#2F5E1E` |
| Danger / cost (red) | `#E0452A` | `#770F12` |

### Space and backdrops

| Role | Hex |
|---|---|
| Deep space | `#020B15` |
| Space navy | `#062448` |
| Nebula blue | `#0D3768` |
| Hangar teal | `#1F3332` |

### Gameplay accents (icons and HUD)

| Role | Hex |
|---|---|
| Hull (resource) | `#C7CCD6` |
| Alloy (resource) | `#8CADD9` |
| Crystal (resource) | `#73F2FF` |
| Tech (resource, drawn as wires) | `#80FF66` |
| GC (credits) | `#FFCC40` |
| Shield / auto / friendly | `#5AD0FF` |
| Manual / warning | `#FFB040` |
| Enemy / damage | `#FF4A3D` |

### Portrait key hues (A.7)

The player bases are painted with these four regions in **key hues**, which appear nowhere else
in the portrait (not in the skin, the eyes' whites or the background). A shader swaps each hue
band for the colour the player picked and keeps the shading. Each hue is far from skin tones
(about 15°–45°) and from the chroma-green background (120°).

| Region | Key hue |
|---|---|
| Hair | magenta `#FF00C8` |
| Eyes (iris) | cyan `#00E5FF` |
| Outfit | blue `#2450FF` |
| Outfit trim | yellow `#FFE600` |

---

## The sheets

| # | Section | Folder | Cells | Status |
|---|---|---|---|---|
| A.1 | `tiles_materials` | `art_src/tiles/` | 15 | ✅ in the game 2026-10-26: hull, armour, hardpoint |
| A.1b | `tiles_cores_shields` | `art_src/tiles/` | 12 | ✅ in the game 2026-10-26: core, shields, damage |
| A.2 | `parts_thrusters` | `art_src/parts/` | 12 | ✅ in the game 2026-10-27: a nozzle per type |
| A.3 | `parts_guns` | `art_src/parts/` | 12, run ×3 | ✅ in the game 2026-10-27: 9 gun heads (A.3b re-rolled flak and seeker) |
| A.3c | `parts_guns_edge` | `art_src/parts/` | edit of `ref_turrets.png`, run ×3 | ✅ in the game 2026-10-27: fixed and swivel pictures (v1 failed ×5) |
| A.3d | `fx_mines` | `art_src/parts/` | 4, run ×3 | ✅ in the game 2026-10-27: run 1 #2 |
| A.4 | `icons_main` | `art_src/icons/` | 15, run ×3 | ✅ in the game 2026-10-27: pickups, FIRE, SWITCH, Pause |
| A.5 | `chrome_panel`, `chrome_header`, `chrome_frame`, `chrome_buttons` | `art_src/ui/` | 3 canvases + 1 sheet | ✅ in the game 2026-10-27: UiTheme |
| A.6 | `icons_map` | `art_src/icons/` | 1 sheet | to write |
| A.7 | `portraits_players`: 4 sheets (man, woman × jacket, suit), 2 stand-ins (villain, ally), then NPC sheets | `art_src/portraits/` | 4 × 4 cells, then ~3 sheets | generated 2026-10-27: all 6 sheets in, to cut |
| A.8 | `station_*` | `art_src/stations/` | ~25 canvases | to write |
| A.9 | `backdrop_arena_*` | `art_src/backgrounds/` | 5 canvases | to write |
| A.10 | `world_asteroids` | `art_src/parts/` | 1 sheet | to write |
| A.11 | `splash`, `app_icon`, `title` | `art_src/backgrounds/`, `art_src/icons/` | 3 canvases | to write |

---

## tiles_materials

**A.1: 15 cells. Save it as `art_src/tiles/tiles_materials.png`.**

The ship tiles are textures, not sprites (PLAN.md §6.2). Tile shapes are any polygon (square,
rect, triangle, hex, wedge), so Gemini paints **materials**, and the ship shader cuts them to
shape, multiplies them by the paint colour, draws the bevelled outline and darkens them with
damage. There are three variants of each, so a big ship doesn't look stamped.

| Cells | Tile | What sells it |
|---|---|---|
| 1–3 | Hull | Plain plating: the cheap, common tile |
| 4–6 | Armour | Thick, heavy, bolted plate: obviously tougher than hull |
| 7–9 | Shield | An emitter grid. Its bright lines become the untinted glow trim. |
| 10–12 | Hardpoint | A reinforced mounting deck: rails and bolt rings, where guns and thrusters attach |
| 13–15 | Core | The cockpit module seen from above, canopy facing right (the ship's forward) |

```
A 1024x1024 sprite sheet of 15 square greyscale surface textures for a top-down 2D
spaceship building game, arranged on a strict 4x4 grid of 256x256 cells. The
bottom-right cell is completely empty, flat black.

STYLE: clean, crisp sci-fi hull panelling seen from DIRECTLY ABOVE, perfectly flat
and orthographic, like the top surface of a starship in a top-down space game. Flat
shading with a little bevel on panel edges, light from the upper left, fine readable
detail that still reads when shrunk to 32 pixels. NOT perspective, NOT isometric,
NOT a photo, NOT pixel art. No cast shadows.

COLOUR: STRICTLY GREYSCALE. No colour at all, no tint, no hue. Mostly light-to-mid
greys (around 55% to 80% brightness) so the game can tint them with paint colours;
dark greys only in seams and recesses; pure white only where noted.

COMPOSITION: each texture is a square swatch filling its whole cell, with a thin
flat black gap of about 8 pixels between neighbouring cells. Textures 1 to 12 are
seamless: each one's left edge continues into its right edge and its top edge
into its bottom edge, with no frame, no border and no vignette at the edges. All
15 cells share the same lighting, scale of detail and level of finish.

BACKGROUND: flat pure black #000000 in the gaps and in the empty bottom-right cell.
No gradient, no grid lines drawn over the art, no borders or frames.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no logos, no
emblems, no insignia.

The 15 textures, left to right, top to bottom:
1. Hull plating: a few large rectangular panels with thin dark seams and small
   rivets along the seams.
2. Hull plating: smaller staggered panels with one or two narrow vent slots.
3. Hull plating: panels with a recessed access hatch and a short band of diagonal
   hazard stripes in light and dark grey.
4. Armour plate: thick heavy slabs with deep bevelled edges and large hex bolts at
   the corners, a few scratches and dents.
5. Armour plate: overlapping layered plates like scales, chunky and solid.
6. Armour plate: a single massive reinforced slab with raised ribs and heavy bolts.
7. Shield emitter grid: a dark-grey hexagonal lattice of small round emitter nodes
   joined by thin lines; the lines and nodes are pure white #FFFFFF.
8. Shield emitter grid: parallel rows of short emitter bars with pure white
   #FFFFFF emitter strips, on dark-grey plating.
9. Shield emitter grid: concentric diamond pattern of thin pure white #FFFFFF
   conductor lines on dark-grey plating.
10. Hardpoint deck: heavy plating crossed by two parallel mounting rails, with bolt
    circles between them.
11. Hardpoint deck: a large central bolt ring (a mount socket) on reinforced plate,
    with smaller bolt rings around it.
12. Hardpoint deck: a grid of square mount sockets with clamps, on reinforced plate.
13. Cockpit module seen from above: a round armoured module centred in the cell,
    filling about 70% of it, with a dark smoked-glass canopy on its RIGHT side
    pointing right; one pure white #FFFFFF highlight on the glass. Hull plating
    around it fills the rest of the cell.
14. The same cockpit module design, a heavier variant: thicker armoured ring, a
    narrower slit canopy pointing right.
15. The same cockpit module design, a sleeker variant: a larger teardrop canopy
    pointing right, with fine sensor details on the ring.

Remember: no text, no labels, no colour, and the bottom-right cell is empty.
```

**What happens to it.** The slicer cuts each cell inside the gaps. It makes cells 1–12
seamless if Gemini didn't quite (cross-fading the edges), and writes each one as a greyscale
PNG. Its pure-white areas become the "untinted trim" mask in the G channel (PLAN.md §6.2), so
shield lines glow in their own colour whatever the paint. The core cells are sampled in the
tile's own UVs, so the canopy appears once per core whatever its size (§8, A.1 ⚠️).

### Review, 2026-10-26: what came back

A strong sheet, and a usable one. Measured:
- The black gutters sit exactly on the 256 px lattice: 8 px, centred on each cell line.
- It's greyscale: mean saturation is about 1 out of 255, which is JPEG noise.
- Brightness averages about 70%, right for tinting.
- Most cells are already nearly seamless: the edge mismatch is under 6 grey levels in 9 of 15.

**But Gemini ignored the numbered list.** It drew 15 generic panel textures: no cockpit cores, no
pure-white shield lines, and two cells with tiny digit-like markings. Asking for 15 different
items one by one is the usual failure. Asking **row by row, one kind per row** is what
`tiles_cores_shields` does instead.

The sheet is kept as the material library, picked by look:

| Tile | Cells | Why |
|---|---|---|
| Hull | 1, 2, 11 | Plain riveted plates, hatches, fine panel lines: light and cheap-looking |
| Armour | 5, 9, 14 | Thick bevelled blocks and bolted angled slabs: obviously heavier |
| Hardpoint | 4, 10, 12 | Vent grilles, bolt rings (mount sockets), sockets and clamps |
| Shield | 7 | The hex cells, a stand-in until `tiles_cores_shields` brings white emitter lines |
| Spare | 3, 6, 8, 13, 15 | 8 is grimy (a damaged-hull look, maybe later); 13 (pipes) isn't seamless; 15 has digit-like markings |

---

## tiles_cores_shields

**A.1b: 12 cells, rows 1–3; row 4 stays empty. Save it as
`art_src/tiles/tiles_cores_shields.png`.**

What `tiles_materials` didn't deliver, asked for **one kind per row**:
- **Row 1, the cores:** a cockpit module drawn once per tile, in the tile's own UVs.
- **Row 2, the shields:** emitter grids whose pure-white lines become the untinted glow trim.
- **Row 3, damage overlays:** dark marks on pure white, multiplied over a tile as it's hurt. White
  multiplies to "no change", so no keying is needed.

The style and lighting words are copied from `tiles_materials` so the two sheets match.

```
A 1024x1024 sprite sheet for a top-down 2D spaceship building game, arranged on a
strict 4x4 grid of 256x256 cells with a thin flat black gap of about 8 pixels
between neighbouring cells. Rows 1 to 3 are filled, 4 cells each. ROW 4 IS
COMPLETELY EMPTY, flat black.

STYLE: clean, crisp sci-fi hull panelling seen from DIRECTLY ABOVE, perfectly flat
and orthographic, like the top surface of a starship in a top-down space game. Flat
shading with a little bevel on panel edges, light from the upper left, fine readable
detail that still reads when shrunk to 32 pixels. NOT perspective, NOT isometric,
NOT a photo, NOT pixel art. No cast shadows.

COLOUR: STRICTLY GREYSCALE. No colour at all, no tint, no hue. Light-to-mid greys
(around 55% to 80% brightness), dark greys only in seams and recesses.

EACH ROW IS ONE KIND OF THING:

ROW 1, four cells: FOUR COCKPIT MODULES seen from directly above, one per cell.
Each is a round armoured module centred in its cell, filling about 75% of it, with
a dark smoked-glass canopy on its RIGHT side pointing RIGHT, and one small pure
white #FFFFFF highlight on the glass. The corners of the cell around the module
are plain hull plating. Four variants of one design family: a standard canopy, a
narrow slit canopy behind a thick armour ring, a large teardrop canopy, and a
twin canopy with two small windows. Every canopy points right.

ROW 2, four cells: FOUR SHIELD EMITTER GRIDS, each a seamless texture filling its
cell (left edge continues into right edge, top into bottom). Dark-grey plating
crossed by thin PURE WHITE #FFFFFF lines, the white being the only very bright
thing in the texture: a hexagonal lattice of white lines with small white nodes;
parallel rows of short white emitter bars; concentric white diamonds; a white
circuit-trace pattern of right angles.

ROW 3, four cells: FOUR DAMAGE OVERLAYS on a PURE WHITE #FFFFFF background
filling each cell: dark grey and black marks only, as if painted onto white paper.
Light scratches and small dents; deeper gouges and cracks; a scorch mark with
bullet holes; heavy torn and buckled damage with large cracks. Increasing damage
from left to right. The white is plain and flat everywhere there is no mark.

ROW 4: completely empty, flat black.

BACKGROUND: flat pure black #000000 in the gaps between cells and in row 4. No
gradient, no grid lines drawn over the art, no borders or frames.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no digits, no
logos, no emblems, no insignia, no readouts.

Remember: no text, no colour, every canopy points right, and row 4 is empty.
```

**What happens to it.**
- **Row 1** is cut out by the module's outline and sampled in the tile's own UVs.
- **Row 2's** white becomes the G-channel trim mask, exactly as the first sheet's plan
  described.
- **Row 3's** overlays are multiplied over a tile as its HP falls, after the shader's darkening:
  light marks at 75% HP, heavy ones at 25%.

### Review, 2026-10-26: what came back

Exactly what was asked, row by row, so asking one kind per row worked.
- **Cores:** all four came back the same design. It's a good one, so one core is used for every
  variant; it's keyed off the black and composited over `hull_a`.
- **Shields:** three of the four are used. Cell 2 has a frame round it, so it can't tile.
- **Damage:** all four are used, one per wear step.

Cut and packed by `tools/slice_sheets.py` (cells and kinds in `art_src/sheets.json`). See it
with `tools/preview.sh res://dev_preview/art_tiles.tscn 1800x700 --ship=gunboat --zoom=2.2`.

---

## parts_thrusters

**A.2: 12 cells, rows 1–3; row 4 stays empty. Save it as `art_src/parts/parts_thrusters.png`.**

The nozzles currently borrow a ribbed panel, tinted per type. This sheet gives each type its
own part, **one type per row** (the A.1b lesson), with four variants per row to pick from.

**Why not 9 cells (type × S/M/L):** a nozzle is the same shape at every size. It covers
0.25 / 0.5 / 1 U of a hardpoint edge and sticks out half that (`Mounting.nozzle()`: a
trapezoid that narrows by 15% each side away from the hull). A Small one is 16 × 8 px at
rest zoom, so a separate Small drawing would never be seen. Size is geometry, not art.

Its shape is fixed by that trapezoid. **The exhaust points right** (house rule), so the edge it
bolts to runs up and down: a nozzle is **twice as tall as it is long**, full height at the
flange on the left, about 70% at the mouth on the right.

| Row | Type | What sells it (§4.3) |
|---|---|---|
| 1 | Pulse | Cheap, blocky, industrial: a thumper that kicks every half second |
| 2 | Jet | Hot and mechanical: a ribbed combustion nozzle with petal flaps |
| 3 | Ion | The best: smooth, precise, wrapped in coils |

```
A 1024x1024 sprite sheet of spaceship thruster nozzles for a top-down 2D spaceship
building game, arranged on a strict 4x4 grid of 256x256 cells. Rows 1 to 3 are
filled, 4 cells each, one nozzle per cell, centred in its cell. ROW 4 IS
COMPLETELY EMPTY, flat chroma green.

BACKGROUND: flat pure chroma green #00FF00 everywhere there is no artwork: around
every nozzle, between the nozzles and in all of row 4. No gradient, no shadow on
the background, no grid lines, no borders or frames.

STYLE: clean, crisp sci-fi machinery seen from DIRECTLY ABOVE, perfectly flat and
orthographic, like an engine part bolted to the edge of a starship in a top-down
space game. Flat shading with a little bevel on edges, light from the upper left,
fine readable detail that still reads when shrunk to 32 pixels. NOT perspective,
NOT isometric, NOT a 3D render, NOT a photo, NOT pixel art. No cast shadows.

COLOUR: STRICTLY GREYSCALE. No colour at all, no tint, no hue, and NO GREEN
anywhere in the artwork. Light-to-mid greys (around 55% to 80% brightness); dark
greys and black only in recesses and inside the nozzle mouth. Each nozzle has
exactly ONE thin band of PURE WHITE #FFFFFF running across its body from top to
bottom, like a painted trim ring; nothing else on it is pure white.

EVERY NOZZLE HAS THE SAME SHAPE AND FACING. It lies flat, seen from above, with
its exhaust pointing RIGHT, so we see its outline side-on:
- It is TALL AND NARROW: about 230 pixels tall and 115 pixels wide, twice as tall
  as it is wide.
- Its LEFT side is a flat, straight mounting flange running its full height,
  where it bolts onto the ship.
- It narrows evenly towards the RIGHT. Its right end, the nozzle mouth, is about
  70% as tall as the flange.
- The mouth is a dark opening with a bevelled rim. NO flame, NO glow, NO exhaust,
  NO light coming out of it.

EACH ROW IS ONE TYPE OF THRUSTER, four variants of one design family per row:

ROW 1, four cells: PULSE THRUSTERS. Chunky and blocky: a heavy squared-off
housing with thick riveted reinforcing bands and a short square mouth with a row
of small round vent ports, like an industrial piston thumper. The cheapest,
toughest-looking engine.

ROW 2, four cells: JET THRUSTERS. A combustion engine: the housing tapers in
clear stacked segments with ribbed cooling fins, into a mouth ringed by
overlapping petal-shaped nozzle flaps. Mechanical and powerful.

ROW 3, four cells: ION THRUSTERS. A high-tech drive: a smooth rounded housing
wrapped in two or three raised magnetic coil bands, ending in a mouth covered by
a fine grid of tiny holes. Sleek, precise, the most advanced engine.

The three rows must be easy to tell apart at a glance by shape alone: pulse is
blocky and square, jet is ribbed with petal flaps, ion is smooth and coiled.

ROW 4: completely empty, flat chroma green.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no digits, no
logos, no emblems, no insignia, no warning signs.

Original designs only: nothing resembling a thruster or ship from any film, TV
show or game.

Remember: no text, no colour, no green in the art, no flames or glow, every
exhaust points right, and row 4 is empty.
```

**What happens to it.**
- The slicer keys off the green (flood-filled from the border, as `keyed` does with black;
  the green key gets added when the sheet arrives) and keeps the cut-out as a coverage mask,
  so the nozzle is drawn with the art's own silhouette, not a plain trapezoid.
- The best variant of each type goes into the thruster column of `tile_atlas.png`, **one type
  per variant row** (pulse, jet, ion), in place of `ribs`. No new texture, so the ship stays one
  draw call.
- The game samples it in the **nozzle's own frame**: across from the flange to the mouth, and
  along the edge. So it turns with the mount, and the same picture serves S, M and L.
- The white band becomes the trim mask (G), coloured **by level** (L1–3, §8 A.2) in place of
  today's whole-nozzle type tint. Type then reads from the shape.

### Review, 2026-10-27: what came back

Right on the first try where it mattered: three rows that read as three types at a glance,
greyscale, no glow, every exhaust pointing right, and most cells with the white band.
- **Gemini ignored the proportions.** It drew each nozzle about as long as it is tall,
  filling the cell, not half as long. Squashed to the game's 2:1 they still read, because the
  slicer stretches a part over its whole cell anyway. **Pixel sizes in a prompt are ignored;
  the cell's shape wins.** If a later part needs a set proportion, ask for it relative to
  something drawn in the same cell.
- It ruled thin dark grid lines on the cell borders. The `part` cut treats a 3 px border as
  background.
- **Used:** pulse 2 (vent ports and a white band; 1 has no band), jet 7, ion 11 (the hole grid).
  The rest are spares in the master.

Seen with `tools/preview.sh res://scenes/debug/thruster_fx_showcase.tscn 1560x720 --frames=45`
(every type × size × level) and `art_tiles.tscn --ship=meteor` (ion) or `--ship=harrier` (jet).

---

## parts_guns

**A.3: 12 cells, rows 1–3; row 4 stays empty. Run ×3. Save them as
`art_src/parts/parts_guns_1.png`, `_2`, `_3`.**

Guns are drawn in code today (`GunView`): a grey disc or block with dark bars for barrels. Each
gun type gets one picture here, a **gun head**: the round housing with its barrels, seen from
above and pointing right. The game turns the whole head about the housing's centre, which
is what "base and barrel as separate cells" was for: one picture turning is simpler and looks
better. On an edge mount (fixed, swivel) the same head sits on the mounting block, so one
picture serves all three mounts.

**Why the proportions are relative:** Gemini ignored pixel sizes on the thruster sheet but
fills the cell. So this prompt sizes the barrel against the housing drawn in the same cell
("about a quarter as thick as the housing"), and the slicer finds the housing's centre itself.

| Row | Family | Cells |
|---|---|---|
| 1 | Kinetic | gatling, multi gatling, cannon, flak |
| 2 | Explosive | rocket pod (fire and forget), seeker pod (homing), mine dropper, spare rocket pod |
| 3 | Energy | laser, EMP, spare laser, spare EMP |

HE and AP rockets share a launcher. The white band is the trim mask, so the warhead (or a
level tier) can colour it.

```
A 1024x1024 sprite sheet of spaceship gun turrets for a top-down 2D spaceship
building game, arranged on a strict 4x4 grid of 256x256 cells. Rows 1 to 3 are
filled, 4 cells each, one gun per cell, centred in its cell. ROW 4 IS COMPLETELY
EMPTY, flat chroma green.

BACKGROUND: flat pure chroma green #00FF00 everywhere there is no artwork: around
every gun, between the guns and in all of row 4. No gradient, no shadow on the
background, no grid lines, no borders or frames.

STYLE: clean, crisp sci-fi machinery seen from DIRECTLY ABOVE, perfectly flat and
orthographic, like a gun turret on the deck of a starship in a top-down space
game. Flat shading with a little bevel on edges, light from the upper left, fine
readable detail that still reads when shrunk to 32 pixels. NOT perspective, NOT
isometric, NOT a 3D render, NOT a photo, NOT pixel art. No cast shadows.

COLOUR: STRICTLY GREYSCALE. No colour at all, no tint, no hue, and NO GREEN
anywhere in the artwork. Light-to-mid greys (around 55% to 80% brightness); dark
greys and black only in recesses, barrel bores and tube mouths. Each gun has
exactly ONE thin band of PURE WHITE #FFFFFF, a trim ring around its round
housing; nothing else on it is pure white.

EVERY GUN HAS THE SAME LAYOUT AND FACING, seen from above, pointing RIGHT:
- A ROUND armoured housing, a circle seen from above, sits in the LEFT half of
  the cell. Its diameter is about 40% of the cell.
- The barrel or barrels come out of the RIGHT side of the housing and point
  straight RIGHT, reaching almost to the right edge of the cell.
- The gun is symmetric about the horizontal line through the housing's centre.
- NO muzzle flash, NO glow, NO beam, NO smoke, NO projectiles.

EACH ROW IS ONE FAMILY OF GUNS, four different guns per row:

ROW 1, four cells: KINETIC GUNS.
1. Gatling: one long barrel, about a quarter as thick as the housing, with a
   ribbed cooling jacket.
2. Multi gatling: a rotary cluster of three thin barrels side by side, bound
   together by two rings.
3. Cannon: one very thick, long barrel, about half as thick as the housing, with
   a slotted muzzle brake at its tip. The heaviest-looking gun.
4. Flak: two short, wide barrels side by side with flared mouths, like a
   double-barrelled shotgun.

ROW 2, four cells: MISSILE LAUNCHERS AND MINES.
5. Rocket pod: a boxy launcher on the housing with two open launch tubes side by
   side, their dark round mouths facing right.
6. Seeker pod: a slimmer launcher with three small tubes and a small round
   sensor dome on top.
7. Mine dropper: a squat armoured box with a wide rectangular hatch facing right
   and a round spiked mine half out of it.
8. Rocket pod, heavy: a launcher with four small tubes in a two-by-two block.

ROW 3, four cells: ENERGY WEAPONS.
9. Laser: a long, slim emitter with rows of cooling fins, ending in a dark
   smoked-glass lens. The lens does NOT glow.
10. EMP projector: a short, stubby emitter wrapped in coil rings, ending in a
   shallow dish with three prongs.
11. Laser, twin rail: two parallel slim rails with a dark lens between their tips.
12. EMP projector, ring: a large ring coil held in front of the housing by two
   short struts.

The three rows must be easy to tell apart at a glance: row 1 has gun barrels,
row 2 has launch tubes and boxes, row 3 has fins, coils and lenses.

ROW 4: completely empty, flat chroma green.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no digits, no
logos, no emblems, no insignia, no warning signs.

Original designs only: nothing resembling a weapon or ship from any film, TV
show or game.

Remember: no text, no colour, no green in the art, no flash or glow, every gun
points right, and row 4 is empty.
```

**What happens to it.**
- Each gun is cut as a `gun` (keyed off green like a `part`). The slicer finds the housing's
  centre from the art's left edge and places it at a fixed **pivot** in the cell, scaled so the
  **barrel tip** lands at a fixed x.
- `GunView` draws the head turning about the pivot, scaled so the tip meets the weapon's
  muzzle (data), and tints the trim band per weapon. Gameplay doesn't move.
- Guns sit above the hull and turn, so they stay one canvas item per ship, drawn from
  `assets/parts/gun_atlas.png`.

### Review, 2026-10-27: what came back

Three good runs, all on brief, with more liked designs than weapons. The owner picked
favourites; the leftovers are catalogued as `spares` in `art_src/sheets.json` for v2's faction
arsenals (PLAN.md §9).
- **Used:** gatling, multi gatling (triple), cannon, flak, seeker, mines, laser and EMP from
  run 2 (#1, 2, 3, 4, 6, 7, 9, 10), and the rocket pod from run 1 (#8). HE and AP share a launcher;
  the trim is red for HE and amber for AP.
- **Barrels came out short:** about 2 housing radii, against the data's 2.2–3.7. Fitting the
  tip to the muzzle makes the housings a little bigger than `turret_radius_u`, which reads fine.
- **Run 3 doesn't fit.** Its housings fill the cell (r 110 px against about 75), so its barrels end
  1.1 r out; fitted to a muzzle, the disc would be wider than a tile. The owner's run-3 picks
  (flak #4, seeker #6) need a re-roll with the gun drawn smaller on its housing. Run 2's
  versions stand in until then.

---

## parts_guns_flak_seeker

**A.3b: 8 cells, rows 1–2; rows 3–4 stay empty. Run ×3. Save them as
`art_src/parts/parts_guns_flak_seeker_1.png`, `_2`, `_3`.**

The re-roll for the owner's two run-3 favourites, the twin flared flak and the triple finned
seeker, at run 2's proportions: a small housing and long barrels. The words are the same as
`parts_guns`, except for the stronger proportion rules, which are given relative to the
housing.

```
A 1024x1024 sprite sheet of spaceship gun turrets for a top-down 2D spaceship
building game, arranged on a strict 4x4 grid of 256x256 cells. Rows 1 and 2 are
filled, 4 cells each, one gun per cell, centred in its cell. ROWS 3 AND 4 ARE
COMPLETELY EMPTY, flat chroma green.

BACKGROUND: flat pure chroma green #00FF00 everywhere there is no artwork: around
every gun, between the guns and in all of rows 3 and 4. No gradient, no shadow on
the background, no grid lines, no borders or frames.

STYLE: clean, crisp sci-fi machinery seen from DIRECTLY ABOVE, perfectly flat and
orthographic, like a gun turret on the deck of a starship in a top-down space
game. Flat shading with a little bevel on edges, light from the upper left, a
thin dark outline, fine readable detail that still reads when shrunk to 32
pixels. NOT perspective, NOT isometric, NOT a 3D render, NOT a photo, NOT pixel
art. No cast shadows.

COLOUR: STRICTLY GREYSCALE. No colour at all, no tint, no hue, and NO GREEN
anywhere in the artwork. Light-to-mid greys (around 55% to 80% brightness); dark
greys and black only in recesses, barrel bores and tube mouths. Each gun has
exactly ONE thin band of PURE WHITE #FFFFFF, a trim ring around its round
housing; nothing else on it is pure white.

EVERY GUN HAS THE SAME LAYOUT AND FACING, seen from above, pointing RIGHT:
- A SMALL ROUND armoured housing, a circle seen from above, at the LEFT of the
  cell. Its diameter is only about one third of the cell.
- The gun on top of it is LONGER THAN THE HOUSING IS WIDE: the barrels or
  missiles reach out to the right about twice the housing's width beyond it,
  almost to the right edge of the cell.
- The gun is symmetric about the horizontal line through the housing's centre.
- NO muzzle flash, NO glow, NO smoke, NO exhaust, NO projectiles in flight.

ROW 1, four cells: FOUR FLAK CANNONS, variants of one design: two thick, short
cannon bodies side by side on the housing, each ending in a long barrel with a
wide flared bell mouth, like a double-barrelled shotgun.

ROW 2, four cells: FOUR SEEKER MISSILE LAUNCHERS, variants of one design: a box
launcher on the housing holding three pointed missiles side by side on rails,
each with small tail fins, their noses pointing right.

ROWS 3 AND 4: completely empty, flat chroma green.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no digits, no
logos, no emblems, no insignia, no warning signs.

Original designs only: nothing resembling a weapon or ship from any film, TV
show or game.

Remember: no text, no colour, no green in the art, a SMALL housing with a LONG
gun, every gun points right, and rows 3 and 4 are empty.
```

**What happens to it.** The best flak and seeker are cut as `gun` cells in place of run 2's,
with no code change.

### Review, 2026-10-27: what came back

- **Run 1** did exactly what was asked (small housings, long guns), but it's plainer than the
  first sheets. **Its seeker (#6) is used.**
- **Run 3** is the owner's favourite and the most detailed, but its housings are still big
  (tip 1.4–1.6 r). **Its flak (#1) is used:** its disc comes out 1.09 U, a little wider than its
  tile, which suits a heavy gun. Its seekers are drawn angled up-right, about 10° off their line
  of fire, so they're spares.
- **Run 2** is pixel art on square bases: off-style, unused.
- Asking for proportions relative to the housing worked in one run of three. Running ×3 is
  what made it pay.

---

## parts_guns_edge

**A.3c: an image edit. Upload `art_src/parts/ref_turrets.png` to Gemini with the prompt below.
Run ×3. Save them as `art_src/parts/parts_guns_edge_v2_1.png`, `_2`, `_3`.**

Side-mounted guns (fixed and swivel, on a hardpoint's edge) get their own picture (owner,
2026-10-27). Until now they borrowed the turret's round housing, so a side gun and a turret
looked the same in the hangar. A side gun is **the same gun on a flat bracket bolted to the
hull edge**, with no round base. The game turns a swivel about the middle of the bracket's flat
side, where it meets the hull.

`ref_turrets.png` is the nine turret heads in use, in their atlas order (row 1: gatling, multi
gatling, cannon, flak; row 2: rocket pod, seeker, mine dropper; row 3: laser, EMP), built from
the masters by hand. **Gemini redraws those guns**, so each side gun matches its turret.

```
This image is a sprite sheet of nine top-down spaceship gun turrets on a chroma
green background, seen from directly above, each pointing right and sitting on a
round turret base.

Redraw this SAME sheet: the same nine guns in the same cells, the same order,
size and position, the same style, line weight, greyscale shading and light from
the upper left. Change ONE thing on every gun:

REMOVE the round turret base disc under the gun completely. Instead, the gun is
mounted on a flat rectangular MOUNTING BRACKET at the far LEFT of its cell:
- the bracket's LEFT SIDE is a straight vertical edge, because it bolts flat
  against the side of a spaceship's hull, seen from above;
- the bracket is narrow, about one eighth of the cell wide, and as tall as the
  gun is wide, with a few bolts and ONE thin pure white #FFFFFF stripe across it;
- the gun's back end sits against the bracket's right side.

Keep every gun's barrels, missiles, coils, fins, details and length exactly as in
the original: the gun itself does not change, only its base. Everything is still
seen from DIRECTLY ABOVE, flat and orthographic, pointing RIGHT. NOT a side view,
NOT a handheld weapon: no handles, no grips, no triggers, no stocks.

Keep the empty cells empty. Background stays flat pure chroma green #00FF00,
with no grid lines, no shadows and no glow. Strictly greyscale artwork, no green
in it. No text, no numbers, no letters anywhere.
```

**What happens to it.** Each gun is cut as an `edge_gun`: keyed off green like a `gun`, with
the pivot at the middle of the bracket's flat left side, and fitted so the barrel tip lands at
a fixed x. The gun atlas has a row per mount type (turret, fixed, swivel), and `GunView` draws
each gun from its mount's row, or from the turret row where a cell is empty.

### Review, 2026-10-27: the edit worked

Every run kept the guns and swapped the base, so each side gun matches its turret. And the
runs differed in a useful way:
- **Run 1** dropped the disc for a narrow bracket: **the fixed mounts.** Its mine dropper grew a
  second mine on a chain, off-centre, so it's a spare.
- **Run 2** kept half the disc on a tall bracket, which reads as a pivot: **the swivel mounts**,
  and the fixed mine dropper (mines never swivel). So fixed and swivel are told apart by their
  art, and the planned code-drawn pivot cap wasn't needed.
- **Run 3** is like run 2 on wide plates: bulkier, all spares.

### Review, 2026-10-27: the first prompt failed (×5)

The first version described the guns from scratch, "bolted to the side of a starship". **The
word "side" made Gemini draw side views**: runs 1–3 are profile views of handheld guns with
pistol grips and triggers, partly in perspective. Runs 4 and 5 are top-down on brackets but
plain and blocky, and none matches its turret. The masters (`parts_guns_edge_1`–`5`) are
kept, unused. **Lesson: to get a variant of art we already have, give Gemini that art and ask
for one change**, rather than describing it again.

---

## fx_mines

**A.3d: 4 cells, row 1 only. Run ×3. Save them as `art_src/parts/fx_mines_1.png`, `_2`, `_3`.**

A mine dropped in space (`vis.fx.mine`). Until this lands, it's a spiked disc drawn by
`tools/make_placeholders.py` (owner, 2026-10-27: "mines look like squares" when they were a
streak). The game draws it about 0.6 U across, turning slowly. So it has to read as **a threat at
40 px**, and look the same from every side.

```
A 1024x1024 sprite sheet for a top-down 2D space shooter, arranged on a strict
4x4 grid of 256x256 cells. ONLY ROW 1 is filled, one object per cell, centred in
its cell and filling about 80% of it. ROWS 2, 3 AND 4 ARE COMPLETELY EMPTY, flat
chroma green.

BACKGROUND: flat pure chroma green #00FF00 everywhere there is no artwork. No
gradient, no shadow on the background, no grid lines, no borders or frames.

STYLE: clean, crisp sci-fi machinery seen from DIRECTLY ABOVE, perfectly flat and
orthographic, like an object floating in space in a top-down space game. Flat
shading with a little bevel on edges, light from the upper left, a thin dark
outline, fine readable detail that still reads when shrunk to 40 pixels. NOT
perspective, NOT isometric, NOT a 3D render, NOT a photo, NOT pixel art. No cast
shadows.

ROW 1, four cells: FOUR SPACE MINES, variants of one design. Each is a ROUND
armoured sphere seen from directly above, with six to eight short sharp spikes
pointing outward evenly all round it, so it looks the same from every side. Dark
steel greys, with ONE small round RED #E0452A warning lamp in its centre. The
lamp is painted, NOT glowing: no light spills from it. Variants: plain spikes; a
ring of rivets between the spikes; spikes with small caps; a segmented shell.

COLOUR: greys and the red lamp only. NO GREEN anywhere in the artwork.

ROWS 2, 3 AND 4: completely empty, flat chroma green.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no digits, no
logos, no warning signs, no symbols.

Remember: no text, no green in the art, no glow, round and the same from every
side, and only row 1 is filled.
```

**What happens to it.** The best mine is cut as a colour `sprite` with `{"key": "green"}` and
staged as `assets/fx/mine.png`, which `vis.fx.mine` points at.

### Review, 2026-10-27: what came back

All twelve were on brief: round, spiked, a painted lamp, no glow. **Run 1 #2 is used**: the
spikes give the silhouette at 40 px, and the riveted ring makes it look built. In space it was
too small and too dark at 0.6 U (dark steel on dark space), so the game draws it at 0.8 U and
pulses it brighter 1.5 times a second, like an armed mine. See it with
`tools/preview.sh res://dev_preview/art_mines.tscn 900x300 --frames=20`.

---

## icons_main

**A.4: 15 cells. Run ×2. Save them as `art_src/icons/icons_main_1.png` and `_2`.**

The first icon sheet, chrome-and-icons tier (glossy and painted, on black). It holds only what
has no in-game art to borrow from. **Thruster, weapon and tile-type icons reuse the part art**
(the A.2 nozzles, the A.3 gun heads and the A.1 material swatches, drawn on a chrome frame), so
an icon always looks like the part it stands for, and A.4 needs one sheet instead of two.

| Row | What | Used by |
|---|---|---|
| 1 | Resources: Hull, Alloy, Crystal, Tech | Hangar costs, loot, market (4.6) |
| 2 | HUD symbols: fire, switch weapon, pause, boost | Combat HUD (4.7) |
| 3 | Power-up badges, ×2 to ×5, with an empty centre | WaveTime (8.3); the game writes the number |
| 4 | GC: coin, coin stack, credit chip (pick one) | Prices, wallet |

```
A 1024x1024 sprite sheet of 15 game icons for a mobile space shooter, arranged on a
strict 4x4 grid of 256x256 cells, one icon centred in each cell, each filling about
75% of its cell. The bottom-right cell is completely empty, flat black.

BACKGROUND: flat pure black #000000 everywhere there is no artwork. No gradient,
no vignette, no glow spilling onto the background, no grid lines, no borders, no
frames around the cells.

STYLE: a rich, glossy, painted mobile-game finish: bevelled edges, soft studio
light from the upper left, a crisp bright highlight on each object, a thin dark
outline so each icon reads on any background. NOT pixel art, NOT flat vector,
NOT a photo. Every icon in the same style, light and level of finish. Each icon
is one solid object or symbol with a clean silhouette, readable when shrunk to
48 pixels.

PALETTE (use these colours):
gold highlight #F3CD37, gold mid #EAA50D, orange shadow #A76711, bronze deep
#5F3514, steel light #C3CAD2, steel mid #7A838D, steel dark #343B44, cream
#FFF1D0, hull grey #C7CCD6, alloy blue #8CADD9, crystal cyan #73F2FF, tech green
#80FF66, credits gold #FFCC40, red #E0452A, amber #FFB040.

EACH ROW IS ONE KIND OF ICON:

ROW 1, four cells: FOUR RAW MATERIALS, each a small pile of the material.
1. Hull: a stack of three light grey #C7CCD6 steel plates with rivets.
2. Alloy: two pale blue #8CADD9 metal ingots crossed.
3. Crystal: a cluster of bright cyan #73F2FF crystal shards.
4. Tech: a coiled bundle of bright green #80FF66 wires ending in a small steel
   connector plug.

ROW 2, four cells: FOUR BUTTON SYMBOLS, cream #FFF1D0 with gold #EAA50D bevelled
edges, the symbol only, with NO button, disc or plate behind it.
5. Fire: a targeting crosshair, a circle with four short ticks.
6. Switch weapon: two curved arrows chasing each other round in a circle.
7. Pause: two thick vertical bars.
8. Boost: two bold chevrons pointing right, one behind the other.

ROW 3, four cells: FOUR ROUND POWER-UP BADGES, each a glossy medallion with a
LARGE EMPTY dark centre (a plain flat dark disc filling half the badge, left
blank because the game writes a number there). Increasingly grand from left to
right:
9. A bronze #A76711 ring.
10. A steel #C3CAD2 ring with four small studs.
11. A gold #F3CD37 ring with a laurel of small leaves.
12. A gold ring set with cyan #73F2FF crystals and short sunburst points round
   the outside.

ROW 4, three cells, then the empty bottom-right cell:
13. A single gold #FFCC40 coin seen at a slight angle, embossed with a simple
   four-pointed star.
14. A short stack of the same gold coins.
15. A thin gold credit chip, a rounded rectangle with circuit lines.
16. EMPTY, flat black.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no digits, no
currency symbols, no logos. The badges' centres stay EMPTY.

Remember: no text, no numbers, black background, the badges' centres empty, and
the bottom-right cell is empty.
```

**What happens to it.** The slicer's `sprite` kind keys each icon off black with the flood fill
(so a badge's dark centre survives; `holes` keys enclosed black too, for the crosshair and the
coil) and writes it as its own 128 px PNG in `assets/icons/`. Code asks for `vis.icon.<id>`, which
shares one grey-ring placeholder, and keeps its old text or shapes until `has_real_art()`.

### Review, 2026-10-27: what came back

Three runs, nearly identical and all on brief: no text, empty badge centres, an empty corner.
**Run 2 is used**: it has the brightest Tech green, and its button symbols are all cream (run 3's
are gold). The coin stack and credit chip are spares. In the game: the loot pickups in flight,
FIRE and SWITCH, and the Pause button. Boost and the badges wait for their features (8.3). See
them with `tools/preview.sh res://dev_preview/art_pickups.tscn 1200x300 --frames=5`.

---

## A.5: UI chrome (four prompts, one batch)

**Upload `insperationPictures/Menu Theme.png` with each prompt** as the style reference: handing
Gemini existing art worked for the side guns (A.3c). Every prompt asks for its finish, not its
layout. Save them in `art_src/ui/` as `<section>_1.png`, and so on.

How the game uses them: each piece becomes a **9-slice** `StyleBoxTexture` in one Godot theme. The
corners stay as painted, and the edges and middle stretch, so **the middle of every piece must be
plain and even**, and the corners must sit well inside the canvas. Fields stay empty because the
game writes its own text.

## chrome_panel

**A.5: one canvas. Run ×2.** The big panel behind menus, dialogs and the pause screen.

```
A single empty UI PANEL for a mobile space shooter game, centred on a 1024x1024
canvas and filling about 90% of it: one wide window frame with a thick bevelled
gold-and-orange rim, chamfered corners, riveted steel corner brackets, and a large
plain dark field (#24100A) inside with very faint horizontal scanlines. The field
is EMPTY and EVEN all over, so it can be stretched.

STYLE: FLASHY ARCADE mobile-game UI chrome, a rich glossy painted finish like
the attached reference image: match its finish and colours, NOT its layout, and
copy nothing from it. Bold saturated gold and orange rims with hot white-gold
highlights, chunky bevels, chamfered (cut) corners, a row of small round LED dots
set into the rim, riveted dark steel brackets, light from the upper left. Loud
and shiny, not tasteful. NOT pixel art, NOT flat vector, NOT a photo.

PALETTE: gold highlight #F3CD37, gold mid #EAA50D, orange shadow #A76711, bronze
deep #5F3514, panel field #24100A, steel light #C3CAD2, steel mid #7A838D, steel
dark #343B44.

BACKGROUND: flat pure black #000000 outside the artwork. No gradient, no
vignette, no glow spilling onto the background, no grid lines.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no logos, no
icons, no symbols. The game puts its own text and icons on top.
```

## chrome_header

**A.5: one canvas. Run ×2.** The bar across the top of a screen: a title on the left, the wallet on the right.

```
A single empty UI HEADER BAR for a mobile space shooter game, on a 1024x1024
canvas: one long horizontal bar spanning about 95% of the canvas width and about
20% of its height, centred. A thick bevelled gold-and-orange rim with chamfered
ends, a row of small LED dots along its bottom edge, steel end-caps with rivets,
and a plain dark field (#24100A) inside. The field is EMPTY and EVEN along its
whole length, so the bar can be stretched sideways.

STYLE: FLASHY ARCADE mobile-game UI chrome, a rich glossy painted finish like
the attached reference image: match its finish and colours, NOT its layout, and
copy nothing from it. Bold saturated gold and orange rims with hot white-gold
highlights, chunky bevels, chamfered (cut) corners, a row of small round LED dots
set into the rim, riveted dark steel brackets, light from the upper left. Loud
and shiny, not tasteful. NOT pixel art, NOT flat vector, NOT a photo.

PALETTE: gold highlight #F3CD37, gold mid #EAA50D, orange shadow #A76711, bronze
deep #5F3514, panel field #24100A, steel light #C3CAD2, steel mid #7A838D, steel
dark #343B44.

BACKGROUND: flat pure black #000000 outside the artwork. No gradient, no
vignette, no glow spilling onto the background, no grid lines.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no logos, no
icons, no symbols. The game puts its own text and icons on top.
```

## chrome_frame

**A.5: one canvas. Run ×2.** A card frame round a picture: a portrait, a ship, a station. Its middle is a hole.

```
A single empty UI CARD FRAME for a mobile space shooter game, centred on a
1024x1024 canvas and filling about 85% of it, square: a thick bevelled
gold-and-orange border with chamfered corners and a thin inner steel lip. The
middle of the frame is a large EMPTY HOLE, plain flat pure black #000000, where
the game puts a picture. The border is the same thickness all round.

STYLE: FLASHY ARCADE mobile-game UI chrome, a rich glossy painted finish like
the attached reference image: match its finish and colours, NOT its layout, and
copy nothing from it. Bold saturated gold and orange rims with hot white-gold
highlights, chunky bevels, chamfered (cut) corners, a row of small round LED dots
set into the rim, riveted dark steel brackets, light from the upper left. Loud
and shiny, not tasteful. NOT pixel art, NOT flat vector, NOT a photo.

PALETTE: gold highlight #F3CD37, gold mid #EAA50D, orange shadow #A76711, bronze
deep #5F3514, panel field #24100A, steel light #C3CAD2, steel mid #7A838D, steel
dark #343B44.

BACKGROUND: flat pure black #000000 outside the artwork. No gradient, no
vignette, no glow spilling onto the background, no grid lines.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no logos, no
icons, no symbols. The game puts its own text and icons on top.
```

## chrome_buttons

**A.5: 15 cells. Run ×2.** Buttons in their states, and the bars, **one kind per row**.

```
A 1024x1024 sprite sheet of mobile-game UI widgets for a space shooter, arranged
on a strict 4x4 grid of 256x256 cells, one widget centred in each cell. The
bottom-right cell is completely empty, flat black.

STYLE: FLASHY ARCADE mobile-game UI chrome, a rich glossy painted finish like
the attached reference image: match its finish and colours, NOT its layout, and
copy nothing from it. Bold saturated gold and orange rims with hot white-gold
highlights, chunky bevels, chamfered (cut) corners, a row of small round LED dots
set into the rim, riveted dark steel brackets, light from the upper left. Loud
and shiny, not tasteful. NOT pixel art, NOT flat vector, NOT a photo.

PALETTE: gold highlight #F3CD37, gold mid #EAA50D, orange shadow #A76711, bronze
deep #5F3514, panel field #24100A, steel light #C3CAD2, steel mid #7A838D, steel
dark #343B44.
Go green highlight #8FC03E, green dark #2F5E1E, danger red highlight #E0452A,
red dark #770F12.

EVERY BUTTON is the same shape: a WIDE rounded-and-chamfered rectangle filling
the cell's width and about 40% of its height, with a thick bevelled rim and a
glossy EMPTY face. NO text, NO icon on it.

ROW 1, four cells: ORANGE-GOLD BUTTONS: normal; pressed (pushed in, darker, the
highlight at the bottom); disabled (dull grey-brown, no shine, no LEDs);
selected (brighter, the rim's LED dots lit).

ROW 2, four cells: GREEN "GO" BUTTONS in the same four states, in the greens.

ROW 3, four cells: RED "DANGER" BUTTONS in the same four states, in the reds.

ROW 4, three cells, then the empty bottom-right cell:
13. A progress bar TRACK: a long thin empty dark trough with a steel rim, the
   width of the cell and about 15% of its height.
14. A progress bar FILL: a long thin glossy gold bar the same size, plain and
   even along its length.
15. A ROUND icon button: a glossy gold-rimmed disc with an EMPTY dark face.
16. EMPTY, flat black.

BACKGROUND: flat pure black #000000 outside the artwork. No gradient, no
vignette, no glow spilling onto the background, no grid lines.

ABSOLUTELY NO TEXT of any kind: no labels, no numbers, no letters, no logos, no
icons, no symbols. The game puts its own text and icons on top.

Remember: no text, no icons, empty button faces, one kind per row, and the
bottom-right cell is empty.
```

**What happens to them.** Each piece is keyed off black (the frame's hole with `holes`), the
9-slice margins are measured from the art, and they become one `Theme` (`assets/ui/theme.tres`)
that the menus, dialogs, pause screen and hangar panels use in place of today's flat boxes.

### Review, 2026-10-27: what came back (×3 each)

All twelve were on style. The picks are the ones that survive 9-slicing:
- **Panel run 2**: mirrored corners and evenly spaced LEDs. Run 1's corners differ from each
  other, and run 3 is plainer.
- **Header run 3**: matching end caps. Run 1 came back on white.
- **Frame run 2**: its brackets come in mirrored pairs near the corners. Runs 1 and 3 have one-off
  brackets.
- **Buttons run 1**: the same button in every row, the states clearly apart. Cell 14 is a fill
  drawn inside its track, so the fill is cut as its left part. Run 2 lost the grid in row 4.

In the game, the "selected" state is too close to "normal" to mark a chosen tab, so UiTheme
brightens it (`LIT`). Stretching smeared the rims' LED dots, so the edges tile instead.
The owner's review caught three broken 9-slices: the bar track has steel straps at ~20% and ~80%
of its length, which smeared in the stretched middle (now inside 16 px ends); the fill's crop
ended in the gold-to-dark fade (now cut at 0.6); and a tall menu tile stretched the buttons' side
LEDs (at 34% and 62% of the height) into ovals, so tiles use `TileButton` with `slice_tall`.

---

## portraits_players

**A.7: four sheets of 4 cells, in two steps. Choose the highest output resolution Gemini offers (2K
or 4K): run 1 came back at 1024, which leaves a head crop of only ~110 px. Save them as
`art_src/portraits/portraits_man_jacket_1.png`, and so on.**

The player's two base characters (§6.5), each in two outfits, the flight jacket and a space suit:
**one sheet per character per outfit, its four moods in a 2×2 grid**. Every cell is filled, because
Gemini filled the "empty" rows of the first sheet with extra characters. The framing is **elbow
height, turned three-quarters to the right**, like the owner's visual-novel references: in a
story-mode conversation the picture stands on the bottom edge of the screen with the dialog box
over its lower body, the player on the left and the other speaker mirrored on the right. Menus and
the HUD show a head crop, so **every cell must put the head in the same place at the same size**. They're
painted in the **key hues** (A.0) so the game can recolour hair, eyes, outfit and trim.

**Step 1: the jackets.** Run `portraits_man_jacket` and `portraits_woman_jacket` ×3 each, uploading
`art_src/portraits/ref_man.png` or `ref_woman.png` (run 1's faces) so the face carries over. Leave
the upload out if you'd rather have new faces.
**Step 2: the suits.** Pick the best jacket sheet of each, then run `portraits_man_suit` and
`portraits_woman_suit` ×3 each **as edits of that pick**: upload it and ask for one change, the
outfit. Editing worked for the side guns (A.3c) where a fresh prompt didn't, and it keeps the face,
the pose and the framing, so the head crop is the same in both outfits.

### portraits_man_jacket

```
A square sprite sheet of character portraits for a mobile space shooter game: a
strict 2x2 grid of four equal square cells, all four filled. The SAME man in all
four cells.

The attached picture shows ONLY his face and hair: copy the face, hairstyle and
colouring, but NOT its framing. It is a close-up; this sheet is a much wider
shot that shows his upper body (see FRAMING).

BACKGROUND: flat pure chroma green #00FF00 behind him in every cell. No
gradient, no shadow, no grid lines, no borders.

STYLE: the highest quality in the game. Detailed, semi-realistic painted
portraits, like the hero portraits of a polished mobile game: rich painterly
shading, a soft warm rim light, crisp clean edges against the background. NOT
pixel art, NOT anime, NOT a photo, NOT a 3D render.

THE MAN: a young space pilot in his late twenties with a big, heavily muscled
build: very broad shoulders, a thick neck, a broad powerful chest and big arms
that strain his fitted flight jacket with a high collar. A heroic action-hero
physique.

FRAMING, identical in all four cells: a MEDIUM SHOT of his upper body, like a
character standing at the edge of a visual-novel dialogue screen. His HEAD IS
SMALL in the cell: from the top of his hair to his chin is only about 30% of
the cell's height, with the top of the hair just below the top of the cell.
Below the head the cell shows his neck, both shoulders, his whole chest and
both upper arms down to the elbows; the bottom edge of the cell cuts straight
across his body at elbow height, with no fade. He is NOT facing straight at
the viewer: his body and head are turned about 30 degrees towards the RIGHT
side of the picture, his eyes on the viewer, arms relaxed at his sides. The
same pose, size and position in every cell: ONLY HIS FACE CHANGES.

THE FOUR MOODS: top left IDLE (calm, confident, a slight half-smile); top right
HAPPY (a big open smile, bright eyes); bottom left SAD (eyes looking down, brows
raised in the middle, mouth turned down); bottom right ANGRY (brows drawn down
hard, gritted teeth, a glare).

RECOLOUR KEY COLOURS, exactly these and nowhere else in the picture:
- HAIR is painted in shades of MAGENTA #FF00C8 (dark magenta in the shadows,
  light pink-magenta in the highlights).
- The IRISES of the eyes are CYAN #00E5FF.
- The flight JACKET is BLUE #2450FF, shaded darker and lighter.
- The jacket's TRIM (collar edge, seams, shoulder stripes) is YELLOW #FFE600.
Skin is a natural skin tone. The whites of the eyes are white. Anything under
the jacket is dark charcoal grey. Nothing else is magenta, cyan, blue, yellow or
green.

ABSOLUTELY NO TEXT of any kind: no labels, no mood names, no numbers, no logos,
no badges with writing.

An original character: he must not resemble any real person, actor, or
character from a film, TV show or game.

Remember: four cells, the same man, pose and framing in each, cut at the elbows,
the key colours exactly, chroma green behind him, and no text.
```

### portraits_woman_jacket

```
A square sprite sheet of character portraits for a mobile space shooter game: a
strict 2x2 grid of four equal square cells, all four filled. The SAME woman in
all four cells.

The attached picture shows ONLY her face and hair: copy the face, hairstyle and
colouring, but NOT its framing. It is a close-up; this sheet is a much wider
shot that shows her upper body (see FRAMING).

BACKGROUND: flat pure chroma green #00FF00 behind her in every cell. No
gradient, no shadow, no grid lines, no borders.

STYLE: the highest quality in the game. Detailed, semi-realistic painted
portraits, like the hero portraits of a polished mobile game: rich painterly
shading, a soft warm rim light, crisp clean edges against the background. NOT
pixel art, NOT anime, NOT a photo, NOT a 3D render.

THE WOMAN: a young space pilot in her late twenties, long hair tied back with a
few loose strands. A curvy hourglass figure: a large, full, soft bust and a
narrow waist, in a fitted flight jacket with a high collar, zipped up.
Glamorous but tasteful, fully clothed.

FRAMING, identical in all four cells: a MEDIUM SHOT of her upper body, like a
character standing at the edge of a visual-novel dialogue screen. Her HEAD IS
SMALL in the cell: from the top of her hair to her chin is only about 30% of
the cell's height, with the top of the hair just below the top of the cell.
Below the head the cell shows her neck, both shoulders, her whole chest and
both upper arms down to the elbows; the bottom edge of the cell cuts straight
across her body at elbow height, with no fade. She is NOT facing straight at
the viewer: her body and head are turned about 30 degrees towards the RIGHT
side of the picture, her eyes on the viewer, arms relaxed at her sides. The
same pose, size and position in every cell: ONLY HER FACE CHANGES.

THE FOUR MOODS: top left IDLE (calm, confident, a slight half-smile); top right
HAPPY (a big open smile, bright eyes); bottom left SAD (eyes looking down, brows
raised in the middle, mouth turned down); bottom right ANGRY (brows drawn down
hard, gritted teeth, a glare).

RECOLOUR KEY COLOURS, exactly these and nowhere else in the picture:
- HAIR is painted in shades of MAGENTA #FF00C8 (dark magenta in the shadows,
  light pink-magenta in the highlights).
- The IRISES of the eyes are CYAN #00E5FF.
- The flight JACKET is BLUE #2450FF, shaded darker and lighter.
- The jacket's TRIM (collar edge, seams, shoulder stripes) is YELLOW #FFE600.
Skin is a natural skin tone. The whites of the eyes are white. Anything under
the jacket is dark charcoal grey. Nothing else is magenta, cyan, blue, yellow or
green.

ABSOLUTELY NO TEXT of any kind: no labels, no mood names, no numbers, no logos,
no badges with writing.

An original character: she must not resemble any real person, actress, or
character from a film, TV show or game.

Remember: four cells, the same woman, pose and framing in each, cut at the
elbows, the key colours exactly, chroma green behind her, and no text.
```

### portraits_man_suit

Upload the chosen `portraits_man_jacket` sheet.

```
Edit the attached sprite sheet. Keep EVERYTHING the same: the same man, his face,
hair, the four expressions, his build, his three-quarter pose, the framing cut
at the elbows,
his size and position in each cell, the 2x2 grid and the flat chroma green
#00FF00 background. Change ONLY his clothes.

Replace the flight jacket with a rugged space suit, helmet off: hard shell chest
and shoulder plates and padded sections in BLUE #2450FF, shaded darker and
lighter, fitted to his big muscular build; YELLOW #FFE600 trim lines along the
plate edges and seams; a chunky steel-grey metal neck ring where the helmet
locks on; grey padded joints and grey hoses; a small grey control box on the
chest with no lights and no writing.

Keep the key colours exact: hair MAGENTA #FF00C8, irises CYAN #00E5FF, suit
BLUE #2450FF, trim YELLOW #FFE600, and nothing else in those colours or in
green. The same painted style. ABSOLUTELY NO TEXT, no logos, no badges.
```

### portraits_woman_suit

Upload the chosen `portraits_woman_jacket` sheet.

```
Edit the attached sprite sheet. Keep EVERYTHING the same: the same woman, her
face, hair, the four expressions, her figure, her three-quarter pose, the
framing cut at the elbows, her size and position in each cell, the 2x2 grid and the flat chroma
green #00FF00 background. Change ONLY her clothes.

Replace the flight jacket with a sleek space suit, helmet off: hard shell chest
and shoulder plates and padded sections in BLUE #2450FF, shaded darker and
lighter, fitted to her curvy figure; YELLOW #FFE600 trim lines along the plate
edges and seams; a chunky steel-grey metal neck ring where the helmet locks on;
grey padded joints and grey hoses; a small grey control box on the chest with no
lights and no writing. Tasteful, fully clothed.

Keep the key colours exact: hair MAGENTA #FF00C8, irises CYAN #00E5FF, suit
BLUE #2450FF, trim YELLOW #FFE600, and nothing else in those colours or in
green. The same painted style. ABSOLUTELY NO TEXT, no logos, no badges.
```

### portraits_npc_villain and portraits_npc_ally

Two stand-ins for the story's cast, so the dialog code has a bad guy and a friend to show before
the story is written (owner, 2026-10-27). Real characters come later, as NPC sheets (A.7). Run
each ×3, no upload. They're NPCs, so they're painted in their own colours: no key hues, but still
**nothing green**, because green is the key.

```
A square sprite sheet of character portraits for a mobile space shooter game: a
strict 2x2 grid of four equal square cells, all four filled. The SAME man in all
four cells.

BACKGROUND: flat pure chroma green #00FF00 behind him in every cell. No
gradient, no shadow, no grid lines, no borders.

STYLE: the highest quality in the game. Detailed, semi-realistic painted
portraits, like the hero portraits of a polished mobile game: rich painterly
shading, a soft warm rim light, crisp clean edges against the background. NOT
pixel art, NOT anime, NOT a photo, NOT a 3D render.

THE MAN: a menacing space pirate warlord in his forties, the villain of the
story: a hard, scarred face, a shaved head, a short black beard, one glowing red
cybernetic eye, a heavy armoured long coat in black and gunmetal with blood-red
trim, spiked shoulder armour, a broad powerful build.

FRAMING, identical in all four cells: a MEDIUM SHOT of his upper body, like a
character standing at the edge of a visual-novel dialogue screen. His HEAD IS
SMALL in the cell: from the top of his hair to his chin is only about 30% of
the cell's height, with the top of the hair just below the top of the cell.
Below the head the cell shows his neck, both shoulders, his whole chest and
both upper arms down to the elbows; the bottom edge of the cell cuts straight
across his body at elbow height, with no fade. He is NOT facing straight at
the viewer: his body and head are turned about 30 degrees towards the RIGHT
side of the picture, his eyes on the viewer, arms relaxed at his sides. The
same pose, size and position in every cell: ONLY HIS FACE CHANGES.

THE FOUR MOODS: top left IDLE (cold, a cruel smirk); top right HAPPY (a wide
gloating grin); bottom left SAD (a bitter scowl, eyes narrowed and looking
away); bottom right ANGRY (a furious snarl, teeth bared).

Nothing in the picture is green except the background.

ABSOLUTELY NO TEXT of any kind: no labels, no mood names, no numbers, no logos,
no badges with writing.

An original character: he must not resemble any real person, actor, or
character from a film, TV show or game.

Remember: four cells, the same man, pose and framing in each, cut at the elbows,
chroma green behind him, and no text.
```

For the ally, use the same prompt with **THE MAN** and **THE FOUR MOODS** swapped for:

```
THE MAN: a friendly veteran space pilot in his fifties, the player's mentor and
ally: a warm weathered face, kind eyes, a grey stubble beard and short grey
hair, a worn orange-and-white flight suit with patched elbows and a scuffed
brown leather collar, a sturdy build.

THE FOUR MOODS: top left IDLE (a warm, steady half-smile); top right HAPPY (a
big laughing grin, eyes crinkled); bottom left SAD (eyes lowered, brows raised in
the middle, a heavy frown); bottom right ANGRY (brows drawn down hard, jaw
clenched, a fierce glare).
```

**What happens to them.** Each cell is cut as a colour sprite off green and staged as
`assets/portraits/<base>_<outfit>_<mood>.png` (the stand-ins as `npc_villain_<mood>.png` and
`npc_ally_<mood>.png`, not recoloured). `PortraitView` swaps its placeholder bust for the
picture, with a shader that swaps each key-hue band for the player's colour and keeps the shading.
In menus and the HUD it shows a fixed head crop (the same rect in every cell, which is why the
framing is pinned); story-mode conversations show the whole picture standing on the bottom edge,
mirrored when the speaker is on the right. If a band bleeds into the
skin, a hand-made mask fixes it (§6.5).

### Review, 2026-10-27: what came back (one run each, all used)

The medium-shot framing worked: every sheet is turned right with the body cut near the elbows,
and the same face, pose and position in all four cells.
- `portraits_man_jacket_1`: Gemini made the jacket a sleeveless vest, which shows the build; the
  head is ~27% of the cell. `portraits_man_suit_1` is the edit of it: the same man, framing and
  crop in the suit.
- `portraits_woman_jacket_1`: the jacket is half unzipped, although the prompt said zipped. The
  crop is tighter than the man's (head ~33%, cut at the ribs), so the head crop is set per sheet.
  `portraits_woman_suit_1` is the edit of it, a match.
- `portraits_npc_villain_1` and `portraits_npc_ally_1`: both on brief. The ally has wing-and-star
  badges, but no writing.
- All came back at 1024 px (512 px cells), with thin black grid lines on the woman's sheets,
  which the slicer insets past.
- The first attempts (a head-and-shoulders bust) were a prompt mix-up, not Gemini, and were
  deleted.

### Review, 2026-10-27: the first sheet (v1, head and shoulders, 4×4)

Run 1 was usable: the same face across each row, the key hues right, at 1024 px. Runs 2 and 3
filled the "empty" rows with extra characters (a second woman, a third pilot), hence 2×2 sheets
with every cell filled. The owner then asked for elbow-height framing for story mode, a muscular
man, a curvy woman and a space-suit outfit, so v1 is replaced. Its faces are kept as
`ref_man.png` and `ref_woman.png`.

---

## After a sheet comes back

Check these before slicing, in the order the failures actually happen (from AOD):

1. **The cells sit on the grid.** Overlay a 256 px lattice first. If the art isn't centred in
   its cells, regenerate the sheet rather than cropping by hand.
2. **The reserved corner is empty**, and the watermark is inside it.
3. **No drift down the sheet.** The first row and the last should have the same light, gloss and
   scale. Drift is the usual failure on a 15-cell ask.
4. **No text crept in.**
5. **The rules held**: no franchise lookalikes, no green on chroma-green sheets, no glows, and no
   colour in a greyscale sheet.
