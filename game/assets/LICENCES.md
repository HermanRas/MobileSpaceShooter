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
| `branding/` | generated | Herman Ras | see GeminiCopyRight.md | Icon and splash, built from `art_src/icons/` and `art_src/backgrounds/` by `tools/make_branding.py`. Before release (15.3): two fighters in the splash look a lot like Star Wars X-wings |
