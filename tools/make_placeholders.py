"""Generate the placeholder tile-material atlas (PLAN.md 6.2) until Gemini art lands (A.1).

    tools/run.sh python3 -I tools/make_placeholders.py

Writes game/assets/placeholders/tile_atlas.png: one 128 px cell per tile type, left to right
in CELLS order. Each cell is seamless. Channels follow the ship shader's contract:
    R = greyscale detail (multiplied with the paint colour)
    G = trim mask (drawn untinted, e.g. the shield's emitter lines)
    B = unused, A = 255
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

CELL = 128
CELLS = ["core", "hull", "armor", "shield", "hardpoint"]
OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "placeholders" / "tile_atlas.png"

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


def main() -> None:
    makers = {"core": core, "hull": hull, "armor": armor, "shield": shield, "hardpoint": hardpoint}
    atlas = np.zeros((CELL, CELL * len(CELLS), 4), dtype=np.uint8)
    for i, name in enumerate(CELLS):
        detail, trim = makers[name]()
        cell = atlas[:, i * CELL:(i + 1) * CELL]
        cell[..., 0] = np.clip(detail, 0, 1) * 255
        cell[..., 1] = np.clip(trim, 0, 1) * 255
        cell[..., 3] = 255
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(atlas, "RGBA").save(OUT)
    print(f"wrote {OUT.relative_to(OUT.parents[3])} ({atlas.shape[1]}x{atlas.shape[0]}, cells: {', '.join(CELLS)})")


if __name__ == "__main__":
    main()
