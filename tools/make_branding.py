"""Build the game's icon and splash files from the owner's art in art_src/.

    tools/run.sh python3 -I tools/make_branding.py

Reads  art_src/icons/Icon-512x512.png   (rounded square with transparent corners)
       art_src/backgrounds/Spash.jpeg   (16:9 splash)
Writes game/assets/branding/:
  icon.png                  512 px, the project icon (window, desktop, store)
  android_icon_192.png      Android's legacy launcher icon
  android_fg_432.png        adaptive icon foreground: the whole icon inside the safe zone, small
                            enough that even a round mask doesn't cut the title text
  android_bg_432.png        adaptive icon background: the icon's own dark backdrop colour
  splash.png                the boot splash, cropped to the reference phone's 2.17:1 (Godot shows
                            it with stretch mode Cover, so other screens trim a little more)
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "art_src" / "icons" / "Icon-512x512.png"
SPLASH = ROOT / "art_src" / "backgrounds" / "Spash.jpeg"
OUT = ROOT / "game" / "assets" / "branding"

# The splash keeps the rows down to the bottom of the title and drops the art's baked-in
# loading bar (a frozen "68%" reads as a hang). As fractions of the source height.
SPLASH_BOTTOM = 676 / 768
SPLASH_ASPECT = 2600 / 1200

ADAPTIVE = 432
# Android shows the inner 72 of 108 dp (288 of 432 px) under any mask. The title text runs
# close to the icon's bottom corners, so the art is shrunk until a round mask clears it.
SAFE = 256


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    icon = Image.open(ICON).convert("RGBA")
    icon.save(OUT / "icon.png")
    icon.resize((192, 192), Image.LANCZOS).save(OUT / "android_icon_192.png")

    foreground = Image.new("RGBA", (ADAPTIVE, ADAPTIVE), (0, 0, 0, 0))
    small = icon.resize((SAFE, SAFE), Image.LANCZOS)
    offset = (ADAPTIVE - SAFE) // 2
    foreground.paste(small, (offset, offset), small)
    foreground.save(OUT / "android_fg_432.png")

    # The backdrop colour: a pixel just inside the icon's border, top-left.
    backdrop = icon.getpixel((icon.width // 6, icon.height // 6))
    Image.new("RGBA", (ADAPTIVE, ADAPTIVE), backdrop[:3] + (255,)).save(OUT / "android_bg_432.png")

    splash = Image.open(SPLASH).convert("RGB")
    bottom = round(splash.height * SPLASH_BOTTOM)
    top = max(0, bottom - round(splash.width / SPLASH_ASPECT))
    splash.crop((0, top, splash.width, bottom)).save(OUT / "splash.png", optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}: icon.png, android_icon_192.png, android_fg_432.png, "
          f"android_bg_432.png (backdrop #{backdrop[0]:02x}{backdrop[1]:02x}{backdrop[2]:02x}), splash.png")


if __name__ == "__main__":
    main()
