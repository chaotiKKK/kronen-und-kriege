"""Deterministic gameplay regions; the administrative atlas stays a separate layer."""
from __future__ import annotations

from dataclasses import dataclass, field
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import struct
from typing import Any, Mapping

from shapely import make_valid, set_precision, union, voronoi_polygons
from shapely.geometry import LineString, MultiPoint, Point, Polygon
from shapely.ops import linemerge, split, substring, unary_union
from shapely.strtree import STRtree


@dataclass(frozen=True)
class RegionBuildConfig:
    target_count: int = 108
    minimum_count: int = 100
    maximum_count: int = 115
    target_area: float = 5000.0
    minimum_per_realm: int = 4
    hard_min: float = .45
    hard_max: float = 1.8

    def __post_init__(self):
        if not 0 < self.minimum_count <= self.target_count <= self.maximum_count:
            raise ValueError("Ungültige Regionszahl")
        if not math.isfinite(self.target_area) or self.target_area <= 0 or self.minimum_per_realm < 1:
            raise ValueError("Ungültige Zielfläche oder Mindestzahl")


@dataclass(frozen=True)
class FrozenInputs:
    europe_geometry: Mapping[str, Any]
    cities: list[Mapping[str, Any]]
    atlas_edges: list[Mapping[str, Any]]
    source_status: Mapping[str, str]
    input_hashes: Mapping[str, str]
    provenance: list[Mapping[str, Any]] = field(default_factory=list)


@dataclass(frozen=True)
class BuildResult:
    manifest: dict
    geometry: bytes
    audit: dict
    frame: Any


def canonical_json_bytes(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def allocate_realm_counts(areas, target, minimum=1):
    if not areas or any(not math.isfinite(a) or a <= 0 for a in areas.values()):
        raise ValueError("Großraumflächen müssen positiv sein")
    if target < len(areas) * minimum:
        raise ValueError("Zielzahl unterschreitet die Mindestzahl")
    total = math.fsum(areas.values())
    raw = {key: target * area / total for key, area in sorted(areas.items())}
    counts = {key: max(minimum, math.floor(value)) for key, value in raw.items()}
    while sum(counts.values()) > target:
        candidates = [key for key in counts if counts[key] > minimum]
        key = min(candidates, key=lambda k: (raw[k] - counts[k], k))
        counts[key] -= 1
    while sum(counts.values()) < target:
        key = min(counts, key=lambda k: (-(raw[k] - counts[k]), k))
        counts[key] += 1
    return counts


def polygons(geometry):
    if geometry.is_empty:
        return []
    if geometry.geom_type == "Polygon":
        return [geometry]
    return [p for g in getattr(geometry, "geoms", []) for p in polygons(g)]


def parts_geometry(parts):
    return set_precision(unary_union([make_valid(Polygon(part)) for part in parts if len(part) >= 3]), 1e-7)


def realm_frames(europe):
    frames, parents, parent_realms = {}, {}, {}
    assigned = Polygon()
    removed = 0.0
    for realm_id, realm in sorted(europe["realms"].items()):
        raw_parents = {pid: parts_geometry(p["parts"]) for pid, p in sorted(realm["provinces"].items())}
        raw_frame = unary_union(list(raw_parents.values()))
        frame = raw_frame.difference(assigned)
        removed += raw_frame.area - frame.area
        if frame.is_empty:
            raise ValueError(f"Leerer Großraum {realm_id}")
        frames[realm_id] = frame
        # Resolve all inherited overlaps, including seams inside one realm.
        parent_assigned = Polygon()
        for pid, parent in raw_parents.items():
            effective = parent.intersection(frame).difference(parent_assigned)
            if effective.is_empty:
                raise ValueError(f"Leere Migrationselternfläche {pid}")
            parents[pid] = effective
            parent_realms[pid] = realm_id
            parent_assigned = unary_union([parent_assigned, effective])
        assigned = unary_union([assigned, frame])
    return frames, parents, parent_realms, removed


def stable_anchors(frame, realm, cities, count):
    pool = {}
    for pid, province in sorted(realm["provinces"].items()):
        xy = tuple(province.get("label", []))
        if len(xy) == 2 and frame.covers(Point(xy)):
            pool[xy] = (0, 0, pid)
    for city in sorted(cities, key=lambda c: str(c.get("id", ""))):
        xy = tuple(city["point"])
        if frame.covers(Point(xy)):
            pool.setdefault(xy, (1, -int(city.get("population", 0)), str(city["id"])))
    # Sparse regions need geographic candidates independent of modern city density.
    minx, miny, maxx, maxy = frame.bounds
    grid = max(12, math.ceil(math.sqrt(count)) * 5)
    for row in range(grid):
        for col in range(grid):
            xy = (minx + (col + .5) * (maxx - minx) / grid,
                  miny + (row + .5) * (maxy - miny) / grid)
            if frame.covers(Point(xy)):
                pool.setdefault(xy, (2, 0, f"grid:{row:03}:{col:03}"))
    if len(pool) < count:
        raise ValueError("Zu wenige stabile Anker")
    first = min(pool, key=lambda xy: (pool[xy], xy))
    selected = [first]
    pool.pop(first)
    while len(selected) < count:
        chosen = min(pool, key=lambda xy: (
            -min((xy[0] - p[0]) ** 2 + (xy[1] - p[1]) ** 2 for p in selected), pool[xy], xy))
        selected.append(chosen)
        pool.pop(chosen)
    return selected


def relaxed_cells(frame, anchors):
    if len(anchors) == 1:
        return [frame]
    target = frame.area / len(anchors)
    for iteration in range(81):
        cells = [set_precision(cell, 1e-7).intersection(frame) for cell in
                 voronoi_polygons(MultiPoint(anchors), extend_to=frame.envelope, ordered=True).geoms]
        if iteration == 80 or all(.9 <= cell.area / target <= 1.1 for cell in cells):
            return cells
        anchors = []
        for cell in cells:
            point = cell.centroid
            if not cell.covers(point):
                point = max(polygons(cell), key=lambda p: p.area).representative_point()
            anchors.append((point.x, point.y))
    raise AssertionError("Unreachable")


def normalized_shares(areas):
    total = math.fsum(areas.values())
    if total <= 0:
        raise ValueError("Leere Schnittanteile")
    result, running = {}, 0.0
    items = sorted(areas.items())
    for index, (key, area) in enumerate(items):
        share = 1.0 - running if index == len(items) - 1 else area / total
        if share <= 0:
            raise ValueError("Nichtpositiver Schnittanteil")
        result[key] = share
        running += share
    return result


def prefer_qualified_edges(cells, edges, config):
    if not edges:
        return cells, 0
    lines = [LineString(e["points"]) for e in edges if len(e.get("points", [])) > 1]
    tree = STRtree(lines)
    cells = list(cells)
    changed = 0
    for i in range(len(cells)):
        for j in range(i + 1, len(cells)):
            boundary = cells[i].boundary.intersection(cells[j].boundary)
            if boundary.length <= .5:
                continue
            old_left = max(polygons(cells[i]), key=lambda p: p.area)
            old_right = max(polygons(cells[j]), key=lambda p: p.area)
            combined = unary_union([old_left, old_right])
            shared = old_left.boundary.intersection(old_right.boundary)
            if shared.length <= .5:
                continue
            if shared.geom_type != "LineString":
                shared = linemerge(shared)
            if shared.geom_type != "LineString":
                line_parts = [g for g in shared.geoms if g.geom_type == "LineString"]
                if not line_parts:
                    continue
                shared = max(line_parts, key=lambda line: line.length)
            start, end = Point(shared.coords[0]), Point(shared.coords[-1])
            candidates = sorted((int(k) for k in tree.query(boundary.buffer(20))),
                                key=lambda k: (start.distance(lines[k]) + end.distance(lines[k]), k))
            for k in candidates[:12]:
                edge = lines[k]
                arc = substring(edge, edge.project(start), edge.project(end))
                if arc.geom_type != "LineString" or arc.length < .25 * shared.length:
                    continue
                if shared.hausdorff_distance(arc) > 20:
                    continue
                cutting = LineString([shared.coords[0], *arc.coords, shared.coords[-1]])
                if not cutting.is_simple:
                    continue
                try:
                    pieces = [set_precision(p, 1e-7) for p in polygons(split(combined, cutting))]
                except ValueError:
                    continue
                if len(pieces) != 2 or any(not p.is_valid for p in pieces):
                    continue
                if any(not config.hard_min <= p.area / config.target_area <= config.hard_max for p in pieces):
                    continue
                if any(4 * math.pi * p.area / p.length ** 2 < .08 for p in pieces):
                    continue
                pieces.sort(key=lambda p: -p.intersection(cells[i]).area)
                if pieces[0].intersection(old_left).area < .5 * old_left.area:
                    continue
                if pieces[1].intersection(old_right).area < .5 * old_right.area:
                    continue
                if unary_union(pieces).symmetric_difference(combined).area > 1e-7:
                    continue
                if old_left.symmetric_difference(pieces[0]).area < 1e-9:
                    break
                cells[i] = unary_union([pieces[0], cells[i].difference(old_left)])
                cells[j] = unary_union([pieces[1], cells[j].difference(old_right)])
                changed += 1
                break
    return cells, changed


def repair_connected_partition(frame, cells):
    cells = list(cells)
    transfers = 0
    for component in sorted(polygons(frame), key=lambda p: (-p.area, p.centroid.x, p.centroid.y)):
        for _ in range(len(cells) * 4):
            transfer = None
            for i, cell in enumerate(cells):
                fragments = sorted(polygons(cell.intersection(component)), key=lambda p: (-p.area, p.centroid.x, p.centroid.y))
                for fragment in fragments[1:]:
                    candidates = []
                    for j, other in enumerate(cells):
                        if j == i:
                            continue
                        shared = fragment.boundary.intersection(other.buffer(1e-7)).length
                        if shared > 1e-6:
                            candidates.append((-shared, other.area, j))
                    if candidates:
                        transfer = (i, min(candidates)[2], fragment)
                        break
                if transfer:
                    break
            if transfer is None:
                break
            i, j, fragment = transfer
            cells[i] = cells[i].difference(fragment)
            cells[j] = union(cells[j], fragment, grid_size=1e-7)
            transfers += 1
    return [unary_union(polygons(cell)) for cell in cells], transfers


def _exception(cell, frame, ratio, config):
    ps = polygons(cell)
    reason, evidence = "", {}
    if len(ps) > 1:
        # A valid exception consists of actual separate frame components only.
        components = polygons(frame)
        disconnected_inside_component = any(len(polygons(cell.intersection(p))) > 1 for p in components)
        if not disconnected_inside_component:
            reason = "island_group"
            evidence = {"component_count": len(ps), "largest_component_area": max(p.area for p in ps)}
    if not config.hard_min <= ratio <= config.hard_max and not reason:
        matching = [p for p in polygons(frame) if p.covers(cell)]
        if matching and matching[0].area < config.hard_min * config.target_area:
            reason = "small_island"
            evidence = {"frame_component_area": matching[0].area}
        elif 4 * math.pi * cell.area / cell.length ** 2 < .08:
            reason = "narrow_coast"
            evidence = {"compactness": 4 * math.pi * cell.area / cell.length ** 2}
    return reason, evidence


def build_regions(inputs, config):
    frames, parents, parent_realms, removed = realm_frames(inputs.europe_geometry)
    counts = allocate_realm_counts({key: value.area for key, value in frames.items()},
                                   config.target_count, config.minimum_per_realm)
    regions, shapes, used_names = [], {}, set()
    snapped_pairs = 0
    fragment_transfers = 0
    for realm_id, frame in sorted(frames.items()):
        anchors = stable_anchors(frame, inputs.europe_geometry["realms"][realm_id], inputs.cities, counts[realm_id])
        cells = relaxed_cells(frame, anchors)
        cells, snapped = prefer_qualified_edges(cells, inputs.atlas_edges, config)
        snapped_pairs += snapped
        cells, transfers = repair_connected_partition(frame, cells)
        fragment_transfers += transfers
        for index, cell in enumerate(sorted(cells, key=lambda c: (c.centroid.x, c.centroid.y)), 1):
            ps = sorted(polygons(cell), key=lambda p: (-p.area, p.centroid.x, p.centroid.y))
            if any(p.interiors for p in ps):
                raise ValueError("Geometrie mit Loch benötigt ein explizites Ringformat")
            point = ps[0].representative_point()
            candidates = sorted([c for c in inputs.cities if cell.covers(Point(c["point"]))],
                                key=lambda c: (-int(c.get("population", 0)), c["id"]))
            name = next((str(c["name"]) for c in candidates if c["name"] not in used_names),
                        f"{realm_id.title()} {index}")
            used_names.add(name)
            region_id = f"{realm_id}__{index:02}"
            intersections = {pid: cell.intersection(p).area for pid, p in parents.items()
                             if parent_realms[pid] == realm_id and cell.intersection(p).area > 1e-8}
            reason, evidence = _exception(cell, frame, cell.area / config.target_area, config)
            regions.append({"id": region_id, "name": name, "kind": "game_region", "realm_id": realm_id,
                            "capital_anchor": [point.x, point.y], "area": cell.area,
                            "area_ratio": cell.area / config.target_area,
                            "parts": [[[x, y] for x, y in list(p.exterior.coords)[:-1]] for p in ps],
                            "bounds": list(cell.bounds), "neighbours": [],
                            "legacy_region_shares": normalized_shares(intersections),
                            "legacy_parent_shares": {}, "exception_reason": reason,
                            "exception_evidence": evidence})
            shapes[region_id] = cell
    for pid, parent in sorted(parents.items()):
        areas = {r["id"]: shapes[r["id"]].intersection(parent).area for r in regions
                 if r["realm_id"] == parent_realms[pid] and shapes[r["id"]].intersection(parent).area > 1e-8}
        for rid, share in normalized_shares(areas).items():
            next(r for r in regions if r["id"] == rid)["legacy_parent_shares"][pid] = share
    boundaries = []
    for i, left in enumerate(regions):
        for right in regions[i + 1:]:
            boundary = shapes[left["id"]].boundary.intersection(shapes[right["id"]].boundary)
            if boundary.length > .5:
                left["neighbours"].append(right["id"])
                right["neighbours"].append(left["id"])
                boundaries.append(boundary)
    qualified = [LineString(e["points"]) for e in inputs.atlas_edges if len(e.get("points", [])) > 1]
    tree = STRtree(qualified)
    qualified_length = 0.0
    for boundary in boundaries:
        matched = [boundary.intersection(qualified[int(i)]) for i in tree.query(boundary)]
        if matched:
            qualified_length += unary_union(matched).length
    geometry = bytearray()
    for r in regions:
        r["geometry_refs"] = []
        for part in r["parts"]:
            r["geometry_refs"].append([len(geometry) // 8, len(part)])
            for x, y in part:
                geometry.extend(struct.pack("<ff", x, y))
    payload = bytes(geometry)
    manifest = {"schema": 1, "region_count": len(regions), "regions": regions,
                "geometry": "res://data/game_region_geometry.bin",
                "source_status": dict(sorted(inputs.source_status.items())),
                "input_hashes": dict(sorted(inputs.input_hashes.items())),
                "legacy_parent_ids": sorted(parents), "geometry_sha256": hashlib.sha256(payload).hexdigest()}
    manifest["catalog_hash"] = catalog_hash(manifest, payload)
    audit = {"region_count": len(regions), "qualified_boundary_length": qualified_length,
             "snapped_pairs": snapped_pairs,
             "fragment_transfers": fragment_transfers,
             "realm_overlap_area_removed": removed, "provenance": inputs.provenance,
             "catalog_hash": manifest["catalog_hash"]}
    return BuildResult(manifest, payload, audit, unary_union(list(frames.values())))


def runtime_manifest(manifest):
    stored = deepcopy(manifest)
    stored.pop("catalog_hash", None)
    for region in stored["regions"]:
        region.pop("parts", None)
    return stored


def catalog_hash(manifest, geometry):
    return hashlib.sha256(canonical_json_bytes(runtime_manifest(manifest)) + geometry).hexdigest()


def validate_manifest(manifest, frame, config):
    errors, shapes, ids, totals = [], {}, set(), {}
    regions = manifest.get("regions", [])
    if not config.minimum_count <= len(regions) <= config.maximum_count or manifest.get("region_count") != len(regions):
        errors.append("Regionszahl außerhalb des Vertrags")
    for r in regions:
        rid = r.get("id", "")
        if not rid or rid in ids:
            errors.append(f"Doppelte/fehlende ID {rid}")
        ids.add(rid)
        cell = parts_geometry(r.get("parts", []))
        shapes[rid] = cell
        if r.get("kind") != "game_region" or cell.is_empty or not cell.is_valid:
            errors.append(f"{rid}: ungültige Spielregion")
            continue
        if not math.isclose(r.get("area", -1), cell.area, abs_tol=1e-7):
            errors.append(f"{rid}: falsche Fläche")
        if not cell.covers(Point(r["capital_anchor"])):
            errors.append(f"{rid}: Hauptstadt außerhalb")
        reason = r.get("exception_reason", "")
        evidence = r.get("exception_evidence", {})
        if reason and (reason not in {"island_group", "small_island", "narrow_coast"} or not evidence):
            errors.append(f"{rid}: unbelegte Ausnahme")
        if (len(polygons(cell)) > 1 or not config.hard_min <= r["area_ratio"] <= config.hard_max) and not reason:
            errors.append(f"{rid}: Flächen-/Zusammenhangsausnahme fehlt")
        shares = r.get("legacy_region_shares", {})
        if not shares or any(not math.isfinite(s) or s <= 0 for s in shares.values()) or abs(sum(shares.values()) - 1) > 1e-6:
            errors.append(f"{rid}: ungültige Regionsanteile")
        for pid, share in r.get("legacy_parent_shares", {}).items():
            if not math.isfinite(share) or share <= 0:
                errors.append(f"{rid}: ungültiger Elternanteil")
            totals[pid] = totals.get(pid, 0) + share
    for pid in manifest.get("legacy_parent_ids", totals):
        if abs(totals.get(pid, 0) - 1) > 1e-6:
            errors.append(f"{pid}: Elternanteile ergeben nicht 1")
    by_id = {r["id"]: r for r in regions}
    for i, r in enumerate(regions):
        for n in r["neighbours"]:
            if n not in ids or n == r["id"] or r["id"] not in by_id[n]["neighbours"]:
                errors.append(f"{r['id']}: ungültiger Nachbar {n}")
        for other in regions[i + 1:]:
            if shapes[r["id"]].intersection(shapes[other["id"]]).area > 1e-6:
                errors.append(f"Überlappung {r['id']}/{other['id']}")
    if unary_union(list(shapes.values())).symmetric_difference(frame).area > max(1e-7, frame.area * 1e-9):
        errors.append("Abdeckung unvollständig")
    return errors


def load_frozen_inputs(root):
    root = Path(root)
    europe = json.loads((root / "data/europe_geometry.json").read_text(encoding="utf-8"))
    atlas = json.loads((root / "data/atlas.json").read_text(encoding="utf-8"))
    payload = (root / "data/atlas_geometry.bin").read_bytes()
    edges = []
    for feature in atlas["features"]:
        if feature.get("kind") not in {"region", "district"} or feature.get("administrative_geometry_eligible") is False:
            continue
        for offset, count in feature.get("paths", []):
            if count < 3 or offset < 0 or (offset + count) * 8 > len(payload):
                continue
            points = [list(struct.unpack_from("<ff", payload, (offset + i) * 8)) for i in range(count)]
            if points[0] != points[-1]:
                points.append(points[0])
            edges.append({"id": feature["id"], "points": points, "source": feature.get("source", "")})
    paths = ["data/europe_geometry.json", "data/atlas.json", "data/atlas_geometry.bin", "tools/game_regions.py"]
    hashes = {p: sha256_file(root / p) for p in paths}
    statuses = {c: atlas["administrative_coverage"][c]["status"] for c in
                ("AZ", "CNM", "IL", "KZ", "LB", "LY", "MA", "TR")}
    return FrozenInputs(europe, atlas["cities"], edges, statuses, hashes, atlas["sources"])


def write_outputs(result, output_dir, receipt_path):
    output_dir, receipt_path = Path(output_dir), Path(receipt_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    stored = runtime_manifest(result.manifest)
    digest = catalog_hash(stored, result.geometry)
    stored["catalog_hash"] = digest
    sources = {"schema": 1, "source_status": stored["source_status"], "input_hashes": stored["input_hashes"],
               "provenance": result.audit.get("provenance", []), "raw_sources_rehashed": False,
               "exceptions": [{"id": r["id"], "reason": r["exception_reason"], "evidence": r["exception_evidence"]}
                              for r in stored["regions"] if r["exception_reason"]]}
    (output_dir / "game_regions.json").write_bytes(canonical_json_bytes(stored) + b"\n")
    (output_dir / "game_region_geometry.bin").write_bytes(result.geometry)
    (output_dir / "game_region_sources.json").write_bytes(canonical_json_bytes(sources) + b"\n")
    receipt_path.write_bytes(canonical_json_bytes({k: v for k, v in result.audit.items() if k != "provenance"}) + b"\n")
    return digest
