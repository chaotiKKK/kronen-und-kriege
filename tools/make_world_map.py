"""Baut aus assets/map/europe_bg.png eine hochaufgelöste Weltkarte.

Die Silhouette bleibt identisch (Provinzen, Grenzen und Marker sitzen weiter),
aber Land und Meer bekommen Klimazonen, Biomkorn, Relief, Meerestiefe und einen
feinen Küstensaum.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/map/europe_bg.png"
DST = ROOT / "assets/map/europe_relief.png"
W, H = 3600, 2280


def noise(rng, octaves=5, base=4):
    """Weiches Mehrskalenrauschen in [0,1]."""
    acc = np.zeros((H, W), dtype=np.float32)
    total = 0.0
    for i in range(octaves):
        cells = max(3, int(base * (2 ** i)))
        small = rng.random((cells, max(3, int(cells * H / W)))).astype(np.float32)
        layer = np.asarray(
            Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC),
            dtype=np.float32,
        ) / 255.0
        acc += layer * (0.55 ** i)
        total += 0.55 ** i
    return acc / total


def grain(rng, radius=1.2, scale=0.06):
    raw = rng.normal(0.0, 1.0, (H, W)).astype(np.float32)
    img = Image.fromarray(((raw * 0.5 + 0.5) * 255).astype(np.uint8))
    soft = np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255.0
    return 1.0 + (soft - 0.5) * scale * 2.0


def mix(a, b, t):
    return a * (1.0 - t[..., None]) + b * t[..., None]


def main():
    rng = np.random.default_rng(1729)
    base = Image.open(SRC).convert("RGB").resize((W, H), Image.LANCZOS)
    rgb = np.asarray(base, dtype=np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    land = (b < r + 0.06).astype(np.float32)
    land_img = Image.fromarray((land * 255).astype(np.uint8))

    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    yy = ys / H

    # Küstennähe und Meerestiefe aus der Landmaske
    near = np.asarray(land_img.filter(ImageFilter.GaussianBlur(14)), dtype=np.float32) / 255.0
    far = np.asarray(land_img.filter(ImageFilter.GaussianBlur(95)), dtype=np.float32) / 255.0
    inland = np.clip(far * 2.6, 0.0, 1.0)
    depth = np.clip((0.42 - far) / 0.42, 0.0, 1.0)

    # --- Höhenfeld --------------------------------------------------------
    broad = noise(rng, 5, 4)
    ridges = 1.0 - np.abs(noise(rng, 4, 9) * 2.0 - 1.0)
    ridges = ridges ** 3.0
    height = inland * 0.20 + broad * 0.16 + ridges * inland * 0.30
    height = np.asarray(
        Image.fromarray((np.clip(height, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2)),
        dtype=np.float32,
    ) / 255.0
    gy, gx = np.gradient(height)
    shade = np.clip(1.0 + (-gx * 0.75 - gy * 0.75) * 16.0, 0.48, 1.52)

    # --- Klimazonen -------------------------------------------------------
    snow_line = np.clip((0.045 - yy) / 0.045, 0.0, 1.0) ** 0.8
    tundra = np.clip((0.185 - yy) / 0.07, 0.0, 1.0) * (1.0 - snow_line)
    boreal = np.clip((0.33 - yy) / 0.12, 0.0, 1.0) * (1.0 - tundra)
    temperate = np.clip((0.56 - yy) / 0.14, 0.0, 1.0) * (1.0 - boreal)
    steppe = np.clip((0.70 - yy) / 0.10, 0.0, 1.0) * (1.0 - temperate)
    desert = np.clip((yy - 0.66) / 0.12, 0.0, 1.0)

    moisture = noise(rng, 5, 7)
    forest = np.clip((moisture - 0.46) * 3.4, 0.0, 1.0)

    grass_col = np.array([0.37, 0.48, 0.27])
    forest_col = np.array([0.21, 0.33, 0.19])
    tundra_col = np.array([0.47, 0.49, 0.41])
    steppe_col = np.array([0.64, 0.57, 0.35])
    desert_col = np.array([0.79, 0.68, 0.44])
    rock_col = np.array([0.50, 0.46, 0.40])
    snow_col = np.array([0.88, 0.91, 0.94])

    ground = np.zeros((H, W, 3), dtype=np.float32)
    ground[:] = grass_col
    ground = mix(ground, forest_col, np.clip(forest * 0.9, 0, 1))
    ground = mix(ground, tundra_col, tundra)
    ground = mix(ground, steppe_col, steppe)
    ground = mix(ground, desert_col, desert)
    ground = mix(ground, rock_col, np.clip((height - 0.42) * 2.0, 0.0, 0.55))
    ground = mix(ground, snow_col, np.clip((height - 0.62) * 3.0, 0.0, 1.0) * 0.75 + snow_line)

    # Küstensaum: schmaler Sandstreifen, danach feuchteres Grün
    coast = np.clip((0.10 - near) * 12.0, 0.0, 1.0) * land
    ground = mix(ground, np.array([0.74, 0.69, 0.51]), coast * 0.55)

    ground = ground * shade[..., None] * grain(rng, 0.9, 0.17)[..., None]
    ground = ground * (0.88 + 0.24 * grain(rng, 5.0, 0.16))[..., None]

    # --- Meer -------------------------------------------------------------
    shallow = np.array([0.31, 0.55, 0.55])
    mid = np.array([0.13, 0.30, 0.38])
    deep = np.array([0.045, 0.12, 0.19])
    t = np.clip(depth * 1.15, 0, 1)[..., None]
    sea = np.where(t < 0.5, shallow * (1 - t * 2) + mid * (t * 2), mid * (2 - t * 2) + deep * (t * 2 - 1))
    ripple = (noise(rng, 3, 230) - 0.5)[..., None] * 0.05
    sea = sea * (1.0 + ripple)

    out = ground * land[..., None] + sea * (1.0 - land)[..., None]

    # --- Küstenkante und Brandung ----------------------------------------
    eroded = np.asarray(land_img.filter(ImageFilter.MinFilter(5)), dtype=np.float32) / 255.0
    edge = np.clip(land - eroded, 0, 1)[..., None]
    out = out * (1 - edge * 0.30) + np.array([0.86, 0.82, 0.66]) * edge * 0.30
    outer = np.asarray(land_img.filter(ImageFilter.MaxFilter(7)), dtype=np.float32) / 255.0
    foam = np.clip(outer - land, 0, 1)[..., None]
    out = out * (1 - foam * 0.28) + np.array([0.62, 0.80, 0.80]) * foam * 0.28

    out = np.clip(out, 0.0, 1.0)
    img = Image.fromarray((out * 255).astype(np.uint8))
    img.save(DST, optimize=True)
    print("WROTE", DST, img.size, DST.stat().st_size // 1024, "KiB")


if __name__ == "__main__":
    main()
