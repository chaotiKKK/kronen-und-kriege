"""Official local-government polygons; no numeric ADM equivalence is invented.

The Finnish municipal (kunta), UK local authority district (LAD), and Irish
county/city council products have different native hierarchies. They share a
rendering role, with their actual source role retained alongside that role.
"""
from __future__ import annotations

import argparse
import csv
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
import math
from pathlib import Path
import re
import unicodedata
from typing import Iterator
from urllib.parse import urlencode

import shapely
from shapely.geometry import shape

from atlas_communal_sources import _download_cached, _write_json, sha256_file, verify_source

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
FI_YEAR = 2026
FI_SOURCE_ID = "statfi-kunta-2026-1000k"
AX_MML_SOURCE_ID = "mml-AX-kunta-2025-10k"
LU_SOURCE_ID = "act-LU-communes-20261105"
LU_CANTON_SOURCE_ID = "act-LU-cantons-20261105"
GB_SOURCE_ID = "ons-LAD25-UK-BGC"
FI_WFS = "https://geo.stat.fi/geoserver/tilastointialueet/wfs"
FI_TYPE = "tilastointialueet:kunta1000k_2026"
FI_CORRESPONDENCE_URL = "https://api.stat.fi/classificationservice/open/api/classifications/v2/correspondenceTables/kunta_1_20260101%23nuts_2_20260101/maps?content=data&format=json&lang=en&meta=min"
AX_MUNICIPALITY_CODES = frozenset({"035", "043", "060", "062", "065", "076", "170", "295", "318", "417", "438", "478", "736", "766", "771", "941"})
GB_SERVICE = "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Local_Authority_Districts_DEC_2025_Boundaries_UK_BGC/FeatureServer"
GB_ITEM_ID = "54b2a8f849f743aea669488cab415c8f"
IE_SOURCE_ID = "tailte-local-authorities-2019-20m"
IE_ITEM_ID = "7f508baddb9644d8ac3c3921df39303a"
IE_SERVICE = "https://services-eu1.arcgis.com/FH5XCsx8rYXqnjF5/arcgis/rest/services/Administrative_Areas___OSi_National_Statutory_Boundaries___Generalised_20m/FeatureServer"
GB_ROLES = {"E06": "Unitary authority", "E07": "Non-metropolitan district",
            "E08": "Metropolitan district", "E09": "London borough",
            "S12": "Council area", "W06": "Principal area",
            "N09": "Local government district"}


def validate_feature_collection(document: dict, expected_count: int) -> list[dict]:
    """Reject incomplete WFS/ArcGIS responses even when they omit a limit flag."""
    rows = document.get("features")
    if document.get("type") != "FeatureCollection" or not isinstance(rows, list):
        raise ValueError("Official boundary source is not a GeoJSON FeatureCollection")
    if document.get("exceededTransferLimit") or document.get("properties", {}).get("exceededTransferLimit"):
        raise ValueError("Official source transfer limit exceeded")
    if expected_count <= 0 or len(rows) != expected_count:
        raise ValueError(f"Incomplete official source: {len(rows)} != {expected_count}")
    for key in ("numberMatched", "totalFeatures", "numberReturned"):
        count = document.get(key)
        if count not in (None, "unknown") and int(count) != expected_count:
            raise ValueError(f"Official source {key} differs from returned feature count")
    return rows


def combine_arcgis_pages(pages: list[dict], expected_count: int, page_size: int) -> dict:
    """Assemble actual pages, retaining each original page and its limit flags."""
    if page_size <= 0 or expected_count <= 0 or len(pages) != math.ceil(expected_count / page_size):
        raise ValueError("Incomplete set of official ArcGIS pages")
    features = []
    seen = set()
    for index, page in enumerate(pages):
        rows = page.get("features")
        wanted = min(page_size, expected_count - index * page_size)
        if page.get("type") != "FeatureCollection" or not isinstance(rows, list) or len(rows) != wanted:
            raise ValueError(f"Incomplete official ArcGIS page {index}")
        for row in rows:
            object_id = (row.get("properties") or {}).get("FID")
            if object_id is None or object_id in seen:
                raise ValueError(f"Missing or duplicate official ArcGIS object identifier: {object_id}")
            seen.add(object_id)
        features.extend(rows)
    combined = {"type": "FeatureCollection", "features": features,
                "properties": {"assembled_from_pages": True, "source_page_count": len(pages),
                               "source_feature_count": expected_count}}
    validate_feature_collection(combined, expected_count)
    return combined


def _area_geometry(feature: dict):
    if not isinstance(feature.get("geometry"), dict):
        raise ValueError("Official local area has no geometry")
    geometry = shape(feature["geometry"])
    if geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty:
        raise ValueError("Official local area is not polygonal")
    repaired = not geometry.is_valid
    if repaired:
        geometry = shapely.make_valid(geometry)
    if geometry.geom_type == "GeometryCollection":
        geometry = shapely.unary_union([part for part in shapely.get_parts(geometry)
                                        if part.geom_type in ("Polygon", "MultiPolygon")])
    if geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty or geometry.area <= 0:
        raise ValueError("Official local area has no valid polygonal area")
    bounds = geometry.bounds
    if not all(math.isfinite(value) for value in bounds) or not (-180 <= bounds[0] <= bounds[2] <= 180 and -90 <= bounds[1] <= bounds[3] <= 90):
        raise ValueError("Official local area is not longitude/latitude geometry")
    return geometry, repaired


def _name(properties: dict, fields: tuple[str, ...]) -> tuple[str, str | None, bool]:
    for field in fields:
        value = properties.get(field)
        if isinstance(value, str) and value.strip():
            return value.strip(), value, True
    return "Gemeinde (Name in Quelle fehlt)", None, False


def finnish_territory_codes(document: list[dict]) -> dict[str, str]:
    """Use the official 2026 municipality-to-NUTS3 correspondence table."""
    if not isinstance(document, list) or not document:
        raise ValueError("Finnish official correspondence is not a nonempty list")
    result = {}
    for row in document:
        table = row.get("correspondenceTable", {})
        if table.get("sourceClassification") != "kunta_1_20260101" or table.get("targetClassification") != "nuts_2_20260101":
            raise ValueError("Official municipality correspondence uses another classification year")
        target = row.get("targetItem", {})
        if target.get("level") != 3:
            continue
        code = row.get("sourceItem", {}).get("code")
        nuts = target.get("code", "")
        if not isinstance(code, str) or re.fullmatch(r"\d{3}", code) is None or re.fullmatch(r"FI[A-Z0-9]{3}", nuts) is None:
            raise ValueError("Invalid official Finnish municipality/NUTS3 code")
        country = "AX" if nuts == "FI200" else "FI"
        if code in result and result[code] != country:
            raise ValueError(f"Conflicting official Finnish territory assignment: {code}")
        result[code] = country
    if not result:
        raise ValueError("Official Finnish correspondence has no NUTS3 assignments")
    return result


def normalize_finnish(feature: dict, territories: dict | None = None) -> dict:
    properties = feature.get("properties") or {}
    code = properties.get("kunta")
    if not isinstance(code, str) or re.fullmatch(r"\d{3}", code) is None:
        raise ValueError("Missing or invalid official Finnish municipal code")
    if properties.get("vuosi") != FI_YEAR:
        raise ValueError("Finnish municipal feature belongs to a different source year")
    if territories is not None and code not in territories:
        raise ValueError(f"Finnish source code has no official territory assignment: {code}")
    country = territories[code] if territories is not None else ("AX" if code in AX_MUNICIPALITY_CODES else "FI")
    geometry, repaired = _area_geometry(feature)
    name, original_name, known = _name(properties, ("nimi", "name", "namn"))
    return {"country": country, "id": f"statfi:kunta:{FI_YEAR}:{code}",
            "country_assignment_method": "official_code", "original_source_country": "FI",
            "municipality_code": code, "name": name, "name_known": known,
            "original_name": original_name,
            "source_names": {key: properties.get(key) for key in ("nimi", "namn", "name")},
            "kind": "municipality", "geometry": geometry,
            "parent_id": "country:" + country, "source": FI_SOURCE_ID,
            "admin_level": None, "native_level": "kunta", "unit_type": "Kunta / kommun",
            "source_year": FI_YEAR, "geometry_repaired": repaired}


def normalize_mml_aland(feature: dict) -> dict:
    properties = feature.get("properties") or {}
    code = properties.get("NATCODE")
    if not isinstance(code, str) or code not in AX_MUNICIPALITY_CODES:
        raise ValueError("MML municipal source has no reviewed official Åland code")
    geometry, repaired = _area_geometry(feature)
    name, original_name, known = _name(properties, ("NAMESWE", "NAMEFIN"))
    return {"country": "AX", "id": f"mml:kunta:2025:{code}",
            "country_assignment_method": "official_code", "original_source_country": "FI",
            "municipality_code": code, "name": name, "name_known": known, "original_name": original_name,
            "source_names": {key: properties.get(key) for key in ("NAMEFIN", "NAMESWE")},
            "kind": "municipality", "geometry": geometry, "parent_id": "country:AX", "source": AX_MML_SOURCE_ID,
            "admin_level": None, "native_level": "kunta", "unit_type": "Kunta / kommun",
            "source_year": 2025, "geometry_repaired": repaired, "merge_priority": 4,
            "geometry_includes_marine_area": True,
            "source_area_km2": {"land": properties.get("LANDAREA"), "freshwater": properties.get("FRESHWAREA"),
                                "sea": properties.get("SEAWAREA"), "total": properties.get("TOTALAREA")}}


def normalize_luxembourg(feature: dict, names: dict | None = None, native_codes: dict | None = None,
                         cantons: dict | None = None) -> dict:
    properties = feature.get("properties") or {}
    code = properties.get("LAU2")
    name = properties.get("COMMUNE")
    if not isinstance(code, str) or re.fullmatch(r"\d{4}", code) is None or not isinstance(name, str) or not name.strip():
        raise ValueError("ACT communal feature has no valid original LAU2 code and name")
    name = unicodedata.normalize("NFC", name.strip())
    if names is not None and names.get(code) != name:
        raise ValueError("ACT municipal name/code does not match the independent official commune register")
    canton_name = unicodedata.normalize("NFC", str(properties.get("CANTON", "")).strip())
    canton_code = None
    if cantons is not None:
        canton_code = cantons.get(canton_name)
        if not isinstance(canton_code, str) or code[:2] != canton_code:
            raise ValueError("ACT commune's original canton name and LAU2 prefix do not join the unique current canton")
    geometry, repaired = _area_geometry(feature)
    return {"country": "LU", "id": "act:LU:commune:"+code, "municipality_code": code,
            "name": name, "original_name": properties["COMMUNE"], "name_known": True,
            "kind": "municipality", "geometry": geometry,
            "parent_id": "act:LU:canton:"+canton_code if canton_code else "country:LU", "source": LU_SOURCE_ID,
            "country_assignment_method": "official_country_product", "native_canton": canton_name,
            "native_canton_code": canton_code,
            "native_commune_code": (native_codes or {}).get(name), "admin_level": None,
            "native_level": "commune administrative / LAU", "unit_type": "Commune", "source_year": 2026,
            "source_date": "2026-11-05", "merge_priority": 4, "geometry_repaired": repaired}


def luxembourg_canton_codes(features: list[dict]) -> dict[str, str]:
    names, codes = {}, set()
    for feature in features:
        properties = feature.get("properties") or {}
        name, code = properties.get("CANTON"), properties.get("LAU1")
        if (not isinstance(name, str) or not name.strip() or not isinstance(code, str)
                or re.fullmatch(r"\d{2}", code) is None or not 1 <= int(code) <= 12):
            raise ValueError("ACT canton lacks its original name and stable two-digit LAU1 source code")
        name = unicodedata.normalize("NFC", name.strip())
        if name in names or code in codes:
            raise ValueError("ACT canton name/code join is ambiguous or duplicated")
        names[name] = code
        codes.add(code)
    if not names:
        raise ValueError("ACT canton layer is empty")
    return names


def normalize_luxembourg_canton(feature: dict) -> dict:
    name, code = next(iter(luxembourg_canton_codes([feature]).items()))
    geometry, repaired = _area_geometry(feature)
    return {"country": "LU", "id": "act:LU:canton:"+code, "name": name, "original_name": name,
            "name_known": True, "kind": "district", "unit_type": "Canton", "canton_code": code,
            "native_code_field": "LAU1", "native_level": "canton (ACT LAU1 field)", "admin_level": None,
            "parent_id": "country:LU", "geometry": geometry, "source": LU_CANTON_SOURCE_ID,
            "source_year": 2026, "source_date": "2026-11-05", "merge_priority": 4,
            "country_assignment_method": "official_country_product", "geometry_repaired": repaired}


def normalize_british(feature: dict) -> dict:
    properties = feature.get("properties") or {}
    code = properties.get("LAD25CD")
    if not isinstance(code, str) or re.fullmatch(r"[ENSW]\d{8}", code) is None or code[:3] not in GB_ROLES:
        raise ValueError("Missing or non-local-government UK LAD25 code")
    geometry, repaired = _area_geometry(feature)
    name, original_name, known = _name(properties, ("LAD25NM", "LAD25NMW"))
    return {"country": "GB", "id": "ons:LAD25:" + code,
            "municipality_code": code, "name": name, "name_known": known,
            "original_name": original_name,
            "source_names": {key: properties.get(key) for key in ("LAD25NM", "LAD25NMW")},
            "kind": "municipality", "geometry": geometry,
            "parent_id": "country:GB", "source": GB_SOURCE_ID,
            "admin_level": None, "native_level": "LAD",
            "unit_type": "City of London" if code == "E09000001" else GB_ROLES[code[:3]],
            "source_year": 2025, "geometry_repaired": repaired}


def normalize_irish(feature: dict) -> dict:
    properties = feature.get("properties") or {}
    identifier = properties.get("GUID")
    if not isinstance(identifier, str) or re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", identifier) is None:
        raise ValueError("Irish local authority has no stable native GUID")
    english = str(properties.get("ENGLISH") or "").upper()
    if english.endswith("CITY AND COUNTY COUNCIL"):
        role = "City and county council"
    elif english.endswith("CITY COUNCIL"):
        role = "City council"
    elif english.endswith("COUNTY COUNCIL"):
        role = "County council"
    else:
        raise ValueError("Irish feature is not an identified county/city local authority")
    geometry, repaired = _area_geometry(feature)
    name, original_name, known = _name(properties, ("ENGLISH", "GAEILGE"))
    return {"country": "IE", "id": "tailte:local-authority:2019:" + identifier.lower(),
            "municipality_code": str(properties.get("CC_ID") or identifier), "source_guid": identifier,
            "name": name, "name_known": known, "original_name": original_name,
            "source_names": {key: properties.get(key) for key in ("ENGLISH", "GAEILGE", "CONTAE")},
            "kind": "municipality", "geometry": geometry, "parent_id": "country:IE",
            "source": IE_SOURCE_ID, "admin_level": None, "native_level": "Local authority",
            "unit_type": role, "source_year": 2019, "geometry_repaired": repaired}


def _fetch(cache: Path, relative: str, url: str) -> tuple[dict, dict]:
    receipt = _download_cached(url, cache / relative)
    with (cache / relative).open(encoding="utf-8-sig") as handle:
        document = json.load(handle)
    if isinstance(document, dict) and "error" in document:
        raise ValueError(f"Official source API error: {document['error']}")
    return document, {**receipt, "cache_file": relative}


def _source_stats(document: dict, expected: int, normalizer) -> dict:
    rows = validate_feature_collection(document, expected)
    seen = set()
    missing_names = []
    repaired = 0
    roles = Counter()
    for feature in rows:
        row = normalizer(feature)
        if row["id"] in seen:
            raise ValueError(f"Duplicate official municipal code: {row['id']}")
        seen.add(row["id"])
        if not row["name_known"]:
            missing_names.append(row["id"])
        repaired += int(row["geometry_repaired"])
        roles[row["unit_type"]] += 1
    return {"source_unit_count": len(rows), "expected_unit_count": expected,
            "source_name_missing_count": len(missing_names), "source_name_missing_ids": missing_names,
            "geometry_repaired_count": repaired, "source_role_counts": dict(sorted(roles.items()))}


def _prepare_finnish(cache: Path) -> dict:
    common = {"service": "WFS", "version": "2.0.0", "typeNames": FI_TYPE,
              "outputFormat": "application/json"}
    schema_url = FI_WFS + "?" + urlencode({**common, "request": "DescribeFeatureType"})
    schema, metadata_receipt = _fetch(cache, "official/statfi-kunta1000k-2026-schema.json", schema_url)
    types = schema.get("featureTypes", [])
    if len(types) != 1 or types[0].get("typeName") != "kunta1000k_2026":
        raise ValueError("Statistics Finland schema is not the requested 2026 municipal product")
    url = FI_WFS + "?" + urlencode({**common, "request": "GetFeature", "srsName": "EPSG:4326", "sortBy": "kunta", "count": 1000})
    document, receipt = _fetch(cache, "official/statfi-kunta1000k-2026.geojson", url)
    expected = int(document.get("numberMatched", 0))
    correspondence, correspondence_receipt = _fetch(cache, "official/statfi-kunta2026-NUTS2026.json", FI_CORRESPONDENCE_URL)
    territories = finnish_territory_codes(correspondence)
    actual_codes = {feature.get("properties", {}).get("kunta") for feature in document.get("features", [])}
    if actual_codes != set(territories) or {code for code, country in territories.items() if country == "AX"} != AX_MUNICIPALITY_CODES:
        raise ValueError("Official Finnish municipality codes or Åland membership changed; source review required")
    stats = _source_stats(document, expected, lambda feature: normalize_finnish(feature, territories))
    return {"id": FI_SOURCE_ID, "country": "FI", "scope_countries": ["FI", "AX"],
            **receipt, **stats, "date": str(FI_YEAR), "admin_level": None, "native_level": "kunta",
            "unit_type": "Kunta / kommun", "kind": "municipality", "license": "CC BY 4.0",
            "license_url": "https://creativecommons.org/licenses/by/4.0/",
            "license_evidence_url": "https://stat.fi/en/about-us/get-to-know-statistics-finland/legislation/terms-of-use",
            "attribution": "Source: Statistics Finland",
            "pinnedmetadataURL": schema_url, "metadata_url": schema_url,
            "metadata_receipts": [metadata_receipt, correspondence_receipt], "pinned_metadata": schema,
            "country_assignment_method": "official_code", "country_assignments": territories,
            "territory_assignment": {**correspondence_receipt, "source_classification": "kunta_1_20260101",
                "target_classification": "nuts_2_20260101", "target_aland_nuts3": "FI200",
                "municipality_count": len(territories), "aland_municipality_codes": sorted(AX_MUNICIPALITY_CODES),
                "license": "CC BY 4.0", "license_url": "https://creativecommons.org/licenses/by/4.0/",
                "attribution": "Source: Statistics Finland",
                "product_url": "https://stat.fi/fi/luokitukset/corrmaps/kunta_1_20260101%23nuts_2_20260101"},
            "product_url": "https://stat.fi/en/services/statistical-data-services/geographic-data/statistical-areas/municipality-based-statistical-units",
            "unit_semantics": {"render_role": "municipality", "source_unit_type": "kunta",
                "native_resolution": "1:1,000,000 municipal boundaries for statistical reference year 2026",
                "scope_note": "Includes Åland. All 308 municipal codes are joined against the official 2026 NUTS correspondence; FI200's 16 municipalities are assigned to AX and their whole original geometry is retained.",
                "coverage_status": "Complete API feature response verified; geometric land coverage not measured here"}}


def _prepare_british(cache: Path) -> dict:
    service, service_receipt = _fetch(cache, "official/ons-LAD25-service.json", GB_SERVICE + "?f=pjson")
    item_url = "https://www.arcgis.com/sharing/rest/content/items/" + GB_ITEM_ID + "?f=pjson"
    item, item_receipt = _fetch(cache, "official/ons-LAD25-item.json", item_url)
    if service.get("serviceItemId") != GB_ITEM_ID or item.get("owner") != "ONSGeography_data" or item.get("title") != "Local Authority Districts (December 2025) Boundaries UK BGC":
        raise ValueError("ArcGIS service is not the reviewed ONS December 2025 LAD BGC product")
    query = GB_SERVICE + "/0/query?"
    count_url = query + urlencode({"where": "1=1", "returnCountOnly": "true", "f": "json"})
    counted, count_receipt = _fetch(cache, "official/ons-LAD25-count.json", count_url)
    expected = int(counted.get("count", 0))
    page_size = 25
    if int(service.get("maxRecordCount", 0)) < page_size:
        raise ValueError("ONS service record limit is below the reviewed page size")
    query_parameters = {"where": "1=1", "outFields": "FID,LAD25CD,LAD25NM,LAD25NMW",
        "returnGeometry": "true", "outSR": 4326, "resultRecordCount": page_size, "orderByFields": "FID", "f": "geojson"}

    def fetch_page(offset: int):
        url = query + urlencode({**query_parameters, "resultOffset": offset})
        return _fetch(cache, f"official/ons-LAD25-pages/offset-{offset:04d}.geojson", url)

    # The monolithic geometry response was terminated by the provider. Small,
    # ordered pages succeeded without modifying geometry or certificate checks.
    with ThreadPoolExecutor(max_workers=3) as executor:
        fetched = list(executor.map(fetch_page, range(0, expected, page_size)))
    document = combine_arcgis_pages([page for page, _ in fetched], expected, page_size)
    relative = "official/ons-LAD25-UK-BGC.geojson"
    path = cache / relative
    _write_json(path, document)
    receipt = {"url": query + urlencode(query_parameters), "cache_file": relative,
               "bytes": path.stat().st_size, "sha256": sha256_file(path)}
    stats = _source_stats(document, expected, normalize_british)
    return {"id": GB_SOURCE_ID, "country": "GB", "scope_countries": ["GB"],
            **receipt, **stats, "date": "2025-12", "admin_level": None, "native_level": "LAD",
            "unit_type": "Local authority district / principal local authority", "kind": "municipality",
            "license": "Open Government Licence v3.0",
            "license_url": "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
            "license_evidence_url": "https://www.ons.gov.uk/methodology/geography/licences",
            "attribution": "Source: Office for National Statistics licensed under the Open Government Licence v.3.0; Contains OS data © Crown copyright and database right 2025",
            "pinnedmetadataURL": item_url, "metadata_url": item_url,
            "metadata_receipts": [service_receipt, item_receipt, count_receipt],
            "pinned_metadata": {"item": item, "service": service, "count_response": counted},
            "download_strategy": "Ordered 25-feature pages; duplicate IDs and complete response count verified",
            "source_page_receipts": [page_receipt for _, page_receipt in fetched],
            "product_url": "https://geoportal.statistics.gov.uk/datasets/ons::local-authority-districts-december-2025-boundaries-uk-bgc/about",
            "unit_semantics": {"render_role": "municipality", "source_unit_type": "Local authority district (LAD)",
                "native_resolution": "20 m generalised and coastline-clipped boundaries, December 2025",
                "scope_note": "England districts/unitary authorities/boroughs, Welsh principal areas, Scottish council areas, Northern Ireland local government districts. Parishes and higher counties are not duplicated here.",
                "role_evidence_url": "https://www.gov.uk/guidance/local-government-structure-and-elections",
                "city_of_london_evidence_url": "https://www.london.gov.uk/who-we-are/how-we-work-london",
                "coverage_status": "Complete API feature response verified; geometric land coverage not measured here"}}


def _prepare_irish(cache: Path) -> dict:
    service, service_receipt = _fetch(cache, "official/tailte-local-authorities-2019-service.json", IE_SERVICE + "?f=pjson")
    item_url = "https://www.arcgis.com/sharing/rest/content/items/" + IE_ITEM_ID + "?f=pjson"
    item, item_receipt = _fetch(cache, "official/tailte-local-authorities-2019-item.json", item_url)
    if service.get("serviceItemId") != IE_ITEM_ID or item.get("owner") != "TailteEireannMapGenie" or item.get("title") != "Administrative Areas - National Statutory Boundaries - 2019 - Generalised 20m":
        raise ValueError("Irish source is not the reviewed 31-authority Tailte product")
    if "creativecommons.org/licenses/by/4.0/" not in str(item.get("licenseInfo", "")):
        raise ValueError("The original Tailte source no longer states the reviewed CC BY 4.0 terms")
    query = IE_SERVICE + "/0/query?"
    count_url = query + urlencode({"where": "1=1", "returnCountOnly": "true", "f": "json"})
    counted, count_receipt = _fetch(cache, "official/tailte-local-authorities-2019-count.json", count_url)
    expected = int(counted.get("count", 0))
    if expected != 31 or int(service.get("maxRecordCount", 0)) < expected:
        raise ValueError("The reviewed Irish 31-authority response cannot be retrieved completely")
    url = query + urlencode({"where": "1=1", "outFields": "ESRI_OID,GUID,CC_ID,ENGLISH,GAEILGE,CONTAE",
        "returnGeometry": "true", "outSR": 4326, "resultRecordCount": 100, "orderByFields": "ESRI_OID", "f": "geojson"})
    document, receipt = _fetch(cache, "official/tailte-local-authorities-2019-20m.geojson", url)
    stats = _source_stats(document, expected, normalize_irish)
    return {"id": IE_SOURCE_ID, "country": "IE", "scope_countries": ["IE"],
            **receipt, **stats, "date": "2019", "admin_level": None, "native_level": "Local authority",
            "unit_type": "County/city local authority", "kind": "municipality",
            "license": "CC BY 4.0", "license_url": "https://creativecommons.org/licenses/by/4.0/",
            "license_evidence_url": item_url, "attribution": "© Tailte Éireann; licensed under CC BY 4.0",
            "pinnedmetadataURL": item_url, "metadata_url": item_url,
            "metadata_receipts": [service_receipt, item_receipt, count_receipt],
            "pinned_metadata": {"item": item, "service": service, "count_response": counted},
            "product_url": "https://www.arcgis.com/home/item.html?id=" + IE_ITEM_ID,
            "unit_semantics": {"render_role": "municipality", "source_unit_type": "Local authority",
                "native_resolution": "Generalised 20 m national statutory boundaries, 2019 snapshot",
                "role_evidence_url": "https://www.cso.ie/en/releasesandpublications/ep/p-cpini/irelandandnorthernireland-ajointcensuspublication2021-2022/backgroundnotes/",
                "scope_note": "31 actual county/city councils, not the 26 traditional counties or 166 electoral areas. The 2019 product year is retained; newer component geometries have not been silently substituted.",
                "coverage_status": "Complete 31-authority API response verified; geometric land coverage not measured here"}}


def _prepare_mml_aland(cache: Path, finnish: dict) -> dict:
    wfs = "https://paituli.csc.fi/geoserver/wfs?"
    source_type = "paituli:mml_hallinto_2025_10k"
    schema_url = wfs + urlencode({"service": "WFS", "version": "2.0.0", "request": "DescribeFeatureType",
                                  "typeNames": source_type, "outputFormat": "application/json"})
    schema, schema_receipt = _fetch(cache, "official/mml-AX-kunta2025-10k-schema.json", schema_url)
    types = schema.get("featureTypes", [])
    if len(types) != 1 or types[0].get("typeName") != "mml_hallinto_2025_10k":
        raise ValueError("MML WFS schema is not the reviewed 2025 municipal product")
    codes = {code for code, country in finnish.get("country_assignments", {}).items() if country == "AX"}
    if codes != AX_MUNICIPALITY_CODES:
        raise ValueError("MML Åland selection has no complete official country-code correspondence")
    params = {"service": "WFS", "version": "2.0.0", "request": "GetFeature", "typeNames": source_type,
              "outputFormat": "application/json", "srsName": "EPSG:4326",
              "CQL_FILTER": "NATCODE IN (" + ",".join("'"+code+"'" for code in sorted(codes)) + ")",
              "count": 20, "sortBy": "NATCODE"}
    # Reuse the separately downloaded native municipal response; it was never
    # used to construct the independent physical-land coverage denominator.
    document, receipt = _fetch(cache, "land-references/AX-MML-2025-10k-frame.json", wfs + urlencode(params))
    stats = _source_stats(document, 16, normalize_mml_aland)
    if {feature["properties"]["NATCODE"] for feature in document["features"]} != codes:
        raise ValueError("MML municipal response does not contain exactly the 16 official Åland codes")
    return {"id": AX_MML_SOURCE_ID, "country": "AX", "scope_countries": ["AX"], **receipt, **stats,
        "date": "2025-01-01", "merge_priority": 4, "admin_level": None, "native_level": "kunta",
        "unit_type": "Kunta / kommun", "kind": "municipality", "license": "CC BY 4.0",
        "license_url": "https://creativecommons.org/licenses/by/4.0/",
        "license_evidence_url": "https://www.maanmittauslaitos.fi/en/opendata-licence-cc40",
        "attribution": "National Land Survey of Finland (Maanmittauslaitos), Administrative Areas 1:10,000, 2025; provided by CSC Paituli. Original marine-inclusive municipal boundaries; cartographic land display requires the separately sourced SYKE physical coastline.",
        "pinnedmetadataURL": "https://boileri.nic.funet.fi/pub/sci/geo/geodata/mml/hallintorajat_10k/2025/tietotuoteseloste_kuntajako_2025_10k.pdf",
        "metadata_url": schema_url, "metadata_receipts": [schema_receipt], "pinned_metadata": schema,
        "country_assignment_method": "official_code", "country_assignments": {code: "AX" for code in sorted(codes)},
        "territory_assignment": finnish["territory_assignment"],
        "geometry_includes_marine_area": True, "requires_physical_land_clip": True,
        "land_reference_source_id": "syke-physical-land-AX-MML2025",
        "replacement_key": "country + kind + municipality_code",
        "product_url": "https://www.maanmittauslaitos.fi/kartat-ja-paikkatieto/aineistot-ja-rajapinnat/tuotekuvaukset/hallinnolliset-aluejaot-vektori",
        "unit_semantics": {"render_role": "municipality", "source_unit_type": "kunta / kommun",
            "native_resolution": "1:10,000 native administrative boundaries including sea and freshwater, 2025",
            "scope_note": "Exactly 16 Åland municipal codes. Higher-priority replacement for these codes only; do not count alongside the same 16 StatFi kunta1000k units. Source year remains 2025.",
            "physical_land_note": "The polygons include marine territory; sea is not relabelled as land. An independent SYKE island/official MML regional product supplies the land denominator.",
            "coverage_status": "Complete 16-code response; native municipal union covers 99.998708% of the independently measured SYKE coastal land, compared with 89.290504% for the coarse StatFi 1:1,000,000 product"}}


def write_manifest(sources: list[dict]) -> None:
    _write_json(ROOT / "data/atlas_official_sources.json", {
        "schema_version": 1, "review_date": "2026-11-09", "raw_data_in_git": False,
        "scope": "Official native local-government products, including their unequal real-world roles",
        "integrity": "Year-addressed requests and cached SHA-256 receipts; subsequent reads reject changed bytes",
        "coverage_warning": "Feature response completeness is separate from geometric land coverage; the atlas merger must measure the latter per country.",
        "sources": sources})


def _prepare_luxembourg_cantons(cache: Path) -> dict:
    from atlas_land_references import luxembourg_product, LU_ZIP, LU_PORTAL
    document, provenance = luxembourg_product(cache, "LIMADM_CANTONS")
    cantons = luxembourg_canton_codes(document["features"])
    if len(cantons) != 12 or set(cantons.values()) != {f"{i:02d}" for i in range(1, 13)}:
        raise ValueError("ACT did not supply the reviewed 12 uniquely coded current cantons")
    stats = _source_stats(document, 12, normalize_luxembourg_canton)
    relative = "official/LU/cantons-ACT-20261105.geojson"
    _write_json(cache / relative, document)
    return {**provenance, **stats, "id": LU_CANTON_SOURCE_ID, "country": "LU", "scope_countries": ["LU"],
        "url": LU_ZIP, "cache_file": relative, "bytes": (cache / relative).stat().st_size,
        "sha256": sha256_file(cache / relative), "date": "2026-11-05", "merge_priority": 4,
        "admin_level": None, "native_level": "canton (ACT LAU1 field)", "unit_type": "Canton", "kind": "district",
        "license_evidence_url": LU_PORTAL, "pinnedmetadataURL": LU_ZIP,
        "canton_codes_by_name": cantons,
        "unit_semantics": {"render_role": "district", "source_unit_type": "Canton",
            "scope_note": "12 actual current cantons, original ACT LIMADM_CANTONS layer with unchanged two-digit LAU1 source field. No inference from abolished districts.",
            "code_note": "LAU1 is the original ACT attribute name, not a claim that the former two-level Eurostat LAU scheme remains current.",
            "historical_district_note": "The source's historical DISTRICT attribute is retained in the raw cache only and creates neither current region features nor parent IDs."}}


def _prepare_luxembourg(cache: Path, cantons: dict | None = None) -> dict:
    from atlas_land_references import luxembourg_product, luxembourg_commune_codes, _download_binary, LU_CODES, LU_NATIVE_CODES, LU_ZIP, LU_PORTAL
    document, provenance = luxembourg_product(cache, "LIMADM_COMMUNES")
    if cantons is None:
        cantons = _prepare_luxembourg_cantons(cache)["canton_codes_by_name"]
    registry_relative = "official/LU/communes-codes-20240709.csv"
    registry_receipt = _download_binary(LU_CODES, cache / registry_relative)
    names = luxembourg_commune_codes((cache / registry_relative).read_text(encoding="utf-8-sig"))
    native_relative = "official/LU/communes-sections-20251021.csv"
    native_receipt = _download_binary(LU_NATIVE_CODES, cache / native_relative)
    native = {}
    for row in csv.DictReader((cache / native_relative).read_text(encoding="utf-8-sig").splitlines()):
        name, code = row["nom_commune_administrative"], row["code_commune_administrative"]
        if re.fullmatch(r"\d{3}", code) is None or (name in native and native[name] != code):
            raise ValueError("ACT native municipal registry contains invalid or conflicting original codes")
        native[unicodedata.normalize("NFC", name)] = code
    if len(names) != 100 or len(native) != 100 or set(names.values()) != set(native):
        raise ValueError("ACT official municipal registries do not agree on the reviewed 100 communes")
    stats = _source_stats(document, 100, lambda feature: normalize_luxembourg(feature, names, native, cantons))
    if {f["properties"]["LAU2"] for f in document["features"]} != set(names):
        raise ValueError("ACT polygon codes differ from the complete official municipal list")
    relative = "official/LU/communes-ACT-20261105.geojson"
    _write_json(cache / relative, document)
    inputs = provenance["input_files"] + [{**registry_receipt, "cache_file": registry_relative},
                                         {**native_receipt, "cache_file": native_relative}]
    return {**provenance, **stats, "id": LU_SOURCE_ID, "country": "LU", "scope_countries": ["LU"],
        "url": LU_ZIP, "cache_file": relative, "bytes": (cache / relative).stat().st_size,
        "sha256": sha256_file(cache / relative), "date": "2026-11-05", "merge_priority": 4,
        "admin_level": None, "native_level": "commune administrative / LAU", "unit_type": "Commune", "kind": "municipality",
        "license_evidence_url": LU_PORTAL, "pinnedmetadataURL": LU_ZIP,
        "official_registry_names": names, "native_commune_codes": native, "input_files": inputs,
        "canton_codes_by_name": cantons,
        "hierarchy_join": {"parent_source": LU_CANTON_SOURCE_ID, "method": "Exact original COMMUNES.CANTON -> CANTONS.CANTON name join, cross-checked against LAU2 prefix and original canton LAU1 code", "joined_municipality_count": 100},
        "registry_date_note": "ACT LAU list 2024-07-09 and commune/section register 2025-10-21; both match all 100 polygons in the 2026-11-05 product",
        "unit_semantics": {"render_role": "municipality", "source_unit_type": "Commune administrative",
            "scope_note": "100 actual administrative communes, exact one-to-one LAU/name join against ACT registers. Cadastral communes, abolished districts and generalised alternatives are not imported.",
            "historical_district_note": "Original ZIP and registry retain historical DISTRICT attributes; they do not create current region features or municipal parents. Municipal parents are the independently read current canton features.",
            "native_resolution": "Original LIMADM_COMMUNES cadastral-derived administrative polygons, 2026-11-05; not LIMADM_GEN_COMMUNES"}}


def prepare_sources(cache: Path) -> list[dict]:
    cache = Path(cache)
    finnish = _prepare_finnish(cache)
    cantons = _prepare_luxembourg_cantons(cache)
    sources = [finnish, _prepare_british(cache), _prepare_irish(cache), _prepare_mml_aland(cache, finnish),
               _prepare_luxembourg(cache, cantons["canton_codes_by_name"]), cantons]
    write_manifest(sources)
    return sources


def iter_boundaries(cache: Path, sources: list[dict]) -> Iterator[dict]:
    for source in sources:
        for dependency in source.get("input_files", []):
            verify_source(Path(cache) / dependency["cache_file"], dependency)
        path = Path(cache) / source["cache_file"]
        verify_source(path, source)
        with path.open(encoding="utf-8-sig") as handle:
            document = json.load(handle)
        rows = validate_feature_collection(document, int(source["source_unit_count"]))
        normalizer = {FI_SOURCE_ID: normalize_finnish, GB_SOURCE_ID: normalize_british,
                      IE_SOURCE_ID: normalize_irish, AX_MML_SOURCE_ID: normalize_mml_aland,
                      LU_SOURCE_ID: normalize_luxembourg, LU_CANTON_SOURCE_ID: normalize_luxembourg_canton}.get(source["id"])
        if normalizer is None:
            raise ValueError(f"Unreviewed official source: {source['id']}")
        seen = set()
        for feature in rows:
            if source["id"] == FI_SOURCE_ID:
                row = normalize_finnish(feature, source.get("country_assignments"))
            elif source["id"] == LU_SOURCE_ID:
                row = normalize_luxembourg(feature, source["official_registry_names"], source["native_commune_codes"], source["canton_codes_by_name"])
            else:
                row = normalizer(feature)
            if row["id"] in seen:
                raise ValueError(f"Duplicate official source key: {row['id']}")
            seen.add(row["id"])
            yield row


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    args = parser.parse_args()
    selected = prepare_sources(args.cache)
    counts = Counter(row["country"] for row in iter_boundaries(args.cache, selected))
    print(json.dumps({"source_counts": counts, "source_bytes": sum(source["bytes"] for source in selected)}, ensure_ascii=False))
