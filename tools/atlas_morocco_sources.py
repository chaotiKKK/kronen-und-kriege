"""Pinned HCP commune identities joined to openly licensed OSM geometry."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import re
from typing import Iterator

import shapely
from shapely.geometry import box, shape

from atlas_communal_sources import _download_cached, _write_json, verify_source

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
COMMIT = "4ec363333fea43e712820e20f59532bac5df0b07"
BASE = f"https://raw.githubusercontent.com/zkousama/morocco-communes/{COMMIT}/data/v1/"
SOURCE_ID = "morocco-communes-HCP2024-OSM202609"
ATLAS_BBOX = (-12, 33, 52, 72)


def iter_topology(topology: dict) -> Iterator[dict]:
    """Decode polygonal TopoJSON, including negative arcs and holes."""
    if topology.get("type") != "Topology":
        raise ValueError("Moroccan boundary source is not TopoJSON")
    transform = topology.get("transform")
    arcs = []
    for raw in topology.get("arcs", []):
        coordinates = []
        x = y = 0
        for position in raw:
            if transform is not None:
                x += position[0]
                y += position[1]
                coordinates.append([x * transform["scale"][0] + transform["translate"][0],
                                    y * transform["scale"][1] + transform["translate"][1]])
            else:
                coordinates.append(list(position[:2]))
        arcs.append(coordinates)

    def ring(indices):
        result = []
        for index in indices:
            if not isinstance(index, int) or isinstance(index, bool):
                raise ValueError("Invalid Moroccan TopoJSON arc reference")
            arc_index = ~index if index < 0 else index
            if arc_index < 0 or arc_index >= len(arcs):
                raise ValueError("Invalid Moroccan TopoJSON arc reference")
            points = list(reversed(arcs[arc_index])) if index < 0 else arcs[arc_index]
            if result and points and result[-1] != points[0]:
                raise ValueError("Moroccan TopoJSON ring contains disconnected arcs")
            result.extend(points[1:] if result else points)
        if len(result) < 4 or result[0] != result[-1]:
            raise ValueError("Moroccan TopoJSON ring is not a closed polygon")
        return result

    collection = topology.get("objects", {}).get("communes", {})
    if collection.get("type") != "GeometryCollection":
        raise ValueError("Moroccan TopoJSON has no reviewed communes collection")
    for geometry in collection.get("geometries", []):
        kind = geometry.get("type")
        if kind == "Polygon":
            coordinates = [ring(indices) for indices in geometry["arcs"]]
        elif kind == "MultiPolygon":
            coordinates = [[ring(indices) for indices in polygon] for polygon in geometry["arcs"]]
        else:
            raise ValueError(f"Moroccan communal boundary is not polygonal: {kind}")
        yield {"type": "Feature", "properties": geometry.get("properties", {}),
               "geometry": {"type": kind, "coordinates": coordinates}}


def normalize_feature(feature: dict, attributes: dict) -> dict:
    digits = str((feature.get("properties") or {}).get("code", ""))
    if digits not in attributes:
        raise ValueError(f"Moroccan geometry has no matching official HCP commune identity: {digits}")
    commune = attributes[digits]
    code = commune.get("code")
    if re.fullmatch(r"\d{9}", digits) is None or not isinstance(code, str) or commune.get("codeDigits") != digits:
        raise ValueError("Invalid Moroccan HCP commune code")
    if commune.get("type") not in ("urban", "rural"):
        raise ValueError("Moroccan geometry identifies a non-communal unit")
    if not isinstance(feature.get("geometry"), dict):
        raise ValueError("Moroccan commune has no boundary geometry")
    geometry = shape(feature["geometry"])
    repaired = not geometry.is_valid
    if repaired:
        geometry = shapely.make_valid(geometry)
    if geometry.geom_type == "GeometryCollection":
        geometry = shapely.unary_union([part for part in shapely.get_parts(geometry)
                                       if part.geom_type in ("Polygon", "MultiPolygon")])
    if geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty or geometry.area <= 0:
        raise ValueError(f"Moroccan commune has no valid polygonal area: {code}")
    x0, y0, x1, y1 = geometry.bounds
    if not all(math.isfinite(v) for v in geometry.bounds) or not (-180 <= x0 <= x1 <= 180 and -90 <= y0 <= y1 <= 90):
        raise ValueError("Moroccan boundary is not longitude/latitude geometry")
    names = commune.get("name") or {}
    original_name = names.get("fr") or names.get("ar")
    known = isinstance(original_name, str) and bool(original_name.strip())
    return {"country": "MA", "id": "hcp:MA:commune:" + code, "municipality_code": digits,
            "name": original_name if known else "Gemeinde (Name in Quelle fehlt)",
            "name_known": known, "original_name": original_name, "source_names": names,
            "kind": "municipality", "geometry": geometry, "parent_id": "country:MA", "source": SOURCE_ID,
            "admin_level": 8, "native_level": "OSM admin_level=8 / HCP commune",
            "unit_type": "Commune urbaine" if commune["type"] == "urban" else "Commune rurale",
            "native_parent_codes": commune.get("parents", {}),
            "osm_relation_id": (commune.get("osm") or {}).get("relationId"),
            "geometry_repaired": repaired, "name_source": "HCP RGPH 2024", "geometry_source": "OpenStreetMap"}


def boundary_gaps(attributes: dict, present: set) -> list[dict]:
    return [{key: row.get(key) for key in ("code", "codeDigits", "name", "parents", "bbox", "centroid", "osm")}
            for digits, row in attributes.items() if digits not in present]


def _fetch(cache: Path, relative: str) -> tuple[dict | list, dict]:
    receipt = _download_cached(BASE + relative, cache / "morocco" / relative)
    with (cache / "morocco" / relative).open(encoding="utf-8-sig") as handle:
        return json.load(handle), {**receipt, "cache_file": "morocco/" + relative}


def prepare_sources(cache: Path) -> list[dict]:
    cache = Path(cache)
    catalogue, catalogue_receipt = _fetch(cache, "attributes/communes.json")
    provenance, provenance_receipt = _fetch(cache, "sources.json")
    if provenance.get("datasetVersion") != "1.10.0":
        raise ValueError("Pinned Moroccan dataset version differs from the reviewed release")
    attributes = {row["codeDigits"]: row for row in catalogue}
    if len(catalogue) != 1503 or len(attributes) != len(catalogue):
        raise ValueError("Pinned HCP commune catalogue is incomplete or duplicates native codes")
    with ThreadPoolExecutor(max_workers=3) as executor:
        fetched = list(executor.map(lambda i: _fetch(cache, f"geometry/{i:02d}.topojson"), range(1, 13)))
    present = set()
    repaired = missing_names = inside_bbox = 0
    selected_types = {}
    atlas_extent = box(*ATLAS_BBOX)
    for topology, _ in fetched:
        if topology.get("license") != "ODbL-1.0" or "admin_level=8" not in str(topology.get("source", "")):
            raise ValueError("Moroccan source no longer states the reviewed OSM licence and communal boundary role")
        for feature in iter_topology(topology):
            row = normalize_feature(feature, attributes)
            digits = row["municipality_code"]
            if digits in present:
                raise ValueError(f"Duplicate Moroccan communal geometry: {digits}")
            present.add(digits)
            repaired += int(row["geometry_repaired"])
            missing_names += int(not row["name_known"])
            inside_bbox += int(row["geometry"].intersects(atlas_extent))
            selected_types[row["unit_type"]] = selected_types.get(row["unit_type"], 0) + 1
    gaps = boundary_gaps(attributes, present)
    if len(present) != 1502 or {row["codeDigits"] for row in gaps} != {"042810511"}:
        raise ValueError("Pinned Moroccan boundary/country gap differs from the reviewed dataset")
    files = [catalogue_receipt, provenance_receipt, *[receipt for _, receipt in fetched]]
    digest = hashlib.sha256(json.dumps(files, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
    source = {"id": SOURCE_ID, "country": "MA", "country_iso3": "MAR", "scope_countries": ["MA"],
        "url": f"https://github.com/zkousama/morocco-communes/tree/{COMMIT}/data/v1",
        "date": "HCP 2024 / OSM 2026-09-17–19", "source_commit": COMMIT, "dataset_version": "1.10.0",
        "license": "ODbL 1.0 (Geometrie); CC BY 4.0 (HCP-Namen und Kennungen)",
        "license_url": "https://opendatacommons.org/licenses/odbl/1-0/",
        "license_evidence_url": "https://www.hcp.ma/Conditions-generales-d-utilisation-Version-1-0_a2194.html",
        "attribution": "© OpenStreetMap contributors, ODbL 1.0; Haut-Commissariat au Plan, RGPH 2024, CC BY 4.0; assembled by Ousama Ajebbar (morocco-communes). Boundaries decoded, projected and clipped for the atlas; no endorsement by HCP implied.",
        "metadata_url": BASE + "sources.json", "pinnedmetadataURL": BASE + "sources.json",
        "license_layers": [
            {"scope": "geometry and geometry-derived fields", "license": "ODbL-1.0", "url": BASE + "geometry/LICENSE", "attribution": "© OpenStreetMap contributors"},
            {"scope": "official commune names and geographic codes", "license": "CC BY 4.0", "url": "https://www.hcp.ma/Conditions-generales-d-utilisation-Version-1-0_a2194.html", "attribution": "Haut-Commissariat au Plan, RGPH 2024"}],
        "admin_level": 8, "native_level": "OSM admin_level=8 / HCP commune", "unit_type": "Commune urbaine / commune rurale", "kind": "municipality",
        "files": files, "bytes": sum(receipt["bytes"] for receipt in files), "sha256": digest,
        "hash_scope": "SHA-256 of the canonical ordered input receipt list; each underlying file retains its own SHA-256",
        "source_catalogue_count": len(attributes), "source_feature_count": len(present), "source_unit_count": len(present),
        "normalized_unit_count": len(present), "units_intersecting_atlas_bbox": inside_bbox, "atlas_bbox": list(ATLAS_BBOX),
        "source_role_counts": selected_types, "geometry_repaired_count": repaired, "source_name_missing_count": missing_names,
        "known_missing_boundaries": gaps, "blocks_full_coverage_claim": True,
        "known_geographic_gap_note": "Upstream documents another approximately 88 km² unassigned gap between Ifrane and Boulemane; no polygon is invented for it. Exact per-country coverage in the atlas bbox remains to be measured.",
        "unit_semantics": {"render_role": "municipality", "source_unit_type": "HCP urban/rural commune",
            "join": "OSM administrative level-8 relation geometry matched by ref:MA:HCP to the official HCP catalogue codeDigits",
            "reference_note": "The full provider footprint includes Western Sahara under HCP classification. That southern territory is outside this atlas's latitude>=33 extent. Catalogue totals are not counts inside the atlas bbox.",
            "coverage_status": "1502 actual boundaries of 1503 catalogued communes; no full coverage claim; bbox intersection count is not land-area coverage"},
        "original_provenance": provenance}
    _write_json(ROOT / "data/atlas_morocco_sources.json", {"schema": 1, "sources": [source]})
    return [source]


def iter_boundaries(cache: Path, sources: list[dict]) -> Iterator[dict]:
    cache = Path(cache)
    for source in sources:
        if source.get("id") != SOURCE_ID or source.get("source_commit") != COMMIT:
            raise ValueError("Unreviewed Moroccan commune source")
        files = source["files"]
        for receipt in files:
            verify_source(cache / receipt["cache_file"], receipt)
        with (cache / files[0]["cache_file"]).open(encoding="utf-8-sig") as handle:
            attributes = {row["codeDigits"]: row for row in json.load(handle)}
        present = set()
        for receipt in files[2:]:
            with (cache / receipt["cache_file"]).open(encoding="utf-8-sig") as handle:
                topology = json.load(handle)
            for feature in iter_topology(topology):
                row = normalize_feature(feature, attributes)
                if row["id"] in present:
                    raise ValueError("Duplicate Moroccan commune identity")
                present.add(row["id"])
                yield row
        if len(present) != int(source["source_unit_count"]):
            raise ValueError("Moroccan source count differs from its admitted manifest")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    args = parser.parse_args()
    selected = prepare_sources(args.cache)
    print(json.dumps({"units": sum(1 for _ in iter_boundaries(args.cache, selected)),
                      "bytes": selected[0]["bytes"], "within_atlas_bbox": selected[0]["units_intersecting_atlas_bbox"]}))
