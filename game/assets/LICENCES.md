# Asset licences

Every file under `game/assets/` (except `.import` files and this file) needs a row here.
`tools/licence_audit.py` fails when one is missing.

**Source** is one of:

- `generated` — made by the project owner with Google Gemini. Effectively unprotectable, not
  MIT (see [GeminiCopyRight.md](../../GeminiCopyRight.md)).
- `project` — made for this project by hand or by code. MIT, like the code.
- `third-party` — someone else's work. Name the author, the licence and a link.

Rows may name a folder (ending in `/`) when every file in it shares one source.

| Path (under `game/assets/`) | Source | Author | Licence | Link / notes |
|---|---|---|---|---|
| `placeholders/` | project | Herman Ras | MIT | Stand-in art, replaced by the art track |
| `branding/` | generated | Herman Ras | see GeminiCopyRight.md | Icon and splash, built from `art_src/icons/` and `art_src/backgrounds/` by `tools/make_branding.py`. Gemini (owner confirmed). The splash is temporary: it has X-wing-like fighters and gets regenerated from in-game ships (PLAN.md 15.3) |
| `tiles/` | generated | Herman Ras | see GeminiCopyRight.md | Tile materials, the core and damage overlays (A.1) and the thruster nozzles (A.2), cut and packed by `tools/slice_sheets.py` from the Gemini masters `art_src/tiles/tiles_materials.jpeg`, `tiles_cores_shields.jpeg` and `art_src/parts/parts_thrusters.jpeg` |
| `parts/` | generated | Herman Ras | see GeminiCopyRight.md | Gun heads (A.3), cut and packed by `tools/slice_sheets.py` from the Gemini masters `art_src/parts/parts_guns_1.jpeg` and `parts_guns_2.jpeg` (`parts_guns_3.jpeg` holds spares) |
