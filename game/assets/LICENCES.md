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
| `branding/` | generated | Herman Ras | see GeminiCopyRight.md | Icon and splash (A.11), built by `tools/make_branding.py` from the Gemini masters `art_src/icons/app_icon_1.jpeg` and `art_src/backgrounds/splash_3.jpeg` (original ships in the game's tile style; the X-wing-like first splash is retired), the splash's title set in Orbitron (see `fonts/`) |
| `tiles/` | generated | Herman Ras | see GeminiCopyRight.md | Tile materials, the core and damage overlays (A.1) and the thruster nozzles (A.2), cut and packed by `tools/slice_sheets.py` from the Gemini masters `art_src/tiles/tiles_materials.jpeg`, `tiles_cores_shields.jpeg` and `art_src/parts/parts_thrusters.jpeg` |
| `parts/` | generated | Herman Ras | see GeminiCopyRight.md | Gun heads (A.3), cut and packed by `tools/slice_sheets.py` from the Gemini masters `art_src/parts/parts_guns_1.jpeg` and `parts_guns_2.jpeg`, `parts_guns_flak_seeker_1`/`_3.jpeg` and `parts_guns_edge_v2_1`/`_2.jpeg` (the side guns, A.3c); the other masters hold spares |
| `icons/` | generated | Herman Ras | see GeminiCopyRight.md | Resource, HUD and power-up icons (A.4) and the map icons `map_*` (A.6), cut by `tools/slice_sheets.py` from the Gemini masters `art_src/icons/icons_main_2.jpeg` and `icons_map_2.jpeg` (the other runs are spares) |
| `fx/` | generated | Herman Ras | see GeminiCopyRight.md | The mine in space (A.3d), cut by `tools/slice_sheets.py` from the Gemini master `art_src/parts/fx_mines_1.jpeg` (runs 2 and 3 are spares) |
| `ui/` | generated | Herman Ras | see GeminiCopyRight.md | The UI chrome (A.5): panel, header, frame, buttons and bars, cut by `tools/slice_sheets.py` from the Gemini masters `art_src/ui/chrome_panel_2`, `chrome_header_3`, `chrome_frame_2` `chrome_buttons_1` and the title plate `title_plate_2` (A.11) (`.jpeg`; the other runs are spares). Style reference: `insperationPictures/Menu Theme.png` |
| `world/` | generated | Herman Ras | see GeminiCopyRight.md | Asteroids (A.10), cut by `tools/slice_sheets.py` from the Gemini master `art_src/parts/world_asteroids_1.jpeg` |
| `space/` | generated | Herman Ras | see GeminiCopyRight.md | Arena nebulae (A.9), made seamless by `tools/slice_sheets.py` from the Gemini masters `art_src/backgrounds/arena_nebula_*.jpeg` (one run of two per nebula) |
| `stations/` | generated | Herman Ras | see GeminiCopyRight.md | Station backdrops, exteriors and rooms (A.8), cut by `tools/slice_sheets.py` from the Gemini masters `art_src/stations/station_*.jpeg` (the picks are in `art_src/sheets.json`) |
| `fonts/` | Orbitron, by The Orbitron Project Authors (Matt McInerney) | Google Fonts (github.com/google/fonts, ofl/orbitron) | SIL OFL 1.1, `fonts/Orbitron-OFL.txt` | The title face (§6.4): the main menu's title and the splash |
| `portraits/` | generated | Herman Ras | see GeminiCopyRight.md | The portraits (A.7): the male and female player bases in a jacket and a space suit (painted in recolour key hues) and the villain and ally stand-ins, 4 moods each, cut by `tools/slice_sheets.py` from the Gemini masters `art_src/portraits/portraits_*_1.jpeg` (the suits are image edits of the jackets); `masks/` are their recolour masks, made from the same art by the slicer |
