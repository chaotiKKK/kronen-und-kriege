#!/usr/bin/env python3
"""Schneidet die beiden 6er-Charakterbögen in Einzelfiguren und Porträts.

Die Quelle bleibt in reference/ (per .gdignore vom Godot-Import ausgeschlossen).
Ergebnis:
  assets/characters/character_01..12.png   freigestellt, volle Figur
  assets/portraits_hd/portrait_01..12.png   256x320 für die Oberfläche
  preview/characters_overview.png
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SHEETS = [
    (ROOT / "reference" / "characters_1.jpg", "f", "Hofdamen"),
    (ROOT / "reference" / "characters_2.jpg", "m", "Hofherren"),
]
OUT_CHARS = ROOT / "assets" / "characters"
OUT_PORTRAITS = ROOT / "assets" / "portraits_hd"
OUT_PREVIEW = ROOT / "preview"
OUT_CHARS.mkdir(parents=True, exist_ok=True)
OUT_PORTRAITS.mkdir(parents=True, exist_ok=True)
OUT_PREVIEW.mkdir(parents=True, exist_ok=True)


def background_colour(arr: np.ndarray) -> np.ndarray:
    h, w, _ = arr.shape
    samples = np.concatenate([
        arr[:24, :24].reshape(-1, 3),
        arr[:24, -24:].reshape(-1, 3),
        arr[-24:, :24].reshape(-1, 3),
        arr[-24:, -24:].reshape(-1, 3),
    ])
    return np.median(samples, axis=0)


def foreground_mask(arr: np.ndarray) -> np.ndarray:
    bg = background_colour(arr)
    dist = np.sqrt(((arr.astype(np.float32) - bg) ** 2).sum(axis=2))
    # Harte Trennlinie plus weiche Kante für die Freistellung.
    mask = (dist > 24).astype(np.uint8)
    # Einzelne JPEG-Sprenkel entfernen, ohne Details zu verschlucken.
    im = Image.fromarray(mask * 255)
    im = im.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    return np.asarray(im) > 0, dist


def column_bounds(fg: np.ndarray) -> list[int]:
    h, w = fg.shape
    counts = fg.sum(axis=0)
    bounds = [0]
    for k in range(1, 6):
        expected = int(w * k / 6)
        lo, hi = max(1, expected - 55), min(w - 2, expected + 55)
        # Der beste Schnitt ist die Spalte mit der wenigsten Figur.
        x = min(range(lo, hi), key=lambda xx: int(counts[max(0, xx - 1):xx + 2].sum()))
        bounds.append(x)
    bounds.append(w)
    return bounds


def crop(im: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    x0, y0, x1, y1 = box
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(im.width, x1), min(im.height, y1)
    return im.crop((x0, y0, x1, y1))


def make_portrait(im: Image.Image, alpha: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    crop_im = im.crop(box).convert("RGBA")
    crop_a = alpha.crop(box)
    crop_im.putalpha(crop_a)
    # Dunkler, warmer Porträt-Hintergrund mit Vignette.
    bg = Image.new("RGBA", (256, 320), (31, 23, 18, 255))
    grad = Image.new("L", (256, 320))
    gd = ImageDraw.Draw(grad)
    for y in range(320):
        gd.line((0, y, 256, y), fill=int(38 + 38 * (1 - abs(y - 130) / 230)))
    warm = Image.new("RGBA", (256, 320), (92, 61, 38, 255))
    bg = Image.composite(warm, bg, grad)
    # Figur proportional einpassen, Kopf oben mit etwas Luft.
    scale = min(256 / crop_im.width, 320 / crop_im.height)
    nw, nh = max(1, int(crop_im.width * scale)), max(1, int(crop_im.height * scale))
    crop_im = crop_im.resize((nw, nh), Image.Resampling.LANCZOS)
    crop_im = crop_im.filter(ImageFilter.UnsharpMask(radius=1.1, percent=55, threshold=2))
    bg.alpha_composite(crop_im, ((256 - nw) // 2, max(0, (320 - nh) // 2)))
    # Dezente Goldkante.
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 0, 255, 319), outline=(123, 91, 48, 180), width=2)
    return bg


def main():
    records = []
    fulls = []
    portraits = []
    number = 0
    for sheet_path, gender, label in SHEETS:
        if not sheet_path.exists():
            raise SystemExit(f"Fehlt: {sheet_path}")
        im = Image.open(sheet_path).convert("RGB")
        arr = np.asarray(im)
        fg, dist = foreground_mask(arr)
        bounds = column_bounds(fg)
        print(sheet_path.name, "Grenzen:", bounds)
        for i in range(6):
            number += 1
            x0, x1 = bounds[i], bounds[i + 1]
            sub = fg[:, x0:x1]
            ys, xs = np.where(sub)
            if len(xs) == 0:
                raise SystemExit(f"Keine Figur in Spalte {i + 1}")
            bx0, bx1 = x0 + int(xs.min()), x0 + int(xs.max()) + 1
            by0, by1 = int(ys.min()), int(ys.max()) + 1
            pad = 6
            # Nicht über die Spaltengrenze hinausschneiden: dort beginnt die
            # Nachbarfigur. Die 2-px-Reserve verhindert harte Kanten.
            box = (max(x0 + 2, bx0 - pad), by0 - pad, min(x1 - 2, bx1 + pad), by1 + pad)
            # Weiche Alpha-Maske aus der Farbdistanz zum grauen Hintergrund.
            alpha_arr = np.clip((dist - 24) * 14, 0, 255).astype(np.uint8)
            alpha_full = Image.fromarray(alpha_arr).filter(ImageFilter.GaussianBlur(0.5))
            # Nur die größte Zusammenhangskomponente dieser Spalte behalten.
            # Das entfernt Arme/Füße der Nachbarfiguren am Rand, die sonst als
            # frestehende Fragmente im Einzelbild landen.
            labels, _ = ndimage.label(np.asarray(alpha_full) > 32, structure=np.ones((3, 3)))
            band_labels = labels[:, x0:x1]
            counts = np.bincount(band_labels.ravel())
            counts[0] = 0
            keep = int(counts.argmax())
            body = (labels == keep).astype(np.uint8) * 255
            body_img = Image.fromarray(body).filter(ImageFilter.GaussianBlur(0.45))
            char = im.crop(box).convert("RGBA")
            char.putalpha(body_img.crop(box))
            char = char.crop(char.getbbox())
            char.save(OUT_CHARS / f"character_{number:02d}.png", optimize=True)

            # Porträt: Kopfmitte aus dem oberen Drittel, 256:320. Der Ausschnitt
            # bleibt bewusst schmal, damit keine Nachbarfigur hineinragt.
            top = fg[by0:by0 + max(1, (by1 - by0) // 3), x0:x1]
            ys2, xs2 = np.where(top)
            head_center = x0 + int(np.median(xs2)) if len(xs2) else (bx0 + bx1) // 2
            crop_w = 256
            crop_h = 320
            px0 = max(0, min(im.width - crop_w, head_center - crop_w // 2))
            py0 = max(0, min(im.height - crop_h, by0 - 18))
            pbox = (px0, py0, px0 + crop_w, py0 + crop_h)
            portrait = make_portrait(im, body_img, pbox)
            portrait.save(OUT_PORTRAITS / f"portrait_{number:02d}.png", optimize=True)
            records.append({
                "id": number, "sheet": sheet_path.name, "gender": gender,
                "character": f"character_{number:02d}.png",
                "portrait": f"portrait_{number:02d}.png",
                "bbox": list(box), "portrait_box": list(pbox),
            })
            fulls.append(Image.open(OUT_CHARS / f"character_{number:02d}.png").convert("RGBA"))
            portraits.append(portrait)
            print(f"  {number:02d} {gender} bbox={box} portrait={pbox}")

    (OUT_CHARS / "characters.json").write_text(
        json.dumps({"characters": records}, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # Kontaktbogen der Porträts und Figuren.
    W, H = 6 * 170, 2 * 220
    sheet = Image.new("RGBA", (W, H), (28, 22, 17, 255))
    d = ImageDraw.Draw(sheet)
    for i, p in enumerate(portraits):
        p = p.copy()
        p.thumbnail((150, 188))
        x = (i % 6) * 170 + 10
        y = 10 if i < 6 else 220
        sheet.alpha_composite(p, (x, y))
        d.text((x, y + 190), f"{i + 1:02d}", fill=(224, 196, 136, 255))
    sheet.convert("RGB").save(OUT_PREVIEW / "portraits_overview.png", optimize=True)

    fw, fh = 6 * 170, 360
    fs = Image.new("RGBA", (fw, fh), (28, 22, 17, 255))
    for i, p in enumerate(fulls):
        p = p.copy()
        p.thumbnail((150, 330))
        x = (i % 6) * 170 + 10
        y = 10
        fs.alpha_composite(p, (x, y))
    fs.convert("RGB").save(OUT_PREVIEW / "characters_overview.png", optimize=True)
    print("FERTIG:", number, "Figuren/Porträts")


if __name__ == "__main__":
    main()
