#!/usr/bin/env python3
"""Erzeugt die hinterlegte Europakarte und die Provinzflächen.

Quelle der Küsten- und Staatsgrenzen: Natural Earth 1:50m admin_0_countries
(public domain). Die politische Einteilung in neun bronzezeitliche Reiche und
die 49 Provinznamen stammen aus dem Spiel; die Geometrie wird daraus abgeleitet.
"""
from __future__ import annotations

import json
import math
import random
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from shapely import affinity
from shapely.geometry import GeometryCollection, MultiPolygon, Point, Polygon, box, shape
from shapely.ops import nearest_points, unary_union

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / ".tools"
DATA = ROOT / "data"
ASSETS = ROOT / "assets" / "map"
GEOJSON = TOOLS / "ne_50m_admin_0_countries.geojson"
GEOJSON_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/"
    "geojson/ne_50m_admin_0_countries.geojson"
)
MAP_W, MAP_H = 1200.0, 760.0
LON0, LON1 = -12.0, 52.0
LAT0, LAT1 = 33.0, 72.0
SS = 2  # Auflösung der Hintergrundkarte

GROUPS = {
    "iberien": ["ESP", "PRT", "AND"],
    "gallien": ["FRA", "BEL", "NLD", "LUX", "MCO"],
    "britannien": ["GBR", "IRL"],
    "italia": ["ITA", "SMR", "VAT", "MLT"],
    "germanien": ["DEU", "AUT", "CHE", "LIE", "CZE", "POL", "SVK"],
    "skandia": ["NOR", "SWE", "DNK", "FIN", "ISL"],
    "hellas": ["GRC", "ALB", "MKD", "XKX", "MNE", "BIH", "HRV", "SRB", "SVN", "BGR"],
    "anatolien": ["TUR", "CYP", "GEO", "ARM", "AZE"],
    "skythien": ["UKR", "BLR", "MDA", "ROU", "HUN", "RUS", "EST", "LVA", "LTU"],
}

# Die bisherigen Provinz-IDs behalten ihre Lage und Bedeutung. Die Anker sind
# historische/geografische Näherungen innerhalb des jeweiligen Reiches.
SEEDS = {
    "iberien": {
        "gades": (-6.30, 36.50), "corduba": (-4.80, 37.90),
        "olisipo": (-9.10, 38.70), "tarraco": (1.25, 41.10),
        "numantia": (-2.40, 41.80),
    },
    "gallien": {
        "lugdunum": (4.80, 45.80), "aedui": (4.40, 47.00),
        "aquitania": (0.60, 44.80), "narbonensis": (3.00, 43.60),
        "belgica": (4.40, 50.80), "armorica": (-2.70, 48.20),
    },
    "britannien": {
        "cantium": (0.90, 51.20), "iceni": (0.90, 52.60),
        "brigantes": (-1.80, 54.00), "cambria": (-3.80, 52.40),
        "caledonia": (-4.00, 57.00),
    },
    "italia": {
        "latium": (12.50, 41.90), "campania": (14.50, 40.80),
        "etruria": (11.30, 43.30), "venetia": (11.50, 45.40),
        "apulia": (16.50, 40.90),
    },
    "germanien": {
        "boiohaemum": (14.40, 50.10), "suebia": (9.00, 48.70),
        "chattia": (9.00, 51.00), "frisia": (6.00, 53.20),
        "saxonia": (10.00, 52.80), "vandalia": (12.00, 54.20),
    },
    "skandia": {
        "vestland": (5.50, 61.00), "norrland": (17.00, 64.00),
        "svealand": (16.00, 59.50), "gotaland": (13.50, 57.80),
        "skane": (13.00, 55.70), "jutland": (9.20, 56.00),
    },
    "hellas": {
        "dalmatia": (16.50, 43.50), "makedonia": (22.00, 40.80),
        "thessalia": (22.50, 39.50), "attika": (23.80, 38.00),
        "boeotia": (22.80, 38.50), "peloponnesos": (22.00, 37.50),
    },
    "anatolien": {
        "troas": (26.30, 39.80), "hatti": (33.00, 39.50),
        "phrygia": (30.50, 38.50), "lycia": (29.50, 36.80),
        "cilicia": (34.50, 37.00),
    },
    "skythien": {
        "borysthenes": (31.00, 49.00), "venedia": (24.00, 50.50),
        "tauris": (34.00, 45.00), "sarmatia": (27.00, 47.00),
        "rha": (40.00, 54.00),
    },
}

CODE_ALIASES = {
    "KOS": "XKX", "KOSOVO": "XKX", "VAT": "VAT",
    "-99": None,
}


def load_countries():
    if not GEOJSON.exists():
        print("Lade Natural-Earth-Grenzen ...")
        TOOLS.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(GEOJSON_URL, GEOJSON)
    with GEOJSON.open(encoding="utf-8") as fh:
        raw = json.load(fh)
    out = {}
    for feature in raw["features"]:
        props = feature["properties"]
        code = str(props.get("ISO_A3") or "").upper()
        if code in ("", "-99", "NONE"):
            code = str(props.get("ADM0_A3") or "").upper()
        code = CODE_ALIASES.get(code, code)
        if not code:
            continue
        admin = str(props.get("ADMIN") or "")
        if admin == "Kosovo":
            code = "XKX"
        geom = shape(feature["geometry"])
        if not geom.is_valid:
            geom = geom.buffer(0)
        out[code] = geom
    return out


def project_point(lon: float, lat: float) -> Point:
    x = (lon - LON0) / (LON1 - LON0) * MAP_W
    y = (LAT1 - lat) / (LAT1 - LAT0) * MAP_H
    return Point(x, y)


def project_geom(geom):
    def xy(coords):
        return [
            (
                (lon - LON0) / (LON1 - LON0) * MAP_W,
                (LAT1 - lat) / (LAT1 - LAT0) * MAP_H,
            )
            for lon, lat in coords
        ]
    return affinity.affine_transform(geom, (MAP_W / (LON1 - LON0), 0, 0,
                                            -MAP_H / (LAT1 - LAT0),
                                            -LON0 * MAP_W / (LON1 - LON0),
                                            LAT1 * MAP_H / (LAT1 - LAT0)))


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


def cell_for(realm, seed: Point, seeds: list[Point]) -> Polygon:
    cell = realm
    for other in seeds:
        if other.equals(seed):
            continue
        dx, dy = other.x - seed.x, other.y - seed.y
        length = math.hypot(dx, dy)
        if length < 1e-9:
            continue
        ux, uy = dx / length, dy / length
        nx, ny = -ux, -uy
        mx, my = (seed.x + other.x) * 0.5, (seed.y + other.y) * 0.5
        big = 20000.0
        # Die Seite der Mittelsenkrechten, auf der der eigene Anker liegt.
        half = Polygon([
            (mx + nx * big - (-uy) * big, my + ny * big - ux * big),
            (mx + nx * big + (-uy) * big, my + ny * big + ux * big),
            (mx - ux * big + (-uy) * big, my - uy * big + ux * big),
            (mx - ux * big - (-uy) * big, my - uy * big - ux * big),
        ])
        # Korrigiere die Reihenfolge: das Rechteck liegt vollständig auf der
        # Seite von seed, die Mittelsenkrechte ist eine Kante.
        half = Polygon([
            (mx - uy * big, my + ux * big),
            (mx + uy * big, my - ux * big),
            (mx + uy * big + nx * big, my - ux * big + ny * big),
            (mx - uy * big + nx * big, my + ux * big + ny * big),
        ])
        if not half.is_valid:
            half = half.buffer(0)
        cell = cell.intersection(half)
        if cell.is_empty:
            break
    return cell


def ring(part: Polygon, precision: float = 0.35):
    simple = part.simplify(precision, preserve_topology=True)
    coords = list(simple.exterior.coords)
    if len(coords) < 4:
        coords = list(part.exterior.coords)
    if coords[0] == coords[-1]:
        coords = coords[:-1]
    return [[round(x, 2), round(y, 2)] for x, y in coords]


def make_geometry(countries):
    geometry = {"projection": {"lon": [LON0, LON1], "lat": [LAT0, LAT1],
                               "size": [MAP_W, MAP_H]}, "realms": {}, "adjacency": {}}
    all_cells = {}
    realm_shapes = {}
    for realm_id, codes in GROUPS.items():
        parts = []
        found = []
        for code in codes:
            g = countries.get(code)
            if g is None:
                continue
            found.append(code)
            g = project_geom(g).intersection(box(0, 0, MAP_W, MAP_H))
            parts.extend(polygons_of(g))
        if not parts:
            raise RuntimeError(f"Kein Land für {realm_id}: {codes}")
        realm = unary_union(parts)
        realm_shapes[realm_id] = realm
        expected = list(SEEDS[realm_id])
        pts = []
        for pid in expected:
            lon, lat = SEEDS[realm_id][pid]
            p = project_point(lon, lat)
            if not realm.buffer(0.2).contains(p):
                p = nearest_points(realm, p)[0]
            pts.append(p)
        cells = []
        for idx, pid in enumerate(expected):
            cell = cell_for(realm, pts[idx], pts)
            if cell.is_empty or cell.area < 0.05:
                # Ein Anker kann durch eine benachbarte Zelle verdrängt werden.
                # In diesem Fall die Zelle am Anker mit einem kleinen Puffer
                # wiederherstellen.
                cell = realm.intersection(pts[idx].buffer(8.0))
            polys = polygons_of(cell)
            if not polys:
                raise RuntimeError(f"Leere Provinz {pid}")
            polys.sort(key=lambda p: p.area, reverse=True)
            cells.append((pid, cell, polys))
            all_cells[pid] = cell
        largest = max(polygons_of(realm), key=lambda p: p.area)
        geometry["realms"][realm_id] = {
            "name": realm_id,
            "countries": found,
            "points": ring(largest),
            "provinces": {},
        }
        for pid, cell, polys in cells:
            label = cell.representative_point()
            geometry["realms"][realm_id]["provinces"][pid] = {
                "parts": [ring(p) for p in polys[:8] if p.area > 0.4],
                "label": [round(label.x, 2), round(label.y, 2)],
            }
        print(f"{realm_id:12s} {len(found):2d} Länder, {len(cells)} Provinzen, "
              f"Fläche {realm.area:9.0f}")

    ids = list(all_cells)
    adjacency = {pid: [] for pid in ids}
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            if all_cells[a].distance(all_cells[b]) < 0.55:
                adjacency[a].append(b)
                adjacency[b].append(a)
    # Inseln erhalten eine Seeverbindung zu den zwei nächsten Provinzen.
    for pid in ids:
        if adjacency[pid]:
            continue
        candidates = sorted(
            (all_cells[pid].distance(all_cells[q]), q) for q in ids if q != pid
        )[:2]
        for _, q in candidates:
            if q not in adjacency[pid]:
                adjacency[pid].append(q)
            if pid not in adjacency[q]:
                adjacency[q].append(pid)
    for pid in ids:
        adjacency[pid].sort()
    geometry["adjacency"] = adjacency
    empty = [pid for pid, ns in adjacency.items() if not ns]
    print("Provinzen:", len(ids), "leere Nachbarschaften:", empty)
    print("Nachbarschaften:", sum(len(v) for v in adjacency.values()) // 2)
    return geometry


def font(size: int):
    for path in ("C:/Windows/Fonts/georgia.ttf", "C:/Windows/Fonts/times.ttf",
                 "C:/Windows/Fonts/arial.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_line_string(draw, xy, text, fnt, fill, spacing=2):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + spacing


def render_background(countries):
    W, H = int(MAP_W * SS), int(MAP_H * SS)
    img = Image.new("RGB", (W, H), (24, 48, 51))
    d = ImageDraw.Draw(img, "RGBA")
    # Meeresstruktur
    for y in range(H):
        t = y / max(1, H - 1)
        c = (int(25 + 9 * t), int(48 + 10 * t), int(52 + 9 * t))
        d.line((0, y, W, y), fill=c)
    rng = random.Random(37)
    for _ in range(700):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H)
        rad = rng.uniform(4, 22) * SS
        d.arc((x - rad, y - rad * .35, x + rad, y + rad * .35),
              rng.uniform(0, 180), rng.uniform(180, 360),
              fill=(117, 155, 151, rng.randint(10, 26)), width=1)

    # Graticule, sehr zurückhaltend
    for lon in range(-10, 51, 10):
        x = (lon - LON0) / (LON1 - LON0) * W
        d.line((x, 0, x, H), fill=(191, 181, 143, 20), width=1)
    for lat in range(35, 71, 10):
        y = (LAT1 - lat) / (LAT1 - LAT0) * H
        d.line((0, y, W, y), fill=(191, 181, 143, 20), width=1)

    land_parts = []
    country_parts = []
    for code, geom in countries.items():
        clipped = project_geom(geom).intersection(box(0, 0, MAP_W, MAP_H))
        for p in polygons_of(clipped):
            if p.area < 0.05:
                continue
            sp = affinity.scale(p, xfact=SS, yfact=SS, origin=(0, 0))
            country_parts.append(sp)
            land_parts.append(sp)
    # Land mit leicht variierender Papiertonung
    for idx, p in enumerate(land_parts):
        pts = [(x, y) for x, y in p.exterior.coords]
        tone = 1.0 + ((idx * 17) % 9 - 4) * 0.008
        fill = (int(205 * tone), int(188 * tone), int(150 * tone), 255)
        d.polygon(pts, fill=fill)
    # sanfte Binnenlinien / Burden
    for p in country_parts:
        if p.area < 3:
            continue
        xs = [x for x, y in p.exterior.coords]
        ys = [y for x, y in p.exterior.coords]
        cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
        d.line([(min(xs), cy), (max(xs), cy)], fill=(106, 84, 53, 12), width=1)
    # Staatsgrenzen
    for p in country_parts:
        pts = [(x, y) for x, y in p.exterior.coords]
        d.line(pts, fill=(116, 91, 56, 150), width=max(1, SS), joint="curve")
    # Küstenlinie kräftiger
    coast = unary_union(land_parts).boundary
    for line in getattr(coast, "geoms", [coast]):
        if line.is_empty:
            continue
        if line.geom_type == "LineString":
            d.line([(x, y) for x, y in line.coords], fill=(67, 52, 31, 235),
                   width=max(2, 3 * SS), joint="curve")

    # Papierkörnung
    arr = np.asarray(img).astype(np.int16)
    noise = np.random.default_rng(11).normal(0, 4.2, (H, W, 1)).astype(np.int16)
    arr = np.clip(arr + noise, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr, "RGB")
    d = ImageDraw.Draw(img, "RGBA")

    # Meeresbeschriftung nur auf Wasser
    sea = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sea, "RGBA")
    f1 = font(int(12 * SS))
    f2 = font(int(9 * SS))
    labels = [
        ("ATLANTIK", (78, 300), f1, (172, 195, 183, 105)),
        ("MITTELMEER", (505, 704), f1, (172, 195, 183, 115)),
        ("NORDSEE", (430, 255), f2, (172, 195, 183, 115)),
        ("OSTSEE", (655, 233), f2, (172, 195, 183, 115)),
        ("SCHWARZES MEER", (855, 478), f2, (172, 195, 183, 115)),
        ("EUROPA", (50, 63), f1, (214, 190, 137, 95)),
    ]
    for text, xy, fnt, col in labels:
        draw_line_string(sd, (xy[0] * SS, xy[1] * SS), text, fnt, col, 2 * SS)
    land_mask = Image.new("L", (W, H), 255)
    lm = ImageDraw.Draw(land_mask)
    for p in land_parts:
        lm.polygon([(x, y) for x, y in p.exterior.coords], fill=0)
    sea.putalpha(Image.composite(sea.getchannel("A"), Image.new("L", (W, H), 0), land_mask))
    img = Image.alpha_composite(img.convert("RGBA"), sea)

    # Kartenrahmen und Vignette
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 0, W - 1, H - 1), outline=(181, 145, 83, 180), width=4 * SS)
    d.rectangle((5 * SS, 5 * SS, W - 6 * SS, H - 6 * SS), outline=(66, 47, 26, 90), width=SS)
    ASSETS.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(ASSETS / "europe_bg.png", optimize=True)
    print("Hintergrund:", ASSETS / "europe_bg.png", img.size)


def main():
    countries = load_countries()
    geometry = make_geometry(countries)
    DATA.mkdir(parents=True, exist_ok=True)
    with (DATA / "europe_geometry.json").open("w", encoding="utf-8") as fh:
        json.dump(geometry, fh, ensure_ascii=False, separators=(",", ":"))
    render_background(countries)
    total = sum(len(r["provinces"]) for r in geometry["realms"].values())
    print("Geometrie:", DATA / "europe_geometry.json", "Provinzen:", total)


if __name__ == "__main__":
    main()
