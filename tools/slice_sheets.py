"""Cut the Gemini masters in art_src/ into cells, and pack them into the game's atlases.

    tools/run.sh python3 -I tools/slice_sheets.py

`art_src/sheets.json` says what each sheet holds and what goes into which atlas. Sliced cells go
to `art_src/<folder>/sliced/` (gitignored, derived), with a labelled `review_<sheet>.png` per
sheet. Atlases are written straight into `game/assets/`. Masters are never rewritten, and nothing
is ever saved as JPEG (PLAN.md 6.3).

Ported from AOD's `slice_ui_sheets.py`, keeping the two fixes that mattered there:

- THE BACKGROUND IS KEYED BY A FLOOD FILL FROM THE BORDER, NOT A THRESHOLD. A cockpit's smoked
  glass is as dark as the background; a global `luma < t` punches it out. The background is the
  dark pixels REACHABLE FROM THE CELL'S BORDER.
- THE THRESHOLD IS MEASURED PER CELL from its own border, since "black" differs per sheet.

What's new for tiles: a material cell is cut INSIDE the black gutters (found per cell, as Gemini
draws them 4-8 px wide and not always centred) and its edges are evened out so it tiles, by
pulling each edge pair toward their mean over a narrow band. That fixes Gemini's near-seamless
textures without the ghosting a cross-fade puts on straight panel lines.

A part (A.2's thruster nozzles) is drawn on chroma green, because its nozzle mouth is as dark
as a black background. Green is keyed the same way, by a flood fill from the border, and its
spill is removed by reading the grey from R and B only (the art is greyscale, so G is the only
channel the green bleeds into). The art is stretched to fill the whole cell, since the game
samples a part in its own frame (flange to mouth, along the edge), and its coverage goes into B
inverted: B = 255 is cut out, so the placeholder atlas (B = 0) stays solid.

A gun (A.3) is a part too, but it turns about its round housing's centre, so it keeps its
shape: the slicer finds the housing from the art's left edge (a circle's chord grows as
2 * sqrt(2 R d - d^2) in from its edge), puts its centre at GUN_PIVOT in a GUN_CELL and scales
the gun so its barrel tip lands on GUN_TIP_X. The game then scales a cell so the tip meets the
weapon's muzzle (data), and the housing is whatever size the art gives it. An `edge_gun` (A.3c,
a side-mounted gun on a flat bracket) is cut the same way, but its pivot is the middle of the
bracket's flat left side, where it meets the hull, placed at EDGE_PIVOT. A "guns" atlas has a
row of those per mount type (RGB = grey, A = coverage), then a trim-mask row (the white band,
for the game to tint) per art row; "" leaves a cell empty.

A sprite (A.4's icons, A.3d's mine) is colour artwork on black (or, with {"key": "green"}, on
chroma green): keyed like `keyed` (a flood fill from the
border, so a dark badge centre ringed by gold survives), kept in colour with its alpha, and
fitted into a square. A "files" atlas writes each sprite as its own PNG, so a Button can use it.

A chrome piece (A.5's panels, header, frame and buttons) is keyed like a sprite but keeps its own
shape: it's cropped tight to the artwork (so a 9-slice's edges are the art's edges) and scaled so
its height is `h` px (or its width `w`). `inset` trims the cell window first, past the grid lines
Gemini draws between cells; `crop` keeps a fraction [x0, y0, x1, y1] of the window (a bar's fill
out of its track). The game draws them at half size, so they stay crisp on the phone.

A portrait (A.7) is a painted character on chroma green, keyed and despilled like a green sprite,
but it keeps its whole cell (past `inset`), scaled to `px`: the prompts pin where the head sits in
the cell, so the game can crop the head with one rect per sheet, and the body runs off the
bottom edge, where a dialog stands it on the screen's. With `mask`, it also gets a recolour mask
(`<id>_mask`): R = hair, G = eyes, B = outfit, A = trim, each the pixels whose hue falls in that
key hue's band (MASK_BANDS; the hair's also takes the pale strands next to it), grown by a pixel and softened so no key-coloured fringe survives at
an edge. The eyes are only looked for inside `mask.eyes` (a box, in fractions of the cell),
because a suit's cyan rim light is the irises' hue (and outside it, that hue is the outfit's);
the box also takes in the brows, which are redder than the hair but share the lips' hue. The report gives each region's mean value,
which the game's shader needs to keep the shading (visuals.json vis.portraits `ref_v`).

Atlas layout (the ship shader's contract): a column per entry of a row, a row per variant, every
cell padded by cell_px / 16 on each side (wrapped for materials, edge-extended otherwise), so
mipmaps and linear filtering never read a neighbouring cell. The pad is 1/18 of the stride
whatever the cell size, which is what lets the placeholder atlas (128 px cells) and the real one
(256 px) share the shader's uniforms.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art_src"
CONFIG = ART / "sheets.json"

GUTTER_LUMA = 40          # a gutter column/row is darker than this on average
INSET_PX = 3              # cut this far inside the gutters, past the JPEG ringing
EVEN_BAND_PX = 16         # how far in from each edge the seam correction reaches
TRIM_FROM, TRIM_TO = 225, 250   # near-white becomes the untinted trim mask (G)
GREEN_MARGIN = 60         # chroma key: G exceeds both R and B by more than this
SPRITE_PX = 128           # an icon file's size
SPRITE_FILL = 0.94        # how much of it the artwork spans
GUN_CELL = (256, 256)     # a gun's atlas cell, w x h
GUN_PIVOT = (96, 128)     # where the housing's centre lands in it
EDGE_PIVOT = (8, 128)     # where an edge gun's bracket meets the hull
GUN_TIP_X = 248           # and the barrel's tip
# A portrait's key hue bands: (hue from, hue to in degrees, min saturation), in mask channel order.
MASK_BANDS = {"hair": (285, 340, 0.35), "eyes": (160, 215, 0.15), "outfit": (185, 255, 0.30),
              "trim": (40, 68, 0.55)}
BROW_HUE = 360            # inside the eye box the hair band reaches this far: the brows are redder
HAIR_PALE = (0.08, 6)     # pale strands in the hair's hue join it: min saturation, within this many px


def luma(rgb: np.ndarray) -> np.ndarray:
    """Max channel: "is anything lit here?" (AOD: a dark saturated red is not background)."""
    return rgb.max(axis=2)


def content_box(lum: np.ndarray) -> tuple[int, int, int, int]:
    """The cell's artwork inside the gutters, as (x0, y0, x1, y1) within `lum`."""
    cols = np.nonzero(lum.mean(axis=0) > GUTTER_LUMA)[0]
    rows = np.nonzero(lum.mean(axis=1) > GUTTER_LUMA)[0]
    if cols.size == 0 or rows.size == 0:
        raise ValueError("empty cell")
    return (int(cols[0]) + INSET_PX, int(rows[0]) + INSET_PX,
            int(cols[-1]) + 1 - INSET_PX, int(rows[-1]) + 1 - INSET_PX)


def even_edges(a: np.ndarray, band: int = EVEN_BAND_PX) -> np.ndarray:
    """Make opposite edges match, so the texture tiles: each edge pair meets at their mean,
    and the correction fades out over `band` px."""
    a = a.astype(np.float32).copy()
    w = (1.0 - np.arange(band, dtype=np.float32) / band) ** 2
    d = (a[:, 0] - a[:, -1]) * 0.5            # per row
    a[:, :band] -= d[:, None] * w[None, :]
    a[:, -band:] += d[:, None] * w[::-1][None, :]
    d = (a[0, :] - a[-1, :]) * 0.5            # per column
    a[:band, :] -= w[:, None] * d[None, :]
    a[-band:, :] += w[::-1][:, None] * d[None, :]
    return np.clip(a, 0, 255)


def seam(a: np.ndarray) -> float:
    """Mean mismatch across both wrap seams, in grey levels."""
    a = a.astype(np.float32)
    return float((np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0, :] - a[-1, :]).mean()) / 2)


def fill_from_border(dark: np.ndarray) -> np.ndarray:
    """Pixels of `dark` 4-connected to the border (iterated dilation; recursion would overflow)."""
    seed = np.zeros_like(dark)
    seed[0, :], seed[-1, :], seed[:, 0], seed[:, -1] = dark[0, :], dark[-1, :], dark[:, 0], dark[:, -1]
    cur = seed
    while True:
        grown = cur.copy()
        grown[1:, :] |= cur[:-1, :]
        grown[:-1, :] |= cur[1:, :]
        grown[:, 1:] |= cur[:, :-1]
        grown[:, :-1] |= cur[:, 1:]
        grown &= dark
        if np.array_equal(grown, cur):
            return cur
        cur = grown


def box_blur3(a: np.ndarray) -> np.ndarray:
    p = np.pad(a, 1, mode="edge")
    return sum(p[dy:dy + a.shape[0], dx:dx + a.shape[1]] for dy in range(3) for dx in range(3)) / 9.0


def resize(a: np.ndarray, size: int) -> np.ndarray:
    return np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "L")
                      .resize((size, size), Image.Resampling.LANCZOS)).astype(np.float32)


def cut_material(rgb: np.ndarray, size: int, report: list[str], ident: str) -> np.ndarray:
    lum = luma(rgb)
    x0, y0, x1, y1 = content_box(lum)
    grey = rgb[y0:y1, x0:x1].mean(axis=2)
    cell = resize(grey, size)
    before = seam(cell)
    cell = even_edges(cell)
    report.append(f"  {ident:16s} material  {x1 - x0}x{y1 - y0} -> {size}  mean {cell.mean():5.1f}  "
                  f"seam {before:4.1f} -> {seam(cell):4.1f}")
    return cell


def cut_overlay(rgb: np.ndarray, size: int, report: list[str], ident: str) -> np.ndarray:
    lum = luma(rgb)
    x0, y0, x1, y1 = content_box(lum)
    cell = resize(rgb[y0:y1, x0:x1].mean(axis=2), size)
    report.append(f"  {ident:16s} overlay   {x1 - x0}x{y1 - y0} -> {size}  mean {cell.mean():5.1f}")
    return cell


def cut_keyed(rgb: np.ndarray, size: int, base: np.ndarray, fill: float,
              report: list[str], ident: str) -> np.ndarray:
    """Key the cell's flat background out from its border, fit the artwork into `fill` of the
    cell, and composite it over `base` (a material cell of the same size)."""
    lum = luma(rgb)
    border = np.concatenate([lum[0, :], lum[-1, :], lum[:, 0], lum[:, -1]])
    thresh = int(min(40, max(10, np.percentile(border, 99.5) + 8)))
    bg = fill_from_border(lum <= thresh)
    alpha = box_blur3((~bg).astype(np.float32))
    ys, xs = np.nonzero(alpha > 0.5)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    grey = rgb.mean(axis=2) / np.maximum(alpha, 1e-3)   # un-premultiply the edge off the black
    art = np.clip(grey, 0, 255)[y0:y1, x0:x1]
    a = alpha[y0:y1, x0:x1]
    scale = size * fill / max(x1 - x0, y1 - y0)
    w, h = max(1, round((x1 - x0) * scale)), max(1, round((y1 - y0) * scale))
    art_img = Image.fromarray(art.astype(np.uint8), "L").resize((w, h), Image.Resampling.LANCZOS)
    a_img = Image.fromarray((a * 255).astype(np.uint8), "L").resize((w, h), Image.Resampling.LANCZOS)
    out = Image.fromarray(base.astype(np.uint8), "L")
    out.paste(art_img, ((size - w) // 2, (size - h) // 2), a_img)
    report.append(f"  {ident:16s} keyed     {x1 - x0}x{y1 - y0} -> {w}x{h} over the base  (key <= {thresh})")
    return np.asarray(out).astype(np.float32)


def key_green(rgb: np.ndarray) -> np.ndarray:
    """Coverage (0..1) of the artwork on a chroma-green cell, ignoring a ruled border."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = (g - np.maximum(r, b)) > GREEN_MARGIN
    # Gemini sometimes rules a thin dark grid line on the cell border: treat it as background.
    green[:INSET_PX, :] = green[-INSET_PX:, :] = True
    green[:, :INSET_PX] = green[:, -INSET_PX:] = True
    return box_blur3((~fill_from_border(green)).astype(np.float32))


def cut_gun(rgb: np.ndarray, report: list[str], ident: str, edge: bool = False) -> tuple[np.ndarray, np.ndarray]:
    """Key a gun off green, find its pivot (a turret's housing centre, or with `edge` the middle
    of its bracket's flat left side) and place it in a GUN_CELL. Returns (grey, coverage 0..1),
    both GUN_CELL sized."""
    cover = key_green(rgb)
    solid = cover > 0.5
    cols = np.nonzero(solid.sum(axis=0) >= 3)[0]
    x0 = cols.min()
    estimates, middles = [], []
    for d in range(2, 12) if edge else range(4, 40):
        ys = np.nonzero(solid[:, x0 + d])[0]
        if ys.size:
            h = ys.max() - ys.min() + 1
            estimates.append((h * h / 4 + d * d) / (2 * d))
            middles.append((ys.max() + ys.min()) / 2)
    radius, cy = float(np.median(estimates)), float(np.median(middles))
    cx = x0 if edge else x0 + radius
    pivot = EDGE_PIVOT if edge else GUN_PIVOT
    tip_x = np.nonzero(solid.sum(axis=0) >= 1)[0].max()
    k = (GUN_TIP_X - pivot[0]) / (tip_x - cx)
    grey = (rgb[..., 0] + rgb[..., 2]) / 2.0
    w, h = round(rgb.shape[1] * k), round(rgb.shape[0] * k)
    scale = lambda a: np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "L")
                                 .resize((w, h), Image.Resampling.LANCZOS)).astype(np.float32)
    big_grey, big_cover = scale(grey), scale(cover * 255) / 255
    out_grey = np.zeros((GUN_CELL[1], GUN_CELL[0]), np.float32)
    out_cover = np.zeros_like(out_grey)
    ox, oy = round(pivot[0] - cx * k), round(pivot[1] - cy * k)
    sx0, sy0 = max(0, -ox), max(0, -oy)
    sx1, sy1 = min(w, GUN_CELL[0] - ox), min(h, GUN_CELL[1] - oy)
    out_grey[sy0 + oy:sy1 + oy, sx0 + ox:sx1 + ox] = big_grey[sy0:sy1, sx0:sx1]
    out_cover[sy0 + oy:sy1 + oy, sx0 + ox:sx1 + ox] = big_cover[sy0:sy1, sx0:sx1]
    lost = 1 - out_cover.sum() / max(big_cover.sum(), 1e-3)
    if edge:
        report.append(f"  {ident:16s} edge gun  pivot at ({cx:5.1f}, {cy:5.1f}), length {tip_x - cx} px "
                      f"-> {GUN_TIP_X - pivot[0]}  clipped {lost:.1%}")
    else:
        report.append(f"  {ident:16s} gun       housing r {radius:5.1f} px at ({cx:5.1f}, {cy:5.1f}), "
                      f"tip {(tip_x - cx) / radius:4.2f} r -> r {radius * k:5.1f} px in the cell  clipped {lost:.1%}")
    return out_grey, out_cover


def cut_sprite(rgb: np.ndarray, size: int, holes: bool, green: bool, report: list[str], ident: str) -> np.ndarray:
    """Key colour artwork off a black cell (or with `green`, a chroma-green one, despilled by
    capping G at max(R, B)) and fit it, centred, into SPRITE_FILL of a square. With `holes`,
    enclosed black goes too (a crosshair's middle); without, it stays (a badge's dark centre).
    Returns RGBA, size x size."""
    if green:
        alpha, thresh = key_green(rgb), "green"
        rgb = rgb.copy()
        rgb[..., 1] = np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2]))
    else:
        alpha, thresh = key_black(rgb, holes)
    ys, xs = np.nonzero(alpha > 0.5)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    rgba = np.dstack([rgb, alpha * 255])[y0:y1, x0:x1]
    k = size * SPRITE_FILL / max(x1 - x0, y1 - y0)
    w, h = max(1, round((x1 - x0) * k)), max(1, round((y1 - y0) * k))
    art = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA").resize((w, h), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(art, ((size - w) // 2, (size - h) // 2))
    report.append(f"  {ident:16s} sprite    {x1 - x0}x{y1 - y0} -> {w}x{h} in {size}  (key <= {thresh})")
    return np.asarray(out).astype(np.float32)


def key_black(rgb: np.ndarray, holes: bool) -> tuple[np.ndarray, int]:
    """Coverage 0..1 of artwork on black (the border-connected dark, or with `holes` all of it),
    and the threshold used, measured from the window's own border."""
    lum = luma(rgb)
    border = np.concatenate([lum[0, :], lum[-1, :], lum[:, 0], lum[:, -1]])
    thresh = int(min(40, max(10, np.percentile(border, 99.5) + 8)))
    dark = lum <= thresh
    return box_blur3((~(dark if holes else fill_from_border(dark))).astype(np.float32)), thresh


def cut_chrome(rgb: np.ndarray, options: dict, report: list[str], ident: str) -> np.ndarray:
    """Key a chrome piece off black, crop it tight and scale it to `h` (or `w`) px. RGBA."""
    inset = int(options.get("inset", 0))
    if inset:
        rgb = rgb[inset:-inset, inset:-inset]
    if "crop" in options:
        x0, y0, x1, y1 = options["crop"]
        h, w = rgb.shape[:2]
        rgb = rgb[round(y0 * h):round(y1 * h), round(x0 * w):round(x1 * w)]
    alpha, thresh = key_black(rgb, bool(options.get("holes", False)))
    ys, xs = np.nonzero(alpha > 0.5)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    k = options["h"] / (y1 - y0) if "h" in options else options["w"] / (x1 - x0)
    w, h = max(1, round((x1 - x0) * k)), max(1, round((y1 - y0) * k))
    rgba = np.dstack([rgb, alpha * 255])[y0:y1, x0:x1]
    art = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA").resize((w, h), Image.Resampling.LANCZOS)
    report.append(f"  {ident:16s} chrome    {x1 - x0}x{y1 - y0} -> {w}x{h}  (key <= {thresh})")
    return np.asarray(art).astype(np.float32)


def hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Hue in degrees, saturation and value (0..1) of 0..255 RGB."""
    a = rgb / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, np.where(mx > 0, (mx - mn) / (mx + 1e-6), 0), mx


def grow(m: np.ndarray) -> np.ndarray:
    """`m` dilated by one pixel (8-connected)."""
    p = np.pad(m, 1)
    return np.max([p[dy:dy + m.shape[0], dx:dx + m.shape[1]] for dy in range(3) for dx in range(3)], axis=0)


def portrait_mask(rgba: np.ndarray, eyes: list[float], report: list[str], ident: str) -> np.ndarray:
    """The recolour mask of a cut portrait (RGBA 0..255): a channel per MASK_BANDS region."""
    h, s, v = hsv(rgba[..., :3])
    solid = rgba[..., 3] > 127
    size = rgba.shape[0]
    x0, y0, x1, y1 = (round(f * size) for f in eyes)
    in_eyes = np.zeros_like(solid)
    in_eyes[y0:y1, x0:x1] = True
    channels, means = [], []
    for region, (h0, h1, smin) in MASK_BANDS.items():
        hard = (h >= h0) & (h <= h1) & (s >= smin) & (v > 0.1) & solid
        if region == "hair":
            hard |= in_eyes & (h > h1) & (h <= BROW_HUE) & (s >= smin) & (v > 0.1) & solid
            near = hard.astype(np.float32)
            for _ in range(HAIR_PALE[1]):
                near = grow(near)
            hard |= (near > 0) & (h >= h0) & (h <= h1) & (s >= HAIR_PALE[0]) & solid
        # The irises' band overlaps the outfit's cyan rim light, so the eye box decides which.
        hard &= in_eyes if region == "eyes" else ~in_eyes if region == "outfit" else True
        means.append(float(v[hard].mean()) if hard.any() else 0.0)
        channels.append(box_blur3(grow(hard.astype(np.float32))) * solid)
    report.append(f"  {ident + '_mask':20s} mask      ref_v [{', '.join(f'{m:.2f}' for m in means)}]")
    return np.dstack(channels) * 255


def cut_portrait(rgb: np.ndarray, options: dict, report: list[str], ident: str) -> np.ndarray:
    """Key a portrait cell off chroma green, despill it, and keep the whole cell at `px`. RGBA."""
    inset = int(options.get("inset", 0))
    if inset:
        rgb = rgb[inset:-inset, inset:-inset]
    alpha = key_green(rgb)
    rgb = rgb.copy()
    rgb[..., 1] = np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2]))
    px = int(options.get("px", rgb.shape[0]))
    rgba = np.dstack([rgb, alpha * 255])
    art = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA").resize((px, px), Image.Resampling.LANCZOS)
    report.append(f"  {ident:20s} portrait  {rgb.shape[1]}x{rgb.shape[0]} -> {px}x{px}  covers {alpha.mean():.0%}")
    return np.asarray(art).astype(np.float32)


def cut_part(rgb: np.ndarray, size: int, report: list[str], ident: str) -> tuple[np.ndarray, np.ndarray]:
    """Key a part off its chroma-green background and stretch it over the whole cell. Returns
    (grey, coverage 0..1)."""
    cover = key_green(rgb)
    ys, xs = np.nonzero(cover > 0.5)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    grey = (rgb[..., 0] + rgb[..., 2]) / 2.0
    stretch = lambda a: np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "L")
                                   .resize((size, size), Image.Resampling.LANCZOS)).astype(np.float32)
    out_grey, out_cover = stretch(grey[y0:y1, x0:x1]), stretch(cover[y0:y1, x0:x1] * 255) / 255
    report.append(f"  {ident:16s} part      {x1 - x0}x{y1 - y0} -> {size}x{size}  "
                  f"covers {out_cover.mean():.0%}  trim {(out_grey * out_cover >= TRIM_FROM).mean():.1%}")
    return out_grey, out_cover


def slice_sheet(name: str, spec: dict, cells: dict[str, np.ndarray], kinds: dict[str, str],
                covers: dict[str, np.ndarray], size: int, report: list[str]) -> None:
    src = ART / spec["file"]
    rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    rows, cols = spec["grid"]
    ch, cw = rgb.shape[0] // rows, rgb.shape[1] // cols
    report.append(f"{name}  ({src.relative_to(ROOT)}, {rgb.shape[1]}x{rgb.shape[0]})")
    # Keyed cells composite over another cell, so cut every plain cell first.
    order = sorted(spec["cells"].items(), key=lambda kv: kv[1][1] == "keyed")
    for number, entry in order:
        ident, kind = entry[0], entry[1]
        options = entry[2] if len(entry) > 2 else {}
        r, c = divmod(int(number) - 1, cols)
        window = rgb[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw]
        if kind == "material":
            cells[ident] = cut_material(window, size, report, ident)
        elif kind == "overlay":
            cells[ident] = cut_overlay(window, size, report, ident)
        elif kind == "sprite":
            cells[ident] = cut_sprite(window, SPRITE_PX, bool(options.get("holes", False)),
                                      options.get("key") == "green", report, ident)
        elif kind == "portrait":
            cells[ident] = cut_portrait(window, options, report, ident)
            if "mask" in options:
                cells[ident + "_mask"] = portrait_mask(cells[ident], options["mask"]["eyes"], report, ident)
        elif kind == "chrome":
            cells[ident] = cut_chrome(window, options, report, ident)
        elif kind in ("gun", "edge_gun"):
            cells[ident], covers[ident] = cut_gun(window, report, ident, kind == "edge_gun")
        elif kind == "part":
            cells[ident], covers[ident] = cut_part(window, size, report, ident)
        elif kind == "keyed":
            cells[ident] = cut_keyed(window, size, cells[options["base"]], float(options.get("fill", 0.9)),
                                     report, ident)
        else:
            raise ValueError(f"{name} cell {number}: unknown kind {kind!r}")
        kinds[ident] = kind
    out_dir = src.parent / "sliced"
    out_dir.mkdir(exist_ok=True)
    for number, entry in spec["cells"].items():
        cell = cells[entry[0]].astype(np.uint8)
        Image.fromarray(cell, "RGBA" if cell.ndim == 3 else "L").save(out_dir / f"{entry[0]}.png")
    if all(entry[1] not in ("sprite", "chrome", "portrait") for entry in spec["cells"].values()):
        review(name, spec, cells, out_dir / f"review_{name}.png")


def review(name: str, spec: dict, cells: dict[str, np.ndarray], path: Path) -> None:
    """Each cut cell tiled 2 x 2 (so a seam shows as a cross), labelled with its id."""
    entries = list(spec["cells"].values())
    tile = 2 * 128
    sheet = Image.new("RGB", (4 * (tile + 12) + 12, ((len(entries) + 3) // 4) * (tile + 34) + 12), (24, 26, 30))
    draw = ImageDraw.Draw(sheet)
    for i, entry in enumerate(entries):
        small = Image.fromarray(cells[entry[0]].astype(np.uint8), "L").resize((128, 128), Image.Resampling.LANCZOS)
        x, y = 12 + (i % 4) * (tile + 12), 12 + (i // 4) * (tile + 34)
        for dx in (0, 128):
            for dy in (0, 128):
                sheet.paste(small, (x + dx, y + dy))
        draw.text((x, y + tile + 6), f"{entry[0]}  ({entry[1]})", fill=(230, 230, 230))
    sheet.save(path)


def write_files(name: str, spec: dict, cells: dict[str, np.ndarray], report: list[str]) -> None:
    """Each listed sprite as its own PNG in the `out` folder, named by its id."""
    out = ROOT / spec["out"]
    out.mkdir(parents=True, exist_ok=True)
    for ident in spec["files"]:
        path = out / f"{ident}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(np.clip(cells[ident], 0, 255).astype(np.uint8), "RGBA").save(path)
    report.append(f"{name} -> {out.relative_to(ROOT)}/  ({len(spec['files'])} files)")


def pack_guns(name: str, spec: dict, cells: dict[str, np.ndarray], covers: dict[str, np.ndarray],
              report: list[str]) -> None:
    """Rows of gun cells (RGB = grey, A = coverage), then a row of trim masks (white, A = the
    near-white band) for each, every cell padded by GUN_CELL[1] / 16. "" is an empty cell."""
    w, h = GUN_CELL
    pad = h // 16
    rows = spec["rows"]
    sw, sh = w + 2 * pad, h + 2 * pad
    out = np.zeros((2 * len(rows) * sh, max(len(row) for row in rows) * sw, 4), dtype=np.uint8)
    for r, row in enumerate(rows):
        for c, ident in enumerate(row):
            if not ident:
                continue
            grey = np.pad(cells[ident], pad, mode="edge")
            cover = np.pad(covers[ident], pad, mode="constant")
            trim = np.clip((grey - TRIM_FROM) / (TRIM_TO - TRIM_FROM), 0, 1) * cover
            art = out[r * sh:(r + 1) * sh, c * sw:(c + 1) * sw]
            art[..., 0] = art[..., 1] = art[..., 2] = np.clip(grey, 0, 255).astype(np.uint8)
            art[..., 3] = (cover * 255).astype(np.uint8)
            band = out[(len(rows) + r) * sh:(len(rows) + r + 1) * sh, c * sw:(c + 1) * sw]
            band[..., :3] = 255
            band[..., 3] = (trim * 255).astype(np.uint8)
    path = ROOT / spec["out"]
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(path)
    report.append(f"{name} -> {path.relative_to(ROOT)}  ({out.shape[1]}x{out.shape[0]}, "
                  f"{len(rows)} rows of {w}x{h} px cells + {pad} px pad, trim rows below)")


def pack(name: str, spec: dict, cells: dict[str, np.ndarray], kinds: dict[str, str],
         covers: dict[str, np.ndarray], report: list[str]) -> None:
    size = int(spec["cell_px"])
    pad = size // 16
    stride = size + 2 * pad
    rows = spec["rows"]
    n_cols = max(len(row) for row in rows)
    out = np.zeros((len(rows) * stride, n_cols * stride, 4), dtype=np.uint8)
    out[..., 3] = 255
    for r, row in enumerate(rows):
        for c, ident in enumerate(row):
            cell = cells[ident]
            if cell.shape[0] != size:
                cell = resize(cell, size)
            padded = np.pad(cell, pad, mode="wrap" if kinds[ident] == "material" else "edge")
            block = out[r * stride:(r + 1) * stride, c * stride:(c + 1) * stride]
            block[..., 0] = np.clip(padded, 0, 255).astype(np.uint8)
            if spec.get("trim", False):
                trim = np.clip((padded - TRIM_FROM) / (TRIM_TO - TRIM_FROM), 0, 1)
                block[..., 1] = (trim * 255).astype(np.uint8)
            if ident in covers:
                cover = np.pad(covers[ident], pad, mode="edge")
                block[..., 1] = (block[..., 1] * cover).astype(np.uint8)
                block[..., 2] = ((1 - cover) * 255).astype(np.uint8)
    path = ROOT / spec["out"]
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(path)
    report.append(f"{name} -> {path.relative_to(ROOT)}  ({out.shape[1]}x{out.shape[0]}, "
                  f"{n_cols} x {len(rows)} cells of {size} px + {pad} px pad)")


def main() -> int:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    size = max(int(a.get("cell_px", 0)) for a in config["atlases"].values())
    cells: dict[str, np.ndarray] = {}
    kinds: dict[str, str] = {}
    covers: dict[str, np.ndarray] = {}
    report: list[str] = []
    for name, spec in config["sheets"].items():
        slice_sheet(name, spec, cells, kinds, covers, size, report)
    for name, spec in config["atlases"].items():
        missing = [i for row in spec.get("rows", [spec.get("files", [])]) for i in row if i and i not in cells]
        if missing:
            print(f"{name}: no cell called {', '.join(sorted(set(missing)))}", file=sys.stderr)
            return 1
        if spec.get("layout") == "files":
            write_files(name, spec, cells, report)
        elif spec.get("layout") == "guns":
            pack_guns(name, spec, cells, covers, report)
        else:
            pack(name, spec, cells, kinds, covers, report)
    print("\n".join(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
