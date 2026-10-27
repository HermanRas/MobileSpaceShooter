"""Generate the placeholder tile-material atlas (PLAN.md 6.2) until Gemini art lands (A.1).

    tools/run.sh python3 -I tools/make_placeholders.py

Writes game/assets/placeholders/tile_atlas.png in the layout tools/slice_sheets.py gives the real
atlas: a column per tile type in CELLS order, VARIANTS identical rows, each cell padded (wrapped)
by CELL / 16 on every side. Each cell is seamless. Channels follow the ship shader's contract:
    R = greyscale detail (multiplied with the paint colour)
    G = trim mask (drawn untinted, e.g. the shield's emitter lines)
    B = unused, A = 255
And game/assets/placeholders/tile_damage.png: four damage overlays, darker speckle per step.
And game/assets/placeholders/icon.png: one grey ring that stands in for every icon (A.4).
And game/assets/placeholders/mine.png: a spiked dark disc with a red lamp, for mines in space.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

CELL = 128
# Append new cells at the end: the noise generator is seeded, so earlier cells stay identical.
CELLS = ["core", "hull", "armor", "shield", "hardpoint", "thruster"]
VARIANTS = 3
PAD = CELL // 16
OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "placeholders" / "tile_atlas.png"
DAMAGE_OUT = OUT.with_name("tile_damage.png")
ICON_OUT = OUT.with_name("icon.png")
MINE_OUT = OUT.with_name("mine.png")
CHROME_OUT = OUT.with_name("chrome.png")
PORTRAIT_OUT = OUT.with_name("portrait.png")
PORTRAIT_MASK_OUT = OUT.with_name("portrait_mask.png")
ICON = 64

yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
rng = np.random.default_rng(7)


def periodic_noise(scale: int, amount: float) -> np.ndarray:
    """Smooth noise that tiles: random values on a coarse wrapped grid, bilinearly upsampled."""
    grid = rng.random((scale, scale)).astype(np.float32)
    fx, fy = xx / CELL * scale, yy / CELL * scale
    x0, y0 = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - x0, fy - y0
    x1, y1 = (x0 + 1) % scale, (y0 + 1) % scale
    x0, y0 = x0 % scale, y0 % scale
    top = grid[y0, x0] * (1 - tx) + grid[y0, x1] * tx
    bottom = grid[y1, x0] * (1 - tx) + grid[y1, x1] * tx
    return (top * (1 - ty) + bottom * ty - 0.5) * amount


def line_mask(coord: np.ndarray, period: float, width: float) -> np.ndarray:
    """1 on lines every `period` px (wrapping at the cell edge), fading over `width` px."""
    d = np.abs(((coord + period / 2) % period) - period / 2)
    return np.clip(1 - d / width, 0, 1)


def hull() -> tuple[np.ndarray, np.ndarray]:
    seams = np.maximum(line_mask(xx, 64, 1.5), line_mask(yy + (xx >= 64) * 32, 64, 1.5))
    rivets = np.zeros_like(xx)
    for cx in (6, 58, 70, 122):
        for cy in range(6, CELL, 26):
            rivets = np.maximum(rivets, np.clip(1 - np.hypot(xx - cx, yy - cy) / 2.2, 0, 1))
    detail = 0.72 + periodic_noise(8, 0.12) - seams * 0.45 + rivets * 0.25
    return detail, np.zeros_like(xx)


def armor() -> tuple[np.ndarray, np.ndarray]:
    diag = (xx + yy) % 64
    band = np.clip(np.minimum(diag, 64 - diag) / 6, 0, 1)
    detail = 0.55 + 0.25 * band + periodic_noise(4, 0.15) - line_mask(xx + yy, 64, 2.0) * 0.4
    return detail, np.zeros_like(xx)


def shield() -> tuple[np.ndarray, np.ndarray]:
    # Hex-ish grid from three line families at 0, 60 and 120 degrees.
    a = line_mask(yy, 32, 1.3)
    b = line_mask(yy * 0.5 + xx * 0.8660, 32, 1.3)
    c = line_mask(yy * 0.5 - xx * 0.8660, 32, 1.3)
    trim = np.clip(a + b + c, 0, 1) * 0.9
    detail = 0.35 + periodic_noise(8, 0.1)
    return detail, trim


def hardpoint() -> tuple[np.ndarray, np.ndarray]:
    rails = line_mask(yy, 32, 2.0)
    bolts = np.zeros_like(xx)
    for cx in (16, 48, 80, 112):
        for cy in (16, 48, 80, 112):
            r = np.hypot(xx - cx, yy - cy)
            bolts = np.maximum(bolts, np.clip(1 - np.abs(r - 5) / 1.5, 0, 1))
    stripes = ((xx - yy) % 32 < 16) * line_mask(xx, 128, 6)
    detail = 0.42 + periodic_noise(8, 0.1) - rails * 0.25 + bolts * 0.4
    return detail, np.clip(stripes, 0, 1) * 0.8


def core() -> tuple[np.ndarray, np.ndarray]:
    r = np.hypot(xx - CELL / 2, yy - CELL / 2)
    rings = np.clip(1 - np.abs(r - 34) / 2.5, 0, 1) + np.clip(1 - np.abs(r - 22) / 1.5, 0, 1)
    canopy = np.clip(1 - r / 18, 0, 1)
    detail = 0.7 + periodic_noise(8, 0.08) - rings * 0.35 + canopy * 0.2
    return detail, np.clip(canopy * 1.4, 0, 1)


def thruster() -> tuple[np.ndarray, np.ndarray]:
    # Machined nozzle metal: cooling ribs across, a bright lip as trim.
    ribs = line_mask(xx, 16, 2.0)
    detail = 0.6 + periodic_noise(8, 0.08) - ribs * 0.3
    lip = line_mask(xx, 128, 5.0)
    return detail, np.clip(lip, 0, 1) * 0.7


def main() -> None:
    makers = {"core": core, "hull": hull, "armor": armor, "shield": shield, "hardpoint": hardpoint,
              "thruster": thruster}
    stride = CELL + 2 * PAD
    atlas = np.zeros((stride * VARIANTS, stride * len(CELLS), 4), dtype=np.uint8)
    for i, name in enumerate(CELLS):
        detail, trim = makers[name]()
        for row in range(VARIANTS):
            cell = atlas[row * stride:(row + 1) * stride, i * stride:(i + 1) * stride]
            cell[..., 0] = np.pad(np.clip(detail, 0, 1) * 255, PAD, mode="wrap")
            cell[..., 1] = np.pad(np.clip(trim, 0, 1) * 255, PAD, mode="wrap")
            cell[..., 3] = 255
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(atlas, "RGBA").save(OUT)
    print(f"wrote {OUT.relative_to(OUT.parents[3])} ({atlas.shape[1]}x{atlas.shape[0]}, cells: {', '.join(CELLS)})")

    damage = np.zeros((stride, stride * 4, 4), dtype=np.uint8)
    damage[..., 3] = 255
    for step in range(4):
        speckle = periodic_noise(16, 1.0) + periodic_noise(32, 0.6)
        marks = np.clip((speckle - (0.45 - step * 0.12)) * 4, 0, 1) * (0.5 + step * 0.12)
        damage[:, step * stride:(step + 1) * stride, 0] = np.pad((1 - marks) * 255, PAD, mode="wrap")
    Image.fromarray(damage, "RGBA").save(DAMAGE_OUT)
    print(f"wrote {DAMAGE_OUT.relative_to(DAMAGE_OUT.parents[3])}")

    # Last, so the seeded noise above stays as it was.
    iy, ix = np.mgrid[0:ICON, 0:ICON].astype(np.float32)
    d = np.hypot(ix - ICON / 2 + 0.5, iy - ICON / 2 + 0.5)
    ring = np.clip(1 - np.abs(d - ICON * 0.36) / 3.0, 0, 1)
    icon = np.zeros((ICON, ICON, 4), dtype=np.uint8)
    icon[..., :3] = 200
    icon[..., 3] = (ring * 255).astype(np.uint8)
    Image.fromarray(icon, "RGBA").save(ICON_OUT)
    print(f"wrote {ICON_OUT.relative_to(ICON_OUT.parents[3])}")

    # The mine: a disc with eight spikes (its radius swells to 1 at each spike's tip), a rim
    # and a red lamp in the middle, lit from the upper left.
    c = ICON / 2 - 0.5
    angle = np.arctan2(iy - c, ix - c)
    d = np.hypot(ix - c, iy - c) / (ICON / 2)
    spikes = np.clip(np.cos(angle * 8), 0, 1) ** 6
    edge = 0.62 + 0.36 * spikes
    inside = np.clip((edge - d) * ICON / 2, 0, 1)
    light = 0.55 + 0.35 * np.clip(((c - ix) + (c - iy)) / ICON, -1, 1)
    grey = np.where(np.abs(d - 0.6) < 0.05, 0.3, light)
    lamp = np.clip((0.2 - d) * ICON / 2, 0, 1)
    mine = np.zeros((ICON, ICON, 4), dtype=np.uint8)
    mine[..., 0] = np.clip((grey * (1 - lamp) + 0.95 * lamp) * 255, 0, 255)
    mine[..., 1] = np.clip(grey * (1 - lamp) * 255 + lamp * 40, 0, 255)
    mine[..., 2] = np.clip(grey * (1 - lamp) * 255 + lamp * 30, 0, 255)
    mine[..., 3] = (inside * 255).astype(np.uint8)
    Image.fromarray(mine, "RGBA").save(MINE_OUT)
    print(f"wrote {MINE_OUT.relative_to(MINE_OUT.parents[3])}")

    # Every vis.ui.* piece: a dark box with a grey rim (UiTheme keeps its flat boxes until the
    # real chrome is in, so this only shows if something draws the texture itself).
    chrome = np.zeros((ICON, ICON, 4), dtype=np.uint8)
    chrome[...] = (150, 156, 164, 255)
    chrome[4:-4, 4:-4, :3] = (20, 24, 32)
    Image.fromarray(chrome, "RGBA").save(CHROME_OUT)
    print(f"wrote {CHROME_OUT.relative_to(CHROME_OUT.parents[3])}")

    # Every vis.portrait.*: a grey bust (head and shoulders) on transparent, and an empty mask
    # (nothing recoloured). PortraitView draws its own bust until the real art is in.
    head = np.hypot(ix - ICON / 2, iy - ICON * 0.34) < ICON * 0.18
    shoulders = np.hypot((ix - ICON / 2) / 1.6, iy - ICON * 1.02) < ICON * 0.3
    bust = np.zeros((ICON, ICON, 4), dtype=np.uint8)
    bust[..., :3] = 150
    bust[..., 3] = ((head | shoulders) * 255).astype(np.uint8)
    Image.fromarray(bust, "RGBA").save(PORTRAIT_OUT)
    Image.fromarray(np.zeros((ICON, ICON, 4), dtype=np.uint8), "RGBA").save(PORTRAIT_MASK_OUT)
    print(f"wrote {PORTRAIT_OUT.relative_to(PORTRAIT_OUT.parents[3])} and portrait_mask.png")

    # A.8-A.10 stand-ins: an asteroid (a lumpy grey disc), a nebula (flat deep space, so the
    # starfield adds nothing), and a station's backdrop (navy), exterior (a grey block) and room
    # (dark teal).
    c = ICON / 2 - 0.5
    lump = 0.8 + 0.12 * np.cos(np.arctan2(iy - c, ix - c) * 5)
    rock = np.zeros((ICON, ICON, 4), dtype=np.uint8)
    rock[..., :3] = 122
    rock[..., 3] = (np.clip((lump - np.hypot(ix - c, iy - c) / (ICON / 2)) * ICON / 2, 0, 1) * 255).astype(np.uint8)
    flat = {"asteroid.png": rock}
    for name, colour in [("nebula.png", (2, 11, 21)), ("station_backdrop.png", (6, 36, 72)),
                         ("station_room.png", (31, 51, 50))]:
        block = np.zeros((ICON, ICON, 4), dtype=np.uint8)
        block[...] = colour + (255,)
        flat[name] = block
    station = np.zeros((ICON, ICON, 4), dtype=np.uint8)
    station[ICON // 3:2 * ICON // 3, 4:-4] = (122, 131, 141, 255)
    flat["station.png"] = station
    for name, pixels in flat.items():
        Image.fromarray(pixels, "RGBA").save(OUT.with_name(name))
    print("wrote " + ", ".join(flat))


if __name__ == "__main__":
    main()
