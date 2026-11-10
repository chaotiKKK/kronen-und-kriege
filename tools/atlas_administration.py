"""Administrative roles and an area-based coverage audit, separate from gameplay."""
from __future__ import annotations

import math
from collections import defaultdict
import importlib
import json
from shapely import make_valid
from shapely.geometry import GeometryCollection
from shapely.ops import transform, unary_union

RADIUS_METRES = 6_371_000.0


def bkg_unit_role(kind: str, properties: dict) -> tuple[str, str]:
    native_type = str(properties.get("bez") or {"region": "Land", "district": "Kreis", "municipality": "Gemeinde"}[kind])
    if kind == "municipality" and native_type == "Gemeindefreies Gebiet":
        return "local_admin", native_type
    return kind, native_type


def natural_earth_role(country: str, properties: dict) -> tuple[str | None, str]:
    # These four sources describe the local authority directly, despite the
    # provider's generic admin_1 filename and empty type_en field.
    local_units = {"MT": "Local Council", "LI": "Gemeinde", "AD": "Parròquia", "SM": "Castello"}
    if country in local_units:
        return "municipality", local_units[country]
    native = str(properties.get("type") or properties.get("type_en") or "Region")
    english = str(properties.get("type_en") or "")
    # The original NE tags conflict with the native ISO unit identities here:
    # Minsk oblast and Saare county are not local municipal governments.
    iso = str(properties.get("iso_3166_2") or "")
    if country == "BY" and iso == "BY-MI":
        return "region", "Woblast"
    if country == "EE" and iso == "EE-74":
        return "region", "Maakond"
    if country == "AZ" and native in {"Sahar", "Sahari"}:
        # Independent city administrations are not the municipalities within
        # them. The municipal boundary needs its own positive territorial proof:
        # https://ganja-ih.gov.az/az/belediyyeler.html (Kapaz excludes Hajikend).
        return "region", native
    if country == "LU" and english == "District":
        return None, native
    if country == "FR" and english in {"Metropolitan department", "Overseas department"}:
        return "district", "Département"
    if country == "IT" and english == "Province":
        return "district", "Provincia"
    if country == "PT" and english == "District":
        return "district", "Distrito"
    if (country == "ES" and english == "Autonomous Community"
            and str(properties.get("adm1_code", "")).startswith("ESP-")):
        # In pinned NE v5.1.2 these 50 ISO province identities carry the wrong
        # generic type. The independent autonomous-community frame is separate.
        return "district", "Provincia"
    if english in {"Municipality", "Commune", "Commune|Municipality"}:
        return "municipality", native
    return "region", native


def _equal_area(geometry):
    def coordinates(x, y, z=None):
        # Equal-area cylindrical projection on a sphere. The same projection
        # is used in numerator and denominator, including high latitudes.
        return ([RADIUS_METRES * math.radians(value) for value in x],
                [RADIUS_METRES * math.sin(math.radians(value)) for value in y])
    return transform(coordinates, geometry)


def land_coverage(land, units) -> dict:
    land = make_valid(land)
    total = float(_equal_area(land).area)
    if total <= 0:
        raise ValueError("Coverage requires a real nonempty land polygon")
    mapped = unary_union([make_valid(unit) for unit in units]) if units else GeometryCollection()
    covered = float(_equal_area(mapped.intersection(land)).area) if not mapped.is_empty else 0.0
    return {"fraction": min(1.0, max(0.0, covered / total)),
            "land_area_km2": total / 1_000_000,
            "covered_land_area_km2": covered / 1_000_000}


def _territory_rows(rows, sources, lands):
    """Preserve source-unit parts on every declared, independently masked land.

    Split IDs identify display parts, not newly invented local governments.
    The source unit ID and original territorial attribution remain explicit.
    """
    for row in rows:
        source = sources.get(row["source"], {})
        geometry = make_valid(row["geometry"])
        scope = source.get("scope_countries", [row["country"]])
        explicit_clip = _scope_clip_requested(source)
        if not explicit_clip and (len(scope) == 1 or row.get("country_assignment_method") == "official_code"):
            # A verified source-country key outranks an exaggerated/generalised
            # small-country map. Keep genuine islands and boundary detail.
            if row["country"] in lands:
                yield {**row, "geometry": geometry}
            continue
        parts = []
        for country in scope:
            if country not in lands or not geometry.intersects(lands[country]):
                continue
            part = geometry.intersection(lands[country])
            if not part.is_empty and part.area > 0:
                parts.append((country, part))
        for country, part in parts:
            item = {**row, "country": country, "geometry": part}
            if explicit_clip:
                item.update(source_geometry_clipped_to_scope=True,
                            scope_clip_basis=source["scope_clip_basis"],
                            scope_clip_evidence_url=source["scope_clip_evidence_url"])
            if row.get("parent_id") and not row["parent_id"].startswith("country:"):
                item["source_parent_id"] = row["parent_id"]
            if len(parts) > 1:
                item.update(id=row["id"] + ":atlas-part:" + country,
                            source_unit_id=row["id"], source_country=row["country"],
                            territorial_part=True)
            if country != row["country"]:
                item["source_country"] = row["country"]
                item["parent_id"] = "country:" + country
            yield item


def _scope_clip_requested(source):
    requested = source.get("clip_to_scope", False)
    if not isinstance(requested, bool):
        raise ValueError("Scope clipping requires an explicit boolean flag")
    if requested:
        scope = source.get("scope_countries")
        basis = source.get("scope_clip_basis")
        evidence = source.get("scope_clip_evidence_url")
        if (not isinstance(scope, list) or not scope
                or any(not isinstance(code, str) or not code for code in scope)
                or len(scope) != len(set(scope))
                or not isinstance(basis, str) or not basis.strip()
                or not isinstance(evidence, str) or not evidence.startswith("https://")):
            raise ValueError("Scope clipping requires distinct territorial codes, an explicit derivation basis and source evidence")
    return requested


def _source_quality_blocked(source, country):
    global_flag = source.get("blocks_full_coverage_claim", False)
    blocked = source.get("blocks_full_coverage_claim_countries", [])
    scope = source.get("scope_countries", [source.get("country")])
    if (not isinstance(global_flag, bool) or not isinstance(blocked, list)
            or any(not isinstance(code, str) or code not in scope for code in blocked)
            or len(blocked) != len(set(blocked))):
        raise ValueError("Source quality blocks require distinct explicitly scoped country codes and a boolean global flag")
    return global_flag or country in blocked


def _restore_territorial_parents(features, part_ids):
    existing = {feature["id"] for feature in features}
    for feature in features:
        source_parent = feature.get("source_parent_id")
        parent = part_ids.get((source_parent, feature.get("country")))
        if parent in existing and parent != feature["id"]:
            feature["parent_id"] = parent


def _source_priority(source, default):
    priority = source.get("merge_priority", default)
    if isinstance(priority, bool) or not isinstance(priority, int) or not 0 <= priority <= 9:
        raise ValueError("Local source merge priority must be an integer from 0 to 9")
    return priority


def _regional_frame_kinds(source):
    kinds = source.get("replace_natural_earth_kinds", [])
    if (not isinstance(kinds, list) or any(kind not in {"region", "district"} for kind in kinds)
            or any(kind != source.get("kind") for kind in kinds)):
        raise ValueError("Unqualified regional frame replacement role")
    return set(kinds)


def _replace_reference_features(features, item, row):
    """Replace named coarse regional references, never a whole partial frame."""
    identifiers = row.get("replaces_reference_features", [])
    if not identifiers:
        return
    if (not isinstance(identifiers, list) or not all(isinstance(value, str) for value in identifiers)
            or len(set(identifiers)) != len(identifiers)
            or not str(row.get("replacement_evidence_url", "")).startswith("https://")):
        raise ValueError("Unqualified regional reference replacement")
    old = [feature for feature in features if feature["id"] in identifiers]
    if (len(old) != len(identifiers) or item["kind"] not in {"region", "district"}
            or any(feature["source"] != "natural-earth-regions"
                   or feature["country"] != item["country"] or feature["kind"] != item["kind"] for feature in old)):
        raise ValueError("Regional reference replacement has missing or unrelated target")
    item["replaced_reference_features"] = old
    features[:] = [feature for feature in features if feature["id"] not in identifiers]
    for feature in features:
        if feature["parent_id"] in identifiers:
            feature["replaced_reference_parent_id"] = feature["parent_id"]
            feature["parent_id"] = item["id"]


def _replace_exact_local_features(features, sources):
    """Replace only named, admitted local units after validating every pair.

    This separate contract deliberately cannot remove whole country sources.
    The original fallback remains unless its actual successor and evidence
    survived normalization, scope filtering and feature creation.
    """
    index = {feature['id']: feature for feature in features}
    replacements = {}
    successors = {}
    for source in sources:
        declared = source.get('replaces_feature_ids', [])
        if not declared:
            continue
        evidence = source.get('feature_replacement_evidence', [])
        if (source.get('replacement_scope') != 'feature'
                or source.get('kind') not in {'municipality', 'local_admin'}
                or not isinstance(declared, list) or not all(isinstance(x, str) for x in declared)
                or len(set(declared)) != len(declared) or not isinstance(evidence, list)
                or len(evidence) != len(declared)):
            raise ValueError('Unqualified exact local replacement declaration')
        evidenced = set()
        for proof in evidence:
            target = proof.get('replaces_feature_id')
            successor = proof.get('source_unit_id')
            old, new = index.get(target), index.get(successor)
            urls = proof.get('evidence_urls')
            if (target not in declared or target in evidenced or target in replacements
                    or not old or not new or target == successor
                    or new.get('source') != source['id']
                    or old.get('source') != f"geofabrik-{source['country']}-admin8-{source['kind']}"
                    or old.get('country') != source['country'] or new.get('country') != source['country']
                    or old.get('kind') != source['kind'] or new.get('kind') != source['kind']
                    or old.get('parent_id') != proof.get('parent_id')
                    or new.get('parent_id') != proof.get('parent_id')
                    or not proof.get('identity_method')
                    or new.get('original_source_id') != proof.get('original_source_id')
                    or not isinstance(urls, list) or not urls
                    or not all(isinstance(url, str) and url.startswith('https://') for url in urls)
                    or new.get('replaces_feature_ids') != [target]):
                raise ValueError(f'Missing, ambiguous or unrelated exact replacement: {target}')
            evidenced.add(target)
            replacements[target] = successor
            successors[successor] = new
        if evidenced != set(declared):
            raise ValueError('Exact replacement evidence does not match declared targets')
    actual = {f['id']: f.get('replaces_feature_ids', []) for f in features if f.get('replaces_feature_ids')}
    if set(actual) != set(successors):
        raise ValueError('Undeclared admitted local feature replacement')
    # Mutation begins only after the complete contract was validated.
    for successor, new in successors.items():
        new['replaced_feature_ids'] = list(actual[successor])
    features[:] = [feature for feature in features if feature['id'] not in replacements]
    for feature in features:
        if feature.get('parent_id') in replacements:
            feature['replaced_source_parent_id'] = feature['parent_id']
            feature['parent_id'] = replacements[feature['parent_id']]
    return replacements


def _merge_verified_aliases(features, alias_rows, geometries):
    """Coalesce only explicitly attested, independently rechecked source pairs."""
    index = {feature["id"]: feature for feature in features}
    redirects = {}
    for row in alias_rows:
        proof = row["verified_source_alias"]
        target_id = proof.get("target_id")
        target = index.get(target_id)
        feature = index[row["id"]]
        if target is None or target_id == row["id"] or target_id in redirects:
            raise ValueError(f"Missing or chained verified source alias: {row['id']}")
        required = ("target_record_id", "target_source", "common_id", "country", "admin_level",
                    "original_name", "geometry_intersection_over_union", "audit_file",
                    "audit_sha256", "geofabrik_cache_sha256")
        if any(key not in proof for key in required):
            raise ValueError(f"Incomplete verified source alias evidence: {row['id']}")
        source_level = str(row.get("source_admin_level", row.get("admin_level", "")))
        target_level = str(target.get("source_admin_level", target.get("admin_level", "")))
        source_name = str(row.get("original_name") or row["name"])
        target_name = str(target.get("original_name") or target["name"])
        identity = (
            row["country"] == target["country"] == proof["country"]
            and row["kind"] == target["kind"]
            and source_level == target_level == str(proof["admin_level"])
            and str(row.get("original_source_id", "")) == str(proof["common_id"])
            and str(target.get("osm_relation_id", "")) == str(proof["common_id"])
            and target_id == "osm:relation:" + str(proof["common_id"])
            and target.get("osm_record_id") == proof["target_record_id"]
            and int(target.get("osm_relation_version", 0)) > 0
            and target.get("osm_record_id") == "r%s@%s" % (
                target.get("osm_relation_id"), int(target.get("osm_relation_version", 0)))
            and target["source"] == proof["target_source"]
            and source_name == target_name == proof["original_name"])
        if not identity:
            raise ValueError(f"Changed verified source alias identity: {row['id']}")
        source_geometry, target_geometry = geometries[row["id"]], geometries[target_id]
        union_area = source_geometry.union(target_geometry).area
        actual_iou = source_geometry.intersection(target_geometry).area / union_area if union_area else 0.0
        reported_iou = float(proof["geometry_intersection_over_union"])
        if not math.isfinite(reported_iou) or actual_iou <= 0.999 or abs(actual_iou - reported_iou) > 1e-6:
            raise ValueError(f"Changed verified source alias geometry: {row['id']}")
        target.setdefault("source_aliases", []).append({
            "id": feature["id"], "source": feature["source"], "name": feature["name"],
            "parent_id": feature["parent_id"], "original_source_id": str(proof["common_id"]),
            "geometry_intersection_over_union": actual_iou,
            "verification": dict(proof)})
        if (target["parent_id"] == "country:" + target["country"]
                and feature["parent_id"] != "country:" + feature["country"]
                and feature.get("parent_relationship") == "inferred-area-containment"):
            target["original_parent_id"] = target["parent_id"]
            target["original_parent_relationship"] = target.get("parent_relationship", "")
            target["parent_id"] = feature["parent_id"]
            target["parent_relationship"] = feature["parent_relationship"]
            target["parent_source_alias"] = feature["id"]
            if "parent_overlap_fraction" in feature:
                target["parent_overlap_fraction"] = feature["parent_overlap_fraction"]
        redirects[feature["id"]] = target_id
    if redirects:
        features[:] = [feature for feature in features if feature["id"] not in redirects]
        for feature in features:
            if feature["parent_id"] in redirects:
                feature["aliased_parent_id"] = feature["parent_id"]
                feature["parent_id"] = redirects[feature["parent_id"]]
    return redirects


def is_local_coverage_area(row):
    if row["kind"] in {"municipality", "local_admin"}:
        return True
    return (row.get("local_government_role") in {"municipality", "local_admin"}
            and bool(row.get("local_government_role_evidence"))
            and not row.get("local_government_represented_by"))


def supplement(features, pool, provinces, make_feature, country_geometries, base_local_geometries, root, cache,
               independent_reference_ids=None):
    """Merge prepared sources; never download during an unfinished provider build."""
    providers = [
        ("atlas_overture_sources", "atlas_overture_sources.json", 1),
        ("atlas_geofabrik_sources", "atlas_geofabrik_sources.json", 2),
        ("atlas_communal_sources", "atlas_communal_sources.json", 2),
        ("atlas_tunisia_sources", "atlas_tunisia_sources.json", 3),
        ("atlas_armenia_sources", "atlas_armenia_sources.json", 3),
        ("atlas_jordan_sources", "atlas_jordan_sources.json", 3),
        ("atlas_cyprus_sources", "atlas_cyprus_sources.json", 4),
        ("atlas_north_cyprus_sources", "atlas_north_cyprus_sources.json", 5),
        ("atlas_iran_sources", "atlas_iran_sources.json", 3),
        ("atlas_regional_sources", "atlas_regional_sources.json", 3),
        ("atlas_official_sources", "atlas_official_sources.json", 3),
        ("atlas_morocco_sources", "atlas_morocco_sources.json", 3),
        ("atlas_osm_sources", "atlas_osm_sources.json", 4),
        ("atlas_sakarya_sources", "atlas_sakarya_sources.json", 5),
    ]
    sources, pending, batches = [], [], []
    for module_name, filename, priority in providers:
        manifest = root / "data" / filename
        if not manifest.exists():
            pending.append(module_name)
            print(f"Noch nicht vorbereitete Quelle: {module_name}", flush=True)
            continue
        entries = json.loads(manifest.read_text(encoding="utf-8"))["sources"]
        for entry in entries:
            _regional_frame_kinds(entry)
            _source_quality_blocked(entry, None)
            _scope_clip_requested(entry)
        module = importlib.import_module(module_name)
        sources.extend(entries)
        batches.append((module, entries, priority))

    # Resolve municipal source preference before adding geometry. German BKG
    # keys stay authoritative; explicit national sources outrank conflated data.
    local_priority = {"DE": 10}
    for _, entries, priority in batches:
        for entry in entries:
            if entry.get("administrative_geometry_eligible") is False:
                continue
            if entry.get("kind") == "municipality" and entry.get("replacement_scope") != "feature":
                for country in entry.get("scope_countries", [entry.get("country")]):
                    local_priority[country] = max(_source_priority(entry, priority), local_priority.get(country, 0))
    local_shapes = defaultdict(list)
    trusted_local_shapes = defaultdict(list)
    alias_rows, alias_geometries = [], {}
    local_sources = defaultdict(set)
    quality_blocks = defaultdict(bool)
    excluded_sources = defaultdict(set)
    excluded_units = defaultdict(list)
    terminal_administrations = defaultdict(list)
    territorial_part_ids = {}
    for index, (country, geometry, source_id) in enumerate(base_local_geometries):
        if country not in local_priority or country == "DE":
            local_shapes[country].append(("base:" + str(index), geometry))
            trusted_local_shapes[country].append(("base:" + str(index), geometry))
            local_sources[country].add(source_id)

    # Replace only obsolete NE local units when a verified municipal provider
    # exists. NE regions are replaced separately only by an actual new frame.
    features[:] = [f for f in features if not (
        f["source"] == "natural-earth-regions" and f["kind"] == "municipality"
        and f["country"] in local_priority)]
    frame_countries = set()
    regional_frames = defaultdict(set)
    source_lookup = {source["id"]: source for source in sources}
    for module, entries, priority in batches:
        for row in _territory_rows(module.iter_boundaries(cache, entries), source_lookup, country_geometries):
            country = row["country"]
            if module.__name__ == "atlas_overture_sources" and country in {"MT", "LI", "AD", "SM"}:
                # These microstates' existing NE polygons already represent
                # verified local authorities; a generic frame must not demote them.
                continue
            geometry = row["geometry"]
            source = source_lookup.get(row["source"], {})
            if country not in country_geometries:
                continue
            if source.get("administrative_geometry_eligible") is False:
                quality_blocks[country] = True
                excluded_sources[country].add(source["id"])
                continue
            if row.get("administrative_geometry_eligible") is False:
                quality_blocks[country] = True
                excluded_units[country].append({"id": row["id"], "source": row["source"], "name": row["name"],
                    "reason": row.get("administrative_ineligibility_note", "Administrative role not qualified"),
                    "evidence": row.get("administrative_ineligibility_evidence_url", row.get("administrative_ineligibility_evidence", "")),
                    "review": {key: value for key, value in row.items() if key.startswith("administrative_")},
                    "source_unit_type": row.get("unit_type", ""),
                    "source_admin_level": row.get("source_admin_level", row.get("admin_level"))})
                continue
            row_priority = _source_priority(source, priority)
            if row["kind"] == "municipality" and row_priority < local_priority.get(country, row_priority):
                continue
            geometry = make_valid(geometry)
            if geometry.is_empty:
                continue
            extra = {key: value for key, value in row.items() if key not in {
                "id", "name", "kind", "geometry", "parent_id", "country", "source"}}
            display_geometry = geometry
            if source.get("requires_physical_land_clip"):
                required = source.get("land_reference_source_id")
                if not required or (independent_reference_ids or {}).get(country) != required:
                    raise ValueError(f"Physical display clipping for {row['id']} requires verified land reference {required}")
                display_geometry = geometry.intersection(country_geometries[country])
                extra["display_clip_source"] = required
            parent = row.get("parent_id", "country:" + country)
            if country != row["country"]:
                extra["source_country"] = row["country"]
                parent = "country:" + country
            item = make_feature(pool, provinces, display_geometry, feature_id=row["id"],
                name=row["name"], kind=row["kind"], parent_id=parent,
                country=country, source=row["source"],
                tolerance=0.02 if row["kind"] == "municipality" else 0.04, **extra)
            if not item:
                continue
            _replace_reference_features(features, item, row)
            features.append(item)
            territorial_part_ids[(row.get("source_unit_id", row["id"]), country)] = item["id"]
            regional_frames[country].update(_regional_frame_kinds(source))
            if row.get("verified_source_alias"):
                alias_rows.append(row)
            if row.get("verified_source_alias") or row.get("osm_record_id"):
                alias_geometries[row["id"]] = geometry
            if module.__name__ in {"atlas_overture_sources", "atlas_geofabrik_sources"} and row["kind"] in {"region", "district"}:
                frame_countries.add(country)
            if is_local_coverage_area(row):
                local_shapes[country].append((row["id"], geometry))
                if row.get("terminal_scope") and row.get("local_government_role") == "local_admin":
                    terminal_administrations[country].append({
                        "id": row["id"], "source": row["source"], "unit_type": row.get("unit_type", ""),
                        "scope": row["terminal_scope"], "evidence": row["local_government_role_evidence"],
                        "municipal_boundary_status": row.get("municipal_boundary_status", "not-established-by-this-source")})
                if not _source_quality_blocked(source, country):
                    trusted_local_shapes[country].append((row["id"], geometry))
                local_sources[country].add(row["source"])
                quality_blocks[country] |= _source_quality_blocked(source, country)

    features[:] = [f for f in features if not (
        f["source"] == "natural-earth-regions" and (
            (f["country"] in frame_countries and f["kind"] != "municipality")
            or f["kind"] in regional_frames[f["country"]]))]
    exact_replacements = _replace_exact_local_features(features, sources)
    # Removed fallbacks must also disappear from both coverage numerators.
    for collection in (local_shapes, trusted_local_shapes):
        for country in collection:
            collection[country] = [(identifier, geometry) for identifier, geometry in collection[country]
                                   if identifier not in exact_replacements]
    _restore_territorial_parents(features, territorial_part_ids)
    removed_aliases = _merge_verified_aliases(features, alias_rows, alias_geometries)
    feature_index = {feature["id"]: feature for feature in features}
    # A partial country query does not disqualify the independently verified
    # same local unit. Transfer that qualification only to its chosen geometry,
    # never by retaining the discarded alias's larger area in the numerator.
    for country, qualified in trusted_local_shapes.items():
        qualified_ids = {identifier for identifier, _ in qualified}
        for old_id, target_id in removed_aliases.items():
            if old_id in qualified_ids and target_id not in qualified_ids:
                qualified.append((target_id, alias_geometries[target_id]))
                qualified_ids.add(target_id)
                feature_index[target_id].setdefault("coverage_qualification_source_aliases", []).append(old_id)
    ids = {f["id"] for f in features}
    for feature in features:
        if feature["parent_id"] and feature["parent_id"] not in ids:
            # Do not invent a missing intermediary administrative polygon.
            feature["source_parent_id"] = feature["parent_id"]
            feature["parent_id"] = "country:" + feature["country"]
            feature["parent_resolution"] = "country_fallback"

    coverage = {}
    for country, land in sorted(country_geometries.items()):
        if land.is_empty or land.area <= 0:
            continue
        result = land_coverage(land, [geometry for identifier, geometry in local_shapes[country]
                                    if identifier not in removed_aliases])
        blocked = quality_blocks[country]
        if blocked and trusted_local_shapes[country]:
            trusted = land_coverage(land, [geometry for identifier, geometry in trusted_local_shapes[country]
                                         if identifier not in removed_aliases])
            result["unblocked_source_fraction"] = trusted["fraction"]
            blocked = trusted["fraction"] < 0.95
        result.update({"sources": sorted(local_sources[country]),
            "blocks_full_coverage_claim": blocked,
            "status": "complete" if result["fraction"] >= 0.95 and not blocked else (
                "source_review" if blocked else "gap"),
            "threshold": 0.95,
            "measurement": "spherical equal-area union of actual local land polygons"})
        if excluded_sources[country]:
            result["excluded_administrative_sources"] = sorted(excluded_sources[country])
        if excluded_units[country]:
            result["excluded_administrative_units"] = sorted(excluded_units[country], key=lambda row: row["id"])
        if terminal_administrations[country]:
            result["nonmunicipal_terminal_administration"] = sorted(terminal_administrations[country], key=lambda row: row["id"])
        coverage[country] = result
        print(f"Örtliche Verwaltungsabdeckung {country}: {100 * result['fraction']:.2f}% ({result['status']})", flush=True)
    return sources, coverage, pending
