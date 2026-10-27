"""Build the game's icon and splash files from the owner's art in art_src/ (A.11).

    tools/run.sh python3 -I tools/make_branding.py

Reads  art_src/icons/app_icon_1.jpeg        a 1024 px rounded square, white outside its corners
       art_src/backgrounds/splash_3.jpeg    16:9, the action at the top, its lower half calm
       game/assets/fonts/Orbitron.ttf       the title face (OFL)
Writes game/assets/branding/:
  icon.png                  512 px, the project icon (window, desktop, store), its corners clear
  android_icon_192.png      Android's legacy launcher icon
  android_fg_432.png        adaptive icon foreground: the whole icon inside the safe zone, small
                            enough that even a round mask doesn't cut the ship's nose or flames
  android_bg_432.png        adaptive icon background: the icon's own deep blue
  splash.png                the boot splash: cropped to the reference phone's 2.17:1 (Godot shows
                            it with stretch mode Cover, so other screens trim a little more), with
                            the title set in Orbitron across its calm lower part. Gemini paints no
                            text, because its text was the first splash's worst failure.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "art_src" / "icons" / "app_icon_1.jpeg"
SPLASH = ROOT / "art_src" / "backgrounds" / "splash_3.jpeg"
FONT = ROOT / "game" / "assets" / "fonts" / "Orbitron.ttf"
OUT = ROOT / "game" / "assets" / "branding"

# The icon art's own rounded corners, in its 1024 px.
ICON_RADIUS = 170
ADAPTIVE = 432
# Android shows the inner 72 of 108 dp (288 of 432 px) under any mask; a round one clears the
# ship's nose and flames at this size.
SAFE = 256

SPLASH_ASPECT = 2600 / 1200
SPLASH_TOP = 24 / 768          # the crop's top, as a fraction of the source height
TITLE = "MOBILE SPACE SHOOTER"
TITLE_Y = 0.83                 # the title's middle, as a fraction of the cropped height
TITLE_WIDTH = 0.62             # of the cropped width
GOLD = (243, 205, 55)
OUTLINE = (58, 22, 6)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    art = Image.open(ICON).convert("RGBA")
    corners = Image.new("L", art.size, 0)
    ImageDraw.Draw(corners).rounded_rectangle((0, 0, art.width - 1, art.height - 1), ICON_RADIUS, fill=255)
    icon = art.copy()
    icon.putalpha(corners)
    icon = icon.resize((512, 512), Image.LANCZOS)
    icon.save(OUT / "icon.png")
    icon.resize((192, 192), Image.LANCZOS).save(OUT / "android_icon_192.png")
    foreground = Image.new("RGBA", (ADAPTIVE, ADAPTIVE), (0, 0, 0, 0))
    small = icon.resize((SAFE, SAFE), Image.LANCZOS)
    foreground.paste(small, ((ADAPTIVE - SAFE) // 2,) * 2, small)
    foreground.save(OUT / "android_fg_432.png")
    # The backdrop colour: the median along the art's top edge, between its corners (a single
    # pixel can land on a star).
    strip = sorted(art.crop((ICON_RADIUS, 8, art.width - ICON_RADIUS, 16)).convert("RGB").getdata(), key=sum)
    backdrop = strip[len(strip) // 2]
    Image.new("RGBA", (ADAPTIVE, ADAPTIVE), backdrop[:3] + (255,)).save(OUT / "android_bg_432.png")

    splash = Image.open(SPLASH).convert("RGB")
    top = round(splash.height * SPLASH_TOP)
    splash = splash.crop((0, top, splash.width, top + round(splash.width / SPLASH_ASPECT)))
    font = ImageFont.truetype(str(FONT), 100)
    font.set_variation_by_name("Black")
    size = 100 * TITLE_WIDTH * splash.width / font.getlength(TITLE)
    font = ImageFont.truetype(str(FONT), round(size))
    font.set_variation_by_name("Black")
    draw = ImageDraw.Draw(splash)
    draw.text((splash.width / 2, splash.height * TITLE_Y), TITLE, font=font, fill=GOLD, anchor="mm",
              stroke_width=max(2, round(size / 12)), stroke_fill=OUTLINE)
    splash.save(OUT / "splash.png", optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}: icon.png, android_icon_192.png, android_fg_432.png, "
          f"android_bg_432.png (#{backdrop[0]:02x}{backdrop[1]:02x}{backdrop[2]:02x}), splash.png ({splash.width}x{splash.height}, title {round(size)} px)")


if __name__ == "__main__":
    main()
