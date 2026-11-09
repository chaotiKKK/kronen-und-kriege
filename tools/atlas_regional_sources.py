"""Verified upper regional units; source ADM numbers are not universal roles."""
from __future__ import annotations

import argparse
import html
import json
import math
from pathlib import Path
import re
import subprocess
from typing import Iterator
from urllib.parse import urlencode

import shapely
from shapely.geometry import shape

from atlas_communal_sources import _download_cached, _prepare_one, _write_json, sha256_file, verify_source

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
COMMIT = "9469f09"
DEFINITIONS = {"FR": ("FRA", 1, 13, "Région"), "IT": ("ITA", 2, 20, "Regione"),
               "ES": ("ESP", 1, 19, "Comunidad autónoma / ciudad autónoma")}
LICENSES = {
    "FR": ("Etalab Open License 2.0", "https://github.com/etalab/licence-ouverte/blob/master/LO.md"),
    "IT": ("Creative Commons Attribution 3.0 License", "https://creativecommons.org/licenses/by/3.0/"),
    "ES": ("Creative Commons Attribution 4.0 International (CC BY 4.0)", "https://creativecommons.org/licenses/by/4.0/")}
ROLE_EVIDENCE = {
    "FR": ["https://www.insee.fr/fr/metadonnees/definition/c1696",
           "https://www.collectivites-locales.gouv.fr/connaitre-les-acteurs-et-les-institutions/structures-territoriales/les-collectivites-statut-particulier/statut-particulier-la-corse"],
    "IT": ["https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici-al-1-gennaio-2018-2/",
           "https://ebiblio.istat.it/digibib/Annuario%20Statistico%20Italiano/ASI_2024.pdf"],
    "ES": ["https://educativo.ign.es/atlas-didactico/organizacion-territorial-bach/organizacin_territorial_espaola.html",
           "https://www.ign.es/resources/licencia/Condiciones_licenciaUso_IGN.pdf"]}
ONS_ITEM = "0139831c7166457ab1f7b3ab1f919cba"
ONS_SERVICE = "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Countries_December_2024_Boundaries_UK_BGC/FeatureServer"
ONS_LICENSE = "https://www.ons.gov.uk/methodology/geography/licences"
ONS_CODES = {"E92000001": "England", "N92000002": "Northern Ireland", "S92000003": "Scotland", "W92000004": "Wales"}


def select_source(metadata: list[dict], country: str) -> dict:
    if country not in DEFINITIONS:
        raise ValueError("GB gbOpen ADM1 is GISCO-derived and is not admitted; use the original ONS country product")
    iso, level, count, unit_type = DEFINITIONS[country]
    rows = [r for r in metadata if r.get("boundaryISO") == iso and r.get("boundaryType") == f"ADM{level}"]
    if len(rows) != 1:
        raise ValueError(f"No unique reviewed regional source for {country}/ADM{level}")
    item = rows[0]
    url = str(item.get("simplifiedGeometryGeoJSON", ""))
    prefix = f"https://github.com/wmgeolab/geoBoundaries/raw/{COMMIT}/releaseData/gbOpen/{iso}/ADM{level}/geoBoundaries-{iso}-ADM{level}"
    license_name, license_url = LICENSES[country]
    if (url != prefix + "_simplified.geojson" or int(item.get("admUnitCount", 0)) != count
            or item.get("boundaryLicense") != license_name):
        raise ValueError("Regional source pin, role count or individual license differs from the verified dataset")
    return {"id": f"gbOpen-regional-{iso}-ADM{level}", "country": country, "country_iso3": iso,
            "kind": "region", "source_type": "gbOpen-regional", "source_commit": COMMIT,
            "admin_level": level, "unit_type": unit_type, "expected_unit_count": count, "declared_unit_count": count,
            "date": str(item.get("boundaryYearRepresented", "")), "url": url, "original_url": prefix + ".geojson",
            "pinnedmetadataURL": prefix + "-metaData.json", "metadata_url": prefix + "-metaData.json",
            "cache_file": f"regional/geoBoundaries-{iso}-ADM{level}_simplified.geojson",
            "license": license_name, "license_url": license_url, "original_boundary_license": license_name,
            "original_license_source": str(item.get("licenseSource", "")), "original_metadata": item,
            "attribution": f"geoBoundaries gbOpen; {item.get('boundarySource', '')}; source year {item.get('boundaryYearRepresented', '')}; {license_name}",
            "role_evidence_urls": ROLE_EVIDENCE[country], "scope_countries": [country],
            "replace_natural_earth_kinds": ["region"], "administrative_geometry_eligible": True,
            "unit_semantics": {"render_role": "region", "source_unit_type": unit_type,
                               "original_canonical": str(item.get("boundaryCanonical", "")),
                               "coverage_status": "Upper regional role verified; no municipal coverage or equal-area claim",
                               "source_adm_note": "ADM numbers belong to the upstream schema; Italian ADM1 contains five statistical macroareas, so actual Regioni are selected at ADM2"}}


def validate_ons_item(item: dict):
    if (item.get("id") != ONS_ITEM or item.get("owner") != "ONSGeography_data"
            or item.get("title") != "Countries (December 2024) Boundaries UK BGC"
            or ONS_LICENSE not in str(item.get("licenseInfo", ""))
            or "Ordnance Survey and ONS Intellectual Property Rights" not in str(item.get("description", ""))):
        raise ValueError("The country source is not the original reviewed ONS product with its stated IPR/licensing reference")


def _ons_licence_receipt(cache: Path) -> dict:
    relative = "regional/ONS-digital-boundary-licences.html"
    path = cache / relative
    sidecar = path.with_suffix(path.suffix + ".receipt.json")
    if path.exists() and sidecar.exists():
        receipt = json.loads(sidecar.read_text(encoding="utf-8"))
        if receipt.get("url") != ONS_LICENSE:
            raise ValueError("Changed ONS licence source")
        verify_source(path, receipt)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".partial")
        subprocess.run(["curl.exe", "--fail", "--location", "--silent", "--show-error", "--connect-timeout", "20",
                        "--max-time", "90", "--max-filesize", "2000000", "--output", str(temporary), ONS_LICENSE], check=True)
        receipt = {"url": ONS_LICENSE, "bytes": temporary.stat().st_size, "sha256": sha256_file(temporary)}
        temporary.replace(path)
        _write_json(sidecar, receipt)
    text = " ".join(html.unescape(re.sub(r"<[^>]+>", " ", path.read_text(encoding="utf-8"))).split())
    if "Digital boundaries and reference maps" not in text or "Open Government Licence v.3.0" not in text:
        raise ValueError("Original ONS digital-boundary licensing evidence is unavailable or changed")
    return {**receipt, "cache_file": relative}


def _prepare_ons(cache: Path) -> dict:
    definitions = [("ONS-country-item.json", f"https://www.arcgis.com/sharing/rest/content/items/{ONS_ITEM}?f=pjson"),
                   ("ONS-country-service.json", ONS_SERVICE + "?f=pjson"),
                   ("ONS-country-layer.json", ONS_SERVICE + "/0?f=pjson"),
                   ("ONS-country-count.json", ONS_SERVICE + "/0/query?where=1%3D1&returnCountOnly=true&f=json")]
    inputs, documents = [], {}
    for filename, url in definitions:
        relative = "regional/" + filename
        receipt = _download_cached(url, cache / relative)
        inputs.append({**receipt, "cache_file": relative})
        documents[filename] = json.loads((cache / relative).read_text(encoding="utf-8"))
    item = documents["ONS-country-item.json"]
    validate_ons_item(item)
    if (documents["ONS-country-service.json"].get("serviceItemId") != ONS_ITEM
            or documents["ONS-country-count.json"].get("count") != 4):
        raise ValueError("ONS country service identity or original feature count differs from the reviewed source")
    fields = {f["name"] for f in documents["ONS-country-layer.json"].get("fields", [])}
    if not {"CTRY24CD", "CTRY24NM", "CTRY24NMW"}.issubset(fields):
        raise ValueError("ONS country product lacks its native code/name schema")
    inputs.append(_ons_licence_receipt(cache))
    url = ONS_SERVICE + "/0/query?" + urlencode({"where": "1=1", "outFields": "FID,CTRY24CD,CTRY24NM,CTRY24NMW",
          "returnGeometry": "true", "outSR": 4326, "orderByFields": "CTRY24CD", "f": "geojson"})
    relative = "regional/ONS-countries-2024-BGC.geojson"
    receipt = _download_cached(url, cache / relative)
    document = json.loads((cache / relative).read_text(encoding="utf-8"))
    rows = document.get("features", [])
    if (document.get("type") != "FeatureCollection" or document.get("exceededTransferLimit") or len(rows) != 4
            or {f.get("properties", {}).get("CTRY24CD") for f in rows} != set(ONS_CODES)):
        raise ValueError("ONS country geometry does not contain the four exact original constituent-country identities")
    return {**receipt, "id": "ons-CTRY24-UK-BGC", "country": "GB", "source_type": "ons-countries-2024",
            "kind": "region", "unit_type": "Constituent country", "admin_level": None,
            "cache_file": relative, "date": "2024-12", "retrieved": "2026-11-09",
            "source_unit_count": len(rows), "expected_unit_count": 4, "declared_unit_count": 4,
            "original_country_names_codes": ONS_CODES, "metadata_url": definitions[0][1],
            "product_url": "https://www.arcgis.com/home/item.html?id=" + ONS_ITEM,
            "license": "Open Government Licence v3.0", "license_url": "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
            "attribution": "Source: Office for National Statistics licensed under the Open Government Licence v.3.0; Contains OS data © Crown copyright and database right 2024",
            "original_attribution": item.get("accessInformation", ""), "original_license_info": item["licenseInfo"],
            "input_files": inputs, "scope_countries": ["GB"], "replace_natural_earth_kinds": ["region"],
            "administrative_geometry_eligible": True,
            "unit_semantics": {"render_role": "region", "source_unit_type": "Constituent country",
                               "coverage_status": "Four original UK constituent-country boundaries; no England statistical regions or country/district renaming",
                               "geometry_resolution": "ONS BGC20m, coast clipped at Mean High Water mark"}}


def _geometry(feature: dict):
    if not isinstance(feature.get("geometry"), dict):
        raise ValueError("Regional source has no original polygon geometry")
    geometry = shapely.make_valid(shape(feature["geometry"]))
    if geometry.geom_type == "GeometryCollection":
        geometry = shapely.unary_union([g for g in shapely.get_parts(geometry) if g.geom_type in ("Polygon", "MultiPolygon")])
    if geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty or geometry.area <= 0:
        raise ValueError("Regional source is not a nonempty polygonal area")
    x0, y0, x1, y1 = geometry.bounds
    if not all(math.isfinite(v) for v in geometry.bounds) or not (-180 <= x0 <= x1 <= 180 and -90 <= y0 <= y1 <= 90):
        raise ValueError("Regional source is not longitude/latitude geometry")
    return geometry


def normalize_feature(feature: dict, source: dict) -> dict:
    properties = feature.get("properties") or {}
    country = source["country"]
    if source.get("source_type") == "ons-countries-2024":
        code, name = properties.get("CTRY24CD"), properties.get("CTRY24NM")
        if country != "GB" or code not in ONS_CODES or name != ONS_CODES[code]:
            raise ValueError("ONS row is not a verified constituent country code/name")
        identifier, unit_type = "ons:GB:country:" + code, "Constituent country"
    else:
        if (properties.get("shapeGroup") != source["country_iso3"]
                or properties.get("shapeType") != f"ADM{source['admin_level']}"):
            raise ValueError("Regional feature belongs to another country or source ADM role")
        code, name = properties.get("shapeID"), properties.get("shapeName")
        if code is None or str(code) == "":
            raise ValueError("Regional source has no original stable feature identifier")
        identifier = f"gbOpen:{source['country_iso3']}:ADM{source['admin_level']}:{code}"
        unit_type = source["unit_type"]
        if country == "FR" and name == "Corse":
            unit_type = "Collectivité de Corse"
        if country == "ES":
            unit_type = "Ciudad autónoma" if name in ("Ciudad Autónoma de Ceuta", "Ciudad Autónoma de Melilla") else "Comunidad autónoma"
    if not isinstance(name, str) or not name.strip():
        raise ValueError("Regional source lacks its reviewed original regional name")
    return {"country": country, "id": identifier, "name": name, "name_known": True, "original_name": name,
            "kind": "region", "geometry": _geometry(feature), "parent_id": "country:" + country,
            "source": source["id"], "admin_level": source.get("admin_level"), "unit_type": unit_type,
            "source_unit_code": str(code), "original_properties": properties}


def iter_boundaries(cache: Path, sources: list[dict]) -> Iterator[dict]:
    for source in sources:
        path = Path(cache) / source["cache_file"]
        verify_source(path, source)
        for dependency in source.get("input_files", []):
            verify_source(Path(cache) / dependency["cache_file"], dependency)
        document = json.loads(path.read_text(encoding="utf-8"))
        rows = document.get("features")
        if document.get("type") != "FeatureCollection" or not isinstance(rows, list) or len(rows) != source["expected_unit_count"]:
            raise ValueError("Regional source count or original FeatureCollection changed")
        seen = set()
        for feature in rows:
            row = normalize_feature(feature, source)
            if row["id"] in seen:
                raise ValueError("Duplicate original regional identifier")
            seen.add(row["id"])
            yield row


def prepare_sources(cache: Path) -> list[dict]:
    cache = Path(cache)
    metadata = json.loads((cache / "coverage-metadata.json").read_text(encoding="utf-8"))
    sources = [_prepare_one(cache, select_source(metadata, country)) for country in DEFINITIONS]
    sources.append(_prepare_ons(cache))
    # Admission also validates the real original feature roles and geometry.
    list(iter_boundaries(cache, sources))
    _write_json(ROOT / "data/atlas_regional_sources.json", {"schema": 1, "review_date": "2026-11-09", "sources": sources,
        "scope": "Verified upper regional units; replacement applies only to Natural Earth kind=region, never district or municipality",
        "unadmitted": {"GB_gbOpen_ADM1": "Eurostat/GISCO-derived source excluded despite a generic CC-BY metadata label; original ONS country boundaries used instead"}})
    return sources


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    args = parser.parse_args()
    sources = prepare_sources(args.cache)
    print(json.dumps({s["country"]: {"units": s["source_unit_count"], "date": s["date"], "license": s["license"]} for s in sources}, ensure_ascii=False))
