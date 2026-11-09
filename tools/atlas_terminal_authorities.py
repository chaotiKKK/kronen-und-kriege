"""Apply documented terminal-administration roles without creating geometry.

The classification is deliberately independent of a geometric coverage audit.
Raw law documents stay in the source cache and never enter a feature or the
runtime source manifest. See docs/atlas-terminal-authorities.md for limits.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "data/atlas_terminal_authorities.json"
DEFAULT_CACHE = ROOT / ".tools/atlas_sources"
SOURCE_ID = "atlas-terminal-authorities"
REVIEWED_ROLES = {"MC": "municipality", "VA": "central_state_administration",
                  "GI": "territorial_government"}


def load_manifest(path=DEFAULT_MANIFEST) -> dict:
    """Load only the three reviewed structural classifications, never shapes."""
    manifest = json.loads(Path(path).read_text(encoding="utf-8"))
    if manifest.get("schema") != 1 or manifest.get("id") != SOURCE_ID:
        raise ValueError("Unsupported terminal-authority manifest")
    if manifest.get("classification_is_geometric_coverage") is not False:
        raise ValueError("Terminal classification cannot claim geometric coverage")
    rows = manifest.get("authorities", [])
    if len(rows) != 3 or {row.get("country") for row in rows} != set(REVIEWED_ROLES):
        raise ValueError("Only the reviewed country scopes MC, VA and GI are supported")
    for row in rows:
        country = row["country"]
        native = row.get("native_scope", {})
        expected_count = 1 if country == "MC" else None
        if native.get("authority_role") != REVIEWED_ROLES[country] or native.get("municipality_count") != expected_count:
            raise ValueError(f"Unsupported authority role for country {country}")
        if not row.get("checked_at") or not row.get("uncertainty") or not row.get("evidence"):
            raise ValueError(f"Missing evidence or limits for country {country}")
        for evidence in row["evidence"]:
            if not all(evidence.get(key) for key in ("id", "url", "provisions", "source_sha256", "cache_receipt")):
                raise ValueError(f"Incomplete primary evidence for country {country}")
    return manifest


def _inside(base: Path, relative: str) -> Path:
    path = (base / relative).resolve()
    if not path.is_relative_to(base.resolve()):
        raise ValueError("Evidence cache path leaves its declared root")
    return path


def verify_evidence_receipts(manifest: dict, cache_root=DEFAULT_CACHE) -> list[dict]:
    """Offline build-time audit of cached HTTP receipts and exact raw hashes."""
    cache_root = Path(cache_root)
    verified = []
    for row in manifest["authorities"]:
        for evidence in row["evidence"]:
            receipt_path = _inside(cache_root, evidence["cache_receipt"])
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            if receipt.get("id") != evidence["id"] or receipt.get("source_url") != evidence["url"]:
                raise ValueError("Evidence receipt identity or source URL mismatch")
            raw_path = _inside(receipt_path.parent, receipt["raw_file"])
            raw = raw_path.read_bytes()
            digest = hashlib.sha256(raw).hexdigest()
            if digest != receipt.get("sha256") or digest != evidence["source_sha256"]:
                raise ValueError("Evidence raw SHA-256 hash mismatch")
            if len(raw) != receipt.get("bytes"):
                raise ValueError("Evidence raw byte count mismatch")
            verified.append(receipt)
    return verified


def apply_scopes(features: list[dict], coverage: dict, source_manifest: dict) -> dict:
    """Annotate existing coverage in-place; return applied country definitions.

    Geometric fractions, areas, provenance and all feature IDs stay intact.
    Monaco gains a reference to its legally countrywide Commune on the existing
    country feature. VA and GI gain no municipality feature or municipal role.
    Unknown countries and missing coverage records are left unchanged.
    """
    manifest = load_manifest()
    applied = {}
    for definition in manifest["authorities"]:
        country = definition["country"]
        if country not in coverage:
            continue
        evidence = [{"source": SOURCE_ID, "url": item["url"], "title": item["title"],
                     "version": item["version"], "provisions": deepcopy(item["provisions"]),
                     "source_sha256": item["source_sha256"]} for item in definition["evidence"]]
        coverage[country].update(status="single_jurisdiction", measurement_applicable=False,
            classification_is_geometric_coverage=False,
            native_scope=deepcopy(definition["native_scope"]), authority_evidence=evidence,
            authority_classification_source=SOURCE_ID, authority_checked_at=definition["checked_at"],
            authority_evidence_basis=definition["evidence_basis"],
            authority_uncertainty=definition["uncertainty"])
        applied[country] = deepcopy(definition)
        if country == "MC":
            for feature in features:
                if feature.get("id") != "country:MC" or feature.get("kind") != "country":
                    continue
                role = {"authority_id": "authority:MC:commune", "authority_name": "Commune de Monaco",
                        "authority_role": "municipality", "native_role": "Commune / Municipalité",
                        "scope": "countrywide", "evidence_source": SOURCE_ID,
                        "geometry_created": False, "coextensive_basis": "Constitution Article 78"}
                roles = feature.setdefault("additional_authority_roles", [])
                if not any(item.get("authority_id") == role["authority_id"] for item in roles):
                    roles.append(role)
    if applied:
        classification_bytes = DEFAULT_MANIFEST.read_bytes()
        source_manifest[SOURCE_ID] = {"id": SOURCE_ID, "name": "Amtlich belegte terminale Zivilverwaltung",
            "kind": "administrative_classification", "geometry_source": False,
            "classification_is_geometric_coverage": False, "date": manifest["checked_at"],
            "url": "https://github.com/chaotiKKK/kronen-und-kriege/blob/main/data/atlas_terminal_authorities.json",
            "bytes": len(classification_bytes), "sha256": hashlib.sha256(classification_bytes).hexdigest(),
            "license": "Nicht anwendbar: eigene Strukturmetadaten; amtliche Rechtstexte werden nur verlinkt",
            "license_url": "",
            "attribution": "Eigene Strukturklassifikation mit Belegen von Legimonaco, Stato della Città del Vaticano und HM Government of Gibraltar",
            "scope_countries": sorted(applied), "evidence": [
                {"country": country, "url": item["url"], "title": item["title"],
                 "version": item["version"], "source_sha256": item["source_sha256"]}
                for country, definition in sorted(applied.items()) for item in definition["evidence"]],
            "coverage_note": "Structural administration classification; not measured complete land coverage."}
    return applied
