#!/usr/bin/env python3
"""Build the offline reference atlas from actual, cached public geodata.

Dependencies: Python 3.11+, Shapely 2.1+, curl.exe (Windows trust store).
No Godot process is started. Run tests with: python tools/test_atlas_data.py
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import subprocess
import urllib.parse
import zipfile

import shapely
from shapely import affinity
from shapely.geometry import LineString, Point, Polygon, box, mapping, shape
from shapely.ops import unary_union
from shapely.strtree import STRtree

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".tools/atlas_sources"
SIZE = (1200, 760)
BOUNDS = (-12, 33, 52, 72)
CLIP = box(*BOUNDS)
NE_VERSION = "v5.1.2"
NE_BASE = f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/{NE_VERSION}/geojson/"
BKG_WFS = "https://sgx.geodatenzentrum.de/wfs_vg250"
BKG_DATE = "2025-01-01"
BKG_PRODUCT = "https://gdz.bkg.bund.de/index.php/default/wfs-verwaltungsgebiete-1-250-000-stand-01-01-wfs-vg250.html"
BKG_CREDIT = "© BKG (2026), dl-de/by-2-0; projiziert, auf Landflächen begrenzt und vereinfacht."
WIDTHS = {"region": 2, "district": 5, "municipality": 8}
RIVER_NAMES = {
    "rhine": "Rhein", "danube": "Donau", "rhone": "Rhône", "rhône": "Rhône",
    "thames": "Themse", "dnieper": "Dnepr", "dnipro": "Dnepr", "tagus": "Tajo",
    "vistula": "Weichsel", "volga": "Wolga", "dniester": "Dnister", "oder": "Oder",
    "elbe": "Elbe", "ebro": "Ebro", "po": "Po", "seine": "Seine", "loire": "Loire",
}
CITY_NAMES = {
    "DE": {"Munich": "München", "Cologne": "Köln", "Hanover": "Hannover", "Nuremberg": "Nürnberg"},
    "AT": {"Vienna": "Wien"},
    "BE": {"Brussels": "Brüssel", "Antwerp": "Antwerpen", "Liège": "Lüttich", "Liege": "Lüttich"},
    "FR": {"Strasbourg": "Straßburg"},
    "RU": {"Moscow": "Moskau", "Saint Petersburg": "Sankt Petersburg"},
    "IT": {"Rome": "Rom", "Milan": "Mailand", "Florence": "Florenz", "Naples": "Neapel", "Venice": "Venedig"},
    "CZ": {"Prague": "Prag"},
    "DK": {"Copenhagen": "Kopenhagen"},
    "GR": {"Athens": "Athen"},
    "PT": {"Lisbon": "Lissabon"},
    "PL": {"Warsaw": "Warschau"},
    "NL": {"The Hague": "Den Haag"},
    "LU": {"Luxembourg": "Luxemburg"},
    "EG": {"Cairo": "Kairo"},
}


def normalise_city_name(name: str, country: str) -> str:
    """Use established German exonyms only within the matching source country."""
    return CITY_NAMES.get(country.upper(), {}).get(name, name)


def project(lon: float, lat: float) -> tuple[float, float]:
    lon, lat = float(lon), float(lat)
    if not math.isfinite(lon) or not math.isfinite(lat):
        raise ValueError("Nonfinite geographic coordinate")
    return ((lon - BOUNDS[0]) * SIZE[0] / (BOUNDS[2] - BOUNDS[0]),
            (BOUNDS[3] - lat) * SIZE[1] / (BOUNDS[3] - BOUNDS[1]))


def props(feature: dict) -> dict:
    return {k.lower(): v for k, v in feature.get("properties", {}).items()}


def country_code(properties: dict) -> str:
    for key in ("iso_a2_eh", "iso_a2", "adm0_a3"):
        value = str(properties.get(key) or "")
        if value.isalpha() and len(value) in (2, 3):
            return value.upper()
    raise ValueError("Natural Earth country has no usable geographic identifier")


def administrative_id(kind: str, ags: str) -> str:
    return f"{kind}:DE-{str(ags).zfill(WIDTHS[kind])}"


def administrative_parent_id(kind: str, ags: str) -> str:
    ags = str(ags).zfill(WIDTHS[kind])
    if kind == "region":
        return "country:DE"
    return administrative_id("region", ags[:2]) if kind == "district" else administrative_id("district", ags[:5])


def valid_geometry(geometry):
    return geometry if geometry.is_valid else shapely.make_valid(geometry)


def merge_ags_features(features: list[dict], width: int) -> list[dict]:
    """Land only (GF=4), then dissolve parts by padded official key.

    VG250 documents GF=2 as coastal/lake water, not additional Gemeinden.
    Features without GF are accepted for normalized sources and unit fixtures.
    """
    groups: dict[str, list] = defaultdict(list)
    metadata = {}
    for feature in features:
        p = props(feature)
        if p.get("gf", 4) != 4 or not feature.get("geometry"):
            continue
        ags = str(p.get("ags", "")).strip().zfill(width)
        if len(ags) != width or not ags.isdecimal():
            raise ValueError(f"Invalid {width}-digit AGS: {ags!r}")
        groups[ags].append(valid_geometry(shape(feature["geometry"])))
        metadata.setdefault(ags, {**p, "ags": ags})
    return [{"type": "Feature", "properties": metadata[key],
             "geometry": mapping(unary_union(groups[key]))} for key in sorted(groups)]


class GeometryPool:
    def __init__(self):
        self.data = bytearray()
        self._paths = {}

    def add_path(self, points) -> list[int] | None:
        points = [(float(p[0]), float(p[1])) for p in points]
        if len(points) < 2:
            return None
        if not all(math.isfinite(v) for p in points for v in p):
            raise ValueError("Nonfinite path coordinate")
        packed = b"".join(struct.pack("<ff", *p) for p in points)
        if packed in self._paths:
            return self._paths[packed]
        ref = [len(self.data) // 8, len(points)]
        self.data.extend(packed)
        self._paths[packed] = ref
        return ref

    def add_geometry(self, geometry) -> list[list[int]]:
        paths = []
        for points in geometry_paths(geometry):
            ref = self.add_path(points)
            if ref is not None:
                paths.append(ref)
        return paths


def geometry_paths(geometry):
    if geometry.is_empty:
        return
    if geometry.geom_type == "Polygon":
        yield geometry.exterior.coords
        for ring in geometry.interiors:
            yield ring.coords
    elif geometry.geom_type in ("LineString", "LinearRing"):
        yield geometry.coords
    elif hasattr(geometry, "geoms"):
        for child in geometry.geoms:
            yield from geometry_paths(child)


def projected_geometry(geometry):
    x_scale = SIZE[0] / (BOUNDS[2] - BOUNDS[0])
    y_scale = SIZE[1] / (BOUNDS[3] - BOUNDS[1])
    return affinity.affine_transform(geometry, [x_scale, 0, 0, -y_scale, -BOUNDS[0] * x_scale, BOUNDS[3] * y_scale])


class ProvinceIndex:
    def __init__(self, path: Path):
        data = json.loads(path.read_text(encoding="utf-8"))
        self.ids, self.polygons = [], []
        for realm in data["realms"].values():
            for pid, entry in realm["provinces"].items():
                for points in entry["parts"]:
                    if len(points) >= 3:
                        self.ids.append(pid)
                        self.polygons.append(valid_geometry(Polygon(points)))
        self.tree = STRtree(self.polygons)

    def resolve(self, point: tuple[float, float]) -> str:
        p = Point(point)
        matches = self.tree.query(p, predicate="intersects")
        return sorted({self.ids[int(i)] for i in matches})[0] if len(matches) else ""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def compact_json(value) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False)


def download(url: str, name: str, refresh: bool = False) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / name
    if path.exists() and not refresh:
        return path
    partial, headers = path.with_suffix(path.suffix + ".part"), path.with_suffix(path.suffix + ".headers")
    print(f"Download {name}", flush=True)
    subprocess.run(["curl.exe", "--fail", "--location", "--silent", "--show-error", "--retry", "3",
                    "--retry-delay", "1", "--connect-timeout", "20", "--max-time", "240",
                    "--max-filesize", "150000000", "--dump-header", str(headers),
                    "--output", str(partial), url], check=True)
    partial.replace(path)
    meta = {"url": url, "retrieved_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "bytes": path.stat().st_size, "sha256": sha256_file(path)}
    for line in headers.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.lower().startswith("last-modified:"):
            meta["last_modified"] = line.partition(":")[2].strip()
    path.with_suffix(path.suffix + ".meta.json").write_text(compact_json(meta) + "\n", encoding="utf-8")
    return path


def source_record(path: Path, source_id: str, url: str, date: str, license_name: str,
                  attribution: str, license_url: str, **extra) -> dict:
    meta_path = path.with_suffix(path.suffix + ".meta.json")
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    return {"id": source_id, "url": url, "date": date, "license": license_name,
            "license_url": license_url, "attribution": attribution, "sha256": sha256_file(path),
            "bytes": path.stat().st_size, "retrieved_utc": meta.get("retrieved_utc", ""), **extra}


def bkg_data(layer: str, refresh: bool = False) -> tuple[dict, dict]:
    """Stable, bounded pages; missing/inconsistent pages fail the build."""
    common = {"service": "WFS", "version": "2.0.0", "request": "GetFeature",
              "typeNames": f"vg250:{layer}", "outputFormat": "application/json",
              "srsName": "EPSG:4326", "CQL_FILTER": "gf=4", "sortBy": "objid"}
    source_url = BKG_WFS + "?" + urllib.parse.urlencode(common)
    assembled = CACHE / f"bkg_{layer}.geojson"
    pages_path = CACHE / f"bkg_{layer}_pages.json"
    if assembled.exists() and pages_path.exists() and not refresh:
        data = json.loads(assembled.read_text(encoding="utf-8"))
        pages = json.loads(pages_path.read_text(encoding="utf-8"))
    else:
        features, pages, seen = [], [], set()
        expected = None
        while expected is None or len(features) < expected:
            if len(pages) >= 100:
                raise RuntimeError(f"Safety page limit reached for {layer}")
            url = BKG_WFS + "?" + urllib.parse.urlencode({**common, "count": 500, "startIndex": len(features)})
            path = download(url, f"{layer}_{len(features):05d}.geojson", refresh)
            page = json.loads(path.read_text(encoding="utf-8"))
            if page.get("type") != "FeatureCollection":
                raise ValueError(f"WFS did not return a FeatureCollection: {path}")
            count = page.get("numberMatched", page.get("totalFeatures"))
            if not isinstance(count, int) and not (isinstance(count, str) and count.isdecimal()):
                raise ValueError(f"WFS count is not verifiable: {count!r}")
            count = int(count)
            if expected is None:
                expected = count
            if count != expected:
                raise ValueError(f"WFS changed while paging {layer}")
            rows = page["features"]
            if not rows:
                raise ValueError(f"WFS ended early: {len(features)} of {expected}")
            for row in rows:
                key = row.get("id", props(row).get("objid"))
                if key is None or key in seen:
                    raise ValueError(f"Missing/repeated source feature in {layer}")
                seen.add(key)
            features.extend(rows)
            pages.append({"file": path.name, "url": url, "sha256": sha256_file(path), "count": len(rows)})
            print(f"BKG {layer}: {len(features)}/{expected}", flush=True)
        if len(features) != expected:
            raise ValueError(f"WFS count mismatch in {layer}")
        data = {"type": "FeatureCollection", "numberMatched": expected, "features": features}
        assembled.write_text(compact_json(data) + "\n", encoding="utf-8")
        pages_path.write_text(compact_json(pages) + "\n", encoding="utf-8")
        assembled.with_suffix(assembled.suffix + ".meta.json").write_text(compact_json({
            "retrieved_utc": datetime.now(timezone.utc).isoformat(timespec="seconds")}) + "\n", encoding="utf-8")
    source = source_record(assembled, "bkg-vg250-" + layer, source_url, BKG_DATE, "DL-DE-BY-2.0",
                           BKG_CREDIT, "https://www.govdata.de/dl-de/by-2-0", product_url=BKG_PRODUCT,
                           raw_feature_count=len(data["features"]), pages=pages, filter="GF=4 (Landflächen)")
    return data, source


def feature_record(pool: GeometryPool, provinces: ProvinceIndex, geometry, *, feature_id: str,
                   name: str, kind: str, parent_id: str, country: str, source: str,
                   tolerance: float, **extra) -> dict | None:
    if geometry.is_empty or not geometry.intersects(CLIP):
        return None
    clipped = valid_geometry(geometry).intersection(CLIP)
    if clipped.is_empty:
        return None
    projected = projected_geometry(clipped).simplify(tolerance, preserve_topology=True)
    refs = pool.add_geometry(projected)
    if not refs:
        return None
    point = projected.representative_point()
    center = (point.x, point.y)
    x0, y0, x1, y1 = projected.bounds
    return {"id": feature_id, "name": str(name), "kind": kind, "parent_id": parent_id,
            "province_id": provinces.resolve(center), "center": [round(v, 4) for v in center],
            "bounds": [round(v, 4) for v in (x0, y0, x1 - x0, y1 - y0)], "paths": refs,
            "country": country, "source": source, **extra}


def build(refresh: bool = False):
    names = {
        "countries": "ne_50m_admin_0_countries.geojson",
        "regions": "ne_10m_admin_1_states_provinces.geojson",
        "rivers": "ne_10m_rivers_lake_centerlines.geojson",
    }
    jobs = [(NE_BASE + name, name) for name in names.values()]
    jobs.append(("https://download.geonames.org/export/dump/cities5000.zip", "cities5000.zip"))
    with ThreadPoolExecutor(max_workers=4) as executor:
        downloaded = list(executor.map(lambda job: download(*job, refresh=refresh), jobs))
    sources = []
    for kind, name in names.items():
        sources.append(source_record(CACHE / name, "natural-earth-" + kind, NE_BASE + name,
            NE_VERSION, "Public Domain", "Made with Natural Earth.",
            "https://www.naturalearthdata.com/about/terms-of-use/"))
    city_path = CACHE / "cities5000.zip"
    city_meta = json.loads(city_path.with_suffix(".zip.meta.json").read_text(encoding="utf-8"))
    city_date = parsedate_to_datetime(city_meta["last_modified"]).date().isoformat() if city_meta.get("last_modified") else city_meta["retrieved_utc"][:10]
    sources.append(source_record(city_path, "geonames-cities5000", jobs[-1][0], city_date,
        "CC-BY-4.0", "GeoNames — www.geonames.org", "https://creativecommons.org/licenses/by/4.0/"))

    pool = GeometryPool()
    provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
    features = []
    country_codes = {}
    country_data = json.loads((CACHE / names["countries"]).read_text(encoding="utf-8"))
    for raw in country_data["features"]:
        p = props(raw)
        code = country_code(p)
        country_codes[p.get("adm0_a3", "")] = code
        item = feature_record(pool, provinces, shape(raw["geometry"]), feature_id="country:" + code,
            name=p.get("name_de") or p.get("name"), kind="country", parent_id="", country=code,
            source="natural-earth-countries", tolerance=0.08)
        if item:
            features.append(item)
    region_data = json.loads((CACHE / names["regions"]).read_text(encoding="utf-8"))
    country_ids = {f["id"] for f in features}
    missing_countries = defaultdict(list)
    missing_country_names = {}
    for raw in region_data["features"]:
        p = props(raw)
        code = country_codes.get(p.get("adm0_a3")) or country_code(p)
        if code == "DE":
            continue
        region_id = str(p.get("adm1_code") or p.get("iso_3166_2"))
        item = feature_record(pool, provinces, shape(raw["geometry"]), feature_id="region:" + region_id,
            name=p.get("name_de") or p.get("name") or p.get("name_en") or region_id,
            kind="region", parent_id="country:" + code, country=code,
            source="natural-earth-regions", tolerance=0.05)
        if item:
            features.append(item)
            if item["parent_id"] not in country_ids:
                missing_countries[code].append(shape(raw["geometry"]))
                missing_country_names[code] = {"ESB": "Dekelia", "WSB": "Akrotiri"}.get(code, p.get("admin") or p.get("name_de") or code)

    # A few tiny admin-0 territories are absent at 1:50m. Their actual
    # 1:10m admin-1 outlines supply the parent, rather than inventing geometry.
    for code, geometries in sorted(missing_countries.items()):
        item = feature_record(pool, provinces, unary_union(geometries), feature_id="country:" + code,
            name=missing_country_names[code], kind="country", parent_id="", country=code,
            source="natural-earth-regions", tolerance=0.08)
        if item:
            features.append(item)

    for layer, kind, tolerance in [("vg250_lan", "region", 0.03), ("vg250_krs", "district", 0.025),
                                    ("vg250_gem", "municipality", 0.02)]:
        raw, source = bkg_data(layer, refresh)
        sources.append(source)
        merged = merge_ags_features(raw["features"], WIDTHS[kind])
        source["unique_ags_count"] = len(merged)
        for raw_feature in merged:
            p = raw_feature["properties"]
            item = feature_record(pool, provinces, shape(raw_feature["geometry"]),
                feature_id=administrative_id(kind, p["ags"]), name=p["gen"], kind=kind,
                parent_id=administrative_parent_id(kind, p["ags"]), country="DE", source="bkg-vg250",
                tolerance=tolerance, ags=p["ags"])
            if item:
                features.append(item)
        print(f"Normalized {kind}: {len(merged)} official keys", flush=True)

    cities = []
    with zipfile.ZipFile(city_path) as archive:
        with archive.open("cities5000.txt") as handle:
            for line in io.TextIOWrapper(handle, encoding="utf-8"):
                row = line.rstrip("\n").split("\t")
                lon, lat = float(row[5]), float(row[4])
                if not (BOUNDS[0] <= lon <= BOUNDS[2] and BOUNDS[1] <= lat <= BOUNDS[3]):
                    continue
                point = project(lon, lat)
                cities.append({"id": "geonames:" + row[0], "name": normalise_city_name(row[1], row[8]),
                    "point": [round(v, 4) for v in point], "population": int(row[14] or 0),
                    "country": row[8], "province_id": provinces.resolve(point), "source": "geonames-cities5000"})
    cities.sort(key=lambda city: (-city["population"], city["id"]))

    river_data = json.loads((CACHE / names["rivers"]).read_text(encoding="utf-8"))
    river_parts = defaultdict(list)
    for raw in river_data["features"]:
        geometry = shape(raw["geometry"])
        if geometry.is_empty or not geometry.intersects(CLIP):
            continue
        p = props(raw)
        original = str(p.get("name_de") or p.get("name") or "")
        # Unnamed real rivers remain real geometry; never invent a place name.
        name = RIVER_NAMES.get(original.casefold(), original)
        key = name or "unnamed:" + str(p.get("ne_id") or len(river_parts))
        river_parts[key].append(geometry.intersection(CLIP))
    rivers = []
    for key, parts in sorted(river_parts.items()):
        geometry = projected_geometry(unary_union(parts)).simplify(0.04, preserve_topology=True)
        refs = pool.add_geometry(geometry)
        if not refs:
            continue
        x0, y0, x1, y1 = geometry.bounds
        rivers.append({"name": "" if key.startswith("unnamed:") else key,
            "bounds": [round(v, 4) for v in (x0, y0, x1 - x0, y1 - y0)], "paths": refs,
            "source": "natural-earth-rivers"})

    features.sort(key=lambda feature: feature["id"])
    atlas = {"schema": 1, "projection": {"size": list(SIZE), "bounds": list(BOUNDS)},
             "geometry": "res://data/atlas_geometry.bin", "sources": sources,
             "features": features, "cities": cities, "rivers": rivers,
             "reference_geography": "Heutige geografische Referenz; keine behaupteten historischen Grenzen oder Gründungsdaten."}
    validate_atlas(atlas, pool)
    binary_path, json_path = ROOT / "data/atlas_geometry.bin", ROOT / "data/atlas.json"
    json_bytes = (compact_json(atlas) + "\n").encode("utf-8")
    # Preserve unchanged outputs, so a cached rebuild cannot briefly truncate
    # data another worker is reading in the editor or test runner.
    for path, payload in ((binary_path, pool.data), (json_path, json_bytes)):
        if not path.exists() or path.read_bytes() != payload:
            temporary = path.with_suffix(path.suffix + ".tmp")
            temporary.write_bytes(payload)
            temporary.replace(path)
    write_documentation(atlas, json_path, binary_path)
    print(compact_json({"features": dict(Counter(f["kind"] for f in features)), "cities": len(cities),
                        "rivers": len(rivers), "geometry_bytes": len(pool.data), "json_bytes": json_path.stat().st_size}), flush=True)


def validate_atlas(atlas: dict, pool: GeometryPool):
    if len(pool.data) >= 100_000_000:
        raise ValueError("Geometry exceeds the 100 MB data budget")
    if len(compact_json(atlas).encode("utf-8")) >= 15_000_000:
        raise ValueError("Metadata exceeds the 15 MB data budget")
    ids = [f["id"] for f in atlas["features"]]
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate feature identifier")
    id_set = set(ids)
    for f in atlas["features"]:
        if f["parent_id"] and f["parent_id"] not in id_set:
            raise ValueError(f"Unresolved parent of {f['id']}: {f['parent_id']}")
    lands = [f for f in atlas["features"] if f["kind"] == "region" and f["country"] == "DE"]
    if len(lands) != 16:
        raise ValueError(f"Expected 16 Bundesländer, found {len(lands)}")
    for name in ("Wiesbaden", "Berlin"):
        found = [c for c in atlas["cities"] if c["name"] == name and c["country"] == "DE"]
        if len(found) != 1 or not found[0]["province_id"]:
            raise ValueError(f"Known city/province link missing: {name}")


def write_documentation(atlas: dict, json_path: Path, binary_path: Path):
    counts = Counter(f["kind"] for f in atlas["features"])
    rows = ["# Quellen und Buildnachweis des Offline-Atlas", "",
        "Der Atlas umfasst Länge −12 bis 52° und Breite 33 bis 72° im Kartenraum 1200×760. "
        "Alle Laufzeitdaten liegen unter `data/` und werden vollständig offline mit dem Spiel verpackt. "
        "Die heutigen Verwaltungsgrenzen und Ortsnamen sind Referenzgeografie, keine behaupteten "
        "Grenzen oder Stadtgründungen der bronzezeitlichen Kampagne.", "",
        "## Eingebetteter Umfang", "", "| Objekt | Anzahl |", "|---|---:|"]
    rows += [f"| {kind} | {count} |" for kind, count in sorted(counts.items())]
    rows += [f"| Städte (GeoNames) | {len(atlas['cities'])} |", f"| Flussnamen/-gruppen | {len(atlas['rivers'])} |", "",
        "Deutschland enthält genau 16 Länder nach AGS. Kreise und Gemeinden werden nach dem "
        "fünf- beziehungsweise achtstelligen AGS vereinigt; führende Nullen bleiben erhalten. "
        "GF=4 wählt gemäß der [BKG-Dokumentation](https://sgx.geodatenzentrum.de/web_public/gdz/dokumentation/deu/vg250.pdf) "
        "die Landflächen. Zusätzliche Gewässerdatensätze werden nicht als weitere Gemeinden gezählt.", "",
        "## Originalquellen und Lizenzen", "",
        "Die folgende Tabelle nennt den tatsächlich benutzten Stand und den SHA-256 der gecachten "
        "Originaldatei beziehungsweise des vollständig aus WFS-Seiten zusammengesetzten GeoJSON-Exports. "
        "Die Hashes und URLs jeder unveränderten WFS-Antwortseite stehen zusätzlich in `data/atlas.json`.", "",
        "| Quelle | Stand | Lizenz | Bytes | SHA-256 |", "|---|---|---|---:|---|"]
    for source in atlas["sources"]:
        rows.append(f"| [{source['id']}]({source['url']}) | {source['date']} | [{source['license']}]({source['license_url']}) | {source['bytes']} | `{source['sha256']}` |")
    rows += ["", "BKG-Quellenvermerk: " + BKG_CREDIT + " "
        "[Datenquellen](https://sgx.geodatenzentrum.de/web_public/gdz/datenquellen/datenquellen_vg_nuts.pdf). "
        "Der verwendete freie WFS dokumentiert Stand 01.01.2025; neuere getrennte Downloadprodukte wurden nicht damit vermischt.", "",
        "GeoNames: © GeoNames, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), "
        "[Datenbeschreibung](https://download.geonames.org/export/dump/readme.txt). "
        "Koordinaten und Datenauswahl wurden projiziert und auf den Kartenausschnitt begrenzt; "
        "einige geläufige deutsche Orts- und Flussnamen wurden normalisiert. "
        "Ortsalias-Regeln gelten ausschließlich für das jeweils passende Quellland (beispielsweise "
        "Brüssel/Antwerpen/Lüttich in Belgien, Straßburg in Frankreich, Sankt Petersburg in Russland, "
        "Mailand/Florenz/Neapel/Venedig in Italien sowie Den Haag und Luxemburg). "
        "Gleichnamige Orte in anderen Ländern behalten ihren Originalnamen.", "",
        "Natural Earth: Made with Natural Earth. Public-Domain-Vektoren aus dem versionierten "
        f"Repository-Tag `{NE_VERSION}`; [Nutzungsbedingungen](https://www.naturalearthdata.com/about/terms-of-use/). "
        "Die Flüsse stammen aus `ne_10m_rivers_lake_centerlines`, nicht aus erfundenen Pixel-Linien.", "",
        "## Verarbeitung und Reproduktion", "",
        "Die Pipeline clippt echte Geometrien im geografischen Koordinatenraum, projiziert sie anschließend "
        "gemeinsam und vereinfacht die Umrisslinien topologieerhaltend mit maximal 0,08 Kartenpixeln "
        "(Gemeinden 0,02). Die Ausgabe enthält Float32-Paare, little endian; `[offset,count]` zählt Punkte, "
        "keine Bytes. Identische Pfade teilen sich einen Pooleintrag. Die 49 ursprünglichen Simulationsgebiete "
        "werden nicht ersetzt; `province_id` wird ausschließlich durch räumliches Enthaltensein bestimmt. "
        "Orte außerhalb dieser Gebiete behalten eine leere Zuordnung.", "",
        "Rohdaten und unveränderte WFS-Seiten liegen ausschließlich im ignorierten Verzeichnis "
        "`.tools/atlas_sources/`. Downloads verwenden `curl.exe` mit Zertifikatsprüfung durch Windows; "
        "es gibt keinen TLS-Bypass. Ein erneuter Build benutzt den Cache; `--refresh` ruft die Quellen "
        "ausdrücklich neu ab. GeoNames und der WFS sind veränderliche Dienste: für einen bytegleichen "
        "Neuaufbau den Cache mit den dokumentierten Quellhashes verwenden.", "",
        "```powershell", "python tools/build_atlas_data.py", "python tools/test_atlas_data.py", "```", "",
        "Der Python-Test umfasst zehn gezielte Pipelinefälle und vier Prüfungen des vollständigen "
        "realen Ausgabedatensatzes: Projektion, AGS-Zusammenführung, Land-/Wassertrennung, "
        "fehlende Natural-Earth-Länderkennungen, Pfadoffsets, Budget, Elternhierarchie, "
        "alle 16 deutschen Länder, mehr als 10.000 Gemeinden, bekannte Positionen von "
        "Wiesbaden/Berlin, bestehende Spielgebietszuordnung, echte Flüsse und Quellenhashes. "
        "Vier neue Aliasfälle wurden zunächst rot beobachtet; Negativkontrollen verhindern "
        "die Umbenennung gleichnamiger Orte in anderen Ländern. "
        "Ein Geodatentest belegt keine gerenderte Karte und keinen Android-Gerätelauf.", "",
        "| Builddatei | Bytes | SHA-256 |", "|---|---:|---|"]
    rows += [f"| `{path.relative_to(ROOT).as_posix()}` | {path.stat().st_size} | `{sha256_file(path)}` |" for path in (json_path, binary_path)]
    (ROOT / "docs/atlas-sources.md").write_text("\n".join(rows) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true", help="Fetch changing sources again instead of reusing their cache")
    build(refresh=parser.parse_args().refresh)
