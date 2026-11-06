#!/usr/bin/env python3
"""Schneidet die sechs neuen 6er-Charakterbögen in Einzelfiguren und Porträts.

Die Quellen liegen als characters_3..8.jpg in reference/. Die neuen Figuren
werden ab Nummer 13 fortlaufend nummeriert, damit die vorhandenen Bilder
1..12 unverändert bleiben. Hintergründe sind weiß, beige oder ein grauer
Verlauf; deshalb wird die Hintergrundfarbe pro Spalte aus den Randzeilen
geschätzt und vertikal interpoliert.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

from crop_characters import OUT_CHARS, OUT_PORTRAITS, OUT_PREVIEW, column_bounds, make_portrait

ROOT = Path(__file__).resolve().parent.parent
SHEETS = [(ROOT / "reference" / f"characters_{i}.jpg", "f") for i in range(3, 9)]
START_NUMBER = 13


def background_model(arr: np.ndarray) -> np.ndarray:
    """Schätzt den Hintergrund pro Spalte aus oberer und unterer Randzeile.

    Ein vertikaler Verlauf (grauer Studiohintergrund) wird linear interpoliert.
    Steigt die untere Farbe stark ab, liegt dort vermutlich Stoff im Bild und
    die obere Hintergrundfarbe wird für die ganze Spalte verwendet.
    """
    h, w, _ = arr.shape
    top = np.median(arr[2:18], axis=0).astype(np.float32)
    bottom = np.median(arr[h - 18:h - 2], axis=0).astype(np.float32)
    jump = np.abs(top - bottom).mean(axis=1)
    bottom = np.where(jump[:, None] > 55.0, top, bottom)
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None, None]
    return top[None, :, :] * (1.0 - ys) + bottom[None, :, :] * ys


def foreground_mask(arr: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    bg = background_model(arr)
    dist = np.sqrt(((arr.astype(np.float32) - bg) ** 2).sum(axis=2))
    raw = dist > 26.0
    # JPEG-Sprenkel entfernen; große Figuren bleiben zusammen.
    labels, count = ndimage.label(raw, structure=np.ones((3, 3)))
    if count > 0:
        sizes = np.bincount(labels.ravel())
        sizes[0] = 0
        keep = sizes > 300
        raw = keep[labels]
    raw = ndimage.binary_closing(raw, structure=np.ones((3, 3)))
    return raw, dist


def remove_small_islands(img: Image.Image, min_ratio: float = 0.01, min_px: int = 350) -> Image.Image:
    """Entfernt winzige, abgetrennte Alpha-Inseln (z. B. Nachbarschuhe)."""
    arr = np.asarray(img).copy()
    alpha = arr[:, :, 3] > 8
    labels, count = ndimage.label(alpha, structure=np.ones((3, 3)))
    if count <= 1:
        return img
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    biggest = int(sizes.max())
    keep = np.zeros_like(alpha)
    for k in range(1, count + 1):
        if sizes[k] >= max(min_px, biggest * min_ratio):
            keep |= labels == k
    arr[:, :, 3] = np.where(keep, arr[:, :, 3], 0)
    out = Image.fromarray(arr)
    return out.crop(out.getbbox())


def main() -> None:
    OUT_CHARS.mkdir(parents=True, exist_ok=True)
    OUT_PORTRAITS.mkdir(parents=True, exist_ok=True)
    OUT_PREVIEW.mkdir(parents=True, exist_ok=True)

    meta_path = OUT_CHARS / "characters.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {"characters": []}
    records = {int(r["id"]): r for r in meta.get("characters", [])}

    fulls: list[Image.Image] = []
    portraits: list[Image.Image] = []
    number = START_NUMBER

    for sheet_path, gender in SHEETS:
        if not sheet_path.exists():
            raise SystemExit(f"Fehlt: {sheet_path}")
        im = Image.open(sheet_path).convert("RGB")
        arr = np.asarray(im)
        fg, dist = foreground_mask(arr)
        fraction = float(fg.mean())
        bounds = column_bounds(fg)
        print(f"{sheet_path.name}: {im.width}x{im.height}, Maske {fraction:.1%}, Grenzen {bounds}")
        if fraction < 0.08 or fraction > 0.75:
            raise SystemExit(f"Maskierung unplausibel in {sheet_path.name}: {fraction:.1%}")

        alpha_arr = np.clip((dist - 20.0) * 8.0, 0.0, 255.0).astype(np.uint8)
        alpha_full = Image.fromarray(alpha_arr).filter(ImageFilter.GaussianBlur(0.55))
        labels, _ = ndimage.label(np.asarray(alpha_full) > 32, structure=np.ones((3, 3)))

        for i in range(6):
            x0, x1 = bounds[i], bounds[i + 1]
            band = labels[:, x0:x1]
            counts = np.bincount(band.ravel())
            counts[0] = 0
            if len(counts) < 2:
                raise SystemExit(f"Keine Figur in {sheet_path.name} Spalte {i + 1}")
            keep = int(counts.argmax())
            body = labels == keep
            # Nachbarfiguren hinter der Spaltengrenze abschneiden.
            body[:, :x0 + 2] = False
            body[:, x1 - 2:] = False
            ys, xs = np.where(body)
            if len(xs) == 0:
                raise SystemExit(f"Leere Figur in {sheet_path.name} Spalte {i + 1}")
            fy0, fy1 = int(ys.min()), int(ys.max()) + 1
            fx0, fx1 = int(xs.min()), int(xs.max()) + 1
            pad = 4
            box = (max(x0 + 2, fx0 - pad), max(0, fy0 - pad),
                   min(x1 - 2, fx1 + pad), min(im.height, fy1 + pad))
            # Nur die gewählte Figur als Alpha verwenden; alpha_full enthält
            # sonst auch Nachbarschuhe und Rocksäume am Spaltenrand.
            body_img = Image.fromarray((body * 255).astype(np.uint8)).filter(
                ImageFilter.GaussianBlur(0.55)
            )
            char = im.crop(box).convert("RGBA")
            char.putalpha(body_img.crop(box))
            char = char.crop(char.getbbox())
            char = remove_small_islands(char)
            char.save(OUT_CHARS / f"character_{number:02d}.png", optimize=True)

            # Kopfmitte aus dem oberen Fünftel; der Ausschnitt bleibt innerhalb
            # der Spalte, damit keine Nachbarfigur ins Porträt ragt.
            head_band = body[fy0:fy0 + max(1, (fy1 - fy0) // 5), :]
            hys, hxs = np.where(head_band)
            head_x = int(np.median(hxs)) if len(hxs) else (fx0 + fx1) // 2
            pw = max(160, min(232, x1 - x0 - 4))
            ph = int(pw * 1.25)
            px0 = min(max(x0 + 2, head_x - pw // 2), x1 - 2 - pw)
            py0 = max(0, min(im.height - ph, fy0 - 12))
            pbox = (px0, py0, px0 + pw, py0 + ph)
            portrait = make_portrait(im, body_img, pbox)
            portrait.save(OUT_PORTRAITS / f"portrait_{number:02d}.png", optimize=True)

            records[number] = {
                "id": number, "sheet": sheet_path.name, "gender": gender,
                "character": f"character_{number:02d}.png",
                "portrait": f"portrait_{number:02d}.png",
                "bbox": list(box), "portrait_box": list(pbox),
            }
            fulls.append(char)
            portraits.append(portrait)
            print(f"  {number:02d} bbox={box} portrait={pbox}")
            number += 1

    meta["characters"] = [records[k] for k in sorted(records)]
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    cols = 6
    cell_w, cell_h = 170, 220
    rows = (len(portraits) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (28, 22, 17, 255))
    for i, p in enumerate(portraits):
        thumb = p.copy()
        thumb.thumbnail((150, 188))
        x = (i % cols) * cell_w + 10
        y = (i // cols) * cell_h + 10
        sheet.alpha_composite(thumb, (x, y))
    sheet.convert("RGB").save(OUT_PREVIEW / "portraits_overview_extra.png", optimize=True)

    cell_w, cell_h = 170, 340
    rows = (len(fulls) + cols - 1) // cols
    fs = Image.new("RGBA", (cols * cell_w, rows * cell_h), (28, 22, 17, 255))
    for i, p in enumerate(fulls):
        thumb = p.copy()
        thumb.thumbnail((150, 320))
        x = (i % cols) * cell_w + 10
        y = (i // cols) * cell_h + 10
        fs.alpha_composite(thumb, (x, y))
    fs.convert("RGB").save(OUT_PREVIEW / "characters_overview_extra.png", optimize=True)
    print(f"FERTIG: {len(portraits)} neue Figuren/Porträts ({START_NUMBER}..{number - 1})")


if __name__ == "__main__":
    main()
