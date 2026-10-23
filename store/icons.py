"""Renders the fork's icons: linden leaf as a heart inside a rosary.

Writes
  store/icon.svg, store/icon-lowcolor.svg              sources
  store/icon-500.png                                   Connect IQ Store app icon (500x500, sRGB)
  store/icon-128.png, store/icon-128-lowcolor.png      optional on-device store icons (OLED / MIP)
  resources-fork/drawables/launcher_icon.png           launcher icon (round, transparent corners)

Needs Python with Pillow and Google Chrome (used headless to rasterise the SVG).
Run from anywhere:  python store/icons.py
"""
import math
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "store")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

FULL = {"bg": "#1D4F9E", "gold": "#F2C14E", "leaf": "#7CB342", "vein": "#2E6B30"}
# Connect IQ low-colour (MIP) palette: every channel is one of 00/55/AA/FF
LOW = {"bg": "#0055AA", "gold": "#FFAA55", "leaf": "#55AA55", "vein": "#005500"}
LOW_PALETTE = [(r, g, b) for r in (0, 85, 170, 255) for g in (0, 85, 170, 255) for b in (0, 85, 170, 255)]


def artwork(c):
    """The icon on a 500x500 canvas, without background."""
    parts = []
    # rosary: ring of beads open at the bottom, drop bead and a Latin cross
    cx, cy, r, n, bead, gap = 250, 210, 165, 26, 13, 40
    for i in range(n):
        a = math.radians(90 + gap / 2 + i * (360 - gap) / (n - 1))
        parts.append(f'<circle cx="{cx + r * math.cos(a):.1f}" cy="{cy + r * math.sin(a):.1f}" r="{bead}" fill="{c["gold"]}"/>')
    by = cy + r
    parts.append(f'<circle cx="{cx}" cy="{by + 4}" r="{bead + 3}" fill="{c["gold"]}"/>')
    parts.append(f'<rect x="{cx - 9}" y="{by + 20}" width="18" height="91" rx="3" fill="{c["gold"]}"/>')
    parts.append(f'<rect x="{cx - 30}" y="{by + 38}" width="60" height="18" rx="3" fill="{c["gold"]}"/>')
    # linden leaf drawn as a heart: notch with the stem at the top, tip at the bottom
    leaf = [
        f'<path d="M250 148 C 232 102, 150 98, 148 168 C 146 222, 205 262, 250 312 C 295 262, 354 222, 352 168 C 350 98, 268 102, 250 148 Z" fill="{c["leaf"]}"/>',
        f'<path d="M250 150 Q 252 118, 270 98" stroke="{c["leaf"]}" stroke-width="10" stroke-linecap="round" fill="none"/>',
    ]
    for d in ("M250 150 L250 292", "M250 150 Q 210 150, 185 175", "M250 150 Q 290 150, 315 175",
              "M250 200 L200 222", "M250 200 L300 222", "M250 245 L222 262", "M250 245 L278 262"):
        leaf.append(f'<path d="{d}" stroke="{c["vein"]}" stroke-width="6" stroke-linecap="round" fill="none"/>')
    # the heart sits slightly below the ring centre to look optically centred
    parts.append('<g transform="translate(0,9)">' + "".join(leaf) + "</g>")
    return "\n  ".join(parts)


def svg(c):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500" width="500" height="500">\n'
            f'  <rect width="500" height="500" fill="{c["bg"]}"/>\n  {artwork(c)}\n</svg>\n')


def render(svg_path, size):
    """Rasterises the SVG with headless Chrome at size x size."""
    with tempfile.TemporaryDirectory() as tmp:
        html = os.path.join(tmp, "page.html")
        png = os.path.join(tmp, "shot.png")
        with open(html, "w", encoding="utf-8") as f:
            f.write(f'<html><body style="margin:0"><img src="file:///{svg_path.replace(os.sep, "/")}" '
                    f'width="{size}" height="{size}" style="display:block"></body></html>')
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        f"--window-size={size},{size}", f"--screenshot={png}", html],
                       check=True, capture_output=True)
        return Image.open(png).convert("RGB").copy()


def to_low_palette(im):
    """Maps every pixel to the nearest MIP palette colour (no dithering)."""
    pal = Image.new("P", (1, 1))
    flat = [v for rgb in LOW_PALETTE for v in rgb]
    pal.putpalette(flat + flat[:3] * (256 - len(LOW_PALETTE)))
    return im.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")


def round_launcher(im):
    """Round icon with transparent corners, supersampled for a smooth edge."""
    big = 4 * im.width
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, big - 1, big - 1), fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask.resize(im.size, Image.LANCZOS))
    return out


def main():
    full_svg = os.path.join(STORE, "icon.svg")
    low_svg = os.path.join(STORE, "icon-lowcolor.svg")
    for path, colours in ((full_svg, FULL), (low_svg, LOW)):
        with open(path, "w", encoding="utf-8") as f:
            f.write(svg(colours))

    render(full_svg, 500).save(os.path.join(STORE, "icon-500.png"))
    render(full_svg, 128).save(os.path.join(STORE, "icon-128.png"))
    to_low_palette(render(low_svg, 128)).save(os.path.join(STORE, "icon-128-lowcolor.png"))

    drawables = os.path.join(ROOT, "resources-fork", "drawables")
    os.makedirs(drawables, exist_ok=True)
    round_launcher(render(full_svg, 256)).save(os.path.join(drawables, "launcher_icon.png"))


if __name__ == "__main__":
    main()
