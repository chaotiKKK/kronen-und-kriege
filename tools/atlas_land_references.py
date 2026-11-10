"""Independent land outlines for auditing local administrative boundaries.

LI is a separate official swisstopo national-boundary product. SM is an
enclosed hole in independently sourced Italian ISTAT polygons. AX combines
physical SYKE islands with a separate official MML regional boundary.
FO uses the independent Faroese Environment Agency physical island layer.
No reference is the union of the target country's imported municipalities.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import unicodedata
import zipfile
from urllib.parse import urlencode

import shapely
from shapely.geometry import Point, box, mapping, shape
from shapely.ops import unary_union
from shapely.ops import transform

from atlas_communal_sources import (_download_cached, _prepare_one, _write_json,
                                   select_source, sha256_file, verify_source)
from atlas_administration import _equal_area

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
SWISS_LAYER = "ch.swisstopo.swissboundaries3d-land-flaeche.fill"
SWISS_URL = "https://api3.geo.admin.ch/rest/services/ech/MapServer/identify?" + urlencode({
    "geometryType": "esriGeometryPoint", "geometry": "9.55,47.15", "sr": 4326,
    "layers": "all:" + SWISS_LAYER, "imageDisplay": "1000,1000,96",
    "mapExtent": "9.45,47.0,9.65,47.3", "tolerance": 0,
    "returnGeometry": "true", "geometryFormat": "geojson"})
SM_EXTENT = (12.2, 43.7, 12.7, 44.2)
SM_SEED = (12.45, 43.94)
MML_BASE = "https://boileri.nic.funet.fi/pub/sci/geo/geodata/mml/hallintorajat_10k/2025/"
SYKE_WFS = "https://paikkatiedot.ymparisto.fi/geoserver/syke_rantaviiva/wfs?"
LU_METADATA = "https://data.public.lu/api/1/datasets/limites-administratives-du-grand-duche-de-luxembourg/"
LU_PORTAL = "https://data.public.lu/en/datasets/limites-administratives-du-grand-duche-de-luxembourg/"
LU_ZIP = "https://download.data.public.lu/resources/limites-administratives-du-grand-duche-de-luxembourg/20261105-042000/limadmin-shp.zip"
LU_CODES = "https://download.data.public.lu/resources/limites-administratives-du-grand-duche-de-luxembourg/20240709-164127/commune-canton-district-circonscription-arrondissements.csv"
LU_NATIVE_CODES = "https://download.data.public.lu/resources/limites-administratives-du-grand-duche-de-luxembourg/20251021-085328/liste-communes-sections.csv"
FO_LAYER = "https://gis.us.fo/arcgis/rest/services/lendiskort/us_lendiskort/MapServer/15"
FO_TERMS = "https://www.foroyakort.fo/um-foeroyakort/terms-and-conditions-in-english"
FO_QUERY = FO_LAYER + "/query?" + urlencode({
    "where": "1=1", "outFields": "OBJECTID,name,feature_id,feature_type,imported_from_usgis,collection_date,modified_date",
    "returnGeometry": "true", "outSR": 4326, "orderByFields": "OBJECTID", "f": "geojson"})
EE_PORTAL = "https://geoportaal.maaruum.ee/est/Ruumiandmed/Haldus-ja-asustusjaotus-p119.html"
EE_TERMS = "https://kataster.ee/sites/default/files/documents/2024-03/MTP_andmeteenuste_kasutustingimused.pdf"
EE_COUNTIES_URL = "https://s3.pilw.io/rp-kemit-kataster/EHAK/maakond_shp.zip"
EE_PHYSICAL_URL = "https://s3.pilw.io/rp-kemit-kataster/EHAK/eesti_mask_json.zip"
EE_COUNTY_CODES = ("0037", "0039", "0045", "0050", "0052", "0056", "0060", "0064", "0068",
                   "0071", "0074", "0079", "0081", "0084", "0087")
EEA_COAST_LAYER = "https://marine.discomap.eea.europa.eu/arcgis/rest/services/Marine/EEA_coastline_2017/MapServer/0"
EEA_COAST_METADATA = "https://sdi.eea.europa.eu/catalogue/eea-statistical-data/api/records/9faa6ea1-372a-4826-a3c7-fb5b05e31c52"
CHANNEL_FRAMES = {"GG": (270009, 69), "JE": (367988, 53)}
CHANNEL_SNAPSHOT = "2026-11-08T21:21:00Z"
CHANNEL_ISLAND_LIMIT_M2 = 500_000_000
CHANNEL_QUERY = {"geometry": "-2.8,48.8,-1.8,49.9", "geometryType": "esriGeometryEnvelope", "inSR": 4326,
                 "outFields": "FID,OBJECTID,Id,Shape_Area"}
DETAILED_FRAMES = {"AM": (364066, 441), "IL": (1473946, 345)}
DETAILED_ARCHIVES = {"AM": "https://download.geofabrik.de/asia/armenia-261108-free.shp.zip",
                     "IL": "https://download.geofabrik.de/asia/israel-and-palestine-261108-free.shp.zip"}
ACTUAL_WATER_CLASSES = {"water": 8200, "reservoir": 8201, "riverbank": 8202, "dock": 8203}
DETAILED_DIRECTORY = "audit/AM-KZ-IL-20261110/"
NE_LAND_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_land.geojson"
NE_COUNTRIES_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson"


def _area(geometry):
    geometry = shapely.make_valid(geometry)
    if geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty or geometry.area <= 0:
        raise ValueError("Independent country reference is not a nonempty polygonal area")
    x0, y0, x1, y1 = geometry.bounds
    if not all(math.isfinite(v) for v in geometry.bounds) or not (-180 <= x0 <= x1 <= 180 and -90 <= y0 <= y1 <= 90):
        raise ValueError("Independent country reference is not longitude/latitude geometry")
    return geometry


def swiss_liechtenstein(document: dict):
    matches = [row for row in document.get("results", [])
               if row.get("featureId") == "LI" and row.get("layerBodId") == SWISS_LAYER]
    if len(matches) != 1 or not isinstance(matches[0].get("geometry"), dict):
        raise ValueError("Official response does not uniquely identify Liechtenstein's national boundary")
    return _area(shape(matches[0]["geometry"]))


def derive_san_marino_enclave(italian_geometries, *, source_country: str):
    if source_country != "IT":
        raise ValueError("San Marino's reference must come from independent Italian country-side data")
    extent = box(*SM_EXTENT)
    seed = Point(*SM_SEED)
    neighbours = [shapely.make_valid(geometry).intersection(extent) for geometry in italian_geometries
                  if geometry.intersects(extent)]
    remainder = extent.difference(unary_union(neighbours))
    matches = [part for part in shapely.get_parts(remainder)
               if part.geom_type == "Polygon" and part.contains(seed)]
    if len(matches) != 1 or matches[0].intersects(extent.boundary):
        raise ValueError("The independent Italian coverage does not enclose a unique San Marino hole")
    return _area(matches[0])


def aland_territorial_frame(document: dict):
    matches = [row for row in document.get("features", [])
               if (row.get("properties") or {}).get("NATCODE") == "21"]
    if len(matches) != 1:
        raise ValueError("The independent regional product does not uniquely identify Åland region 21")
    properties = matches[0]["properties"]
    if properties.get("NAMEFIN") != "Ahvenanmaa" or properties.get("NAMESWE") != "Åland":
        raise ValueError("The independent regional identity has unexpected official names")
    return _area(shape(matches[0]["geometry"]))


def derive_aland_land(island_geometries, territorial_frame, *, coastline_source: str, territorial_source: str):
    if coastline_source != "SYKE:Ranta10_merisaari" or territorial_source != "MML:maakunta2025_10k":
        raise ValueError("Åland's denominator requires independent physical coastline and a regional territorial frame")
    pieces = []
    for geometry in island_geometries:
        geometry = _area(geometry)
        if geometry.intersects(territorial_frame):
            clipped = geometry.intersection(territorial_frame)
            if clipped.area > 0:
                pieces.append(clipped)
    return _area(unary_union(pieces))


def validate_wfs_pages(pages: list[dict]) -> list[dict]:
    result, ids, total = [], set(), None
    for page in pages:
        matched = page.get("numberMatched")
        if not isinstance(matched, int) or matched < 1 or (total is not None and matched != total):
            raise ValueError("WFS result count is absent, empty or changed between pages")
        total = matched
        features = page.get("features")
        if page.get("type") != "FeatureCollection" or not isinstance(features, list) or page.get("numberReturned") != len(features):
            raise ValueError("WFS returned count does not match its actual feature page")
        for feature in features:
            identity = feature.get("id")
            if not isinstance(identity, str) or not identity or identity in ids:
                raise ValueError("WFS pages have missing or duplicate source feature identities")
            ids.add(identity)
            result.append(feature)
    if total is None or len(result) != total:
        raise ValueError("WFS pages do not cover the complete declared source selection")
    return result


def _download_binary(url: str, path: Path, max_bytes: int = 8*1024*1024, *, user_agent: str | None = None) -> dict:
    receipt_path = path.with_suffix(path.suffix + ".receipt.json")
    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if receipt.get("url") != url:
            raise ValueError("Changed source URL for a cached independent regional product")
        verify_source(path, receipt)
        return receipt
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".partial")
    command = ["curl.exe", "--fail", "--location", "--silent", "--show-error",
               "--max-filesize", str(max_bytes), "--connect-timeout", "20",
               "--max-time", "90", "--output", str(temporary)]
    if user_agent:
        command.extend(["--user-agent", user_agent])
    subprocess.run([*command, url], check=True)
    receipt = {"url": url, "bytes": temporary.stat().st_size, "sha256": sha256_file(temporary)}
    temporary.replace(path)
    _write_json(receipt_path, receipt)
    return receipt


def _mml_region(cache: Path):
    dependencies = ROOT / ".tools/atlas_land_deps"
    if str(dependencies) not in sys.path:
        sys.path.insert(0, str(dependencies))
    try:
        import shapefile
        import pyproj
    except ImportError as error:
        raise RuntimeError("Install pyproj==3.7.2 and pyshp==2.3.1 into .tools/atlas_land_deps") from error
    stem = "SuomenMaakuntajako_2025_10k"
    files = []
    for extension in ("shp", "shx", "dbf", "prj"):
        relative = "land-references/mml-2025-region/" + stem + "." + extension
        receipt = _download_binary(MML_BASE + stem + "." + extension, cache / relative)
        files.append({**receipt, "cache_file": relative})
    prj = (cache / files[3]["cache_file"]).read_text(encoding="utf-8")
    crs = pyproj.CRS.from_wkt(prj)
    if crs.to_epsg() != 3067:
        raise ValueError("Independent MML regional data have an unreviewed projection")
    project = pyproj.Transformer.from_crs(crs, 4326, always_xy=True).transform
    encoding = mml_dbf_encoding((cache / files[2]["cache_file"]).read_bytes()[:32])
    reader = shapefile.Reader(str(cache / "land-references/mml-2025-region" / stem), encoding=encoding)
    fields = [row[0] for row in reader.fields[1:]]
    matches = []
    for record in reader.iterShapeRecords():
        properties = dict(zip(fields, record.record))
        if properties.get("NATCODE") == "21":
            geometry = transform(project, shape(record.shape.__geo_interface__))
            matches.append({"type": "Feature", "properties": properties, "geometry": mapping(geometry)})
    frame = aland_territorial_frame({"features": matches})
    return frame, files, {"pyproj": pyproj.__version__, "pyshp": shapefile.__version__}


def mml_dbf_encoding(header: bytes) -> str:
    # dBASE language-driver 0x03 declares Windows ANSI; do not silently ignore
    # decoding failures or replace Åland's official Swedish characters.
    if len(header) < 30 or header[29] != 0x03:
        raise ValueError("Unreviewed MML dBASE language-driver encoding")
    return "cp1252"


def _prepare_aland(cache: Path) -> dict:
    derived_receipt = cache / "land-references/AX-independent-source.json"
    if derived_receipt.exists():
        source = json.loads(derived_receipt.read_text(encoding="utf-8"))
        if source.get("id") != "syke-physical-land-AX-MML2025" or source.get("derivation_version") != 1:
            raise ValueError("Unreviewed cached Åland land-derivation version")
        _validate_aland_source(source)
        verify_source(cache / source["cache_file"], source)
        for dependency in source["input_files"]:
            verify_source(cache / dependency["cache_file"], dependency)
        return source
    frame, frame_files, versions = _mml_region(cache)
    x0, y0, x1, y1 = frame.bounds
    # Round outward so the WFS selection cannot silently trim a boundary island.
    extent = (math.floor(x0*1e6)/1e6, math.floor(y0*1e6)/1e6,
              math.ceil(x1*1e6)/1e6, math.ceil(y1*1e6)/1e6)
    if not (18 < extent[0] < extent[2] < 23 and 58 < extent[1] < extent[3] < 62):
        raise ValueError("Independent Åland frame left the reviewed bounded coastline query")
    page_size = 2000
    pages, files = [], list(frame_files)
    expected = None
    start = 0
    while expected is None or start < expected:
        params = {"service": "WFS", "version": "2.0.0", "request": "GetFeature",
            "typeNames": "syke_rantaviiva:Ranta10_merisaari", "srsName": "EPSG:4326",
            "outputFormat": "application/json", "count": page_size, "startIndex": start,
            "sortBy": "objectid", "CQL_FILTER": "BBOX(geom," + ",".join(map(str, extent)) + ",'EPSG:4326')"}
        relative = f"land-references/syke-AX-islands/page-{start:05d}.json"
        receipt = _download_cached(SYKE_WFS + urlencode(params), cache / relative)
        with (cache / relative).open(encoding="utf-8-sig") as handle:
            page = json.load(handle)
        matched = page.get("numberMatched")
        if not isinstance(matched, int) or not 0 < matched <= 100000:
            raise ValueError("SYKE did not confirm a bounded, nonempty Åland island selection")
        if expected is None:
            expected = matched
        if matched != expected or page.get("numberReturned") != min(page_size, expected-start):
            raise ValueError("SYKE changed the declared count or truncated a coastline page")
        pages.append(page)
        files.append({**receipt, "cache_file": relative})
        start += page_size
    features = validate_wfs_pages(pages)
    islands = []
    repaired = 0
    for feature in features:
        if not str(feature.get("id", "")).startswith("Ranta10_merisaari.") or not isinstance(feature.get("geometry"), dict):
            raise ValueError("SYKE returned an unreviewed island feature or missing geometry")
        geometry = shape(feature["geometry"])
        repaired += int(not geometry.is_valid)
        islands.append(geometry)
    land = derive_aland_land(islands, frame,
        coastline_source="SYKE:Ranta10_merisaari", territorial_source="MML:maakunta2025_10k")
    relative = "land-references/AX-SYKE-physical-islands-MML-region2025.geojson"
    _write_json(cache / relative, mapping(land))
    area = _equal_area(land).area / 1_000_000
    if not 1300 < area < 1800:
        raise ValueError(f"Independent physical Åland coastline has an implausible measured area: {area} km²")
    source = {"id": "syke-physical-land-AX-MML2025", "country": "AX", "source_type": "aland-physical-coastline",
        "derivation_version": 1,
        "cache_file": relative, "bytes": (cache / relative).stat().st_size,
        "sha256": sha256_file(cache / relative), "url": SYKE_WFS.rstrip("?"),
        "date": "SYKE Ranta10 (MML topographic basis 2000–2008), coastal package 2025; MML region 2025-01-01",
        "license": "CC BY 4.0 (SYKE coastline and MML administrative regional frame)",
        "license_url": "https://creativecommons.org/licenses/by/4.0/",
        "license_evidence_url": "https://metatieto.ymparisto.fi/geonetwork/srv/api/records/%7BC40D8B4A-DC66-4822-AF27-7B382D89C8ED%7D",
        "attribution": "Finnish Environment Institute (Syke), Ranta10 Shoreline 1:10,000; National Land Survey of Finland (Maanmittauslaitos), topographic coastline and Administrative Areas 1:10,000, 2025. Åland coastal land derived by intersecting physical sea-island polygons with the separate official regional boundary.",
        "product_url": "https://www.syke.fi/en/environmental-data/downloadable-spatial-datasets",
        "metadata_url": "https://www.maanmittauslaitos.fi/kartat-ja-paikkatieto/aineistot-ja-rajapinnat/tuotekuvaukset/hallinnolliset-aluejaot-vektori",
        "additional_license_urls": ["https://www.maanmittauslaitos.fi/en/opendata-licence-cc40",
                                    "https://www.syke.fi/en/environmental-data/use-license-and-responsibilities"],
        "reference_role": "physical coastal land, independent of tested municipality boundaries",
        "territorial_frame": {"product": "SuomenMaakuntajako_2025_10k", "NATCODE": "21",
            "NAMEFIN": "Ahvenanmaa", "NAMESWE": "Åland", "includes_marine_area": True,
            "marine_and_land_area_km2": _equal_area(frame).area / 1_000_000,
            "note": "Only a territorial membership frame; never used as the land denominator by itself"},
        "coastline_product": "syke_rantaviiva:Ranta10_merisaari", "input_files": files,
        "input_bytes": sum(row["bytes"] for row in files), "source_feature_count": len(features),
        "page_size": page_size, "page_count": len(pages), "query_bbox": list(extent),
        "geometry_repaired_count": repaired, "tool_versions": versions,
        "reference_area_km2": area, "independent_of_target_municipalities": True,
        "derivation": "Union of independently supplied SYKE physical sea-island polygons intersected with official MML regional feature 21; no StatFi kunta1000k features or municipal-target union are read",
        "limitation": "Physical coastline has an older topographic basis; the coastal footprint can include inland freshwater within an island and is not an asserted current legal/ellipsoidal land-area figure"}
    _write_json(derived_receipt, source)
    return source


def _validate_aland_source(source: dict) -> None:
    frame = source.get("territorial_frame", {})
    if (source.get("country") != "AX" or source.get("coastline_product") != "syke_rantaviiva:Ranta10_merisaari"
            or frame.get("product") != "SuomenMaakuntajako_2025_10k" or frame.get("NATCODE") != "21"
            or not source.get("independent_of_target_municipalities") or not source.get("input_files")):
        raise ValueError("Åland's reference is not the reviewed independent coastline/regional combination")


def luxembourg_national_outline(document: dict, *, source_layer: str):
    if source_layer != "LIMADM_PAYS" or len(document.get("features", [])) != 1:
        raise ValueError("Luxembourg's reference requires the separate, unique official national feature")
    geometry = _area(shape(document["features"][0]["geometry"]))
    if not geometry.contains(Point(6.13, 49.61)):
        raise ValueError("Official Luxembourg national feature does not contain its documented capital")
    return geometry


def luxembourg_commune_codes(text: str) -> dict[str, str]:
    result = {}
    for row in csv.DictReader(text.lstrip("\ufeff").splitlines()):
        code, name = row.get("CODE_LAU2"), row.get("COMMUNE")
        if not isinstance(code, str) or not re.fullmatch(r"\d{4}", code) or not isinstance(name, str) or not name.strip():
            raise ValueError("Official ACT municipal list contains an invalid LAU code or name")
        if code in result:
            raise ValueError("Official ACT municipal list duplicates a LAU code")
        result[code] = unicodedata.normalize("NFC", name.strip())
    if not result:
        raise ValueError("Official ACT municipal code list is empty")
    return result


def luxembourg_source_epsg(wkt: str) -> int:
    # ACT declares 2169 both in its product metadata and in the original PRJ.
    # Its older Luxembourg_1930 datum label is not an invitation to let PROJ
    # choose a zero-shift ballpark transformation for an unrecognised datum.
    if not re.search(r'AUTHORITY\["EPSG",\s*"?2169"?\]\s*\]$', wkt.strip(), re.I):
        raise ValueError("ACT projection does not declare the reviewed EPSG:2169 reference")
    required = {"False_Easting": 80000, "False_Northing": 100000, "Central_Meridian": 6+1/6,
                "Scale_Factor": 1, "Latitude_Of_Origin": 49+5/6}
    if 'PROJECTION["Transverse_Mercator"]' not in wkt or 'SPHEROID["International_1924",6378388.0,297.0]' not in wkt:
        raise ValueError("ACT projection or ellipsoid differs from the declared Luxembourg TM product")
    for name, expected in required.items():
        match = re.search(r'PARAMETER\["'+name+r'",([\d.eE+-]+)\]', wkt)
        if match is None or not math.isclose(float(match[1]), expected, rel_tol=0, abs_tol=1e-8):
            raise ValueError("ACT projection parameters differ from the reviewed EPSG:2169 product")
    return 2169


def luxembourg_product(cache: Path, layer: str) -> tuple[dict, dict]:
    if layer not in ("LIMADM_COMMUNES", "LIMADM_PAYS", "LIMADM_CANTONS"):
        raise ValueError("Unreviewed ACT role; historical districts and cadastral units are not imported")
    cache = Path(cache)
    metadata_relative = "official/LU-portal-metadata.json"
    metadata_receipt = _download_cached(LU_METADATA, cache / metadata_relative)
    metadata = json.loads((cache / metadata_relative).read_text(encoding="utf-8"))
    if metadata.get("license") != "cc-zero" or metadata.get("organization", {}).get("id") != "56f54c310d6ceb552837f07c":
        raise ValueError("Luxembourg source is not the reviewed ACT/CC0 government product")
    archive_relative = "official/LU/limadmin-20261105.zip"
    archive_receipt = _download_binary(LU_ZIP, cache / archive_relative, max_bytes=16*1024*1024)
    advertised = [r for r in metadata["resources"] if r.get("url") == LU_ZIP]
    if len(advertised) != 1 or archive_receipt["bytes"] != advertised[0]["filesize"]:
        raise ValueError("ACT archive differs from its original government's dated resource")
    deps = ROOT / ".tools/atlas_land_deps"
    if str(deps) not in sys.path:
        sys.path.insert(0, str(deps))
    import shapefile
    import pyproj
    members, payloads = [], {}
    with zipfile.ZipFile(cache / archive_relative) as archive:
        for extension in ("shp", "shx", "dbf", "prj", "cpg"):
            name = layer + "." + extension
            if archive.namelist().count(name) != 1:
                raise ValueError("ACT national/municipal layer has missing or ambiguous components")
            member = archive.getinfo(name)
            payload = archive.read(member)  # Original ZIP CRC is checked here.
            payloads[extension] = payload
            members.append({"name": name, "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest(),
                            "crc32": f"{member.CRC:08x}"})
    if payloads["cpg"].decode("ascii").strip().upper() != "UTF-8":
        raise ValueError("ACT source changed its declared Unicode encoding")
    epsg = luxembourg_source_epsg(payloads["prj"].decode("utf-8"))
    project = pyproj.Transformer.from_crs(epsg, 4326, always_xy=True, allow_ballpark=False, only_best=True)
    reader = shapefile.Reader(shp=io.BytesIO(payloads["shp"]), shx=io.BytesIO(payloads["shx"]),
                              dbf=io.BytesIO(payloads["dbf"]), encoding="utf-8")
    fields = [row[0] for row in reader.fields[1:]]
    features = [{"type": "Feature", "properties": dict(zip(fields, record.record)),
                 "geometry": mapping(transform(project.transform, shape(record.shape.__geo_interface__)))}
                for record in reader.iterShapeRecords()]
    used_operation = project.get_last_used_operation()
    provenance = {"input_files": [{**metadata_receipt, "cache_file": metadata_relative},
                                   {**archive_receipt, "cache_file": archive_relative}],
                  "zip_members": members, "source_layer": layer, "source_crs": epsg,
                  "source_date": "2026-11-05", "license": "CC0 1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                  "metadata_url": LU_METADATA, "product_url": LU_PORTAL,
                  "attribution": "Administration du cadastre et de la topographie (ACT), Grand-Duché de Luxembourg; Limites administratives, 2026-11-05; CC0 1.0",
                  "coordinate_transformation": used_operation.description, "transformation_accuracy_metres": used_operation.accuracy,
                  "crs_note": "Original PRJ's historical Luxembourg_1930 label resolved through its explicit EPSG2169 declaration and checked TM/ellipsoid parameters; no ballpark datum transformation allowed",
                  "tool_versions": {"pyproj": pyproj.__version__, "pyshp": shapefile.__version__}}
    return {"type": "FeatureCollection", "features": features}, provenance


def prepare_luxembourg_reference(cache: Path) -> dict:
    document, provenance = luxembourg_product(cache, "LIMADM_PAYS")
    geometry = luxembourg_national_outline(document, source_layer=provenance["source_layer"])
    relative = "land-references/LU-ACT-national-20261105.geojson"
    _write_json(cache / relative, mapping(geometry))
    return {**provenance, "id": "act-national-LU-20261105", "country": "LU",
            "source_type": "act-national-geojson", "cache_file": relative,
            "bytes": (cache / relative).stat().st_size, "sha256": sha256_file(cache / relative),
            "url": LU_ZIP, "date": "2026-11-05", "reference_area_km2": _equal_area(geometry).area/1e6,
            "independent_of_target_municipalities": True,
            "derivation": "Original separate ACT LIMADM_PAYS national feature projected from explicitly declared EPSG2169; no municipal union, no historical district or cadastral layer"}


def faroe_physical_land(document: dict, metadata: dict, *, declared_count: int):
    if (metadata.get("id") != 15 or metadata.get("name") != "Oyggjar"
            or metadata.get("geometryType") != "esriGeometryPolygon"):
        raise ValueError("Faroese physical land requires the separate reviewed Oyggjar layer, not municipalities or sea")
    features = document.get("features")
    if (document.get("type") != "FeatureCollection" or not isinstance(features, list)
            or not isinstance(declared_count, int) or declared_count <= 0 or len(features) != declared_count):
        raise ValueError("Faroese island result does not contain the complete declared source feature count")
    identifiers, geometries = set(), []
    for feature in features:
        identity = feature.get("id")
        if identity is None or identity in identifiers or not isinstance(feature.get("geometry"), dict):
            raise ValueError("Faroese physical islands have absent/duplicate identities or missing original geometry")
        if feature.get("properties", {}).get("OBJECTID") != identity:
            raise ValueError("Faroese physical feature identity differs from its original OBJECTID")
        identifiers.add(identity)
        geometries.append(_area(shape(feature["geometry"])))
    return _area(unary_union(geometries))


def prepare_faroe_reference(cache: Path) -> dict:
    # Retain the already reviewed raw research cache; no second large download.
    directory = "audit/fo-physical-2026/"
    definitions = [("metadata.json", FO_LAYER + "?f=pjson"),
                   ("count.json", FO_LAYER + "/query?where=1%3D1&returnCountOnly=true&f=pjson"),
                   ("islands.geojson", FO_QUERY)]
    inputs, documents = [], {}
    for name, url in definitions:
        relative = directory + name
        receipt = _download_cached(url, cache / relative)
        inputs.append({**receipt, "cache_file": relative})
        documents[name] = json.loads((cache / relative).read_text(encoding="utf-8"))
    relative = directory + "license-public.html"
    terms = _download_binary(FO_TERMS, cache / relative, user_agent="Mozilla/5.0")
    inputs.append({**terms, "cache_file": relative})
    geometry = faroe_physical_land(documents["islands.geojson"], documents["metadata.json"],
                                  declared_count=documents["count.json"].get("count"))
    relative = "land-references/FO-US-physical-islands-20261109.geojson"
    _write_json(cache / relative, mapping(geometry))
    return {"id": "us-physical-islands-FO-20261109", "country": "FO", "source_type": "faroe-physical-islands",
            "source_layer": "lendiskort/us_lendiskort/15", "url": FO_QUERY,
            "metadata_url": FO_LAYER + "?f=pjson", "product_url": "https://www.foroyakort.fo/vevtaenastur",
            "cache_file": relative, "bytes": (cache / relative).stat().st_size, "sha256": sha256_file(cache / relative),
            "date": "2026-11-09", "date_role": "retrieval date; service does not declare a fixed dataset release",
            "original_feature_count": len(documents["islands.geojson"]["features"]), "input_files": inputs,
            "license": "Faroese Environment Agency free maps/data terms, June 2019", "license_url": FO_TERMS,
            "attribution": "Data from the Faroese Environment Agency, Umhvørvisstovan: Lendiskort — Oyggjar; downloaded 2026-11-09",
            "license_conditions": "Worldwide copying, distribution, modification and commercial use permitted; credit agency, dataset and download date, retain terms link, no endorsement or nautical navigation; front-page agency credit when other sources are credited there",
            "independent_of_target_municipalities": True,
            "reference_area_km2": _equal_area(geometry).area/1e6,
            "derivation": "All 34 original Oyggjar physical island polygons unioned; no municipal geometry, marine boundary or Natural Earth clipping used",
            "limitations": "Original source names contain replacement characters; original bytes preserved. Names are not used to derive physical geometry. Small coast disagreements remain measured."}


def estonia_physical_land(county_features: list[dict], physical_mask, *, source_layer: str):
    if source_layer != "maakond" or len(county_features) != len(EE_COUNTY_CODES):
        raise ValueError("Estonia's national frame requires the separate complete 15-county product, not target municipalities")
    codes = [f.get("properties", {}).get("MKOOD") for f in county_features]
    if len(set(codes)) != len(codes) or set(codes) != set(EE_COUNTY_CODES):
        raise ValueError("Estonia's independent county frame has missing, duplicated or unreviewed official EHAK codes")
    country = unary_union([_area(shape(f["geometry"])) for f in county_features])
    return _area(country.intersection(_area(physical_mask)))


def _validate_estonia_source(source: dict):
    if (source.get("country") != "EE" or source.get("source_layer") != "maakond"
            or source.get("coastline_product") != "ETAK:eesti_mask"
            or set(source.get("county_codes", [])) != set(EE_COUNTY_CODES)
            or len(source.get("county_codes", [])) != len(EE_COUNTY_CODES)
            or not source.get("independent_of_target_municipalities") or not source.get("input_files")):
        raise ValueError("Estonian land reference requires independent physical coast and the complete reviewed county frame")


def estonia_source_epsg(wkt: str) -> int:
    # The original ESRI WKT declares a numeric AUTHORITY value that PROJ does
    # not identify confidently. Resolve only the explicit, checked definition.
    if (not re.search(r'AUTHORITY\["EPSG",\s*"?3301"?\]', wkt)
            or 'PROJECTION["Lambert_Conformal_Conic"]' not in wkt
            or 'DATUM["D_Estonia_1997"' not in wkt
            or not re.search(r'SPHEROID\["GRS_1980",\s*6378137\.0*,\s*298\.257222101\]', wkt)):
        raise ValueError("Estonian county projection is not the reviewed explicitly declared EST97/EPSG3301 definition")
    required = {"False_Easting": 500000.0, "False_Northing": 6375000.0, "Central_Meridian": 24.0,
                "Standard_Parallel_1": 58.0, "Standard_Parallel_2": 59.33333333333334,
                "Latitude_Of_Origin": 57.51755393055556}
    for name, expected in required.items():
        match = re.search(r'PARAMETER\["' + name + r'",([\d.eE+-]+)\]', wkt)
        if match is None or not math.isclose(float(match[1]), expected, rel_tol=0, abs_tol=1e-8):
            raise ValueError("Estonian source parameters differ from the reviewed EPSG3301 projection")
    return 3301


def prepare_estonia_reference(cache: Path) -> dict:
    derived = cache / "land-references/EE-independent-source.json"
    if derived.exists():
        source = json.loads(derived.read_text(encoding="utf-8"))
        if source.get("id") != "maaruum-physical-land-EE-20261101" or source.get("derivation_version") != 1:
            raise ValueError("Unreviewed cached Estonian reference derivation")
        _validate_estonia_source(source)
        verify_source(cache / source["cache_file"], source)
        for dependency in source["input_files"]:
            verify_source(cache / dependency["cache_file"], dependency)
        return source
    directory = "audit/ee-physical-2026/"
    inputs = []
    for filename, url, limit in [("maakond_shp.zip", EE_COUNTIES_URL, 16*1024*1024),
                                  ("eesti_mask_json.zip", EE_PHYSICAL_URL, 20*1024*1024),
                                  ("portal.html", EE_PORTAL, 2*1024*1024),
                                  ("terms.pdf", EE_TERMS, 2*1024*1024)]:
        relative = directory + filename
        receipt = _download_binary(url, cache / relative, max_bytes=limit, user_agent="Mozilla/5.0")
        inputs.append({**receipt, "cache_file": relative})
    if not (cache / (directory + "terms.pdf")).read_bytes().startswith(b"%PDF-"):
        raise ValueError("Estonian original public data-service conditions are not the reviewed PDF")
    deps = ROOT / ".tools/atlas_land_deps"
    if str(deps) not in sys.path:
        sys.path.insert(0, str(deps))
    import shapefile
    import pyproj
    members = []
    with zipfile.ZipFile(cache / (directory + "maakond_shp.zip")) as archive:
        payloads = {}
        for extension in ("shp", "shx", "dbf", "prj"):
            name = "maakond." + extension
            if archive.namelist().count(name) != 1:
                raise ValueError("Separate Estonian county product lacks unique original components")
            member = archive.getinfo(name)
            payloads[extension] = archive.read(member)
            members.append({"archive": "maakond_shp.zip", "name": name, "bytes": len(payloads[extension]),
                            "sha256": hashlib.sha256(payloads[extension]).hexdigest(), "crc32": f"{member.CRC:08x}"})
    epsg = estonia_source_epsg(payloads["prj"].decode("utf-8"))
    encoding = mml_dbf_encoding(payloads["dbf"][:32])  # The original DBF explicitly declares language driver 0x03.
    project = pyproj.Transformer.from_crs(epsg, 4326, always_xy=True, allow_ballpark=False, only_best=True)
    reader = shapefile.Reader(shp=io.BytesIO(payloads["shp"]), shx=io.BytesIO(payloads["shx"]),
                              dbf=io.BytesIO(payloads["dbf"]), encoding=encoding)
    fields = [f[0] for f in reader.fields[1:]]
    counties = []
    for record in reader.iterShapeRecords():
        properties = {k: v.isoformat() if hasattr(v, "isoformat") else v for k, v in zip(fields, record.record)}
        if properties.get("EKSPORT") != "2026-11-01":
            raise ValueError("Estonian county product changed its reviewed original export date")
        counties.append({"type": "Feature", "properties": properties,
                         "geometry": mapping(transform(project.transform, shape(record.shape.__geo_interface__)))})
    with zipfile.ZipFile(cache / (directory + "eesti_mask_json.zip")) as archive:
        if archive.namelist() != ["eesti_mask_json.json"]:
            raise ValueError("Estonian physical coastal mask has unexpected original archive members")
        member = archive.getinfo("eesti_mask_json.json")
        payload = archive.read(member)
        members.append({"archive": "eesti_mask_json.zip", "name": member.filename, "bytes": len(payload),
                        "sha256": hashlib.sha256(payload).hexdigest(), "crc32": f"{member.CRC:08x}"})
        mask = json.loads(payload)
    if (mask.get("name") != "eesti_mask" or mask.get("crs", {}).get("properties", {}).get("name") != "EPSG:3301"
            or len(mask.get("features", [])) != 1
            or mask["features"][0].get("properties", {}).get("eksport") != "19.11.2025"):
        raise ValueError("Physical Estonian mask identity, projection or original export date is not the reviewed product")
    physical = transform(project.transform, shape(mask["features"][0]["geometry"]))
    geometry = estonia_physical_land(counties, physical, source_layer="maakond")
    operation = project.get_last_used_operation()
    relative = "land-references/EE-MaaRuum-physical-land-20261101.geojson"
    _write_json(cache / relative, mapping(geometry))
    source = {"id": "maaruum-physical-land-EE-20261101", "country": "EE", "source_type": "estonia-physical-land",
              "source_layer": "maakond", "coastline_product": "ETAK:eesti_mask", "derivation_version": 1,
              "cache_file": relative, "bytes": (cache / relative).stat().st_size, "sha256": sha256_file(cache / relative),
              "url": EE_PHYSICAL_URL, "metadata_url": EE_PORTAL, "product_url": EE_PORTAL,
              "date": "2026-11-01", "retrieved": "2026-11-09", "physical_mask_export": "2025-11-19",
              "county_codes": sorted(f["properties"]["MKOOD"] for f in counties),
              "original_county_properties": [f["properties"] for f in counties],
              "original_physical_mask_properties": mask["features"][0]["properties"],
              "input_files": inputs, "zip_members": members,
              "license": "Maa- ja Ruumiamet public data-service terms (Maatoimingute platvorm), 2024-03",
              "license_url": EE_TERMS,
              "attribution": "Haldus- ja asustusjaotus: Maa- ja Ruumiamet 2026-11-01, Maakonnad; Eesti lõikemask, ETAK export 2025-11-19; downloaded 2026-11-09",
              "license_conditions": "Unrestricted public data may be used commercially and redistributed under section2.5; credit Maa- ja Ruumiamet and source date as stated by the official product portal",
              "source_crs": 3301, "source_encoding": encoding,
              "coordinate_transformation": operation.description, "transformation_accuracy_metres": operation.accuracy,
              "crs_note": "Original numeric EPSG3301 AUTHORITY and every projection/ellipsoid parameter checked explicitly; no low-confidence code inference or ballpark datum conversion",
              "tool_versions": {"pyproj": pyproj.__version__, "pyshp": shapefile.__version__},
              "independent_of_target_municipalities": True, "reference_area_km2": _equal_area(geometry).area/1e6,
              "derivation": "Separate complete 15-Maakond county product intersected with independent ETAK physical coastal clip mask; no target municipalities or Natural Earth geometry used",
              "limitations": "Physical mask alone includes neighbouring foreign land and is not a national boundary. Its original export2025-11-19 differs from county export2026-11-01; both dates preserved. Residual coast disagreement is measured, not filled."}
    _write_json(derived, source)
    return source


def channel_islands_country_frame(payload: dict, *, country: str):
    from atlas_osm_sources import full_geometry_relations, _member_lines, _closed_polygons
    if country not in CHANNEL_FRAMES:
        raise ValueError("Unreviewed Channel Islands national reference")
    identifier, version = CHANNEL_FRAMES[country]
    related = full_geometry_relations(payload, CHANNEL_SNAPSHOT)
    relation = related.get(identifier, {})
    tags = relation.get("tags", {})
    if (relation.get("version") != version or tags.get("ISO3166-1") != country
            or tags.get("admin_level") != "2" or tags.get("boundary") != "administrative"):
        raise ValueError("Channel Islands territorial frame lacks its reviewed original national ISO/level/version identity")
    outer, inner = _member_lines(relation, related)
    geometry = unary_union(_closed_polygons(outer, identifier, "outer"))
    if inner:
        geometry = geometry.difference(unary_union(_closed_polygons(inner, identifier, "inner")))
    return _area(geometry)


def channel_islands_physical_land(features: list[dict], territorial_frame, *, country: str):
    if country not in CHANNEL_FRAMES:
        raise ValueError("Physical island selection is reviewed only for GG and JE")
    seen, selected = set(), []
    for feature in features:
        identity = feature.get("id")
        if (identity is None or identity in seen or feature.get("properties", {}).get("FID") != identity
                or not isinstance(feature.get("geometry"), dict)):
            raise ValueError("EEA physical islands have absent/duplicate source identities or missing geometry")
        seen.add(identity)
        geometry = _area(shape(feature["geometry"]))
        if _equal_area(geometry).area >= CHANNEL_ISLAND_LIMIT_M2:
            raise ValueError("An unreviewed continental/large physical polygon entered the small-island source selection")
        if not geometry.intersects(territorial_frame):
            continue
        if not territorial_frame.covers(geometry):
            raise ValueError("A national frame cuts an original physical island: no partial coastline or continental chips admitted")
        selected.append(geometry)
    return _area(unary_union(selected))


def _validate_channel_source(source: dict):
    country = source.get("country")
    frame = source.get("territorial_frame", {})
    if (country not in CHANNEL_FRAMES or source.get("physical_product") != "EEA:coastline2017-v3"
            or frame.get("ISO3166-1") != country or frame.get("admin_level") != 2
            or frame.get("relation_id") != CHANNEL_FRAMES[country][0]
            or not source.get("independent_of_target_municipalities") or not source.get("input_files")):
        raise ValueError("Channel Islands reference requires independent physical EEA islands and a separate national frame")


def prepare_channel_islands_references(cache: Path) -> list[dict]:
    directory = "audit/channel-islands-physical-2026/"
    derived = cache / "land-references/channel-islands-independent-sources.json"
    if derived.exists():
        document = json.loads(derived.read_text(encoding="utf-8"))
        if document.get("derivation_version") != 1 or len(document.get("sources", [])) != 2:
            raise ValueError("Unreviewed cached Channel Islands reference derivation")
        for source in document["sources"]:
            _validate_channel_source(source)
            verify_source(cache / source["cache_file"], source)
            for dependency in source["input_files"]:
                verify_source(cache / dependency["cache_file"], dependency)
        return document["sources"]
    identities_query = {"where": "1=1", **CHANNEL_QUERY, "returnGeometry": "false", "f": "json"}
    physical_query = {"where": "Shape_Area<500000000", **CHANNEL_QUERY, "returnGeometry": "true",
                      "outSR": 4326, "orderByFields": "FID", "f": "geojson"}
    inputs, documents = [], {}
    for name, url in [("metadata.json", EEA_COAST_LAYER + "?f=pjson"),
                      ("bbox-identities.json", EEA_COAST_LAYER + "/query?" + urlencode(identities_query)),
                      ("physical-islands.geojson", EEA_COAST_LAYER + "/query?" + urlencode(physical_query))]:
        relative = directory + name
        receipt = _download_cached(url, cache / relative)
        inputs.append({**receipt, "cache_file": relative})
        documents[name] = json.loads((cache / relative).read_text(encoding="utf-8"))
    relative = directory + "EEA-metadata.html"
    receipt = _download_binary(EEA_COAST_METADATA, cache / relative, max_bytes=2*1024*1024, user_agent="Mozilla/5.0")
    inputs.append({**receipt, "cache_file": relative})
    metadata = documents["metadata.json"]
    if (metadata.get("id") != 0 or metadata.get("geometryType") != "esriGeometryPolygon"
            or metadata.get("name", "").strip() != "EEA coastline for analysis (polygon) - version 3.0, March 2017"):
        raise ValueError("Unreviewed EEA physical coastline layer")
    identities = documents["bbox-identities.json"]
    physical = documents["physical-islands.geojson"]
    if identities.get("exceededTransferLimit") or physical.get("exceededTransferLimit"):
        raise ValueError("EEA Channel Islands query is incomplete")
    expected = {r["attributes"]["FID"] for r in identities.get("features", [])
                if r["attributes"]["Shape_Area"] < CHANNEL_ISLAND_LIMIT_M2}
    features = physical.get("features", [])
    if (physical.get("type") != "FeatureCollection" or not expected or len(features) != len(expected)
            or {f.get("id") for f in features} != expected):
        raise ValueError("EEA physical query lost source features from its independently queried identity list")
    result = []
    for country, (identifier, version) in CHANNEL_FRAMES.items():
        relative = directory + country + "-country-full.json"
        receipt = _download_cached(f"https://api.openstreetmap.org/api/0.6/relation/{identifier}/full.json", cache / relative)
        country_input = {**receipt, "cache_file": relative}
        payload = json.loads((cache / relative).read_text(encoding="utf-8"))
        frame = channel_islands_country_frame(payload, country=country)
        geometry = channel_islands_physical_land(features, frame, country=country)
        relative = f"land-references/{country}-EEA-physical-islands-v3-2017.geojson"
        _write_json(cache / relative, mapping(geometry))
        feature_ids = [f["id"] for f in features if frame.covers(shape(f["geometry"]))]
        source = {"id": f"eea-physical-islands-{country}-v3-2017", "country": country,
                  "source_type": "eea-physical-islands", "physical_product": "EEA:coastline2017-v3",
                  "date": "2017-03-01", "retrieved": "2026-11-09", "date_role": "Physical coastline product publication; separate national-frame snapshot recorded below",
                  "url": EEA_COAST_LAYER, "metadata_url": EEA_COAST_METADATA, "product_url": EEA_COAST_METADATA,
                  "cache_file": relative, "bytes": (cache / relative).stat().st_size, "sha256": sha256_file(cache / relative),
                  "input_files": [*inputs, country_input], "source_feature_ids": feature_ids,
                  "source_feature_count": len(feature_ids), "reference_area_km2": _equal_area(geometry).area/1e6,
                  "territorial_frame": {"ISO3166-1": country, "admin_level": 2, "relation_id": identifier,
                                        "relation_version": version, "snapshot": CHANNEL_SNAPSHOT,
                                        "role": "national territorial assignment only; marine geometry is not land"},
                  "license": "CC BY 4.0 (EEA physical coastline); ODbL 1.0 (separate OSM national territorial reference)",
                  "license_url": "https://creativecommons.org/licenses/by/4.0/",
                  "license_layers": [{"scope": "physical coastline polygons", "license": "CC BY 4.0", "holder": "European Environment Agency (EEA)", "url": "https://creativecommons.org/licenses/by/4.0/"},
                                     {"scope": "national territorial assignment reference", "license": "ODbL 1.0", "holder": "OpenStreetMap contributors", "url": "https://opendatacommons.org/licenses/odbl/1-0/"}],
                  "attribution": "European Environment Agency (EEA), EEA coastline for analysis polygon v3, March 2017, CC BY 4.0; © OpenStreetMap contributors, national territorial reference, ODbL 1.0; downloaded 2026-11-09",
                  "independent_of_target_municipalities": True,
                  "derivation": "Whole original EEA physical island polygons wholly contained in a separately ISO-verified national OSM frame; no target municipal union and no island/continental clipping",
                  "limitations": "Physical source is a historical 2017 product at1:100000 scale. Residual shoreline differences are measured. National marine frames select membership only; they never supply physical land area."}
        result.append(source)
    _write_json(derived, {"derivation_version": 1, "sources": result})
    return result


def detailed_national_frame(payload: dict, *, country: str):
    from atlas_osm_sources import full_geometry_relations, _member_lines, _closed_polygons
    if country not in DETAILED_FRAMES:
        raise ValueError("Unreviewed detailed national reference")
    identifier, version = DETAILED_FRAMES[country]
    related = full_geometry_relations(payload, CHANNEL_SNAPSHOT)
    relation = related.get(identifier, {})
    tags = relation.get("tags", {})
    if (relation.get("version") != version or tags.get("ISO3166-1") != country
            or tags.get("admin_level") != "2" or tags.get("boundary") != "administrative"):
        raise ValueError("Detailed national frame lacks its original reviewed ISO/level/version identity")
    outer, inner = _member_lines(relation, related)
    geometry = unary_union(_closed_polygons(outer, identifier, "outer"))
    if inner:
        geometry = geometry.difference(unary_union(_closed_polygons(inner, identifier, "inner")))
    if not geometry.is_valid:
        raise ValueError("Original national frame is invalid; no boundary repair or guessed closing segment allowed")
    return _area(geometry)


def national_physical_land(national_frame, physical_land, water_features: list[dict], *, country: str):
    if country not in DETAILED_FRAMES:
        raise ValueError("Unreviewed detailed physical country")
    water = []
    for feature in water_features:
        properties = feature.get("properties") or {}
        category = properties.get("fclass")
        if category not in ACTUAL_WATER_CLASSES:
            continue  # Wetlands and glaciers are not open-water exclusions.
        if properties.get("code") != ACTUAL_WATER_CLASSES[category] or not isinstance(feature.get("geometry"), dict):
            raise ValueError("Physical-water source has conflicting original class/code or missing geometry")
        geometry = shape(feature["geometry"])
        if (geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.is_empty
                or not geometry.is_valid or geometry.area <= 0):
            raise ValueError("Original physical-water geometry is invalid; no buffer, snapping, repair or invented closure allowed")
        if geometry.intersects(national_frame):
            water.append(geometry)
    return _area(_area(national_frame).intersection(_area(physical_land)).difference(unary_union(water)))


def _physical_water_inputs(cache: Path, country: str):
    from atlas_geofabrik_sources import RangeSource, RemoteZip
    directory = DETAILED_DIRECTORY + country + "-water-stage/"
    folder = cache / directory
    receipt_path = folder / "receipt.json"
    if not receipt_path.exists():
        remote = RangeSource(folder, DETAILED_ARCHIVES[country])
        members = []
        with zipfile.ZipFile(RemoteZip(remote.snapshot["bytes"], remote.fetch)) as archive:
            names = ["gis_osm_water_a_free_1." + extension for extension in ("cpg", "dbf", "prj", "shp", "shx")]
            for name in [*names, "README"]:
                if archive.namelist().count(name) != 1:
                    raise ValueError("Reviewed physical-water archive lacks a unique original component")
                info = archive.getinfo(name)
                if info.file_size > 16*1024*1024:
                    raise ValueError("Physical-water original component exceeds the reviewed bounded size")
                payload = archive.read(info)  # Original ZIP CRC checked by zipfile.
                target = folder / "members" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                temporary = target.with_suffix(target.suffix + ".partial")
                temporary.write_bytes(payload)
                temporary.replace(target)
                item = {"name": name, "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest(), "crc32": f"{info.CRC:08x}"}
                if name == "README":
                    readme = item
                else:
                    members.append(item)
        _write_json(receipt_path, {"snapshot": remote.snapshot, "members": members, "readme": readme})
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt.get("snapshot", {}).get("url") != DETAILED_ARCHIVES[country]:
        raise ValueError("Physical-water source changed its reviewed original dated archive")
    wanted = {"gis_osm_water_a_free_1." + extension for extension in ("cpg", "dbf", "prj", "shp", "shx")}
    if {r.get("name") for r in receipt.get("members", [])} != wanted or len(receipt["members"]) != 5:
        raise ValueError("Physical-water archive components are incomplete or duplicated")
    inputs = []
    for item in [*receipt["members"], receipt["readme"]]:
        relative = directory + "members/" + item["name"]
        verify_source(cache / relative, item)
        inputs.append({**item, "cache_file": relative, "url": DETAILED_ARCHIVES[country]})
    readme_text = (folder / "members/README").read_text(encoding="utf-8")
    if "data as of " + CHANNEL_SNAPSHOT not in readme_text:
        raise ValueError("Original physical-water README does not match the fixed OSM snapshot")
    return inputs, receipt


def _validate_detailed_physical_source(source: dict):
    country = source.get("country")
    frame = source.get("national_frame", {})
    if (country not in DETAILED_FRAMES or source.get("physical_product") != "NaturalEarth:10m_land:v5.1.2"
            or source.get("water_product") != "Geofabrik:gis_osm_water_a_free"
            or frame.get("ISO3166-1") != country or frame.get("admin_level") != 2
            or (frame.get("relation_id"), frame.get("relation_version")) != DETAILED_FRAMES[country]
            or not source.get("independent_of_target_municipalities") or not source.get("input_files")):
        raise ValueError("Detailed physical land requires separate original national, physical-coast and physical-water products")


def _baseline_national_frame(document: dict, *, country: str):
    matches = [f for f in document.get("features", []) if country in (
        f.get("properties", {}).get("ISO_A2"), f.get("properties", {}).get("ISO_A2_EH"))]
    if country not in DETAILED_FRAMES or len(matches) != 1:
        raise ValueError("The original Natural Earth national reference is absent or ambiguous")
    if matches[0].get("properties", {}).get("ADMIN") != {"AM": "Armenia", "IL": "Israel"}[country]:
        raise ValueError("Natural Earth original ISO country and source name disagree")
    return _area(shape(matches[0]["geometry"]))


def conservative_physical_land(countries: dict, physical_land, water_features: list[dict], *, country: str):
    """Retain the project's territorial decision; correct only physical water."""
    frame = _baseline_national_frame(countries, country=country)
    return national_physical_land(frame, physical_land, water_features, country=country)


def _validate_conservative_physical_source(source: dict):
    country = source.get("country")
    frame = source.get("national_frame", {})
    if (country not in DETAILED_FRAMES or source.get("physical_product") != "NaturalEarth:10m_land:v5.1.2"
            or source.get("water_product") != "Geofabrik:gis_osm_water_a_free"
            or frame.get("ISO3166-1") != country or frame.get("product") != "NaturalEarth:admin0:v5.1.2"
            or frame.get("territorial_policy") != "original-reference-unchanged"
            or not source.get("independent_of_target_municipalities") or not source.get("input_files")):
        raise ValueError("Conservative physical reference must retain the original Natural Earth territorial assignment")


def prepare_detailed_physical_references(cache: Path) -> list[dict]:
    from collections import Counter
    from atlas_geofabrik_sources import _shapefile
    derived = cache / "land-references/AM-IL-NE-territorial-physical-sources-20261108.json"
    if derived.exists():
        document = json.loads(derived.read_text(encoding="utf-8"))
        if document.get("derivation_version") != 1 or len(document.get("sources", [])) != 2:
            raise ValueError("Unreviewed detailed national/physical reference derivation")
        for source in document["sources"]:
            _validate_conservative_physical_source(source)
            verify_source(cache / source["cache_file"], source)
            for dependency in source["input_files"]:
                verify_source(cache / dependency["cache_file"], dependency)
        return document["sources"]
    relative = DETAILED_DIRECTORY + "ne_10m_land-v5.1.2.geojson"
    land_receipt = {**_download_cached(NE_LAND_URL, cache / relative), "cache_file": relative}
    document = json.loads((cache / relative).read_text(encoding="utf-8"))
    if document.get("type") != "FeatureCollection" or not document.get("features"):
        raise ValueError("Independent global physical land product is missing")
    physical = _area(unary_union([_area(shape(f["geometry"])) for f in document["features"]]))
    # Reuse the exact baseline source without modifying the builder's cache.
    relative = "ne_10m_admin_0_countries.geojson"
    baseline_meta = cache / (relative + ".meta.json")
    if (cache / relative).exists() and baseline_meta.exists():
        country_receipt = json.loads(baseline_meta.read_text(encoding="utf-8"))
        if country_receipt.get("url") != NE_COUNTRIES_URL:
            raise ValueError("Project national baseline is not the reviewed Natural Earth release")
        verify_source(cache / relative, country_receipt)
    else:
        relative = DETAILED_DIRECTORY + "ne_10m_admin_0_countries-v5.1.2.geojson"
        country_receipt = _download_cached(NE_COUNTRIES_URL, cache / relative)
    country_receipt = {**country_receipt, "cache_file": relative}
    countries = json.loads((cache / relative).read_text(encoding="utf-8"))
    sources = []
    for country, (identifier, version) in DETAILED_FRAMES.items():
        frame = _baseline_national_frame(countries, country=country)
        water_inputs, water_receipt = _physical_water_inputs(cache, country)
        stem = cache / (DETAILED_DIRECTORY + country + "-water-stage/members/gis_osm_water_a_free_1")
        if stem.with_suffix(".cpg").read_text(encoding="ascii").strip().upper() != "UTF-8":
            raise ValueError("Physical-water original encoding is not the reviewed UTF-8")
        prj = stem.with_suffix(".prj").read_text(encoding="utf-8")
        if 'GEOGCS["GCS_WGS_1984"' not in prj or 'UNIT["Degree",0.017453292519943295]' not in prj:
            raise ValueError("Physical-water source no longer declares its reviewed WGS84 longitude/latitude coordinates")
        reader = _shapefile().Reader(str(stem), encoding="utf-8")
        fields = [f[0] for f in reader.fields[1:]]
        features, class_counts = [], Counter()
        for record in reader.iterShapeRecords():
            properties = dict(zip(fields, record.record))
            class_counts[properties.get("fclass")] += 1
            if properties.get("fclass") not in ACTUAL_WATER_CLASSES:
                continue
            if not record.shape.points:
                raise ValueError("Physical-water source contains a missing original water geometry")
            features.append({"properties": properties, "geometry": record.shape.__geo_interface__})
        geometry = national_physical_land(frame, physical, features, country=country)
        relative = f"land-references/{country}-NE-territorial-physical-water-20261108.geojson"
        _write_json(cache / relative, mapping(geometry))
        source = {"id": f"ne-physical-water-{country}-20261108", "country": country,
                  "source_type": "ne-territorial-physical-land", "derivation_version": 1,
                  "physical_product": "NaturalEarth:10m_land:v5.1.2", "water_product": "Geofabrik:gis_osm_water_a_free",
                  "national_frame": {"ISO3166-1": country, "product": "NaturalEarth:admin0:v5.1.2", "territorial_policy": "original-reference-unchanged"},
                  "cache_file": relative, "bytes": (cache / relative).stat().st_size, "sha256": sha256_file(cache / relative),
                  "url": DETAILED_ARCHIVES[country], "metadata_url": NE_COUNTRIES_URL, "date": "2026-11-08", "retrieved": "2026-11-10",
                  "physical_source_version": "Natural Earth v5.1.2; publication version retained separately from 2026 OSM snapshot",
                  "input_files": [land_receipt, country_receipt, *water_inputs], "water_archive_snapshot": water_receipt["snapshot"],
                  "original_water_class_counts": dict(class_counts), "open_water_feature_count": len(features),
                  "excluded_water_classes": ACTUAL_WATER_CLASSES, "retained_classes": sorted(set(class_counts)-set(ACTUAL_WATER_CLASSES)),
                  "license": "ODbL 1.0 (original physical-water polygons); Public Domain (unchanged Natural Earth national reference and independent physical coastline)",
                  "license_url": "https://opendatacommons.org/licenses/odbl/1-0/",
                  "license_layers": [{"scope": "unmodified physical open-water polygons", "license": "ODbL 1.0", "url": "https://opendatacommons.org/licenses/odbl/1-0/"},
                                     {"scope": "original national frame and global physical land/coast", "license": "Public Domain", "url": "https://www.naturalearthdata.com/about/terms-of-use/"}],
                  "attribution": "© OpenStreetMap contributors; Geofabrik GmbH, physical-water polygons, snapshot2026-11-08. Made with Natural Earth v5.1.2 unchanged national reference and physical land. Downloaded2026-11-10.",
                  "product_url": "https://download.geofabrik.de/osm-data-in-gis-formats-free.pdf",
                  "independent_of_target_municipalities": True, "reference_area_km2": _equal_area(geometry).area/1e6,
                  "derivation": "Original project Natural Earth national territorial frame intersected with independent global physical coastline, minus every original open-water/reservoir/riverbank/dock polygon. No change of national assignment and no target municipality/district union; wetlands and glaciers remain land.",
                  "water_geometry_policy": "Unmodified original geographic water geometry; invalid or missing polygons fail. No repair, buffer, rounding, snapping, invented boundary or omission based on coverage.",
                  "limitations": "The project's original Natural Earth national assignment is retained exactly. Its generalized border/coast uncertainties remain; the independently measured more detailed OSM national proposal is not integrated because it would change neighbouring country assignments. This physical correction does not certify administrative borders or resolve remaining gaps."}
        sources.append(source)
    _write_json(derived, {"derivation_version": 1, "sources": sources})
    return sources


def prepare_sources(cache: Path) -> list[dict]:
    cache = Path(cache)
    li_relative = "land-references/LI-swisstopo-identify-2026.json"
    receipt = _download_cached(SWISS_URL, cache / li_relative)
    with (cache / li_relative).open(encoding="utf-8-sig") as handle:
        liechtenstein = swiss_liechtenstein(json.load(handle))
    li = {"id": "swisstopo-land-LI-2026", "country": "LI", "source_type": "swiss-identify",
          **receipt, "cache_file": li_relative, "date": "2026-01-01",
          "license": "Federal Office of Topography swisstopo License",
          "license_url": "https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices",
          "attribution": "Federal Office of Topography swisstopo; swissBOUNDARIES3D national boundaries, 2026",
          "product_url": "https://www.swisstopo.admin.ch/en/landscape-models",
          "metadata_url": "https://api3.geo.admin.ch/rest/services/api/MapServer/" + SWISS_LAYER + "/legend",
          "reference_area_km2": _equal_area(liechtenstein).area / 1_000_000,
          "derivation": "Official national-boundary feature LI selected from the reviewed service; no target municipal union",
          "independent_of_target_municipalities": True}

    metadata = json.loads((cache / "coverage-metadata.json").read_text(encoding="utf-8"))
    italy = _prepare_one(cache, select_source(metadata, "IT"))
    with (cache / italy["cache_file"]).open(encoding="utf-8-sig") as handle:
        document = json.load(handle)
    selected = []
    selected_ids = []
    extent = box(*SM_EXTENT)
    for feature in document["features"]:
        geometry = shape(feature["geometry"])
        if geometry.intersects(extent):
            selected.append(geometry)
            selected_ids.append(str(feature["properties"]["shapeID"]))
    san_marino = derive_san_marino_enclave(selected, source_country=italy["country"])
    sm_relative = "land-references/SM-ISTAT-enclave-2023.geojson"
    _write_json(cache / sm_relative, mapping(san_marino))
    input_source = {key: italy[key] for key in (
        "id", "country", "url", "cache_file", "bytes", "sha256", "date", "license", "license_url",
        "attribution", "pinnedmetadataURL", "metadata_sha256", "original_license_source")}
    sm = {"id": "istat-italy-enclave-SM-2023", "country": "SM", "source_type": "derived-geojson",
          "cache_file": sm_relative, "bytes": (cache / sm_relative).stat().st_size,
          "sha256": sha256_file(cache / sm_relative), "url": italy["url"], "date": italy["date"],
          "license": italy["license"], "license_url": italy["license_url"],
          "attribution": italy["attribution"] + "; San Marino outline derived from the enclosed gap in Italian municipal coverage",
          "product_url": "https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici-al-1-gennaio-2018-2/",
          "metadata_url": italy["pinnedmetadataURL"], "input_source": input_source,
          "reference_area_km2": _equal_area(san_marino).area / 1_000_000,
          "derivation": "Bounding-box complement of independently sourced ISTAT Italian municipality polygons; the single closed component containing the documented San Marino seed is selected",
          "derivation_bbox": list(SM_EXTENT), "derivation_seed_lonlat": list(SM_SEED),
          "derivation_input_feature_ids": selected_ids,
          "independent_of_target_municipalities": True,
          "limitation": "The independent ISTAT input is simplified; a small residual geometric disagreement remains and is measured, not hidden"}
    aland = _prepare_aland(cache)
    luxembourg = prepare_luxembourg_reference(cache)
    faroe = prepare_faroe_reference(cache)
    estonia = prepare_estonia_reference(cache)
    channel_islands = prepare_channel_islands_references(cache)
    detailed = prepare_detailed_physical_references(cache)
    sources = [li, sm, aland, luxembourg, faroe, estonia, *channel_islands, *detailed]
    _write_json(ROOT / "data/atlas_land_references.json", {
        "schema": 1, "review_date": "2026-11-10", "sources": sources,
        "purpose": "Independent country outlines and coverage denominators; never unions of the target country's imported communes",
        "unresolved": {}})
    return sources


def load_references(cache: Path, sources: list[dict]) -> dict:
    result = {}
    for source in sources:
        path = Path(cache) / source["cache_file"]
        verify_source(path, source)
        with path.open(encoding="utf-8-sig") as handle:
            document = json.load(handle)
        source_type = source.get("source_type")
        if source_type == "swiss-identify":
            geometry = swiss_liechtenstein(document)
        elif source_type == "derived-geojson":
            dependency = source.get("input_source", {})
            if dependency.get("country") != "IT" or source.get("country") != "SM":
                raise ValueError("Derived enclave source is not independent of its target municipalities")
            verify_source(Path(cache) / dependency["cache_file"], dependency)
            geometry = _area(shape(document))
        elif source_type == "aland-physical-coastline":
            _validate_aland_source(source)
            for dependency in source["input_files"]:
                verify_source(Path(cache) / dependency["cache_file"], dependency)
            geometry = _area(shape(document))
        elif source_type == "act-national-geojson":
            if source.get("country") != "LU" or source.get("source_layer") != "LIMADM_PAYS" or not source.get("independent_of_target_municipalities"):
                raise ValueError("Luxembourg reference is not the independently read national ACT feature")
            for dependency in source.get("input_files", []):
                verify_source(Path(cache) / dependency["cache_file"], dependency)
            geometry = luxembourg_national_outline({"features": [{"geometry": document}]}, source_layer=source["source_layer"])
        elif source_type == "faroe-physical-islands":
            if (source.get("country") != "FO" or source.get("source_layer") != "lendiskort/us_lendiskort/15"
                    or not source.get("independent_of_target_municipalities") or not source.get("input_files")):
                raise ValueError("Faroese reference is not independently sourced physical island geometry")
            for dependency in source["input_files"]:
                verify_source(Path(cache) / dependency["cache_file"], dependency)
            geometry = _area(shape(document))
        elif source_type == "estonia-physical-land":
            _validate_estonia_source(source)
            for dependency in source["input_files"]:
                verify_source(Path(cache) / dependency["cache_file"], dependency)
            geometry = _area(shape(document))
        elif source_type == "eea-physical-islands":
            _validate_channel_source(source)
            for dependency in source["input_files"]:
                verify_source(Path(cache) / dependency["cache_file"], dependency)
            geometry = _area(shape(document))
        elif source_type == "national-physical-land":
            _validate_detailed_physical_source(source)
            for dependency in source["input_files"]:
                verify_source(Path(cache) / dependency["cache_file"], dependency)
            geometry = _area(shape(document))
        elif source_type == "ne-territorial-physical-land":
            _validate_conservative_physical_source(source)
            for dependency in source["input_files"]:
                verify_source(Path(cache) / dependency["cache_file"], dependency)
            geometry = _area(shape(document))
        else:
            raise ValueError(f"Unreviewed country-reference source type: {source_type}")
        country = str(source["country"])
        if country in result:
            raise ValueError(f"Ambiguous independent references for {country}")
        result[country] = geometry
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    args = parser.parse_args()
    sources = prepare_sources(args.cache)
    geometries = load_references(args.cache, sources)
    print(json.dumps({country: {"area_km2": _equal_area(geometry).area / 1_000_000,
                               "bounds": geometry.bounds} for country, geometry in geometries.items()}))
