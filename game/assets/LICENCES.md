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
| `parts/` | generated | Herman Ras | see GeminiCopyRight.md | Gun heads (A.3), cut and packed by `tools/slice_sheets.py` from the Gemini masters `art_src/parts/parts_guns_1.jpeg` and `parts_guns_2.jpeg`, `parts_guns_flak_seeker_1`/`_3.jpeg` and `parts_guns_edge_v2_1`/`_2.jpeg` (the side guns, A.3c); the other masters hold spares |
| `icons/` | generated | Herman Ras | see GeminiCopyRight.md | Resource, HUD and power-up icons (A.4), cut by `tools/slice_sheets.py` from the Gemini master `art_src/icons/icons_main_2.jpeg` (runs 1 and 3 are spares) |
| `fx/` | generated | Herman Ras | see GeminiCopyRight.md | The mine in space (A.3d), cut by `tools/slice_sheets.py` from the Gemini master `art_src/parts/fx_mines_1.jpeg` (runs 2 and 3 are spares) |
| `ui/` | generated | Herman Ras | see GeminiCopyRight.md | The UI chrome (A.5): panel, header, frame, buttons and bars, cut by `tools/slice_sheets.py` from the Gemini masters `art_src/ui/chrome_panel_2`, `chrome_header_3`, `chrome_frame_2` and `chrome_buttons_1` (`.jpeg`; the other runs are spares). Style reference: `insperationPictures/Menu Theme.png` |
| `portraits/` | generated | Herman Ras | see GeminiCopyRight.md | The portraits (A.7): the male and female player bases in a jacket and a space suit (painted in recolour key hues) and the villain and ally stand-ins, 4 moods each, cut by `tools/slice_sheets.py` from the Gemini masters `art_src/portraits/portraits_*_1.jpeg` (the suits are image edits of the jackets); `masks/` are their recolour masks, made from the same art by the slicer |
