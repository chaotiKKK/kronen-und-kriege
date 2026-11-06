#!/usr/bin/env python3
"""Erzeugt Titelbild und Wortmarke für „Kronen und Kriege“.

Drei Figuren aus dem neuen Charakterpool werden freigestellt, entrauscht und
als Gruppe vor einen dunklen, warm ausgeleuchteten Hintergrund gesetzt. Die
Wortmarke liegt separat, damit sie auf 16:9- und 20:9-Geräten unabhängig vom
Hintergrundanschnitt sitzt.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
W, H = 1920, 1080
GOLD_TOP = (248, 229, 176)
GOLD_BOTTOM = (176, 121, 42)
DARK = (30, 18, 8)
FONT_BOLD = "C:/Windows/Fonts/GeorgiaPro-Bold.ttf"
FONT_REG = "C:/Windows/Fonts/GeorgiaPro-Regular.ttf"


def radial_background() -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = yy / H
    base = np.zeros((H, W, 3), dtype=np.float32)
    base[:, :, 0] = 8 + 20 * t
    base[:, :, 1] = 6 + 13 * t
    base[:, :, 2] = 4 + 8 * t

    def glow(cx: float, cy: float, rx: float, ry: float, colour: tuple[int, int, int], strength: float):
        d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
        a = np.clip(1.0 - d, 0.0, 1.0) ** 2 * strength
        for c in range(3):
            base[:, :, c] += colour[c] * a

    glow(840, 500, 760, 620, (96, 62, 30), 1.0)
    glow(1180, 420, 430, 430, (62, 44, 30), 0.7)
    glow(300, 760, 500, 340, (44, 28, 16), 0.55)

    # Feiner Goldring als Bühnenhintergrund.
    d = np.sqrt(((xx - 870) / 610) ** 2 + ((yy - 520) / 610) ** 2)
    ring = np.exp(-((d - 1.0) / 0.012) ** 2)
    for c, v in enumerate((150, 108, 52)):
        base[:, :, c] += ring * v * 0.20

    # Vignette und Filmkorn.
    vx = (xx / W - 0.5) * 2.0
    vy = (yy / H - 0.5) * 2.0
    vig = np.clip(1.06 - 0.44 * (vx * vx + vy * vy), 0.38, 1.0)
    base *= vig[:, :, None]
    rng = np.random.default_rng(7)
    base += rng.normal(0, 2.6, (H, W, 1))
    base = np.clip(base, 0, 255).astype(np.uint8)
    im = Image.fromarray(base, "RGB")

    # Weiche Lichtstrahlen von oben.
    rays = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    for x0, spread in [(-100, 380), (420, 250), (980, 300), (1460, 260)]:
        rd.polygon([(x0, -60), (x0 + spread, -60), (x0 + spread + 380, H), (x0 + 260, H)],
                   fill=(208, 164, 96, 10))
    rays = rays.filter(ImageFilter.GaussianBlur(46))
    im = Image.alpha_composite(im.convert("RGBA"), rays)
    return im


def character(cid: int, height: int, centre_x: int, bottom_y: int, darken: float) -> Image.Image:
    im = Image.open(ROOT / "assets" / "characters" / f"character_{cid:02d}.png").convert("RGBA")
    # Erosion entfernt den hellen Saum des ursprünglichen Studiohintergrunds.
    im.putalpha(im.getchannel("A").filter(ImageFilter.MinFilter(3)))
    scale = height / im.height
    im = im.resize((max(1, int(im.width * scale)), height), Image.Resampling.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=55, threshold=2))
    if darken < 1.0:
        arr = np.asarray(im).astype(np.float32)
        arr[:, :, :3] *= darken
        im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    im._centre_x = centre_x  # type: ignore[attr-defined]
    im._bottom_y = bottom_y  # type: ignore[attr-defined]
    return im


def place(canvas: Image.Image, im: Image.Image, centre_x: int, bottom_y: int, glow: int = 0) -> None:
    x = centre_x - im.width // 2
    y = bottom_y - im.height
    alpha = im.getchannel("A")
    if glow > 0:
        halo = Image.new("RGBA", im.size, (214, 158, 82, 255))
        halo.putalpha(alpha.filter(ImageFilter.GaussianBlur(16)).point(lambda v: int(v * 0.48)))
        canvas.alpha_composite(halo, (x, y))
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 255))
    shadow.putalpha(alpha.filter(ImageFilter.GaussianBlur(26)).point(lambda v: int(v * 0.55)))
    canvas.alpha_composite(shadow, (x + 26, y + 26))
    canvas.alpha_composite(im, (x, y))


def spaced(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, font: ImageFont.FreeTypeFont,
           fill, spacing: int, stroke_width: int = 0, stroke_fill=None) -> int:
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill, stroke_width=stroke_width,
                  stroke_fill=stroke_fill)
        x += int(round(font.getlength(ch))) + spacing
    return x


def text_width(text: str, font: ImageFont.FreeTypeFont, spacing: int) -> int:
    return int(round(sum(font.getlength(c) for c in text) + spacing * (len(text) - 1)))


def gold_text(canvas: Image.Image, text: str, font: ImageFont.FreeTypeFont, centre_x: int,
              top: int, spacing: int, stroke: int = 4) -> None:
    mask = Image.new("L", (canvas.width, canvas.height), 0)
    md = ImageDraw.Draw(mask)
    width = text_width(text, font, spacing)
    spaced(md, (centre_x - width // 2, top), text, font, 255, spacing)

    grad = Image.new("RGB", (canvas.width, canvas.height))
    gd = ImageDraw.Draw(grad)
    for y in range(canvas.height):
        k = min(1.0, max(0.0, (y - top) / 150.0))
        col = tuple(int(GOLD_TOP[i] * (1 - k) + GOLD_BOTTOM[i] * k) for i in range(3))
        gd.line((0, y, canvas.width, y), fill=col)

    shadow = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(7)).point(lambda v: int(v * 0.62)))
    canvas.alpha_composite(shadow, (0, 7))

    outline = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(outline)
    spaced(od, (centre_x - width // 2, top), text, font, (0, 0, 0, 0), spacing,
           stroke_width=stroke, stroke_fill=DARK + (255,))
    canvas.alpha_composite(outline)

    fill = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    fill.paste(grad, (0, 0), mask)
    canvas.alpha_composite(fill)


def crown(canvas: Image.Image, cx: int, cy: int) -> None:
    pts = [(cx - 102, cy + 62), (cx - 112, cy - 34), (cx - 60, cy + 4), (cx, cy - 72),
           (cx + 60, cy + 4), (cx + 112, cy - 34), (cx + 102, cy + 62)]
    mask = Image.new("L", canvas.size, 0)
    md = ImageDraw.Draw(mask)
    md.polygon(pts, fill=255)
    md.rectangle((cx - 102, cy + 55, cx + 102, cy + 84), fill=255)
    grad = Image.new("RGB", canvas.size)
    gd = ImageDraw.Draw(grad)
    for y in range(canvas.height):
        k = min(1.0, max(0.0, (y - (cy - 80)) / 170.0))
        col = tuple(int(GOLD_TOP[i] * (1 - k) + GOLD_BOTTOM[i] * k) for i in range(3))
        gd.line((0, y, canvas.width, y), fill=col)
    outline = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(outline)
    od.polygon(pts, fill=DARK + (255,), outline=DARK + (255,), width=5)
    od.rectangle((cx - 102, cy + 55, cx + 102, cy + 84), outline=DARK + (255,), width=5)
    canvas.alpha_composite(outline)
    fill = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    fill.paste(grad, (0, 0), mask)
    canvas.alpha_composite(fill)
    d = ImageDraw.Draw(canvas)
    for jx, jy, col in [(cx - 112, cy - 30, (150, 34, 30)), (cx, cy - 68, (46, 82, 120)),
                        (cx + 112, cy - 30, (52, 96, 62)), (cx, cy + 69, (150, 34, 30))]:
        d.ellipse((jx - 9, jy - 9, jx + 9, jy + 9), fill=col, outline=DARK, width=3)
        d.ellipse((jx - 4, jy - 5, jx + 1, jy), fill=(255, 232, 180, 190))
    # Ziselierung
    for off in (-64, -32, 0, 32, 64):
        d.line((cx + off, cy + 10, cx + off, cy + 54), fill=(110, 74, 28, 150), width=2)


def ribbon(canvas: Image.Image, cx: int, y: int, width: int, height: int, text: str,
           font: ImageFont.FreeTypeFont) -> None:
    d = ImageDraw.Draw(canvas)
    left = cx - width // 2
    right = cx + width // 2
    body = [(left, y), (right, y), (right, y + height), (left, y + height)]
    tail_l = [(left, y), (left - 34, y + 9), (left - 22, y + height // 2),
              (left - 40, y + height - 8), (left, y + height)]
    tail_r = [(right, y), (right + 34, y + 9), (right + 22, y + height // 2),
              (right + 40, y + height - 8), (right, y + height)]
    d.polygon(tail_l, fill=(86, 20, 17, 255), outline=(34, 10, 8, 255))
    d.polygon(tail_r, fill=(86, 20, 17, 255), outline=(34, 10, 8, 255))
    d.polygon(body, fill=(126, 31, 26, 255), outline=(42, 12, 9, 255))
    d.line((left, y + 5, right, y + 5), fill=(196, 138, 60, 170), width=2)
    d.line((left, y + height - 5, right, y + height - 5), fill=(60, 16, 12, 220), width=2)
    tw = text_width(text, font, 3)
    spaced(d, (cx - tw // 2, y + (height - font.size) // 2 - 3), text, font,
           (247, 231, 190, 255), 3)


def logo() -> Image.Image:
    canvas = Image.new("RGBA", (660, 640), (0, 0, 0, 0))
    crown(canvas, 330, 96)
    f_big = ImageFont.truetype(FONT_BOLD, 112)
    f_mid = ImageFont.truetype(FONT_BOLD, 72)
    f_small = ImageFont.truetype(FONT_REG, 22)
    f_ribbon = ImageFont.truetype(FONT_BOLD, 27)
    gold_text(canvas, "KRONEN", f_big, 330, 178, 10, stroke=4)
    gold_text(canvas, "UND KRIEGE", f_mid, 330, 306, 13, stroke=4)

    d = ImageDraw.Draw(canvas)
    d.line((150, 420, 300, 420), fill=(196, 152, 78, 210), width=2)
    d.line((360, 420, 510, 420), fill=(196, 152, 78, 210), width=2)
    d.polygon([(330, 411), (340, 420), (330, 429), (320, 420)], fill=(214, 170, 96, 255))

    sub = "BRONZEZEIT · GRAND STRATEGY"
    sw = text_width(sub, f_small, 4)
    spaced(d, (330 - sw // 2, 444), sub, f_small, (206, 180, 132, 255), 4)

    ribbon(canvas, 330, 500, 470, 62, "BRONZEZEIT EDITION", f_ribbon)
    return canvas


def main() -> None:
    bg = radial_background()
    left = character(15, 1120, 430, 1260, 0.78)
    queen = character(19, 1210, 845, 1290, 1.0)
    right = character(39, 1110, 1150, 1250, 0.74)
    place(bg, left, 430, 1260, glow=0)
    place(bg, right, 1150, 1250, glow=0)
    place(bg, queen, 845, 1290, glow=1)

    # Rechte Seite für Wortmarke und Menü abdunkeln.
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for x in range(1180, W):
        a = int(150 * min(1.0, (x - 1180) / 520.0))
        sd.line((x, 0, x, H), fill=(4, 3, 2, a))
    for y in range(840, H):
        a = int(95 * (y - 840) / (H - 840))
        sd.line((0, y, W, y), fill=(4, 3, 2, a))
    bg = Image.alpha_composite(bg, shade)

    bg.convert("RGB").save(ROOT / "assets" / "ui" / "title_bg.png", optimize=True)
    lg = logo()
    lg.save(ROOT / "assets" / "ui" / "logo_title.png", optimize=True)

    preview = bg.copy()
    small = lg.resize((560, int(560 * lg.height / lg.width)), Image.Resampling.LANCZOS)
    preview.alpha_composite(small, (1352, 92))
    preview.convert("RGB").save(ROOT / "preview" / "title_screen.png", optimize=True)
    preview.convert("RGB").resize((1280, 720), Image.Resampling.LANCZOS).save(
        ROOT / "preview" / "title_screen.jpg", quality=90)
    print("Titelbild:", (ROOT / "assets" / "ui" / "title_bg.png").stat().st_size,
          "Bytes; Logo:", (ROOT / "assets" / "ui" / "logo_title.png").stat().st_size, "Bytes")


if __name__ == "__main__":
    main()
