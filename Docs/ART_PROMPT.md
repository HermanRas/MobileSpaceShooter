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
| **Chrome and icons** | Panels, buttons, frames, bars, icons, map icons | A rich, glossy painted mobile-game finish, like "Menu Theme": bevelled gold and orange rims, dark warm fields, riveted steel brackets, soft studio light from the upper left. **NOT** pixel art, **NOT** flat vector. |
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
| A.2 | `parts_thrusters` | `art_src/parts/` | 9 | to write |
| A.3 | `parts_weapons_*` | `art_src/parts/` | 2–3 sheets | to write |
| A.4 | `icons_*` | `art_src/icons/` | 2 sheets | to write |
| A.5 | `chrome_*` | `art_src/ui/` | one canvas per piece | to write |
| A.6 | `icons_map` | `art_src/icons/` | 1 sheet | to write |
| A.7 | `portraits_*` | `art_src/portraits/` | ~4 sheets | to write |
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
