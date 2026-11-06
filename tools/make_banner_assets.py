#!/usr/bin/env python3
"""Heraldik-Bausteine für den Banner-Generator.

Alle Formen sind eigene Vektorgeometrie. Die Symbole werden als weiße
Alpha-Silhouetten gespeichert, damit Godot sie mit jeder Wappenfarbe tönen kann.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SYM = ROOT / "assets" / "banners" / "symbols"
TPL = ROOT / "assets" / "banners" / "templates"
PRE = ROOT / "assets" / "banners" / "presets"
for p in (SYM, TPL, PRE):
    p.mkdir(parents=True, exist_ok=True)
S = 1024
OUT = 256


def canvas():
    return Image.new("L", (S, S), 0)


def down(mask):
    return mask.resize((OUT, OUT), Image.Resampling.LANCZOS)


def point(cx, cy, r, a):
    return (cx + math.cos(a) * r, cy + math.sin(a) * r)


def star(d, cx, cy, r1, r2, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        pts.append(point(cx, cy, r1 if i % 2 == 0 else r2, a))
    d.polygon(pts, fill=255)


def symbol_cross(d):
    w, h, arm = 220, 760, 165
    cx, cy = S / 2, S / 2
    d.polygon([(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2),
               (cx + w / 2, cy - arm / 2), (cx + h / 2, cy - arm / 2),
               (cx + h / 2, cy + arm / 2), (cx + w / 2, cy + arm / 2),
               (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2),
               (cx - w / 2, cy + arm / 2), (cx - h / 2, cy + arm / 2),
               (cx - h / 2, cy - arm / 2), (cx - w / 2, cy - arm / 2)], fill=255)


def symbol_saltire(d):
    w = 150
    for a in (math.radians(45), math.radians(-45)):
        dx, dy = math.cos(a) * 500, math.sin(a) * 500
        nx, ny = -math.sin(a) * w / 2, math.cos(a) * w / 2
        d.polygon([(S / 2 - dx + nx, S / 2 - dy + ny), (S / 2 + dx + nx, S / 2 + dy + ny),
                   (S / 2 + dx - nx, S / 2 + dy - ny), (S / 2 - dx - nx, S / 2 - dy - ny)], fill=255)


def symbol_star(d):
    star(d, S / 2, S / 2, 390, 160, 8, -math.pi / 8)


def symbol_crescent(d):
    d.ellipse((160, 90, 864, 934), fill=255)
    d.ellipse((390, 40, 1094, 884), fill=0)


def symbol_sun(d):
    d.ellipse((330, 330, 694, 694), fill=255)
    for i in range(12):
        a = i * math.tau / 12
        dx, dy = math.cos(a), math.sin(a)
        d.polygon([(S / 2 + dx * 245 - dy * 24, S / 2 + dy * 245 + dx * 24),
                   (S / 2 + dx * 245 + dy * 24, S / 2 + dy * 245 - dx * 24),
                   (S / 2 + dx * 385 + dy * 18, S / 2 + dy * 385 - dx * 18),
                   (S / 2 + dx * 385 - dy * 18, S / 2 + dy * 385 + dx * 18)], fill=255)


def symbol_fleur(d):
    cx, cy = S / 2, S / 2 + 25
    d.polygon([(cx, 110), (cx - 95, 390), (cx - 215, 300), (cx - 115, 520),
               (cx - 235, 740), (cx, 610), (cx + 235, 740), (cx + 115, 520),
               (cx + 215, 300), (cx + 95, 390)], fill=255)
    d.rectangle((cx - 245, 590, cx + 245, 700), fill=255)
    d.rectangle((cx - 55, 630, cx + 55, 900), fill=255)


def symbol_crown(d):
    d.rectangle((190, 650, 834, 810), fill=255)
    d.polygon([(190, 650), (250, 300), (430, 500), (512, 220),
               (594, 500), (774, 300), (834, 650)], fill=255)
    for x in (250, 512, 774):
        d.ellipse((x - 65, 200, x + 65, 330), fill=255)


def symbol_sword(d):
    cx = S / 2
    d.polygon([(cx - 46, 880), (cx - 30, 225), (cx, 90), (cx + 30, 225),
               (cx + 46, 880)], fill=255)
    d.rectangle((cx - 230, 690, cx + 230, 770), fill=255)
    d.rectangle((cx - 48, 760, cx + 48, 930), fill=255)
    d.ellipse((cx - 80, 880, cx + 80, 1000), fill=255)


def symbol_tower(d):
    d.rectangle((260, 370, 764, 920), fill=255)
    for x in (250, 380, 510, 640):
        d.rectangle((x, 265, x + 115, 430), fill=255)
    d.pieslice((430, 720, 594, 930), 180, 360, fill=0)
    d.rectangle((430, 820, 594, 930), fill=0)
    d.rectangle((330, 500, 410, 590), fill=0)
    d.rectangle((614, 500, 694, 590), fill=0)


def symbol_eagle(d):
    cx = S / 2
    d.ellipse((cx - 90, 180, cx + 90, 420), fill=255)
    d.polygon([(cx, 330), (cx - 340, 170), (cx - 440, 360), (cx - 280, 420),
               (cx - 410, 520), (cx - 210, 570), (cx - 300, 700), (cx - 80, 650),
               (cx, 900), (cx + 80, 650), (cx + 300, 700), (cx + 210, 570),
               (cx + 410, 520), (cx + 280, 420), (cx + 440, 360), (cx + 340, 170)], fill=255)
    d.polygon([(cx - 30, 215), (cx - 150, 255), (cx - 40, 300)], fill=255)


def symbol_lion(d):
    cx, cy = S / 2, S / 2
    # Löwe im Profil, aufgerichtet, mit Mähne und geringeltem Schweif.
    d.ellipse((cx - 90, 330, cx + 250, 710), fill=255)
    d.ellipse((cx - 270, 170, cx - 20, 430), fill=255)
    d.polygon([(cx - 220, 250), (cx - 300, 160), (cx - 245, 390), (cx - 130, 420)], fill=255)
    d.polygon([(cx - 160, 600), (cx - 260, 890), (cx - 170, 900), (cx - 40, 650)], fill=255)
    d.polygon([(cx + 140, 600), (cx + 120, 900), (cx + 210, 900), (cx + 240, 620)], fill=255)
    d.polygon([(cx + 150, 400), (cx + 350, 270), (cx + 300, 370), (cx + 380, 500),
               (cx + 220, 530)], fill=255)
    d.arc((cx + 120, 300, cx + 420, 700), 250, 80, fill=255, width=36)
    d.polygon([(cx - 215, 280), (cx - 320, 300), (cx - 250, 340)], fill=255)


def symbol_boar(d):
    d.ellipse((170, 390, 760, 760), fill=255)
    d.ellipse((610, 360, 900, 680), fill=255)
    d.polygon([(810, 470), (970, 520), (820, 580)], fill=255)
    d.polygon([(850, 600), (960, 640), (830, 680)], fill=255)
    for x in (260, 420, 580, 700):
        d.rectangle((x, 650, x + 70, 900), fill=255)
    d.polygon([(180, 450), (60, 390), (160, 540)], fill=255)


def make_symbols():
    makers = [
        ("cross", symbol_cross), ("saltire", symbol_saltire), ("star", symbol_star),
        ("crescent", symbol_crescent), ("sun", symbol_sun), ("fleur", symbol_fleur),
        ("crown", symbol_crown), ("sword", symbol_sword), ("tower", symbol_tower),
        ("eagle", symbol_eagle), ("lion", symbol_lion), ("boar", symbol_boar),
    ]
    for i, (name, fn) in enumerate(makers):
        mask = canvas()
        d = ImageDraw.Draw(mask)
        fn(d)
        alpha = down(mask).filter(ImageFilter.GaussianBlur(0.35))
        rgba = Image.new("RGBA", (OUT, OUT), (255, 255, 255, 0))
        rgba.putalpha(alpha)
        rgba.save(SYM / f"symbol_{i:02d}.png", optimize=True)
        print("symbol", name)


def shape_mask(kind, w=512, h=512):
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    if kind == 0:  # klassischer Schild
        d.polygon([(55, 45), (457, 45), (445, 300), (360, 420), (256, 480),
                   (152, 420), (67, 300)], fill=255)
    elif kind == 1:  # runder Schild
        d.rounded_rectangle((55, 45, 457, 400), radius=90, fill=255)
        d.polygon([(55, 300), (152, 440), (256, 480), (360, 440), (457, 300)], fill=255)
    elif kind == 2:  # iberischer Schild
        d.polygon([(75, 45), (437, 45), (460, 250), (400, 390), (256, 470),
                   (112, 390), (52, 250)], fill=255)
    elif kind == 3:  # Fahne
        d.rectangle((45, 80, 467, 390), fill=255)
    elif kind == 4:  # Stander
        d.polygon([(45, 80), (467, 80), (390, 235), (467, 390), (45, 390)], fill=255)
    else:  # Banner
        d.rectangle((145, 35, 367, 420), fill=255)
        d.polygon([(145, 420), (256, 470), (367, 420)], fill=255)
        d.rectangle((120, 20, 392, 65), fill=255)
    return im


def colored_shape(kind, bg, fg, border, symbol_idx, split=False):
    w = h = 512
    mask = shape_mask(kind, w, h)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fill = Image.new("RGBA", (w, h), bg)
    if split:
        d = ImageDraw.Draw(fill)
        if kind <= 2:
            d.rectangle((256, 0, 512, 512), fill=fg)
        else:
            d.rectangle((0, 235, 512, 512), fill=fg)
    out.alpha_composite(fill)
    out.putalpha(mask)
    d = ImageDraw.Draw(out)
    if border:
        bm = mask.resize((w, h), Image.Resampling.NEAREST)
        edge = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ed = ImageDraw.Draw(edge)
        ed.bitmap((0, 0), bm, fill=border)
        # inneren Bereich wieder freistellen
        inner = shape_mask(kind, int(w * .92), int(h * .92)).resize((w, h))
        ed.bitmap((0, 0), inner, fill=(0, 0, 0, 0))
        out.alpha_composite(edge)
    if symbol_idx is not None:
        s = Image.open(SYM / f"symbol_{symbol_idx:02d}.png").convert("RGBA")
        s = s.resize((280, 280), Image.Resampling.LANCZOS)
        tint = Image.new("RGBA", s.size, (245, 225, 170, 255))
        tint.putalpha(s.getchannel("A"))
        out.alpha_composite(tint, (116, 100 if kind <= 2 else 95))
    return out.resize((160, 160), Image.Resampling.LANCZOS)


def make_templates():
    configs = [
        (0, (112, 40, 38, 255), (230, 222, 197, 255), (208, 166, 82, 255), 2, False),
        (1, (37, 56, 93, 255), (214, 202, 172, 255), (201, 164, 83, 255), 0, True),
        (2, (75, 54, 94, 255), (223, 197, 128, 255), (214, 176, 88, 255), 7, True),
        (3, (35, 75, 55, 255), (218, 204, 170, 255), (205, 170, 93, 255), 5, True),
        (4, (40, 62, 82, 255), (206, 201, 176, 255), (207, 170, 90, 255), 3, False),
        (5, (91, 43, 48, 255), (211, 193, 149, 255), (210, 171, 91, 255), 9, False),
    ]
    for i, cfg in enumerate(configs):
        colored_shape(*cfg).save(TPL / f"template_{i}.png", optimize=True)
        colored_shape(*cfg).save(PRE / f"preset_{i}.png", optimize=True)
    # zweite Reihe leicht variierter Presets
    configs2 = [
        (0, (50, 76, 64, 255), (227, 215, 184, 255), (205, 171, 94, 255), 4, True),
        (1, (116, 75, 29, 255), (218, 206, 177, 255), (225, 184, 94, 255), 6, False),
        (2, (44, 50, 70, 255), (202, 193, 167, 255), (209, 172, 96, 255), 8, True),
        (3, (88, 33, 43, 255), (229, 217, 188, 255), (211, 173, 93, 255), 10, False),
        (4, (48, 69, 84, 255), (221, 210, 180, 255), (205, 168, 87, 255), 11, True),
        (5, (62, 57, 48, 255), (221, 208, 174, 255), (211, 171, 88, 255), 1, False),
    ]
    for i, cfg in enumerate(configs2):
        colored_shape(*cfg).save(PRE / f"preset_{i + 6}.png", optimize=True)


if __name__ == "__main__":
    from PIL import ImageFilter
    make_symbols()
    make_templates()
    print("Banner-Assets fertig.")
