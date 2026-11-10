"""One positively identified terminal Liwa; never a generic municipal fallback.

The map only intersects Jordan north of 33 degrees. Ruwaished is the
terminal deconcentrated jurisdiction there, while municipal territory is
separate and does not blanket the desert. Preserve both distinctions.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import zipfile

from shapely.geometry import box, mapping, shape

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
SOURCE_ID = "geofabrik-JO-Ruwaished-terminal-20261108"
URL = "https://download.geofabrik.de/asia/jordan-261108-free.shp.zip"
STAGE = "geofabrik-mena-stage/jordan"
OUTPUT = "jordan-terminal-20261110/Ruwaished-Liwa.geojson"
DOS = "https://dosweb.dos.gov.jo/databank/Population/Population_Estimares/PopulationEstimates.pdf"
MOI = "https://www.moi.gov.jo/ebv4.0/root_storage/ar/eb_list_page/نظام_التشكيلات_الادارية_.pdf"
STRUCTURE = "https://culture.gov.jo/AR/ListDetails/أرشيف_مدن_الثقافة_الأردنية/96/4"
RESERVE = "https://www.rscn.org.jo/public/reserve/5"
MEMBERS = {
    "cpg": (6, "146d6789ffe033a5297c1ad046e6a62ee35319b86b021444f05b6ea2aa8a1f4a"),
    "dbf": (22782, "00e68cf324ce9b96d234bde67893874baf7f2c1477b490535ff308e852810b6c"),
    "prj": (144, "ffc9162903c37f0867d1e7f36c20036a165f7aa555dda24c1ae0ee4328d2977f"),
    "shp": (1470808, "d0324d2730b412b6f3c6e5c63d0a72bf7ef7310954b85e2dc17ecdae1717be4a"),
    "shx": (1348, "2e2b50df6103e236ebda92a167a69ef8680cc3c872ccca3e3bd43bafe3ee2f1b"),
}


def normalize_terminal_liwa(properties: dict, geometry) -> dict:
    expected = {"osm_id": "13376111", "code": 1205, "fclass": "admin_level5", "name": "لواء الرويشد"}
    if any(properties.get(key) != value for key, value in expected.items()):
        raise ValueError("This exception requires the exact positively reviewed Ruwaished Liwa identity")
    if (geometry.is_empty or not geometry.is_valid or geometry.geom_type not in {"Polygon", "MultiPolygon"}
            or not box(37, 31.5, 39.5, 33.5).covers(geometry)
            or geometry.intersection(box(37, 33, 39.5, 34)).area <= 0):
        raise ValueError("Invalid or geographically inconsistent Ruwaished terminal jurisdiction")
    return {"id": "geofabrik:JO:5:13376111", "country": "JO", "source": SOURCE_ID,
            "name": "Ruwaished", "name_known": True, "kind": "district",
            "unit_type": "Liwa / dekonzentrierter Verwaltungsbezirk", "admin_level": 5,
            "source_admin_level": 5, "original_name": properties["name"],
            "original_source_id": "13376111", "original_properties": deepcopy(properties),
            "parent_id": "country:JO", "parent_relationship": "hierarchy-not-supplied",
            "local_government_role": "local_admin", "local_government_role_evidence": DOS,
            "local_government_role_note": "Terminal deconcentrated state administration; not municipal self-government.",
            "role_evidence_urls": [MOI, DOS, STRUCTURE, RESERVE],
            "terminal_scope": "Ruwaished Liwa; atlas intersection north of 33 degrees",
            "municipal_boundary_status": "not-established-by-this-source",
            "superseded_duplicate_source_id": "13376112",
            "geometry": geometry}


def _verified_members(cache: Path) -> Path:
    from atlas_geofabrik_sources import RangeSource, RemoteZip, extract_admin_members
    directory = cache / STAGE
    members = directory / "members"
    if not all((members / ("gis_osm_adminareas_a_free_1." + ext)).exists() for ext in MEMBERS):
        remote = RangeSource(directory, URL)
        if remote.snapshot["bytes"] != 60584695 or remote.snapshot["etag"] != '"39c72f7-65fce84d0def6"':
            raise ValueError("Changed Jordan archive snapshot; explicit source review required")
        with zipfile.ZipFile(RemoteZip(remote.snapshot["bytes"], remote.fetch)) as archive:
            extract_admin_members(archive, members)
    for ext, (size, digest) in MEMBERS.items():
        raw = (members / ("gis_osm_adminareas_a_free_1." + ext)).read_bytes()
        if len(raw) != size or hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError("Changed original Jordan member hash: " + ext)
    return members


def prepare_sources(cache: Path = DEFAULT_CACHE) -> list[dict]:
    from atlas_geofabrik_sources import _shapefile
    cache = Path(cache)
    members = _verified_members(cache)
    selected = []
    with _shapefile().Reader(str(members / "gis_osm_adminareas_a_free_1.shp"), encoding="utf-8") as reader:
        for record in reader.iterShapeRecords():
            properties = record.record.as_dict()
            if properties["osm_id"] == "13376111":
                selected.append(normalize_terminal_liwa(properties, shape(record.shape.__geo_interface__)))
    if len(selected) != 1:
        raise ValueError("Expected exactly one original Ruwaished Liwa, without its duplicate old Qadaa")
    row = selected[0]
    feature = {"type": "Feature", "properties": {k: v for k, v in row.items() if k != "geometry"},
               "geometry": mapping(row["geometry"])}
    raw = (json.dumps({"type": "FeatureCollection", "features": [feature]}, ensure_ascii=False,
                      separators=(",", ":")) + "\n").encode("utf-8")
    path = cache / OUTPUT
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    source = {"id": SOURCE_ID, "country": "JO", "kind": "district", "admin_level": 5,
              "cache_file": OUTPUT, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
              "source_unit_count": 1, "expected_unit_count": 1, "replacement_scope": "feature",
              "url": URL, "date": "2026-11-08", "osm_timestamp": "2026-11-08T21:21:00Z",
              "license": "ODbL-1.0", "license_url": "https://opendatacommons.org/licenses/odbl/1-0/",
              "attribution": "© OpenStreetMap contributors; Geofabrik GmbH",
              "role_evidence_urls": [MOI, DOS, STRUCTURE, RESERVE],
              "unit_semantics": {"render_role": "district", "additional_role": "terminal deconcentrated local administration",
                  "municipal_boundary_status": "not-established-by-this-source",
                  "coverage_scope": "Only the actual atlas intersection; no whole-Jordan municipal completeness claim."},
              "original_members": [{"name": "gis_osm_adminareas_a_free_1." + ext, "bytes": size, "sha256": digest}
                                   for ext, (size, digest) in MEMBERS.items()]}
    manifest = ROOT / "data/atlas_jordan_sources.json"
    manifest.write_text(json.dumps({"sources": [source]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return [source]


def iter_boundaries(cache: Path, sources: list[dict]):
    for source in sources:
        if (source.get("id") != SOURCE_ID or source.get("source_unit_count") != 1
                or source.get("expected_unit_count") != 1 or source.get("country") != "JO"
                or source.get("kind") != "district"):
            raise ValueError("Unknown or changed Jordan terminal source identity/count")
        path = (Path(cache) / source["cache_file"]).resolve()
        if not path.is_relative_to(Path(cache).resolve()):
            raise ValueError("Jordan cache path escapes source directory")
        raw = path.read_bytes()
        if len(raw) != source["bytes"] or hashlib.sha256(raw).hexdigest() != source["sha256"]:
            raise ValueError("Changed Jordan terminal geometry integrity/hash")
        features = json.loads(raw)["features"]
        if len(features) != 1:
            raise ValueError("Changed Jordan terminal feature count")
        feature = features[0]
        original = feature["properties"]["original_properties"]
        yield normalize_terminal_liwa(original, shape(feature["geometry"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    print(json.dumps(prepare_sources(parser.parse_args().cache), indent=2))
