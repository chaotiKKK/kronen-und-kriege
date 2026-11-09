"""Pinned, independently cached Overture administrative frame for the atlas.

The game and the ordinary atlas builder do not depend on DuckDB. A separate
Python environment is used only for bounded remote GeoParquet extraction.
"""
from __future__ import annotations

import argparse
from collections import Counter
import gzip
import hashlib
import io
import json
import math
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import sys
from typing import Iterator
from urllib.parse import urlencode
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RELEASE = "2026-10-21.0"
NORMALIZER_VERSION = 3
EXTRACTION_VERSION = 2
BOUNDS = [-12.0, 33.0, 52.0, 72.0]
BASE = "https://overturemaps-us-west-2.s3.us-west-2.amazonaws.com/"
LICENSE_URL = "https://opendatacommons.org/licenses/odbl/1-0/"
GUIDE_URL = "https://docs.overturemaps.org/guides/divisions/"
DIVISION_SCHEMA_URL = "https://docs.overturemaps.org/schema/reference/divisions/division/"
AREA_SCHEMA_URL = "https://docs.overturemaps.org/schema/reference/divisions/division_area/"
DIRECTORY = "overture-" + RELEASE


def role_for(country: str, subtype: str, local_type=None):
    if country == "DE":
        return None
    if subtype in {"region", "county"} and isinstance(local_type, dict):
        native_type = local_type.get("en")
        if isinstance(native_type, str):
            normalized = " ".join(native_type.casefold().replace("_", " ").replace("-", " ").split())
            if country == "JE" and subtype == "region" and normalized == "parish":
                return "municipality", native_type
            if country == "GG" and subtype == "county" and normalized == "parish":
                return "municipality", native_type
            if country == "JE" and subtype == "county" and normalized in {"vingtaine", "cueillette"}:
                return "local_admin", native_type
            if normalized in {"municipality", "commune", "local council", "civil parish"}:
                return "municipality", native_type
    if subtype == "region":
        return "region", "Overture region"
    if subtype == "county":
        if country in {"DK", "NO"}:
            return "municipality", "Kommune"
        return "district", {"FI": "Subregion", "RU": "District", "TR": "District"}.get(country, "Overture county")
    if subtype == "localadmin" and country in {"CZ", "SK"}:
        return "municipality", "Obec"
    return None


def source_id(country: str, subtype: str, kind: str) -> str:
    return f"overture-{RELEASE}-{country}-{subtype}-{kind}"


def sha256_file(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def write_json(path: Path, value) -> None:
    content = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    if path.exists() and path.read_bytes() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(content)
    temporary.replace(path)


def normalize_feature(raw: dict) -> dict | None:
    from shapely.geometry import shape
    import shapely

    country, subtype = str(raw.get("country", "")), str(raw.get("subtype", ""))
    role = role_for(country, subtype, raw.get("local_type"))
    if role is None or not raw.get("is_land"):
        return None
    division_id = str(raw.get("division_id") or "")
    if not division_id:
        raise ValueError("Missing Overture division identifier")
    if not isinstance(raw.get("geometry"), dict):
        raise ValueError(f"Missing area geometry: {division_id}")
    geometry = shape(raw["geometry"])
    if geometry.is_empty or geometry.geom_type not in ("Polygon", "MultiPolygon"):
        raise ValueError(f"Overture geometry is not an area: {division_id}")
    if not geometry.is_valid:
        geometry = shapely.make_valid(geometry)
    if geometry.geom_type == "GeometryCollection":
        geometry = shapely.unary_union([part for part in shapely.get_parts(geometry) if part.geom_type in ("Polygon", "MultiPolygon")])
    if geometry.is_empty or geometry.geom_type not in ("Polygon", "MultiPolygon") or geometry.area <= 0:
        raise ValueError(f"Invalid Overture land geometry: {division_id}")
    west, south, east, north = geometry.bounds
    if not all(math.isfinite(x) for x in geometry.bounds) or not (-180 <= west <= east <= 180 and -90 <= south <= north <= 90):
        raise ValueError(f"Non-geographic Overture geometry: {division_id}")
    parent = raw.get("parent_division_id")
    if raw.get("parent_kind") == "country":
        parent_id, relationship = "country:" + country, "source-parent"
    elif parent:
        parent_id, relationship = "overture:" + str(parent), "source-parent"
    else:
        parent_id, relationship = "country:" + country, "unresolved-source-parent"
    name = raw.get("name")
    known = isinstance(name, str) and bool(name.strip())
    return {"country": country, "id": "overture:" + division_id,
            "name": name.strip() if known else "Gebiet (Name in Quelle fehlt)", "name_known": known,
            "original_name": name, "kind": role[0], "geometry": geometry,
            "parent_id": parent_id, "parent_relationship": relationship,
            "source": source_id(country, subtype, role[0]), "admin_level": raw.get("admin_level"),
            "source_admin_level": raw.get("admin_level"), "unit_type": role[1],
            "overture_division_id": division_id, "raw_subtype": subtype,
            "local_type": raw.get("local_type"), "original_parent_division_id": parent,
            "original_source_records": raw.get("sources", []),
            "original_area_ids": [str(raw.get("area_id") or "")],
            "is_land": True, "is_territorial": bool(raw.get("is_territorial"))}


def deduplicate_records(records: list[dict]) -> list[dict]:
    import shapely

    grouped = {}
    for record in records:
        key = record["id"]
        if key not in grouped:
            grouped[key] = record.copy()
            continue
        previous = grouped[key]
        for field in ("country", "kind", "parent_id", "source"):
            if previous[field] != record[field]:
                raise ValueError(f"Conflicting division metadata: {key}/{field}")
        previous["geometry"] = shapely.union(previous["geometry"], record["geometry"])
        previous["original_area_ids"] = sorted(set(previous["original_area_ids"] + record["original_area_ids"]))
        for item in record["original_source_records"]:
            if item not in previous["original_source_records"]:
                previous["original_source_records"].append(item)
    return [grouped[key] for key in sorted(grouped)]


def _download(url: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".download")
    subprocess.run(["curl.exe", "--fail", "--location", "--silent", "--show-error", "--retry", "2",
                    "--connect-timeout", "20", "--max-time", "300", "--output", str(temporary), url], check=True)
    temporary.replace(path)


def _parquet_files(cache: Path, kind: str) -> list[str]:
    listing = cache / DIRECTORY / (kind + "-files.xml")
    if not listing.exists():
        query = urlencode({"list-type": "2", "prefix": f"release/{RELEASE}/theme=divisions/type={kind}/", "max-keys": 1000})
        _download(BASE + "?" + query, listing)
    namespace = {"s": "http://s3.amazonaws.com/doc/2006-03-01/"}
    document = ET.parse(listing)
    if document.find("s:IsTruncated", namespace).text == "true":
        raise ValueError("The pinned Parquet listing requires pagination")
    return [BASE + item.find("s:Key", namespace).text for item in document.findall("s:Contents", namespace)
            if item.find("s:Key", namespace).text.endswith(".parquet")]


def _connection(cache: Path):
    import duckdb

    engine = cache / DIRECTORY / "engine"
    engine.mkdir(parents=True, exist_ok=True)
    compressed = engine / "httpfs.duckdb_extension.gz"
    library = engine / "httpfs.duckdb_extension"
    if not compressed.exists():
        pilot = cache / "overture-pilot/httpfs.duckdb_extension.gz"
        if pilot.exists() and duckdb.__version__ == "2.0.0":
            shutil.copyfile(pilot, compressed)
        else:
            _download(f"https://extensions.duckdb.org/v{duckdb.__version__}/windows_amd64/httpfs.duckdb_extension.gz", compressed)
    if not library.exists():
        with gzip.open(compressed, "rb") as original, library.open("wb") as target:
            shutil.copyfileobj(original, target)
    con = duckdb.connect(config={"threads": "2", "memory_limit": "4GB", "temp_directory": str(engine / "tmp"), "extension_directory": str(engine / "extensions")})
    con.execute("SET preserve_insertion_order=false")
    con.execute("LOAD '" + str(library).replace("'", "''") + "'")
    certificate_file = engine / "windows-root-ca.pem"
    certificates = [ssl.DER_cert_to_PEM_cert(certificate) for certificate, encoding, trust in ssl.enum_certificates("ROOT")
                    if encoding == "x509_asn" and (trust is True or "1.3.6.1.5.5.7.3.1" in trust)]
    certificate_file.write_text("".join(certificates), encoding="ascii")
    con.execute("SET ca_cert_file='" + str(certificate_file).replace("'", "''") + "'")
    con.execute("SET enable_server_cert_verification=true")
    con.execute("SET disable_parquet_prefetching=true")
    con.execute("SET external_file_cache_remote_max_block_size=262144")
    con.execute("SET enable_http_metadata_cache=true")
    con.execute("SET http_timeout=40")
    con.execute("SET http_retries=2")
    return con


def completed_part(cache: Path, receipt_path: Path, url: str, countries: list[str]) -> dict | None:
    if not receipt_path.exists():
        return None
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if (receipt.get("release") != RELEASE or receipt.get("extraction_version") != EXTRACTION_VERSION
            or receipt.get("url") != url or receipt.get("countries") != countries or receipt.get("bounds") != BOUNDS):
        raise ValueError("Overture completed-part selection/scope mismatch")
    path = cache / receipt["cache_file"]
    if not path.exists() or sha256_file(path) != receipt.get("sha256"):
        raise ValueError("Overture completed-part hash mismatch")
    if path.stat().st_size != int(receipt["bytes"]):
        raise ValueError("Overture completed-part size mismatch")
    return receipt


def _extract(cache: Path) -> None:
    directory = cache / DIRECTORY
    directory.mkdir(parents=True, exist_ok=True)
    snapshot = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
    countries = sorted({f["country"] for f in snapshot["features"] if f.get("kind") == "country" and f["country"] != "DE"})
    area_files, point_files = _parquet_files(cache, "division_area"), _parquet_files(cache, "division")
    con = _connection(cache)
    print("OVERTURE: bounded land frame extraction started", flush=True)
    parameters = ",".join("?" for _ in countries)
    con.execute("""
        CREATE TEMP TABLE points AS
        SELECT id, country, subtype, parent_division_id, local_type
        FROM read_parquet(?) WHERE country IN (""" + parameters + """)
          AND subtype IN ('country','dependency','macroregion','region','macrocounty','county','localadmin')
    """, [point_files, *countries])
    print("OVERTURE: parent metadata ready", flush=True)
    selection = """
        SELECT a.id AS area_id, a.division_id, a.country, a.subtype, a.admin_level,
               a.names.primary AS name, a.is_land, a.is_territorial,
               d.parent_division_id, p.subtype AS parent_kind, d.local_type,
               a.sources, CAST(ST_AsGeoJSON(a.geometry) AS JSON) AS geometry
        FROM read_parquet(?) a
        LEFT JOIN points d ON d.id=a.division_id
        LEFT JOIN points p ON p.id=d.parent_division_id
        WHERE a.country IN (""" + parameters + """) AND a.is_land
          AND (a.subtype IN ('region','county') OR (a.subtype='localadmin' AND a.country IN ('CZ','SK')))
          AND a.bbox.xmin<=52 AND a.bbox.xmax>=-12 AND a.bbox.ymin<=72 AND a.bbox.ymax>=33
    """
    parts = []
    all_counts = Counter()
    parts_directory = directory / "parts"
    parts_directory.mkdir(exist_ok=True)
    for index, url in enumerate(area_files):
        path = parts_directory / f"part-{index:04d}.jsonl.gz"
        receipt_path = parts_directory / f"part-{index:04d}.receipt.json"
        part = completed_part(cache, receipt_path, url, countries)
        if part is None:
            temporary = path.with_suffix(path.suffix + ".partial")
            temporary.unlink(missing_ok=True)
            profile = parts_directory / f"part-{index:04d}.profile.json"
            con.execute("PRAGMA enable_profiling='json'")
            con.execute("PRAGMA profiling_output='" + str(profile).replace("'", "''") + "'")
            print(f"OVERTURE: streaming source part {index+1}/{len(area_files)}", flush=True)
            copied = con.execute("COPY (" + selection + ") TO ? (FORMAT JSON, COMPRESSION GZIP)",
                                 [[url], *countries, str(temporary)]).fetchone()[0]
            counts = Counter()
            with gzip.open(temporary, "rt", encoding="utf-8") as stream:
                for line in stream:
                    record = json.loads(line)
                    if not isinstance(record.get("geometry"), dict):
                        raise ValueError("Streaming geometry was not serialized as GeoJSON")
                    counts[record["country"] + ":" + record["subtype"]] += 1
            if sum(counts.values()) != copied:
                raise ValueError("Streaming part row count mismatch")
            temporary.replace(path)
            part = {"release": RELEASE, "extraction_version": EXTRACTION_VERSION, "url": url,
                "countries": countries, "bounds": BOUNDS, "cache_file": path.relative_to(cache).as_posix(),
                "bytes": path.stat().st_size, "sha256": sha256_file(path), "raw_counts": dict(sorted(counts.items())),
                "profile_file": profile.relative_to(cache).as_posix()}
            write_json(receipt_path, part)
        parts.append(part)
        all_counts.update(part["raw_counts"])
        print(json.dumps({"completed_parts": index+1, "total_parts": len(area_files),
            "part_features": sum(part["raw_counts"].values()), "part_gzip_bytes": part["bytes"]}), flush=True)
    profiles = [json.loads((cache / part["profile_file"]).read_text(encoding="utf-8")) for part in parts]
    summary = {"io": {"total_bytes_read": sum(p.get("io", {}).get("total_bytes_read", 0) for p in profiles)},
        "query": {key: sum(p.get("query", {}).get(key, 0) for p in profiles) for key in
            ("total_time", "total_row_groups_scanned", "total_row_groups_to_scan", "total_rows_scanned")},
        "system": {key: max(p.get("system", {}).get(key, 0) for p in profiles) for key in
            ("peak_buffer_memory", "peak_temp_dir_size", "blocked_thread_time")},
        "note": "Completed sequential per-source COPY queries; parent-metadata query excluded"}
    write_json(directory / "extraction-profile.json", summary)
    write_json(directory / "raw-receipt.json", {"release": RELEASE, "extraction_version": EXTRACTION_VERSION,
        "bounds": BOUNDS, "requested_countries": countries, "parts": parts,
        "area_files": area_files, "division_files": point_files, "raw_counts": dict(sorted(all_counts.items()))})
    print(json.dumps({"raw_features": sum(all_counts.values()), "gzip_bytes": sum(part["bytes"] for part in parts)}), flush=True)


def _prepare_cache(cache: Path) -> dict:
    from shapely.geometry import mapping

    directory = cache / DIRECTORY
    raw_receipt = json.loads((directory / "raw-receipt.json").read_text(encoding="utf-8"))
    if raw_receipt.get("release") != RELEASE:
        raise ValueError("Unexpected raw Overture release")
    records = []
    for raw_part in raw_receipt.get("parts", [raw_receipt]):
        raw_path = cache / raw_part["cache_file"]
        if sha256_file(raw_path) != raw_part["sha256"]:
            raise ValueError("Raw Overture cache hash mismatch")
        with gzip.open(raw_path, "rt", encoding="utf-8") as stream:
            for line in stream:
                record = normalize_feature(json.loads(line))
                if record is not None:
                    records.append(record)
    records = deduplicate_records(records)
    available = {record["id"] for record in records}
    for record in records:
        if record["parent_id"].startswith("overture:") and record["parent_id"] not in available:
            record["unavailable_parent_id"] = record["parent_id"]
            record["parent_id"] = "country:" + record["country"]
            record["parent_relationship"] = "unresolved-source-parent"
    target = directory / "frame.geojsonl.gz"
    counts = Counter()
    metadata = {}
    unit_types = {}
    with target.open("wb") as binary, gzip.GzipFile(filename="", mode="wb", fileobj=binary, mtime=0) as compressed, io.TextIOWrapper(compressed, encoding="utf-8", newline="\n") as output:
        for record in records:
            identifier = record["source"]
            counts[identifier] += 1
            unit_types.setdefault(identifier, set()).add(record["unit_type"])
            if identifier not in metadata:
                metadata[identifier] = {"id": identifier, "country": record["country"], "kind": record["kind"],
                    "raw_subtype": record["raw_subtype"], "admin_level": record["admin_level"], "unit_type": record["unit_type"],
                    "url": GUIDE_URL, "catalog_url": f"https://stac.overturemaps.org/{RELEASE}/catalog.json",
                    "division_schema_url": DIVISION_SCHEMA_URL, "geometry_schema_url": AREA_SCHEMA_URL,
                    "license": "ODbL-1.0", "license_url": LICENSE_URL, "date": RELEASE.split(".")[0], "release": RELEASE,
                    "normalizer_version": NORMALIZER_VERSION,
                    "attribution": "Overture Maps Foundation; © OpenStreetMap contributors and other recorded contributors; ODbL 1.0",
                    "scope": "is_land=true; area bbox intersects [-12,33,52,72]; geometry not clipped by this reader",
                    "level_semantics": "Overture normalized hierarchy position, not the original OSM admin_level",
                    "cache_file": target.relative_to(cache).as_posix(),
                    "unit_semantics": {"source_unit_type": record["unit_type"], "render_role": record["kind"], "coverage_status": "Downstream land-mask coverage not yet measured"}}
            payload = {**record, "geometry": mapping(record["geometry"])}
            output.write(json.dumps(payload, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n")
    digest, byte_count = sha256_file(target), target.stat().st_size
    sources = []
    for key in sorted(metadata):
        native_types = sorted(unit_types[key])
        sources.append({**metadata[key], "unit_type": "; ".join(native_types),
            "unit_types": native_types, "source_unit_count": counts[key],
            "expected_unit_count": counts[key], "sha256": digest, "bytes": byte_count,
            "unit_semantics": {**metadata[key]["unit_semantics"],
                "source_unit_type": "; ".join(native_types), "source_unit_types": native_types}})
    present_countries = sorted({source["country"] for source in sources})
    missing_countries = sorted(set(raw_receipt["requested_countries"]) - set(present_countries))
    receipt = {"release": RELEASE, "normalizer_version": NORMALIZER_VERSION, "bounds": BOUNDS, "requested_countries": raw_receipt["requested_countries"],
        "countries_with_frame": present_countries, "countries_without_frame": missing_countries,
        "area_files": raw_receipt["area_files"], "division_files": raw_receipt["division_files"],
        "cache_file": target.relative_to(cache).as_posix(), "sha256": digest, "bytes": byte_count, "sources": sources,
        "note": "Region/county frame; native municipality/commune/local council/civil parish types use a municipal role. No locality promoted to municipality. CZ/SK localadmin retain the validated municipal role."}
    profile_path = directory / "extraction-profile.json"
    if profile_path.exists():
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
        receipt["extraction"] = {"profile_file": profile_path.relative_to(cache).as_posix(),
            "profile_sha256": sha256_file(profile_path), "io": profile.get("io", {}),
            "query": {key: profile.get("query", {}).get(key) for key in
                ("total_time", "total_row_groups_scanned", "total_row_groups_to_scan", "total_rows_scanned")},
            "system": {key: profile.get("system", {}).get(key) for key in
                ("peak_buffer_memory", "peak_temp_dir_size", "blocked_thread_time")}}
    write_json(directory / "receipt.json", receipt)
    return receipt


def _verify_cache(cache: Path, receipt: dict, *, require_current: bool = True) -> None:
    if receipt.get("release") != RELEASE:
        raise ValueError("Unexpected Overture release")
    path = cache / receipt["cache_file"]
    if not path.exists() or sha256_file(path) != receipt.get("sha256"):
        raise ValueError("Overture cache hash mismatch")
    if path.stat().st_size != int(receipt["bytes"]):
        raise ValueError("Overture cache size mismatch")
    if require_current and receipt.get("normalizer_version") != NORMALIZER_VERSION:
        raise ValueError("Overture normalizer cache version mismatch")


def prepare_sources(cache: Path) -> list[dict]:
    cache = Path(cache)
    receipt_path = cache / DIRECTORY / "receipt.json"
    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        _verify_cache(cache, receipt, require_current=False)
        if receipt.get("normalizer_version") != NORMALIZER_VERSION:
            receipt = _prepare_cache(cache)
    else:
        if (cache / DIRECTORY / "raw-extract.lock").exists():
            raise RuntimeError("Overture extraction is already in progress; wait for its verified cache")
        raw_receipt_path = cache / DIRECTORY / "raw-receipt.json"
        if not raw_receipt_path.exists():
            executable = ROOT / ".tools/atlas_env/Scripts/python.exe"
            if not executable.exists():
                raise RuntimeError("Bounded extraction needs .tools/atlas_env with DuckDB 2.0.0; cached reads do not.")
            subprocess.run([str(executable), str(Path(__file__).resolve()), "--extract", "--cache", str(cache)], check=True)
        receipt = _prepare_cache(cache)
    write_manifest(receipt)
    return receipt["sources"]


def iter_boundaries(cache: Path, sources: list[dict]) -> Iterator[dict]:
    from shapely.geometry import shape

    cache = Path(cache)
    selected = {source["id"]: source for source in sources}
    files = {source["cache_file"] for source in sources}
    if len(files) != 1:
        raise ValueError("Overture sources must use one verified extraction cache")
    first = sources[0]
    _verify_cache(cache, {"release": RELEASE, **first})
    seen, counts = set(), Counter()
    with gzip.open(cache / first["cache_file"], "rt", encoding="utf-8") as stream:
        for line in stream:
            record = json.loads(line)
            if record.get("source") not in selected:
                continue
            if record["id"] in seen:
                raise ValueError("Duplicate cached division identifier: " + record["id"])
            seen.add(record["id"])
            counts[record["source"]] += 1
            record["geometry"] = shape(record["geometry"])
            yield record
    for identifier, source in selected.items():
        if counts[identifier] != int(source["source_unit_count"]):
            raise ValueError("Cached Overture feature count mismatch: " + identifier)


def write_manifest(receipt: dict) -> None:
    write_json(ROOT / "data/atlas_overture_sources.json", {"schema": 1, **receipt})
    lines = ["# Overture-Rahmenquellen des Referenzatlas", "", f"Festgeschriebener Stand: **{RELEASE}**. Der getrennte Leser verwendet Landflächen (`is_land=true`) und führt Varianten anhand der eigentlichen `division_id` zusammen. Deutschland bleibt beim BKG-Rahmen. Keine Siedlung wird allein anhand des Subtyps `locality` in eine Gemeinde umbenannt.", "", "| Land | Quellsubtyp | Darstellungsrolle | tatsächliche Rolle | Roh-Einheiten im Auswahlbereich |", "|---|---|---|---|---:|"]
    for source in receipt["sources"]:
        lines.append(f"| {source['country']} | {source['raw_subtype']} | {source['kind']} | {source['unit_type']} | {source['source_unit_count']} |")
    lines += ["", "Die Zahlen beschreiben die gespeicherte bbox-Auswahl, noch keine gemessene lückenlose Flächenabdeckung. Die Geometrie wird erst im Hauptimport auf Länderlandmasken und Kartenausschnitt geschnitten. Overtures `admin_level` bezeichnet eine normalisierte Hierarchieposition; es ist nicht die ursprüngliche OSM-ADM-Zahl. CZ/SK-localadmin erhalten deshalb weiterhin `admin_level=null`.", "", "Angefragte Ländercodes ohne gespeicherte Region-/County-/validierte Localadmin-Fläche: " + ", ".join(receipt["countries_without_frame"]) + ". Deutschland wird absichtlich nicht angefragt und behält die BKG-Quellen.", "", "## Rollen und verbleibende Grenzen", "", f"Der [native Gebietstyp `local_type`]({DIVISION_SCHEMA_URL}) erhält Vorrang vor dem generischen Quellsubtyp: Bei `region`/`county` werden ausschließlich die positiven Typen `municipality`, `commune`, `local council` und `civil parish` als kommunale Einheit behandelt. Diese Regel gilt länderübergreifend, unter anderem für kommunale County-Knoten in LT/EE/AL. Norwegische und dänische County-Knoten sind ebenfalls Kommunen. Tschechische und slowakische `localadmin`-Einheiten behalten ihre geprüfte Gemeinderolle. Alle originalen Typen und Subtypen bleiben erhalten.", "", "Britische County-Knoten ohne belegten kommunalen Typ, russische/türkische Bezirke und finnische Subregionen bleiben Bezirksrahmen. Damit ist keine vollständige kommunale Abdeckung für RU/TR/GB/FI nachgewiesen. Der Typ `locality` wird auch bei kommunal klingendem Namen nie pauschal übernommen. Ein OSM-Quellbezeichner mit `r`-Präfix allein belegt ebenfalls keine administrative Grenze. Aktuelle kommunale Alternativquellen bleiben erforderlich. Fehlende Eltern in der Auswahl werden ausdrücklich als `unresolved-source-parent` protokolliert; ursprüngliche Kennungen bleiben erhalten.", "", "## Lizenz und Aufbereitung", "", f"[Overture Divisions]({GUIDE_URL}) wird unter [ODbL 1.0]({LICENSE_URL}) veröffentlicht. Quellenhinweis: Overture Maps Foundation; © OpenStreetMap contributors und weitere je Datensatz vermerkte Quellen. Originale `sources`-Einträge, `division_id`, Area-IDs und Elternkennungen bleiben im Cache erhalten. Die abgeleitete Geometriedatenbank muss mit ihrer Datenbanklizenz und Namensnennung weitergegeben werden; daraus folgt nicht automatisch eine ODbL-Lizenz für unabhängigen Spielcode.", "", f"Geprüfter Cache: `{receipt['cache_file']}`, {receipt['bytes']} Bytes, SHA-256 `{receipt['sha256']}`. Die Quell-Parquet-URLs stehen im Manifest. Das Rohdatenformat wird nicht zur Laufzeit gelesen: der gewöhnliche Python-Leser benutzt den Cache, ohne DuckDB vorauszusetzen. Cache-Normalizer: {receipt['normalizer_version']}.", "", f"Extraktionswerkzeug: `.tools/atlas_env/Scripts/python.exe` mit DuckDB 2.0.0 und signierter offizieller httpfs-Erweiterung. TLS-Zertifikatsprüfung wird ausdrücklich aktiviert und benutzt die Windows-ROOT-Vertrauensanker. Der Download liest nur benötigte GeoParquet-Spalten/Zeilengruppen; keine vollständige globale Geometriedatei wird absichtlich geladen. [Flächengeometrie und Land-/Territorialvarianten]({AREA_SCHEMA_URL}) werden anhand von `is_land=true` unterschieden.", "", "```powershell", "python tools/atlas_overture_sources.py --cache .tools/atlas_sources", "python -m unittest discover -s tools -p test_atlas_overture_sources.py", "```", ""]
    path = ROOT / "docs/atlas-overture-sources.md"
    lines += ["## Nachgewiesene Sonderrollen", "",
        "Guernseys zehn Parishes sind heutige zivile Verwaltungseinheiten mit gewählten Douzaines "
        "([offizielle Parishverwaltung Vale](https://valeparish.gg/douzaine/about-us/)). "
        "Der native Typ `parish` bekommt bei GG-County-Knoten deshalb eine Gemeinderolle. "
        "Die zehn Hauptinselparishes beweisen für sich noch keine lückenlose Verwaltungsabdeckung des gesamten Bailiwicks einschließlich seiner anderen Inseln.", "",
        "Jerseys 12 Parishes sind verwaltende Pfarrgemeinden "
        "([amtliche Flächengliederung](https://www.gov.je/Environment/LandHabitats/pages/sizelandcover.aspx)). "
        "Ihre Vingtaines beziehungsweise Cueillettes sind darunterliegende politische Untergliederungen "
        "([Government Open Data](https://opendata.gov.je/dataset/2021-census/resource/8a69b1b1-2675-44a1-93e4-a5b346959032)); "
        "belegte native Typen werden deshalb als `municipality` beziehungsweise `local_admin` getrennt geführt.", "",
        "Für die Isle of Man belegt die "
        "[amtliche Wahlverwaltung](https://elections.gov.im/elections/local-authority-elections/) aktuell 21 Local Authorities. "
        "24 Overture-Regionen oder historische Parishes sind damit nicht automatisch 24 heutige kommunale Behörden.", "",
        "Nordmazedonien besitzt 80 Gemeinden. "
        "[Skopje ist zusätzlich eine besondere Selbstverwaltungseinheit über zehn dieser Gemeinden](https://makstat.stat.gov.mk/PXWeb/pxweb/en/MakStat/MakStat__Popisi__Popis2021__NaselenieSet/T1001P21.px/). "
        "Ein aggregiertes Skopje-Polygon darf daher bei einer disjunkten Gemeindeflächenzählung nicht nochmals als 81. Einzelgemeinde addiert werden.", ""]
    if receipt.get("extraction"):
        extraction = receipt["extraction"]
        lines += ["## Gemessene Extraktion", "",
            f"Das Abschlussprofil des Geometrie-SELECT meldet {extraction['io'].get('total_bytes_read')} gelesene Bytes, "
            f"{extraction['query'].get('total_row_groups_scanned')} tatsächlich gescannte von "
            f"{extraction['query'].get('total_row_groups_to_scan')} verfügbaren Zeilengruppen und "
            f"{extraction['query'].get('total_time')} Sekunden Abfragezeit. Der Wert umfasst den Geometrie-SELECT; "
            "die vorherige Parent-Metadatenabfrage und S3-Dateilisten sind darin nicht gesondert nachgewiesen.", "",
            f"Profil: `{extraction['profile_file']}`, SHA-256 `{extraction['profile_sha256']}`.", ""]
    lines += ["## Getrennte Werkzeugumgebung", "",
        "Der nachgewiesene Lauf verwendet Python 3.14.7, DuckDB 2.0.0 für die Extraktion und Shapely 2.1.2 für die Normalisierung. "
        "Eine frische isolierte Umgebung lässt sich ohne globale SDK-Änderung vorbereiten:", "", "```powershell",
        "python -m venv .tools/atlas_env",
        ".tools/atlas_env/Scripts/python.exe -m pip install duckdb==2.0.0 shapely==2.1.2",
        ".tools/atlas_env/Scripts/python.exe tools/atlas_overture_sources.py --cache .tools/atlas_sources",
        "```", "",
        "Bei bereits vorhandenem geprüftem Cache braucht der gewöhnliche Import nur Python und Shapely; DuckDB wird nicht geladen. "
        "Die Netzextraktion ist durch eine separate Schreibsperre gegen versehentliche parallele Starts geschützt.", ""]
    content = "\n".join(lines).encode("utf-8")
    if not path.exists() or path.read_bytes() != content:
        path.write_bytes(content)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, default=ROOT / ".tools/atlas_sources")
    parser.add_argument("--extract", action="store_true")
    arguments = parser.parse_args()
    if arguments.extract:
        lock = arguments.cache / DIRECTORY / "raw-extract.lock"
        lock.parent.mkdir(parents=True, exist_ok=True)
        try:
            with lock.open("x", encoding="ascii") as handle:
                handle.write(str(os.getpid()))
        except FileExistsError as error:
            raise RuntimeError("Overture extraction is already in progress") from error
        try:
            _extract(arguments.cache)
        finally:
            lock.unlink(missing_ok=True)
    else:
        sources = prepare_sources(arguments.cache)
        print(json.dumps({"sources": len(sources), "features": sum(source["source_unit_count"] for source in sources)}))


if __name__ == "__main__":
    main()
