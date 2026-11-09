"""Snapshot-pinned OSM administrative polygons, separate from the game atlas.

Only one Overpass HTTP request is active. Public-provider work is bounded,
cached and resumable; partial scans never imply complete country coverage.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import gzip
import hashlib
import json
import math
from pathlib import Path
import subprocess
import time
from typing import Iterator

from shapely.geometry import LineString, Polygon, MultiPolygon, box, mapping, shape
from shapely.ops import polygonize_full, unary_union

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
ENDPOINT = "https://overpass-api.de/api/interpreter"
BOUNDS = (-12.0, 33.0, 52.0, 72.0)
LEVELS = {"RU": (8,), "TR": (7, 8)}
COUNTRY_EXTENTS = {"RU": (19.0, 41.0, 52.0, 72.0), "TR": (25.0, 35.5, 45.0, 42.5)}
PILOT_IDS = {"RU": [1306580, 1650682, 339228], "TR": [3403828, 8852697, 9286607]}
PILOT_BBOX_QL = {"RU": "59.55,29.2,60.05,30.5", "TR": "40.95,29.00,41.03,29.10"}
LICENSE_URL = "https://opendatacommons.org/licenses/odbl/1-0/"
MANIFEST = ROOT / "data/atlas_osm_sources.json"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value) -> None:
    content = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    if path.exists() and path.read_bytes() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(content)
    temporary.replace(path)


def _cached_payload(root: Path, receipt: dict, url=None, query=None) -> bytes:
    if url is not None and receipt.get("url") != url:
        raise ValueError("Changed immutable OSM cache origin")
    if query is not None and receipt.get("query_sha256") != sha256(query.encode("utf-8")):
        raise ValueError("Changed immutable OSM cache query")
    path = (root / receipt["path"]).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("OSM cache path leaves the provider directory")
    payload = path.read_bytes()
    if sha256(payload) != receipt["sha256"]:
        raise ValueError("Changed immutable OSM cache bytes")
    return payload


@contextmanager
def provider_lock(cache: Path):
    cache.mkdir(parents=True, exist_ok=True)
    handle = (cache / "overpass.lock").open("a+b")
    handle.seek(0, 2)
    if handle.tell() == 0:
        handle.write(b"0")
        handle.flush()
    handle.seek(0)
    acquired = False
    try:
        try:
            if __import__("os").name == "nt":
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            acquired = True
        except OSError as error:
            raise RuntimeError("Another Overpass request is already active") from error
        yield
    finally:
        if acquired:
            handle.seek(0)
            if __import__("os").name == "nt":
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        handle.close()


class OverpassCache:
    def __init__(self, cache: Path, endpoint: str = ENDPOINT):
        self.root = Path(cache)
        self.endpoint = endpoint

    def request(self, query: str, fetch=None) -> tuple[dict, dict]:
        key = sha256((self.endpoint + "\n" + query).encode())
        directory = self.root / "requests" / key
        receipt_path = directory / "receipt.json"
        if receipt_path.exists():
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            payload = _cached_payload(self.root, receipt, self.endpoint, query)
            return json.loads(payload), receipt
        directory.mkdir(parents=True, exist_ok=True)
        query_path = directory / "query.ql"
        query_path.write_bytes(query.encode("utf-8"))
        with provider_lock(self.root):
            if fetch is not None:
                payload = fetch(query)
            else:
                output = directory / "response.tmp"
                subprocess.run(["curl.exe", "--fail", "--location", "--silent", "--show-error",
                                "--connect-timeout", "20", "--max-time", "210", "--get",
                                "--retry", "2", "--retry-delay", "5",
                                "--user-agent", "BangerQueensAtlas/1.6 (bounded administrative data import)",
                                "--data-urlencode", "data@" + str(query_path), "--output", str(output), self.endpoint], check=True)
                payload = output.read_bytes()
                output.unlink()
                time.sleep(1)
            decoded = json.loads(payload)
            if decoded.get("remark"):
                raise ValueError("Overpass incomplete response: " + str(decoded["remark"]))
            digest = sha256(payload)
            target = directory / (digest + ".json")
            if target.exists() and target.read_bytes() != payload:
                raise ValueError("Immutable response collision")
            target.write_bytes(payload)
            receipt = {"url": self.endpoint, "query_sha256": sha256(query.encode("utf-8")), "request_sha256": key,
                       "path": target.relative_to(self.root).as_posix(),
                       "sha256": digest, "bytes": len(payload),
                       "osm_timestamp": decoded.get("osm3s", {}).get("timestamp_osm_base")}
            write_json(receipt_path, receipt)
        return decoded, receipt

    def request_url(self, url: str, fetch=None) -> tuple[dict, dict]:
        """Explicit small OSM read-API fallback; never a bulk object downloader."""
        if not url.startswith("https://api.openstreetmap.org/api/0.6/relation/") or not url.endswith("/full.json"):
            raise ValueError("Only an explicit OSM relation/full URL is accepted")
        directory = self.root / "api_requests" / sha256(url.encode())
        receipt_path = directory / "receipt.json"
        if receipt_path.exists():
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            payload = _cached_payload(self.root, receipt, url)
            return json.loads(payload), receipt
        directory.mkdir(parents=True, exist_ok=True)
        with provider_lock(self.root):
            if fetch is None:
                output = directory / "response.tmp"
                subprocess.run(["curl.exe", "--fail", "--location", "--silent", "--show-error",
                                "--connect-timeout", "20", "--max-time", "120",
                                "--user-agent", "BangerQueensAtlas/1.6 (bounded administrative data import)",
                                "--output", str(output), url], check=True)
                payload = output.read_bytes()
                output.unlink()
                time.sleep(1)
            else:
                payload = fetch(url)
            decoded = json.loads(payload)
            if not isinstance(decoded.get("elements"), list):
                raise ValueError("OSM API response has no element array")
            digest = sha256(payload)
            target = directory / (digest + ".json")
            if not target.exists():
                target.write_bytes(payload)
            receipt = {"url": url, "path": target.relative_to(self.root).as_posix(),
                       "sha256": digest, "bytes": len(payload),
                       "retrieved_at": datetime.now(timezone.utc).isoformat(),
                       "snapshot_contract": "Every returned element version must predate the pinned snapshot."}
            write_json(receipt_path, receipt)
        return decoded, receipt


def full_geometry_relations(payload: dict, snapshot: str) -> dict[int, dict]:
    """Expand actual way/node references without guessing absent member geometry."""
    pinned = datetime.fromisoformat(snapshot.replace("Z", "+00:00"))
    elements = payload.get("elements", [])
    for element in elements:
        timestamp = element.get("timestamp")
        if not timestamp or not isinstance(element.get("version"), int) or element["version"] < 1:
            raise ValueError("Missing version/timestamp for snapshot validation")
        if datetime.fromisoformat(timestamp.replace("Z", "+00:00")) > pinned:
            raise ValueError("OSM element is newer than the pinned snapshot")
    nodes = {int(row["id"]): row for row in elements if row.get("type") == "node"}
    ways = {}
    for row in elements:
        if row.get("type") != "way":
            continue
        points = []
        for identifier in row.get("nodes", []):
            if int(identifier) not in nodes:
                raise ValueError(f"Missing member node {identifier}")
            node = nodes[int(identifier)]
            points.append({"lon": node["lon"], "lat": node["lat"]})
        ways[int(row["id"])] = points
    result = {}
    for row in elements:
        if row.get("type") == "relation":
            members = [{**member, **({"geometry": ways[int(member["ref"])]}
                       if member.get("type") == "way" and int(member["ref"]) in ways else {})}
                       for member in row.get("members", [])]
            result[int(row["id"])] = {**row, "members": members}
    return result


def role_for(country: str, level: str, tags: dict) -> tuple[str, str]:
    if country == "RU" and str(level) == "8":
        return "municipality", str(tags.get("official_status", "Kommunales Verwaltungsgebiet")).removeprefix("ru:")
    if country == "TR" and str(level) == "7":
        return "municipality", "Belde"
    if country == "TR" and str(level) == "8":
        name = str(tags.get("name", "")).casefold()
        return "local_admin", "Mahalle" if "mahalle" in name else ("Köy" if "köy" in name else "Mahalle / Köy")
    raise ValueError(f"Unselected administrative role: {country}/{level}")


def _member_lines(relation: dict, related: dict, inherited_inner=False, seen=None):
    seen = set() if seen is None else set(seen)
    identifier = int(relation["id"])
    if identifier in seen:
        raise ValueError(f"Cyclic OSM relation {identifier}")
    seen.add(identifier)
    outer, inner = [], []
    for member in relation.get("members", []):
        role = str(member.get("role", ""))
        if role not in {"", "outer", "inner"}:
            continue
        is_inner = inherited_inner != (role == "inner")
        if member.get("type") == "relation":
            child = related.get(int(member["ref"]))
            if child is None:
                raise ValueError(f"Missing child relation geometry {member['ref']}")
            a, b = _member_lines(child, related, is_inner, seen)
            outer.extend(a)
            inner.extend(b)
        elif member.get("type") == "way":
            geometry = member.get("geometry")
            if not isinstance(geometry, list) or len(geometry) < 2:
                raise ValueError(f"Missing member way geometry {member.get('ref')}")
            points = []
            for point in geometry:
                if not isinstance(point, dict) or "lon" not in point or "lat" not in point:
                    raise ValueError(f"Incomplete member way {member.get('ref')}")
                x, y = float(point["lon"]), float(point["lat"])
                if not (math.isfinite(x) and math.isfinite(y) and -180 <= x <= 180 and -90 <= y <= 90):
                    raise ValueError("Invalid OSM geographic coordinate")
                points.append((x, y))
            (inner if is_inner else outer).append(LineString(points))
    return outer, inner


def _closed_polygons(lines: list, identifier: int, role: str):
    if not lines:
        raise ValueError(f"Missing {role} ways for relation {identifier}")
    polygons, cuts, dangles, invalid = polygonize_full(unary_union(lines))
    if not cuts.is_empty or not dangles.is_empty or not invalid.is_empty or polygons.is_empty:
        raise ValueError(f"Unclosed or invalid {role} member ways for relation {identifier}")
    # Keep individual shells: unioning nested outer shells here would erase
    # islands before the corresponding inner holes are subtracted.
    return [Polygon(polygon.exterior) for polygon in polygons.geoms]


def normalize_relation(relation: dict, country: str, source_id: str, *, related=None, bounds=BOUNDS) -> dict:
    tags = relation.get("tags", {})
    if relation.get("type") != "relation" or tags.get("boundary") != "administrative" or tags.get("type") not in {"boundary", "multipolygon"}:
        raise ValueError("Not an administrative boundary relation")
    explicit_country = tags.get("addr:country", tags.get("is_in:country_code"))
    if explicit_country is not None and str(explicit_country).upper() != country:
        raise ValueError("OSM relation contradicts the selected country")
    kind, unit_type = role_for(country, str(tags.get("admin_level", "")), tags)
    if not isinstance(relation.get("version"), int) or int(relation["version"]) <= 0:
        raise ValueError("Missing source relation version")
    outer, inner = _member_lines(relation, related or {})
    shells = _closed_polygons(outer, int(relation["id"]), "outer")
    geometry = unary_union(shells)
    if inner:
        inner_shells = _closed_polygons(inner, int(relation["id"]), "inner")
        holes = unary_union(inner_shells)
        if holes.difference(geometry).area > 1e-12:
            raise ValueError("Inner OSM ring lies outside outer boundary")
        geometry = unary_union([shell.difference(unary_union([hole for hole in inner_shells if shell.covers(hole)]))
                                for shell in shells])
    if not isinstance(geometry, (Polygon, MultiPolygon)) or not geometry.is_valid or geometry.area <= 0:
        raise ValueError("OSM member ways do not form a valid area")
    original_bounds = list(geometry.bounds)
    geometry = geometry.intersection(box(*bounds))
    if geometry.geom_type == "GeometryCollection":
        # A clipping edge touching a hole can also return zero-area linework.
        geometry = unary_union([part for part in geometry.geoms if isinstance(part, (Polygon, MultiPolygon))])
    if geometry.is_empty or geometry.area <= 0 or not isinstance(geometry, (Polygon, MultiPolygon)):
        raise ValueError("OSM administrative area does not intersect atlas bounds")
    name = tags.get("name:de") or tags.get("name")
    known = isinstance(name, str) and bool(name.strip())
    return {"id": f"osm:relation:{relation['id']}", "country": country, "kind": kind,
            "unit_type": unit_type, "name": name.strip() if known else "Verwaltungsgebiet (Name in Quelle fehlt)",
            "name_known": known, "original_name": tags.get("name"),
            "source": source_id, "geometry": geometry, "admin_level": int(tags["admin_level"]),
            "source_admin_level": tags["admin_level"], "osm_tags": tags,
            "osm_relation_id": int(relation["id"]), "osm_relation_version": int(relation["version"]),
            "osm_record_id": f"r{relation['id']}@{relation['version']}",
            "source_timestamp": relation.get("timestamp"), "unclipped_bounds": original_bounds,
            "parent_id": "country:" + country, "parent_relationship": "query-country-scope"}


def fixed_tiles(country: str, step=4.0) -> list[tuple[float, float, float, float]]:
    west, south, east, north = COUNTRY_EXTENTS[country]
    tiles = []
    y = south
    while y < north:
        x = west
        while x < east:
            tiles.append((x, y, min(x + step, east), min(y + step, north)))
            x += step
        y += step
    return tiles


def metadata_query(country: str, bounds, snapshot=None, ids=None) -> str:
    west, south, east, north = bounds
    date = f'[date:"{snapshot}"]' if snapshot else ""
    identifiers = "(id:" + ",".join(str(int(identifier)) for identifier in ids) + ")" if ids else ""
    levels = "|".join(str(value) for value in LEVELS[country])
    return (f'[out:json][timeout:180][maxsize:134217728]{date};\n'
            f'area["ISO3166-1"="{country}"]["admin_level"="2"]->.country;\n'
            f'relation{identifiers}(area.country)["boundary"="administrative"]["admin_level"~"^({levels})$"]'
            f'({south},{west},{north},{east});out meta;')


def geometry_query(ids, snapshot: str) -> str:
    identifiers = ",".join(str(int(identifier)) for identifier in ids)
    return f'[out:json][timeout:180][maxsize:268435456][date:"{snapshot}"];relation(id:{identifiers});out meta geom;'


def pilot_metadata_query(country: str) -> str:
    """The exact small, previously recorded metadata pilot; TR7 remains unscanned."""
    return ('[out:json][timeout:120][maxsize:67108864];\n'
            f'area["ISO3166-1"="{country}"]["admin_level"="2"]->.country;\n'
            'relation(area.country)["boundary"="administrative"]["admin_level"="8"]'
            f'({PILOT_BBOX_QL[country]});\nout meta;\n')


def _source_id(country: str, level: int, snapshot: str) -> str:
    return f"osm-{country}-admin{level}-" + snapshot.replace(":", "").replace("-", "")


def _cache_features(cache: Path, rows: list[dict]) -> dict:
    serializable = [{**row, "geometry": mapping(row["geometry"])} for row in rows]
    content = gzip.compress(json.dumps(serializable, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode(), mtime=0)
    digest = sha256(content)
    path = cache / "features" / (digest + ".json.gz")
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_bytes(content)
    elif sha256(path.read_bytes()) != digest:
        raise ValueError("Changed immutable normalized geometry cache")
    return {"path": path.relative_to(cache).as_posix(), "sha256": digest, "bytes": len(content), "count": len(rows)}


def _geometry_batch(store: OverpassCache, ids: list[int], snapshot: str):
    response, receipt = store.request(geometry_query(ids, snapshot))
    receipts = [receipt]
    relations = {int(row["id"]): row for row in response.get("elements", []) if row.get("type") == "relation"}
    for depth in range(8):
        missing = sorted({int(member["ref"]) for row in relations.values() for member in row.get("members", [])
                          if member.get("type") == "relation" and member.get("role", "") in {"", "inner", "outer"}
                          and int(member["ref"]) not in relations})
        if not missing:
            break
        for offset in range(0, len(missing), 4):
            child_response, child_receipt = store.request(geometry_query(missing[offset:offset+4], snapshot))
            receipts.append(child_receipt)
            children = {int(row["id"]): row for row in child_response.get("elements", []) if row.get("type") == "relation"}
            if not children:
                break
            relations.update(children)
    return relations, receipts


def _geometry_batch_api(store: OverpassCache, ids: list[int], snapshot: str):
    relations, receipts, fetched = {}, [], set()
    pending = list(ids)
    while pending:
        identifier = pending.pop(0)
        if identifier in fetched:
            continue
        if len(fetched) >= 64:
            raise ValueError("OSM API pilot exceeded 64 relation/full requests")
        response, receipt = store.request_url(f"https://api.openstreetmap.org/api/0.6/relation/{identifier}/full.json")
        fetched.add(identifier)
        receipts.append(receipt)
        decoded = full_geometry_relations(response, snapshot)
        # A full parent response contains child references, not recursively all
        # child ways/nodes. Fetch child relations explicitly before polygonizing.
        if identifier not in decoded:
            raise ValueError(f"Missing requested OSM API relation {identifier}")
        relations[identifier] = decoded[identifier]
        pending.extend(int(member["ref"]) for member in decoded[identifier].get("members", [])
                       if member.get("type") == "relation" and member.get("role", "") in {"", "outer", "inner"}
                       and int(member["ref"]) not in fetched)
    return relations, receipts


def prepare_sources(cache: Path = DEFAULT_CACHE, *, countries=("RU", "TR"), mode="pilot", batch_size=4,
                    max_tiles=0, max_relations=0, snapshot=None, endpoint=ENDPOINT,
                    geometry_provider="overpass") -> list[dict]:
    if batch_size < 1 or batch_size > 20 or mode not in {"pilot", "metadata", "tiles"}:
        raise ValueError("Use relation batches 1..20 and pilot/metadata/tiles mode")
    if geometry_provider not in {"overpass", "osm-api"}:
        raise ValueError("Use an explicit overpass/osm-api geometry provider")
    if geometry_provider == "osm-api" and (mode != "pilot" or max_relations > 6):
        raise ValueError("The editing API fallback is restricted to the six-relation pilot")
    directory = Path(cache) / "osm-administration"
    session = directory / "sessions" / (snapshot.replace(":", "").replace("-", "") if snapshot else "pinned")
    state_path = session / "state.json"
    state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {
        "snapshot": snapshot, "completed_tiles": [], "metadata": {}, "prepared": {}, "failures": {}, "raw_receipts": [], "feature_files": []}
    state.setdefault("request_failures", {})
    state.setdefault("metadata_selections", list(state["completed_tiles"]))
    store = OverpassCache(directory, endpoint=endpoint)
    work = [(country, "pilot", BOUNDS, PILOT_IDS[country]) for country in countries] if mode == "pilot" else [
        (country, f"tile-{index}", tile, None) for country in countries for index, tile in enumerate(fixed_tiles(country))]
    processed_tiles, processed_relations = 0, 0
    def checkpoint():
        write_json(state_path, state)
        sources = _sources_from_state(state, directory, countries)
        manifest_countries = tuple(country for country in LEVELS if country in countries
                                   or any(row["country"] == country for row in state["metadata"].values()))
        manifest_sources = _sources_from_state(state, directory, manifest_countries)
        write_json(MANIFEST, {"schema": 1, "bounds": list(BOUNDS), "sources": manifest_sources,
                             "coverage_status": "Partial OSM mapping; no country land-area audit has been completed."})
        return sources
    for country, tile_id, bounds, ids in work:
        key = country + ":" + tile_id
        if key in state["completed_tiles"]:
            continue
        if mode == "metadata" and key in state["metadata_selections"]:
            continue
        if max_tiles and processed_tiles >= max_tiles:
            break
        try:
            query = pilot_metadata_query(country) if mode == "pilot" else metadata_query(country, bounds, state["snapshot"], ids)
            response, receipt = store.request(query)
        except (ValueError, subprocess.CalledProcessError) as error:
            state["request_failures"][key + ":metadata"] = str(error)
            checkpoint()
            raise
        if not state["snapshot"]:
            state["snapshot"] = response.get("osm3s", {}).get("timestamp_osm_base")
            if not state["snapshot"]:
                raise ValueError("Overpass response has no source snapshot")
        state["raw_receipts"].append(receipt)
        if key not in state["metadata_selections"]:
            state["metadata_selections"].append(key)
        eligible = []
        for row in response.get("elements", []):
            tags = row.get("tags", {})
            if row.get("type") != "relation" or tags.get("boundary") != "administrative" or int(tags.get("admin_level", -1)) not in LEVELS[country]:
                raise ValueError("Metadata response violates the administrative selection")
            identifier = str(row["id"])
            state["metadata"][identifier] = {"country": country, "version": row.get("version"), "level": int(tags["admin_level"])}
            if mode == "pilot" and int(identifier) not in PILOT_IDS[country]:
                continue
            if identifier not in state["prepared"] and identifier not in state["failures"]:
                eligible.append(int(identifier))
        checkpoint()
        if mode == "metadata":
            if not eligible:
                state["completed_tiles"].append(key)
            processed_tiles += 1
            checkpoint()
            print(f"OSM {country} {tile_id}: metadata={len(response.get('elements', []))}, geometry_pending={len(eligible)}", flush=True)
            continue
        for offset in range(0, len(eligible), batch_size):
            if max_relations and processed_relations >= max_relations:
                break
            batch = eligible[offset:offset+batch_size]
            if max_relations:
                batch = batch[:max_relations-processed_relations]
            try:
                reader = _geometry_batch_api if geometry_provider == "osm-api" else _geometry_batch
                rows, receipts = reader(store, batch, state["snapshot"])
            except (ValueError, subprocess.CalledProcessError) as error:
                state["request_failures"][key + ":geometry:" + ",".join(map(str, batch))] = str(error)
                checkpoint()
                raise
            state["raw_receipts"].extend(receipts)
            produced = []
            for identifier in batch:
                try:
                    relation = rows.get(identifier)
                    if relation is None or relation.get("version") != state["metadata"][str(identifier)]["version"]:
                        raise ValueError("Missing or different-version relation geometry")
                    level = state["metadata"][str(identifier)]["level"]
                    normalized = normalize_relation(relation, country, _source_id(country, level, state["snapshot"]), related=rows)
                    produced.append(normalized)
                    state["prepared"][str(identifier)] = {"country": country, "level": level, "version": relation["version"]}
                except ValueError as error:
                    state["failures"][str(identifier)] = {"country": country, "reason": str(error)}
                processed_relations += 1
            if produced:
                state["feature_files"].append(_cache_features(directory, produced))
            checkpoint()
            print(f"OSM {country} {tile_id}: prepared={len(state['prepared'])}, failures={len(state['failures'])}", flush=True)
        # A limited tile remains resumable until every selected ID was attempted.
        if all(str(identifier) in state["prepared"] or str(identifier) in state["failures"] for identifier in eligible):
            state["completed_tiles"].append(key)
        processed_tiles += 1
        checkpoint()
        if max_relations and processed_relations >= max_relations:
            break
    return checkpoint()


def _sources_from_state(state: dict, directory: Path, countries) -> list[dict]:
    sources = []
    for country in countries:
        for level in LEVELS[country]:
            entries = {identifier: row for identifier, row in state["prepared"].items() if row["country"] == country and row["level"] == level}
            metadata = [row for row in state["metadata"].values() if row["country"] == country and row["level"] == level]
            snapshot = state.get("snapshot") or "unprepared"
            metadata_ids = {identifier for identifier, row in state["metadata"].items() if row["country"] == country and row["level"] == level}
            failed_ids = {identifier for identifier in metadata_ids if identifier in state["failures"]}
            completed_tiles = [key for key in state["completed_tiles"] if key.startswith(country + ":tile-")]
            scan_complete = len(completed_tiles) == len(fixed_tiles(country)) and metadata_ids.issubset(entries)
            raw_requests = list({receipt["sha256"]: receipt for receipt in state["raw_receipts"]}.values())
            provenance = {"snapshot": snapshot, "country": country, "admin_level": level,
                          "raw_requests": raw_requests, "feature_files": state["feature_files"]}
            provenance_bytes = (json.dumps(provenance, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()
            provenance_sha = sha256(provenance_bytes)
            provenance_path = directory / "provenance" / (provenance_sha + ".json")
            provenance_path.parent.mkdir(parents=True, exist_ok=True)
            if not provenance_path.exists():
                provenance_path.write_bytes(provenance_bytes)
            sources.append({"id": _source_id(country, level, snapshot), "country": country,
                "kind": "local_admin" if country == "TR" and level == 8 else "municipality",
                "admin_level": level, "unit_type": role_for(country, str(level), {})[1],
                "url": raw_requests[0]["url"] if raw_requests else ENDPOINT,
                "endpoints": sorted({receipt["url"] for receipt in raw_requests}),
                "date": snapshot, "license": "ODbL-1.0", "license_url": LICENSE_URL,
                "attribution": "© OpenStreetMap contributors; Open Database License 1.0",
                "normalizer_version": 1, "source_unit_count": len(entries), "metadata_unit_count": len(metadata),
                "prepared_area_count": len(entries), "failed_geometry_count": len(failed_ids),
                "pending_geometry_count": len(metadata_ids - set(entries) - failed_ids),
                "metadata_selections": [key for key in state.get("metadata_selections", []) if key.startswith(country + ":")],
                "sha256": provenance_sha, "bytes": len(provenance_bytes),
                "provenance_path": provenance_path.relative_to(directory).as_posix(),
                "replacement_scope": "feature", "blocks_full_coverage_claim": not scan_complete,
                "cache_directory": directory.name, "feature_files": state["feature_files"],
                "raw_requests": raw_requests,
                "failures": {key: row for key, row in state["failures"].items() if key in failed_ids},
                "completed_tiles": completed_tiles,
                "total_tiles": len(fixed_tiles(country)),
                "request_failures": state["request_failures"],
                "coverage_status": "Partial until a complete tile scan and country land-area audit are recorded.",
                "parent_relationship": "Country selection proven by Overpass ISO area and atlas bbox; finer hierarchy unresolved."})
    return sources


def iter_boundaries(cache: Path, sources: list[dict]) -> Iterator[dict]:
    seen = set()
    for source in sources:
        directory = Path(cache) / source["cache_directory"]
        for receipt in source["feature_files"]:
            payload = _cached_payload(directory, receipt)
            for row in json.loads(gzip.decompress(payload)):
                if row["source"] != source["id"] or row["id"] in seen:
                    continue
                seen.add(row["id"])
                yield {**row, "geometry": shape(row["geometry"])}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--mode", choices=["pilot", "metadata", "tiles"], default="pilot")
    parser.add_argument("--countries", nargs="+", choices=list(LEVELS), default=list(LEVELS))
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--max-tiles", type=int, default=0)
    parser.add_argument("--max-relations", type=int, default=0)
    parser.add_argument("--snapshot")
    parser.add_argument("--endpoint", default=ENDPOINT, help="Explicit Overpass provider; recorded in provenance")
    parser.add_argument("--geometry-provider", choices=["overpass", "osm-api"], default="overpass")
    args = parser.parse_args()
    sources = prepare_sources(args.cache, countries=args.countries, mode=args.mode,
                              batch_size=args.batch_size, max_tiles=args.max_tiles,
                              max_relations=args.max_relations, snapshot=args.snapshot, endpoint=args.endpoint,
                              geometry_provider=args.geometry_provider)
    print(json.dumps({"sources": len(sources), "prepared": sum(source["source_unit_count"] for source in sources),
                      "failures": sum(len(source["failures"]) for source in sources)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
