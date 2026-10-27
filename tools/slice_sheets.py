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


def cut_part(rgb: np.ndarray, size: int, report: list[str], ident: str) -> tuple[np.ndarray, np.ndarray]:
    """Key a part off its chroma-green background and stretch it over the whole cell. Returns
    (grey, coverage 0..1)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = (g - np.maximum(r, b)) > GREEN_MARGIN
    # Gemini sometimes rules a thin dark grid line on the cell border: treat it as background.
    green[:INSET_PX, :] = green[-INSET_PX:, :] = True
    green[:, :INSET_PX] = green[:, -INSET_PX:] = True
    cover = box_blur3((~fill_from_border(green)).astype(np.float32))
    ys, xs = np.nonzero(cover > 0.5)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    grey = (r + b) / 2.0
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
        Image.fromarray(cells[entry[0]].astype(np.uint8), "L").save(out_dir / f"{entry[0]}.png")
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
    size = max(int(a["cell_px"]) for a in config["atlases"].values())
    cells: dict[str, np.ndarray] = {}
    kinds: dict[str, str] = {}
    covers: dict[str, np.ndarray] = {}
    report: list[str] = []
    for name, spec in config["sheets"].items():
        slice_sheet(name, spec, cells, kinds, covers, size, report)
    for name, spec in config["atlases"].items():
        missing = [i for row in spec["rows"] for i in row if i not in cells]
        if missing:
            print(f"{name}: no cell called {', '.join(sorted(set(missing)))}", file=sys.stderr)
            return 1
        pack(name, spec, cells, kinds, covers, report)
    print("\n".join(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
