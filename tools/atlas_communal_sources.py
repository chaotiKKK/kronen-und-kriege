"""Pinned, country-specific communal boundary sources for the offline atlas.

This module does not change the base atlas. It prepares independently licensed
source files and yields geographic Shapely features to the atlas merger.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
from typing import Iterator

import shapely
from shapely.geometry import shape

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
METADATA_URL = "https://www.geoboundaries.org/api/current/gbOpen/ALL/ALL/"
SOURCE_DEFINITIONS = {
    "FR": ("FRA", 5, "Commune / arrondissement municipal"),
    "IT": ("ITA", 4, "Comune"),
    "ES": ("ESP", 3, "Municipio"),
    "PL": ("POL", 3, "Gmina"),
    "AT": ("AUT", 3, "Gemeinde"),
    "CH": ("CHE", 3, "Gemeinde / commune / comune"),
    "DK": ("DNK", 2, "Kommune"),
    "NL": ("NLD", 2, "Gemeente"),
    "SE": ("SWE", 2, "Kommun"),
    "GR": ("GRC", 3, "Dimos"),
    "PT": ("PRT", 3, "Freguesia"),
    "BG": ("BGR", 2, "Obshtina"),
    "HR": ("HRV", 2, "Općina / grad"),
    "RO": ("ROU", 2, "Comună / oraș / municipiu"),
    "UA": ("UKR", 3, "Village council (source division, not reformed hromada)"),
    "AM": ("ARM", 2, "Municipal community"),
    "GE": ("GEO", 2, "Municipality"),
    "DZ": ("DZA", 3, "Commune"),
    "IR": ("IRN", 4, "Dehestan (rural district)"),
    "BE": ("BEL", 4, "Gemeente / commune / Gemeinde"),
    "LU": ("LUX", 3, "Commune"),
    "LT": ("LTU", 2, "Savivaldybė"),
    "ME": ("MNE", 1, "Opština / capital city"),
    "RS": ("SRB", 2, "Opština / grad"),
    "XK": ("XKX", 2, "Komuna / opština"),
    "LI": ("LIE", 1, "Gemeinde"),
    "SM": ("SMR", 1, "Castello"),
    "SI": ("SVN", 2, "Občina / mestna občina"),
    "BA": ("BIH", 3, "Općina / opština / grad"),
    "CY": ("CYP", 2, "Dimos / koinotita (municipality / community)"),
}
SOURCE_SEMANTIC_EVIDENCE = {
    "BE": {"evidence_urls": ["https://statbel.fgov.be/nl/over-statbel/methodologie/classificaties/geografie"],
           "reference_note": "589 municipalities are the official classification valid through 31 December 2018; 2019 and 2025 mergers are not silently applied to this dated geometry.",
           "license_evidence_url": "https://data.namur.be/terms/terms-and-conditions/"},
    "LU": {"evidence_urls": ["https://elections.public.lu/de/fusion-communes.html", "https://data.public.lu/en/datasets/limites-administratives-du-grand-duche-de-luxembourg/"],
           "reference_note": "102 communes is the official 2018 division, before the 2023 mergers to 100. Some source labels contain encoding damage; raw labels are preserved.",
           "license_evidence_url": "https://data.public.lu/en/datasets/limites-administratives-du-grand-duche-de-luxembourg/"},
    "LT": {"evidence_urls": ["https://osp.stat.gov.lt/en/regionine-statistika-pagal-statistikos-sritis"],
           "reference_note": "The 60 savivaldybės are municipalities, below 10 counties; the finer 544 ADM3 units are not substituted for this municipal role."},
    "ME": {"evidence_urls": ["https://monstat.org/userfiles/file/publikacije/godisnjak%202017/1.pdf"],
           "reference_note": "MONSTAT's 2017 yearbook lists the same 23 municipalities, with territorial count as at December 2015. Newer Tuzi and Zeta municipalities are not fabricated in the 2017 source."},
    "RS": {"evidence_urls": ["https://mduls.gov.rs/registri/lokalne-samouprave-u-srbiji/?script=lat", "https://socijalnoukljucivanje.gov.rs/wp-content/uploads/2014/05/mapping_social_welfare_services.pdf"],
           "reference_note": "145 municipality/city local-government areas in the source's Serbia footprint; Belgrade and Niš are single city units, not counts of their urban municipalities. Kosovo has a separate source and spatial footprint."},
    "XK": {"evidence_urls": ["https://akk.rks-gov.net/en/kca", "https://askapi.rks-gov.net/Custom/a1b1ba38-f116-43da-9134-53bbc568486c.pdf"],
           "reference_note": "38 municipalities, matching the native canonical Municipality role. This is an atlas source footprint, not an interpretation of sovereignty claims."},
    "LI": {"evidence_urls": ["https://www.llv.li/de/privatpersonen/notfall-und-katastrophenfall/katastrophen-und-notfall/feuerwehr/feuerwehren"],
           "reference_note": "The actual 11 Gemeinden are already the first administrative level; no finer artificial areas are generated."},
    "SM": {"evidence_urls": ["https://interni.sm/pub1/InterniSM/Giunte-di-Castello/Le-Giunte-di-Castello.html"],
           "reference_note": "The nine Castelli are territorial institutions with local administrative functions, not nine national regions requiring invented municipalities."},
    "SI": {"evidence_urls": ["https://www.gov.si/en/topics/municipalities-in-numbers", "https://www.stat.si/StatWeb/gl/News/Index/9423"],
           "reference_note": "212 actual municipalities. The original source contains 213 features because Maribor has two touching polygon parts with distinct shapeIDs. The simplified source drops the tiny part; both original parts are retained and united under the main stable Maribor ID."},
    "BA": {"evidence_urls": ["https://www.popis.gov.ba/popis2013/doc/Knjiga6/K6_B_E.pdf"],
           "reference_note": "The official 2013 census covers 142 local areas: 79 Federation municipalities, 62 Republika Srpska municipalities and Brčko District. The district retains its own special role; equal municipality names do not imply the same municipality."},
    "CY": {"evidence_urls": ["https://www.data.gov.cy/en/dataset/187", "https://www.cystat.gov.cy/el/Announcement?id=74185"],
           "reference_note": "Municipality/community boundary role corroborated by the Cyprus DLS portal. These source geometries are explicitly dated 2009, not the 2024 reform. Original and simplified files both contain 610 features versus 612 declared; no administrative-unit or complete-coverage claim follows from that unexplained discrepancy. Identical names are not merged. The source covers the island across current territory masks."},
}
SOURCE_COMPONENT_GROUPS = {
    ("9469f09", "SI"): {"79292919B61607630754818": ["79292919B61607630754818", "79292919B38849654156102"]},
}
SOURCE_UNIT_TYPE_OVERRIDES = {
    ("f549eab", "BA"): {"43093233B82378099338701": "Brčko District"},
}
UNADMITTED_CANDIDATES = {
    "EE": {"source": "EST/ADM2", "reason": "Metadata declares 215 units and year 2017, but original and simplified files contain 214; names mix older municipal geography (including Kaarma and Lääne-Saare). The local role is genuine; temporal consistency and completeness remain unresolved.",
           "evidence_urls": ["https://www.stat.ee/sites/default/files/2020-07/Aastaraamat_2014.pdf", "https://www.valimised.ee/en/archive/local-government-council-elections/local-government-council-elections"]},
    "HU": {"source": "HUN/ADM3", "reason": "3357 source objects have not been verified as a consistent settlement-municipality level; the largest available ADM number is not sufficient evidence.", "evidence_urls": []},
    "AL": {"source": "ALB/ADM3", "reason": "373 genuine local units describe the pre-reform 2013 municipalities and communes; a separate modern 61-municipality source is being evaluated, so this older division is not silently substituted.",
           "evidence_urls": ["https://www.instat.gov.al/media/3552/regional_accounts_in_albania_2013.pdf"]},
    "MT": {"source": "MLT/ADM1", "reason": "The metadata says Public Domain but the original d-maps provider states copyright and imposes original-map-URL and 10-map publication limits. A compatible unrestricted redistribution route is not established by the metadata label.",
           "evidence_urls": ["https://d-maps.com/conditions.php?lang=en"]},
}


def unadmitted_candidates() -> dict:
    return {country: value for country, value in UNADMITTED_CANDIDATES.items() if country not in SOURCE_DEFINITIONS}


KNOWN_METADATA_COUNTS = {
    ("9469f09", "PL"): {"declared": 2480, "actual": 2478,
        "status": "actual-count-corroborated-by-national-statistics",
        "evidence": "https://stat.gov.pl/files/gfx/portalinformacyjny/pl/defaultaktualnosci/5515/2/18/1/rocznik_statystyczny_rzeczypospolitej_polskiej_2018_.pdf",
        "blocks_full_coverage_claim": False},
    ("9469f09", "IR"): {"declared": 2815, "actual": 2772,
        "status": "metadata-discrepancy-unresolved",
        "evidence": "Original and simplified pinned files both contain 2772 features; metadata declares 2815.",
        "blocks_full_coverage_claim": True},
    ("9469f09", "CY"): {"declared": 612, "actual": 610,
        "status": "metadata-discrepancy-unresolved",
        "evidence": "Original and simplified pinned files both contain 610 features; metadata declares 612. The difference is not a simplification loss.",
        "blocks_full_coverage_claim": True},
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _write_json(path: Path, value) -> None:
    data = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    if path.exists() and path.read_bytes() == data:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def _license_url(name: str) -> str:
    lower = name.lower()
    if "swisstopo" in lower:
        return "https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices"
    if "open data commons attribution" in lower:
        return "https://opendatacommons.org/licenses/by/1-0/"
    if "database license" in lower:
        return "https://opendatacommons.org/licenses/odbl/1-0/"
    if "sharealike" in lower or "share-alike" in lower:
        return "https://creativecommons.org/licenses/by-sa/2.0/" if "2.0" in lower else "https://creativecommons.org/licenses/by-sa/3.0/"
    if "igo" in lower or "intergovernmental" in lower:
        return "https://creativecommons.org/licenses/by/3.0/igo/"
    if "cc0" in lower:
        return "https://creativecommons.org/publicdomain/zero/1.0/"
    if lower == "public domain":
        return "https://creativecommons.org/publicdomain/mark/1.0/"
    if "attribution" in lower and "3.0" in lower:
        return "https://creativecommons.org/licenses/by/3.0/"
    if "attribution" in lower and "4.0" in lower:
        return "https://creativecommons.org/licenses/by/4.0/"
    raise ValueError(f"Unreviewed source license: {name!r}")


def select_source(metadata: list[dict], country: str) -> dict:
    """Select a documented local role, never merely the largest ADM number."""
    if country not in SOURCE_DEFINITIONS:
        raise ValueError(f"No validated communal source for {country}")
    iso3, level, unit_type = SOURCE_DEFINITIONS[country]
    matches = [item for item in metadata if item.get("boundaryISO") == iso3 and item.get("boundaryType") == f"ADM{level}"]
    if len(matches) != 1:
        raise ValueError(f"Missing or ambiguous source metadata for {iso3}/ADM{level}")
    item = matches[0]
    url = str(item.get("simplifiedGeometryGeoJSON", ""))
    match = re.fullmatch(r"https://github\.com/wmgeolab/geoBoundaries/raw/([0-9a-f]{7,40})/releaseData/gbOpen/" + iso3 + rf"/ADM{level}/geoBoundaries-{iso3}-ADM{level}_simplified\.geojson", url)
    if match is None:
        raise ValueError(f"The boundary download is not pinned to a source commit: {url!r}")
    license_name = str(item.get("boundaryLicense", ""))
    expected = int(item.get("admUnitCount", 0))
    if expected <= 0:
        raise ValueError(f"Invalid source count for {country}")
    source_id = f"gbOpen-{iso3}-ADM{level}"
    metadata_url = url.replace("_simplified.geojson", "-metaData.json")
    source = {"id": source_id, "country": country, "country_iso3": iso3,
            "url": url, "license": license_name, "license_url": _license_url(license_name),
            "original_url": url.replace("_simplified.geojson", ".geojson"),
            "date": str(item.get("boundaryYearRepresented", "")),
            "admin_level": level, "unit_type": unit_type, "kind": "municipality",
            "expected_unit_count": expected, "source_commit": match.group(1),
            "pinnedmetadataURL": metadata_url, "metadata_url": metadata_url,
            "original_metadata_url": f"https://www.geoboundaries.org/api/current/gbOpen/{iso3}/ADM{level}/",
            "attribution": f"geoBoundaries gbOpen; {item.get('boundarySource', '')}; {license_name}",
            "unit_semantics": {"render_role": "municipality", "source_unit_type": unit_type,
                               "original_canonical": str(item.get("boundaryCanonical", "")),
                               "coverage_status": "Geometric land coverage has not yet been measured"},
            "original_boundary_license": license_name,
            "original_license_source": str(item.get("licenseSource", "")),
            "original_metadata": item,
            "cache_file": f"communal/geoBoundaries-{iso3}-ADM{level}_simplified.geojson"}
    source["declared_unit_count"] = expected
    semantic_evidence = SOURCE_SEMANTIC_EVIDENCE.get(country)
    if semantic_evidence:
        source["unit_semantics"].update(semantic_evidence)
    component_groups = SOURCE_COMPONENT_GROUPS.get((match.group(1), country))
    if component_groups:
        source["component_groups"] = component_groups
    unit_type_overrides = SOURCE_UNIT_TYPE_OVERRIDES.get((match.group(1), country))
    if unit_type_overrides:
        source["unit_type_overrides"] = unit_type_overrides
    if country == "CY":
        source["scope_countries"] = ["CY", "CYN", "ESB", "WSB", "CNM"]
        source["territorial_scope_note"] = (
            "Historical 2009 municipal/community reference polygons span current territorial masks, including "
            "CNM UN buffer-zone parts; these are original municipal reference parts, not a claim of UN municipal government. "
            "The merger preserves source_country=CY and marks cross-territory fragments territorial_part=true. "
            "Original 610-versus-declared612 discrepancy and full-coverage claim block remain unchanged.")
    if country == "AM" and match.group(1) == "9469f09" and expected == 39:
        source.update({
            "administrative_geometry_eligible": False,
            "blocks_full_coverage_claim": True,
            "administrative_ineligibility_note": (
                "The original HDX producer description explicitly calls this ADM2 dataset 'not an official administrative level': "
                "it contains Ministry of Emergency Situations RegionID reference areas, not the present-day legal municipal layer. "
                "The upstream gbOpen canonical label Municipal Communities is preserved as original metadata but does not establish eligibility. "
                "All 39 original geometries, identifiers, source-year declarations and license receipts remain in quarantine; "
                "they must not be rendered or counted as municipalities or re-labelled districts."),
            "administrative_ineligibility_evidence_urls": [
                "https://data.wu.ac.at/schema/data_humdata_org/MzdiODk1NTUtZWYzZS00YjI2LWExYmEtMDcwMzE4MDE2ODUz",
                "https://data.humdata.org/dataset/armenia-administrative-boundaries",
                "https://www.arlis.am/hy/acts/231073"],
            "source_review": {"status": "quarantined-administrative-role", "review_date": "2026-11-09",
                              "evidence_role": "Archived original HDX producer metadata description, corroborated against consolidated official administrative-division law; live HDX page currently returns403"}})
        source["unit_semantics"]["coverage_status"] = "Quarantined: original producer disclaims an official administrative level; no current municipal coverage claim"
    correction = KNOWN_METADATA_COUNTS.get((match.group(1), country))
    if correction and expected == correction["declared"]:
        source.update({"expected_unit_count": correction["actual"], "metadata_discrepancy": True,
                       "metadata_count_status": correction["status"],
                       "metadata_count_evidence": correction["evidence"],
                       "blocks_full_coverage_claim": correction["blocks_full_coverage_claim"]})
    return source


def verify_source(path: Path, source: dict) -> None:
    if not path.is_file() or path.stat().st_size != int(source["bytes"]) or sha256_file(path) != source["sha256"]:
        raise ValueError(f"Source integrity mismatch: {path}")


def _download_cached(url: str, path: Path) -> dict:
    sidecar = path.with_suffix(path.suffix + ".receipt.json")
    if path.exists() and sidecar.exists():
        saved = json.loads(sidecar.read_text(encoding="utf-8"))
        if saved.get("url") == url:
            verify_source(path, saved)
            return saved
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".part")
    subprocess.run(["curl.exe", "--fail", "--location", "--silent", "--show-error", "--retry", "3",
                    "--retry-delay", "1", "--connect-timeout", "20", "--max-time", "600",
                    "--max-filesize", "160000000", "--output", str(temporary), url], check=True)
    # Detect Git-LFS pointer text, HTML errors, and truncated JSON before admission.
    with temporary.open(encoding="utf-8-sig") as handle:
        json.load(handle)
    receipt = {"url": url, "bytes": temporary.stat().st_size, "sha256": sha256_file(temporary)}
    temporary.replace(path)
    _write_json(sidecar, receipt)
    return receipt


def _prepare_one(cache: Path, source: dict) -> dict:
    path = cache / source["cache_file"]
    print(f"Prepare {source['country_iso3']}/ADM{source['admin_level']}", flush=True)
    receipt = _download_cached(source["url"], path)
    metadata_path = path.with_name(path.name.replace("_simplified.geojson", "-metaData.json"))
    metadata_receipt = _download_cached(source["pinnedmetadataURL"], metadata_path)
    pinned = json.loads(metadata_path.read_text(encoding="utf-8"))
    if pinned.get("boundaryISO") != source["country_iso3"] or pinned.get("boundaryType") != f"ADM{source['admin_level']}":
        raise ValueError(f"Pinned source metadata identifies another administrative dataset: {metadata_path}")
    if int(pinned.get("admUnitCount", 0)) != source.get("declared_unit_count", source["expected_unit_count"]):
        raise ValueError(f"Current and pinned source counts disagree: {source['id']}")
    with path.open(encoding="utf-8-sig") as handle:
        document = json.load(handle)
    if document.get("type") != "FeatureCollection" or not isinstance(document.get("features"), list):
        raise ValueError(f"Source is not a GeoJSON FeatureCollection: {path}")
    actual = len(document["features"])
    selected_rows = document["features"]
    source = {**source, "geometry_variant": "simplified"}
    if actual != source["expected_unit_count"]:
        full_url = source.get("original_url", source["url"].replace("_simplified.geojson", ".geojson"))
        if full_url == source["url"]:
            raise ValueError(f"No original geometry fallback for incomplete source: {source['id']}")
        full_path = path.with_name(path.name.replace("_simplified.geojson", ".geojson"))
        receipt = _download_cached(full_url, full_path)
        with full_path.open(encoding="utf-8-sig") as handle:
            original = json.load(handle)
        if original.get("type") != "FeatureCollection" or not isinstance(original.get("features"), list):
            raise ValueError(f"Original source is not a FeatureCollection: {full_path}")
        source.update({"geometry_variant": "original", "simplified_unit_count": actual,
                       "simplified_url": source["url"], "url": full_url,
                       "cache_file": full_path.relative_to(cache).as_posix()})
        actual = len(original["features"])
        selected_rows = original["features"]
        if actual != source["expected_unit_count"]:
            raise ValueError(f"Original source completeness mismatch for {source['id']}: {actual} != {source['expected_unit_count']}")
    if source.get("metadata_discrepancy"):
        original_path = path.with_name(path.name.replace("_simplified.geojson", ".geojson"))
        original_receipt = _download_cached(source["original_url"], original_path)
        with original_path.open(encoding="utf-8-sig") as handle:
            corroborating = json.load(handle)
        original_count = len(corroborating.get("features", []))
        if original_count != actual:
            raise ValueError(f"Original geometry does not corroborate the documented source count: {source['id']}")
        source["original_geometry_verification"] = {**original_receipt, "source_unit_count": original_count}
    missing_names = [str((feature.get("properties") or {}).get("shapeID", "")) for feature in selected_rows
                     if not isinstance((feature.get("properties") or {}).get("shapeName"), str)
                     or not (feature.get("properties") or {}).get("shapeName", "").strip()]
    source["source_name_missing_count"] = len(missing_names)
    source["source_name_missing_ids"] = missing_names
    component_groups = source.get("component_groups", {})
    if component_groups:
        identifiers = [str((row.get("properties") or {}).get("shapeID", "")) for row in selected_rows]
        grouped_ids = [identifier for members in component_groups.values() for identifier in members]
        if len(set(grouped_ids)) != len(grouped_ids) or not set(grouped_ids).issubset(identifiers):
            raise ValueError(f"Verified source component groups do not match original features: {source['id']}")
        if any(main not in members for main, members in component_groups.items()):
            raise ValueError(f"Source component group has no canonical main feature: {source['id']}")
    source["source_feature_count"] = actual
    source["normalized_unit_count"] = actual - sum(len(parts) - 1 for parts in component_groups.values())
    return {**source, "bytes": receipt["bytes"], "sha256": receipt["sha256"],
            "metadata_sha256": metadata_receipt["sha256"], "source_unit_count": actual,
            "pinned_metadata": pinned}


def prepare_sources(cache: Path) -> list[dict]:
    cache = Path(cache)
    metadata_path = cache / "coverage-metadata.json"
    if not metadata_path.exists():
        _download_cached(METADATA_URL, metadata_path)
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    selected = [select_source(metadata, country) for country in SOURCE_DEFINITIONS]
    # One country is parsed at a time by each worker; avoid materializing all geometry.
    with ThreadPoolExecutor(max_workers=3) as executor:
        prepared = list(executor.map(lambda source: _prepare_one(cache, source), selected))
    write_manifest(prepared)
    return prepared


def normalize_feature(feature: dict, source: dict) -> dict:
    p = feature.get("properties") or {}
    if p.get("shapeGroup") not in (None, source["country_iso3"]):
        raise ValueError(f"Wrong source country in {source['id']}")
    if p.get("shapeType") not in (None, f"ADM{source['admin_level']}"):
        raise ValueError(f"Wrong source administrative level in {source['id']}")
    identifier = p.get("shapeID")
    name = p.get("shapeName")
    if identifier is None or str(identifier) == "":
        raise ValueError(f"Missing source identifier in {source['id']}")
    name_known = isinstance(name, str) and bool(name.strip())
    display_name = name.strip() if name_known else "Gemeinde (Name in Quelle fehlt)"
    if not isinstance(feature.get("geometry"), dict):
        raise ValueError(f"Missing geometry for {source['id']}/{identifier}")
    geometry = shape(feature["geometry"])
    if geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty:
        raise ValueError(f"Communal geometry is not an area: {source['id']}/{identifier}")
    if not geometry.is_valid:
        geometry = shapely.make_valid(geometry)
    if geometry.geom_type == "GeometryCollection":
        areas = [part for part in shapely.get_parts(geometry) if part.geom_type in ("Polygon", "MultiPolygon")]
        geometry = shapely.unary_union(areas)
    if geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty or geometry.area <= 0:
        raise ValueError(f"Communal boundary has no valid land area: {source['id']}/{identifier}")
    bounds = geometry.bounds
    if not all(math.isfinite(value) for value in bounds) or not (-180 <= bounds[0] <= bounds[2] <= 180 and -90 <= bounds[1] <= bounds[3] <= 90):
        raise ValueError(f"Non-geographic source geometry: {source['id']}/{identifier}")
    return {"country": source["country"], "id": f"gbOpen:{source['country_iso3']}:ADM{source['admin_level']}:{identifier}",
            "name": display_name, "name_known": name_known, "original_name": name,
            "kind": "municipality", "geometry": geometry,
            "parent_id": "country:" + source["country"], "source": source["id"],
            "admin_level": int(source["admin_level"]),
            "unit_type": source.get("unit_type_overrides", {}).get(str(identifier), source["unit_type"])}


def iter_boundaries(cache: Path, sources: list[dict]) -> Iterator[dict]:
    for source in sources:
        path = Path(cache) / source["cache_file"]
        verify_source(path, source)
        with path.open(encoding="utf-8-sig") as handle:
            document = json.load(handle)
        rows = document.get("features")
        if not isinstance(rows, list) or len(rows) != int(source["expected_unit_count"]):
            raise ValueError(f"Source feature count changed: {source['id']}")
        seen = set()
        component_groups = source.get("component_groups", {})
        component_ids = {identifier for members in component_groups.values() for identifier in members}
        row_by_id = {str((row.get("properties") or {}).get("shapeID", "")): row for row in rows} if component_groups else {}
        if component_groups and len(row_by_id) != len(rows):
            raise ValueError(f"Repeated source component identifier: {source['id']}")
        for feature in rows:
            identifier = str((feature.get("properties") or {}).get("shapeID", ""))
            if identifier in component_ids and identifier not in component_groups:
                continue
            record = normalize_feature(feature, source)
            if identifier in component_groups:
                parts = [normalize_feature(row_by_id[part_id], source) for part_id in component_groups[identifier]]
                if any(part["name"] != record["name"] for part in parts):
                    raise ValueError(f"Verified source parts disagree on local-unit name: {record['id']}")
                record["geometry"] = shapely.unary_union([part["geometry"] for part in parts])
                record["source_part_ids"] = list(component_groups[identifier])
            if record["id"] in seen:
                raise ValueError(f"Repeated administrative identifier: {record['id']}")
            seen.add(record["id"])
            yield record
        del document, rows


def write_manifest(sources: list[dict]) -> None:
    _write_json(ROOT / "data/atlas_communal_sources.json", {"schema": 1, "sources": sources,
        "unadmitted_candidates": unadmitted_candidates(),
        "note": "Real source units; downstream clipping and per-country geometric coverage must be measured independently."})
    lines = ["# Kommunale Quellen des Referenzatlas", "", "Diese Quellen werden unverändert und mit Hashbeleg im ignorierten Cache aufbewahrt. Der Import verwendet fachlich ausgewählte lokale Rollen statt der höchsten ADM-Nummer. Die Orts-/Verwaltungsgeometrien sind heutige beziehungsweise datierte Referenzgeografie und ändern keine der 49 Simulationskennungen.", "",
             "| Land | Ebene / tatsächliche Rolle | Quellfeatures | Lokale Einheiten | Stand | Bytes | Lizenz |", "|---|---|---:|---:|---|---:|---|"]
    for source in sources:
        lines.append(f"| {source['country']} | ADM{source['admin_level']} · {source['unit_type']} | {source['source_unit_count']} | {source.get('normalized_unit_count', source['source_unit_count'])} | {source['date']} | {source['bytes']} | [{source['license']}]({source['license_url']}) |")
    lines.extend(["", "## Nachgewiesene Metadatendiskrepanzen", "", "Die Metadaten zählen für Polen 2.480 Einheiten, während sowohl Original- als auch vereinfachte Datei 2.478 enthalten. Das amtliche polnische Jahrbuch bestätigt für 2017 2.478 Gminas. Für Iran enthalten beide Dateien 2.772 Einheiten statt der deklarierten 2.815; die Ursache ist ungeklärt und jede Vollständigkeitsbehauptung bleibt bis zur geometrischen Flächenprüfung gesperrt. Die zyprischen Original- und Simplified-Dateien enthalten beide 610 Features statt der deklarierten 612; auch dort bleibt der Zählunterschied ungeklärt und eine Vollständigkeitsbehauptung gesperrt. Es werden weder Einheiten erfunden noch Originalmetadaten überschrieben. Tatsächliche und deklarierte Zahlen sowie Hashes beider Geometrieversionen sind im Manifest getrennt dokumentiert.", "", "## Quellfeatures und tatsächliche lokale Einheiten", "", "Slowenien belegt einen anderen Fall: Die Originaldatei enthält 213 Quellfeatures für die amtlich bestätigten 212 Gemeinden. Zwei berührende Teile von Maribor besitzen verschiedene stabile shapeIDs. Der winzige zweite Teil fehlt in der Simplified-Datei. Deshalb wird das vollständige Original verwendet und werden ausschließlich diese beiden ausdrücklich festgeschriebenen Maribor-Teile vereinigt. Beide Quellkennungen bleiben in `source_part_ids` erhalten. Das Manifest unterscheidet `source_feature_count=213` und `normalized_unit_count=212`; die Metadatenzählung wird dafür nicht fälschlich als Fehler korrigiert. In anderen Ländern werden gleichnamige Flächen nicht pauschal vereinigt, insbesondere nicht die zwei Novi Grad in Bosnien und Herzegowina oder gleichnamige zyprische Gemeinden/Gemeinschaften.", "", "## Namensabdeckung", "", "In der algerischen Quelle besitzen 31 echte Grenzobjekte keinen Namen. Ihre Geometrien und stabilen Kennungen bleiben erhalten; `original_name=null` und `name_known=false` unterscheiden diese Lücke von einem bekannten Ortsnamen. Der Anzeigetext „Gemeinde (Name in Quelle fehlt)“ ist ausdrücklich kein erfundener geografischer Name. Alle anderen ausgewählten Quellen enthalten Namen für sämtliche Objekte. Nichtleere Namen können dennoch Quellfehler enthalten: bekannte Kodierungsschäden werden in den Länderhinweisen dokumentiert. Namensabdeckung und Grenzflächenabdeckung sind getrennte Messwerte.", "", "## Quellen- und Integritätsbelege", "", "Die Originalbezeichnung `boundaryLicense`, die unveränderte API-Metadatenantwort und das am Datencommit festgeschriebene Metadata-JSON bleiben im Manifest erhalten. Share-Alike-Quellen dürfen nicht pauschal als CC BY 4.0 ausgegeben werden. Hinweise auf OpenStreetMap bleiben erhalten; die ursprüngliche Quellen-Lizenzangabe wird nicht durch die heutige Lizenzseite ersetzt.", ""])
    for source in sources:
        lines.extend([f"### {source['id']}", "", f"- Quelle: [{source['unit_type']}]({source['url']})", f"- Attribution: {source['attribution']}", f"- SHA-256: `{source['sha256']}`", f"- [Festgeschriebene Metadaten]({source['pinnedmetadataURL']}), SHA-256 `{source['metadata_sha256']}`", f"- Ursprünglicher Lizenzverweis: `{source['original_license_source']}`", ""])
        evidence = source["unit_semantics"]
        if evidence.get("evidence_urls"):
            lines.extend(["- Belegte Verwaltungsrolle: " + evidence["reference_note"]])
            lines.extend([f"- [Amtlicher Rollen-/Standbeleg]({url})" for url in evidence["evidence_urls"]])
            if evidence.get("license_evidence_url"):
                lines.append(f"- [Zusätzlicher ursprünglicher Lizenzbeleg]({evidence['license_evidence_url']})")
            lines.append("")
    lines.extend(["## Noch nicht aufgenommene Kandidaten", "", "Diese Kandidaten bleiben als offene Daten-/Lizenzprüfung sichtbar. Ihre bloße Existenz gilt nicht als nachgewiesene kommunale Flächenabdeckung.", ""])
    for country, candidate in unadmitted_candidates().items():
        lines.append(f"- **{country} · {candidate['source']}**: {candidate['reason']}")
        lines.extend([f"  [Primärbeleg]({url})" for url in candidate["evidence_urls"]])
    lines.extend(["", "## Fachliche Grenzen", "", "Frankreich umfasst auch kommunale Arrondissements; Portugal liefert Freguesias unterhalb der Municipios. Die Ukrainequelle bezeichnet Village Councils und wird nicht als reformierte Hromada-Gliederung ausgegeben. Die iranische Dehestan-Ebene ist eine ländliche Verwaltungsebene und beweist keine flächendeckende urbane Gemeindeabdeckung. Bezugsjahre unterscheiden sich. Die 2018er belgischen und luxemburgischen Quellen behalten den damaligen Gemeindenstand; spätere Fusionen werden nicht erfunden. Montenegro enthält die 23 Einheiten des Quellenstands statt der neueren 25. Serbien und Kosovo haben getrennte Quelldatensätze, deren Landeszuordnung im Atlas räumlich kontrolliert wird. Liechtenstein und San Marino besitzen auf ihrer ersten Verwaltungsebene bereits echte lokale Körperschaften. Luxemburg enthält teilweise beschädigte Quellnamens-Kodierungen, etwa `PrÃ©izerdaul`; diese werden nicht als nachträglich amtlich bestätigte Schreibweisen ausgegeben. Für Russland und Türkei werden vorhandene Kreis-/Raiondaten nicht in Gemeinden umbenannt. Die amtlichen FI-/GB-Quellen stehen im separaten Reader `atlas_official_sources.py`; Norwegen ist in dieser gbOpen-Liste weiterhin nicht erschlossen.", "", "Eine heruntergeladene vollständige FeatureCollection belegt die Vollständigkeit der Quelldatei, keine 95-%-Landesflächenabdeckung. Die geometrische Union und verbleibende Lücken je Land werden erst durch den nachgelagerten Atlas-Build gemessen.", ""])
    path = ROOT / "docs/atlas-communal-sources.md"
    content = ("\n".join(lines)).encode("utf-8")
    if not path.exists() or path.read_bytes() != content:
        temporary = path.with_suffix(".md.tmp")
        temporary.write_bytes(content)
        temporary.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--validate-boundaries", action="store_true")
    args = parser.parse_args()
    sources = prepare_sources(args.cache)
    counts = {}
    if args.validate_boundaries:
        for record in iter_boundaries(args.cache, sources):
            counts[record["country"]] = counts.get(record["country"], 0) + 1
    print(json.dumps({"sources": len(sources), "bytes": sum(source["bytes"] for source in sources),
                      "features": sum(source["source_unit_count"] for source in sources),
                      "normalized_units": sum(source.get("normalized_unit_count", source["source_unit_count"]) for source in sources),
                      "normalized_by_country": counts}, ensure_ascii=False))


if __name__ == "__main__":
    main()
