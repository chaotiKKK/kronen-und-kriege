"""Erzeugt die detaillierte Hauptweltkarte aus Natural-Earth-Vektoren.

Gleiche Projektion wie tools/make_europe_map.py (equirectangular, 1200x760),
aber vierfache Auflösung (4800x3040) mit Relief, Klimazonen, grober
Biomtextur, Meerestiefe und Küstensaum. Die Silhouette bleibt deckungsgleich mit der
Provinzgeometrie des Spiels.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import shapely
from PIL import Image, ImageDraw, ImageFilter
from shapely import affinity
from shapely.geometry import GeometryCollection, MultiPolygon, Polygon, box, shape

ROOT = Path(__file__).resolve().parent.parent
GEOJSON = ROOT / ".tools/ne_50m_admin_0_countries.geojson"
DST = ROOT / "assets/map/europe_detail.png"

MAP_W, MAP_H = 1200.0, 760.0
LON0, LON1 = -12.0, 52.0
LAT0, LAT1 = 33.0, 72.0
SS = 4
W, H = int(MAP_W * SS), int(MAP_H * SS)


def polygons_of(geom):
    if geom.is_empty:
        return []
    if isinstance(geom, Polygon):
        return [geom]
    if isinstance(geom, MultiPolygon):
        return list(geom.geoms)
    if isinstance(geom, GeometryCollection):
        out = []
        for g in geom.geoms:
            out.extend(polygons_of(g))
        return out
    return []


def project(geom):
    return affinity.affine_transform(
        geom,
        (MAP_W / (LON1 - LON0), 0, 0, -MAP_H / (LAT1 - LAT0),
         -LON0 * MAP_W / (LON1 - LON0), LAT1 * MAP_H / (LAT1 - LAT0)),
    )


def load_land():
    raw = json.loads(GEOJSON.read_text(encoding="utf-8"))
    parts = []
    for feature in raw["features"]:
        geom = shape(feature["geometry"])
        if not geom.is_valid:
            geom = geom.buffer(0)
        clipped = project(geom).intersection(box(0, 0, MAP_W, MAP_H))
        for poly in polygons_of(clipped):
            if poly.area < 0.02:
                continue
            scaled = affinity.scale(poly, xfact=SS, yfact=SS, origin=(0, 0))
            parts.append(scaled)
    return parts


def noise(rng, cells, size=(W, H), octaves=4):
    acc = np.zeros((size[1], size[0]), dtype=np.float32)
    total = 0.0
    for i in range(octaves):
        c = max(3, int(cells * (2 ** i)))
        rows = max(3, int(c * size[1] / size[0]))
        small = rng.random((rows, c)).astype(np.float32)
        layer = np.asarray(
            Image.fromarray((small * 255).astype(np.uint8)).resize(size, Image.BICUBIC),
            dtype=np.float32,
        ) / 255.0
        acc += layer * (0.58 ** i)
        total += 0.58 ** i
    return acc / total


def smoothstep(edge0, edge1, value):
    t = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    return a * (1.0 - t[..., None]) + b * t[..., None]


def main():
    rng = np.random.default_rng(4242)
    land_polys = load_land()

    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    for poly in land_polys:
        md.polygon([(x, y) for x, y in poly.exterior.coords], fill=255)
        for ring in poly.interiors:
            md.polygon([(x, y) for x, y in ring.coords], fill=0)
    land = np.asarray(mask, dtype=np.float32) / 255.0
    del mask

    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    lat = LAT1 - (ys / H) * (LAT1 - LAT0)

    # Distanzen für Küstensaum und Meerestiefe
    from scipy.ndimage import distance_transform_edt

    coast_dist = distance_transform_edt(land > 0.5)
    sea_dist = distance_transform_edt(land < 0.5)
    inland = np.clip(coast_dist / 90.0, 0.0, 1.0)

    # Höhenfeld: Küstenebene, Binnenland, geriffelte Kämme
    broad = noise(rng, 5, (W, H), 5)
    ridge = 1.0 - np.abs(noise(rng, 8, (W, H), 4) * 2.0 - 1.0)
    ridge = ridge ** 4.0
    belt = np.clip((noise(rng, 4, (W, H), 3) - 0.52) * 5.0, 0.0, 1.0)
    height = inland * 0.10 + broad * 0.10 + ridge * inland * belt * 0.45
    height = np.asarray(
        Image.fromarray((np.clip(height, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2)),
        dtype=np.float32,
    ) / 255.0
    gy, gx = np.gradient(height)
    shade = np.clip(1.0 + (-gx * 0.8 - gy * 0.8) * 11.0, 0.62, 1.38)

    # Klimazonen: weiche Gewichte um Breitengrad-Zentren
    grass = np.array([0.40, 0.50, 0.29])
    forest_c = np.array([0.21, 0.33, 0.19])
    tundra_c = np.array([0.49, 0.51, 0.43])
    steppe_c = np.array([0.66, 0.59, 0.36])
    desert_c = np.array([0.80, 0.69, 0.45])
    rock = np.array([0.49, 0.45, 0.39])
    snow_c = np.array([0.88, 0.91, 0.94])
    bands = [(35.0, desert_c, "dry"), (42.0, steppe_c, "dry"), (50.0, grass, "temperate"),
             (57.0, forest_c, "temperate"), (63.0, tundra_c, "cold"), (68.0, snow_c, "cold")]
    weight_sum = np.zeros((H, W), dtype=np.float32)
    dry_weight = np.zeros((H, W), dtype=np.float32)
    ground = np.zeros((H, W, 3), dtype=np.float32)
    for center, color, climate in bands:
        w = np.exp(-((lat - center) / 3.4) ** 2).astype(np.float32)
        ground += color * w[..., None]
        weight_sum += w
        if climate == "dry":
            dry_weight += w
    ground /= weight_sum[..., None]
    dry_weight /= weight_sum

    moisture = noise(rng, 8, (W, H), 5)
    forest = np.clip((moisture - 0.46) * 2.8, 0.0, 1.0)
    forest *= np.clip((lat - 45.0) / 8.0, 0.0, 1.0) * np.clip((66.0 - lat) / 6.0, 0.0, 1.0)
    ground = mix(ground, forest_c, np.clip(forest * 0.75, 0, 1))
    ground = mix(ground, rock, np.clip((height - 0.34) * 1.8, 0.0, 0.45))
    snow_high = np.clip((height - 0.52) * 3.0, 0.0, 1.0) * 0.65
    snow_low = np.clip((lat - 67.0) / 3.5, 0.0, 1.0)
    snow_cover = np.clip(snow_high + snow_low, 0.0, 1.0)
    ground = mix(ground, snow_c, snow_cover)

    # Grobe Biomtextur statt Pixelkorn. Die Muster liegen bei 25-340 Quellpixeln
    # und bleiben damit auch bei 4x Zoom sichtbar und ruhig. Ein eigener
    # Generator hält Höhen, Küsten und Klimafarben gegenüber dem alten Stand fest.
    texture_rng = np.random.default_rng(911)
    broad_patch = noise(texture_rng, 14, (W, H), 3) - 0.5
    meadow_patch = noise(texture_rng, 46, (W, H), 3) - 0.5
    canopy = smoothstep(0.48, 0.70, noise(texture_rng, 40, (W, H), 3)) - 0.5
    tufts = smoothstep(0.50, 0.74, noise(texture_rng, 64, (W, H), 2)) - 0.5
    dry_wave = np.sin((xs * 0.058 + ys * 0.026) + (noise(texture_rng, 22, (W, H), 2) - 0.5) * 3.2)
    # Schwellenmuster auf Mittelwert null ziehen, damit die Klimafarben nicht
    # systematisch dunkler werden. Die alte Grain-Formel hob das Land um 10 % an.
    canopy -= float(canopy.mean())
    tufts -= float(tufts.mean())
    ground = ground * shade[..., None] * 1.10
    ground = ground * (1.0 + broad_patch * 0.110 + meadow_patch * 0.070)[..., None]
    ground = ground * (1.0 + canopy[..., None] * forest[..., None] * 0.140)
    ground = ground * (1.0 + tufts[..., None] * (0.75 + forest[..., None] * 0.25) * 0.160)
    ground = ground * (1.0 + dry_wave[..., None] * dry_weight[..., None] * 0.040)

    # Küstensaum auf dem Land
    sand = np.clip((4.0 - coast_dist) / 4.0, 0.0, 1.0) * land
    ground = mix(ground, np.array([0.78, 0.72, 0.54]), sand * 0.5)

    # Meer: Tiefenverlauf, Rippel, Brandung
    depth = np.clip(sea_dist / 90.0, 0.0, 1.0)
    shallow = np.array([0.26, 0.47, 0.49])
    mid = np.array([0.11, 0.28, 0.36])
    deep = np.array([0.045, 0.12, 0.19])
    t = depth[..., None]
    sea = np.where(t < 0.5, shallow * (1 - t * 2) + mid * (t * 2), mid * (2 - t * 2) + deep * (t * 2 - 1))
    swell = noise(texture_rng, 24, (W, H), 3) - 0.5
    sea = sea * (1.0 + swell[..., None] * 0.065)

    out = ground * land[..., None] + sea * (1.0 - land)[..., None]

    foam = np.clip((3.0 - sea_dist) / 3.0, 0.0, 1.0) * (1.0 - land)
    out = out * (1 - foam[..., None] * 0.22) + np.array([0.60, 0.78, 0.78]) * foam[..., None] * 0.22
    edge = np.clip((1.5 - coast_dist) / 1.5, 0.0, 1.0) * land
    out = out * (1 - edge[..., None] * 0.16) + np.array([0.32, 0.29, 0.20]) * edge[..., None] * 0.16

    img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))
    DST.parent.mkdir(parents=True, exist_ok=True)
    img.save(DST, optimize=True)
    print("WROTE", DST, img.size, DST.stat().st_size // 1024, "KiB", "| Landpolygone:", len(land_polys))


if __name__ == "__main__":
    main()
