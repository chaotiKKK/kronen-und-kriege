"""Pinned Map Tunisia municipality polygons; no synthetic administrative level."""
from __future__ import annotations

import argparse
from collections import defaultdict
import csv
import hashlib
import json
import math
from pathlib import Path
import re
from typing import Iterator
import urllib.request

from shapely.geometry import box, shape

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
COMMIT = "2b704248c6105ceb2d8963ef9cfa052c683d0457"
BASE = f"https://raw.githubusercontent.com/Alaa-Taieb/map-tunisia/{COMMIT}/"
SOURCE_ID = "map-tunisia-municipalities-OSM20261016"
CACHE_DIRECTORY = "audit/tunisia-municipal-2026/producer"
ATLAS_BBOX = (-12, 33, 52, 72)
OSM_TIMESTAMP = "2026-10-16T20:21:21Z"
OSM_PBF_SHA256 = "444dd6e1e64e1ab4626cde5e54d911876c7761b63f4624a98872421007f50429"
ATTRIBUTION = "Map data © OpenStreetMap contributors · Map Tunisia by Alaa Taieb; ODbL 1.0"
GEOMETRY_FILE = "data/source/tunisia-municipalities.geojson"
ATTRIBUTES_FILE = "data/attributes/municipalities.csv"
REPORT_FILE = "data/source/municipalities-report.json"
PINNED_FILES = {
    GEOMETRY_FILE: (6702026, "4db4db6a972077cb0cf3a0c470e4c70afdaea9760b18d6b09b76cd039fa90d55"),
    ATTRIBUTES_FILE: (24866, "59673998765cb574b3db3c902b3b8230002c13fd794372affcd04533c75110a7"),
    REPORT_FILE: (4382, "3d4098dad3851c814d1b1644a63818bf7c506d487f92d36ccc930945e49c8efc"),
    "data/source/extract-report.json": (49643, "e90aa626107e0fa607ae33d717410392769385cb440defc8cb9660d87352f4dc"),
    "LICENSE-DATA.md": (2276, "679dd574ae1a675d8988e56b75c0bc8108995e9d8b47742bafc4fbf74d2cabb2"),
    "docs/methodology.md": (19642, "948562815c7afc01c2ca34ae7bf9ae716636960db38eb1a2e1670273cb442803"),
    "docs/accuracy.md": (25798, "611ad9c8afaa297b59e18b9b62f83954b6bbed143c45fc7d4b2d8584a0b68a43"),
    "scripts/extract/municipalities.py": (12131, "0381481d01f9ed1993e87929150120cbd4c4fd1b3368ecdf86f73bdb7a262d28"),
}


def verify_file(path: Path, receipt: dict) -> None:
    raw = path.read_bytes()
    if len(raw) != receipt["bytes"] or hashlib.sha256(raw).hexdigest() != receipt["sha256"]:
        raise ValueError(f"Changed Tunisian source file integrity/hash: {path.name}")


def _file_receipts() -> list[dict]:
    return [{"cache_file": CACHE_DIRECTORY + "/" + relative, "producer_path": relative,
             "url": BASE + relative, "bytes": size, "sha256": digest}
            for relative, (size, digest) in PINNED_FILES.items()]


def _receipt_digest(files: list[dict]) -> str:
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def normalize_feature(feature: dict, attributes: dict) -> dict:
    """Join the producer's exact geometry to its original relation attributes."""
    properties = feature.get("properties") or {}
    unit_id = properties.get("municipality", "")
    match = re.fullmatch(r"municipality-([1-9]\d*)", unit_id) if isinstance(unit_id, str) else None
    attribute = attributes.get(unit_id)
    if not match or attribute is None:
        raise ValueError("Tunisian municipality geometry has no matching source catalogue identity")
    relation_id = match[1]
    if attribute.get("id") != unit_id or str(attribute.get("osm_relation")) != relation_id:
        raise ValueError("Changed Tunisian municipality catalogue/relation identity")
    governorate = properties.get("governorate")
    if (not isinstance(governorate, str) or re.fullmatch(r"TN-\d{2}", governorate) is None
            or attribute.get("governorate") != governorate):
        raise ValueError("Changed Tunisian municipality source governorate identity")
    geometry = shape(feature.get("geometry") or {})
    if (geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty
            or not geometry.is_valid or geometry.area <= 0):
        raise ValueError(f"Invalid Tunisian municipal polygon geometry: {unit_id}")
    x0, y0, x1, y1 = geometry.bounds
    if (not all(math.isfinite(value) for value in geometry.bounds)
            or not (-180 <= x0 <= x1 <= 180 and -90 <= y0 <= y1 <= 90)):
        raise ValueError("Tunisian municipality geometry is not longitude/latitude")
    names = {language: attribute.get("name_" + language, "") for language in ("fr", "ar", "en")}
    original_name = names["fr"] or names["ar"] or names["en"]
    return {"id": "map-tunisia:municipality:" + relation_id, "source_unit_id": unit_id,
            "country": "TN", "source": SOURCE_ID, "kind": "municipality",
            "geometry": geometry, "name": original_name or "Gemeinde (Quellname fehlt)",
            "original_name": original_name, "name_known": bool(original_name), "source_names": names,
            "osm_relation_id": int(relation_id), "original_source_id": relation_id,
            "source_boundary": "municipality", "native_level": "OSM boundary=municipality",
            "unit_type": "Baladiya / Municipalité", "parent_id": "country:TN",
            "parent_relationship": "source-country; municipal boundaries do not nest in delegations",
            "source_governorate": governorate, "source_governorate_assignment": "producer largest area overlap",
            "source_commit": COMMIT, "source_osm_timestamp": OSM_TIMESTAMP,
            "source_license": "ODbL-1.0", "source_attribution": ATTRIBUTION,
            "role_evidence_url": BASE + "docs/methodology.md#9-municipalities",
            "geometry_modified_by_importer": False}


def _read_dataset(cache: Path) -> tuple[list[dict], dict, list[dict]]:
    directory = cache / CACHE_DIRECTORY
    report = json.loads((directory / REPORT_FILE).read_text(encoding="utf-8"))
    source = report.get("source", {})
    if (source.get("selector") != "relations tagged boundary=municipality"
            or source.get("license") != "ODbL-1.0" or source.get("osm_timestamp") != OSM_TIMESTAMP
            or source.get("sha256") != OSM_PBF_SHA256
            or report.get("counts", {}).get("relations_read") != 338):
        raise ValueError("Changed Tunisian municipality role/license/snapshot source report")
    extract = json.loads((directory / "data/source/extract-report.json").read_text(encoding="utf-8"))
    if extract.get("source", {}).get("sha256") != OSM_PBF_SHA256:
        raise ValueError("Tunisian municipality and administrative extract snapshots differ")
    with (directory / ATTRIBUTES_FILE).open(encoding="utf-8", newline="") as handle:
        catalogue = list(csv.DictReader(handle))
    attributes = {attribute["id"]: attribute for attribute in catalogue}
    if len(attributes) != len(catalogue) or len(attributes) != 338:
        raise ValueError("Duplicate or missing Tunisian municipality catalogue identities")
    dataset = json.loads((directory / GEOMETRY_FILE).read_text(encoding="utf-8"))
    if dataset.get("type") != "FeatureCollection":
        raise ValueError("Tunisian municipality source is not a GeoJSON FeatureCollection")
    rows = [normalize_feature(feature, attributes) for feature in dataset["features"]]
    if (len(rows) != 338 or len({row["id"] for row in rows}) != 338
            or {row["source_unit_id"] for row in rows} != set(attributes)):
        raise ValueError("Changed Tunisian municipality polygon identities/count")
    names = defaultdict(list)
    for row in rows:
        names[(row["source_governorate"], row["original_name"])].append(row["source_unit_id"])
    duplicates = [{"governorate": country, "original_name": name, "source_unit_ids": sorted(identifiers)}
                  for (country, name), identifiers in sorted(names.items()) if len(identifiers) > 1]
    return rows, report, duplicates


def prepare_sources(cache: Path) -> list[dict]:
    """Admit only pinned producer bytes; existing cache corruption is an error."""
    cache = Path(cache)
    files = _file_receipts()
    for receipt in files:
        path = cache / receipt["cache_file"]
        if not path.exists():
            request = urllib.request.Request(receipt["url"], headers={"User-Agent": "BangerQueens-atlas-source-audit"})
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read(receipt["bytes"] + 1)
            if len(raw) != receipt["bytes"] or hashlib.sha256(raw).hexdigest() != receipt["sha256"]:
                raise ValueError("Downloaded Tunisian municipality file has changed integrity/hash")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        verify_file(path, receipt)
    rows, report, duplicates = _read_dataset(cache)
    atlas_extent = box(*ATLAS_BBOX)
    inside = sum(row["geometry"].intersects(atlas_extent)
                 and row["geometry"].intersection(atlas_extent).area > 0 for row in rows)
    source = {"id": SOURCE_ID, "country": "TN", "country_iso3": "TUN", "scope_countries": ["TN"],
              "kind": "municipality", "unit_type": "Baladiya / Municipalité", "merge_priority": 3,
              "url": f"https://github.com/Alaa-Taieb/map-tunisia/tree/{COMMIT}",
              "date": OSM_TIMESTAMP, "osm_timestamp": OSM_TIMESTAMP, "source_commit": COMMIT,
              "producer": "Map Tunisia by Alaa Taieb", "producer_report_generated": report["generated"],
              "license": "ODbL-1.0", "license_url": "https://opendatacommons.org/licenses/odbl/1-0/",
              "license_evidence_url": BASE + "LICENSE-DATA.md", "attribution": ATTRIBUTION,
              "role_evidence_urls": [BASE + "docs/methodology.md#9-municipalities"],
              "source_boundary": "municipality", "native_level": "OSM boundary=municipality; no admin_level",
              "files": files, "bytes": sum(receipt["bytes"] for receipt in files),
              "sha256": _receipt_digest(files),
              "hash_scope": "SHA-256 of canonical ordered input receipts; each input also has its pinned SHA-256",
              "source_unit_count": len(rows), "source_feature_count": len(rows), "normalized_unit_count": len(rows),
              "units_intersecting_atlas_bbox": inside, "atlas_bbox": list(ATLAS_BBOX),
              "source_name_duplicate_groups": duplicates, "source_warnings": report["warnings"],
              "upstream_geometry_corrections": report["corrections"], "geometry_modified_by_importer": False,
              "upstream_coverage_report": report["topology"], "upstream_uncovered_examples": report["uncovered"],
              "upstream_osm_pbf": report["source"], "blocks_full_coverage_claim": True,
              "unit_semantics": {"render_role": "municipality", "source_unit_type": "Baladiya / Municipalité",
                  "join": "Source municipality-<OSM relation> identifier to producer CSV osm_relation; no name-based merge",
                  "hierarchy": "Municipalities are separate from delegations/imadas; source governorate retained without forced nesting",
                  "geometry": "Producer full-precision municipal GeoJSON unchanged. Producer clips to its land and subtracts one 6.468 km² overlap from relation 7304421; no importer repair or gap allocation.",
                  "coverage_status": "338 actual source relation polygons, not an official current municipality total. Producer gaps remain gaps; dated 2016/2018 counts are not completeness targets. Country coverage must be independently measured inside the atlas bbox."}}
    manifest = ROOT / "data/atlas_tunisia_sources.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({"schema": 1, "sources": [source]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return [source]


def iter_boundaries(cache: Path, sources: list[dict]) -> Iterator[dict]:
    """Read the admitted snapshot without downloads, mutation, clipping or repair."""
    cache = Path(cache)
    expected_files = _file_receipts()
    for source in sources:
        if (source.get("id") != SOURCE_ID or source.get("source_commit") != COMMIT
                or source.get("country") != "TN" or source.get("kind") != "municipality"
                or source.get("source_unit_count") != 338 or "admin_level" in source):
            raise ValueError("Unreviewed Tunisian municipality source identity/commit/count")
        if source.get("files") != expected_files or source.get("sha256") != _receipt_digest(expected_files):
            raise ValueError("Changed Tunisian source receipt integrity/hash")
        for receipt in expected_files:
            verify_file(cache / receipt["cache_file"], receipt)
        rows, _, _ = _read_dataset(cache)
        yield from rows


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    arguments = parser.parse_args()
    selected = prepare_sources(arguments.cache)
    print(json.dumps({"source_units": sum(1 for _ in iter_boundaries(arguments.cache, selected)),
                      "atlas_intersections": selected[0]["units_intersecting_atlas_bbox"],
                      "bytes": selected[0]["bytes"]}))
