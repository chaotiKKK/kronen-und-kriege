"""Reproduce only the frozen Iran raw inputs, without invoking normalization.

Uses Windows curl's verified TLS, bounded HTTP ranges, the exact dated archive,
and versioned OSM relation metadata. No Shapely/Godot/runtime dependency.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile
import zlib

import atlas_geofabrik_sources as core

ROOT = Path(__file__).resolve().parents[1]
RAW = Path("audit/IR-qualification-20261110/geofabrik")
RECIPE = ROOT / "tools/fixtures/iran-stage-20261108.json"
RECIPE_SHA256 = "03f4f81688640630b5da6725b6964167b6e2028ef00102e1febcde5ba9d7b4c0"


def load_recipe():
    # The recipe is tracked text; a fresh Git checkout may normalize CRLF/LF.
    # Only line endings are normalized. All payload hashes inside remain exact.
    payload = RECIPE.read_bytes().replace(b"\r\n", b"\n")
    if core.digest(payload) != RECIPE_SHA256:
        raise ValueError("Changed frozen Iranian raw recipe")
    return json.loads(payload)


def province_url(provinces):
    identifiers = ",".join(f"{p['id']}v{p['version']}" for p in provinces)
    return "https://api.openstreetmap.org/api/0.6/relations.json?relations=" + identifiers


def validate_snapshot(snapshot, recipe):
    if any(snapshot.get(k) != recipe["archive"][k] for k in ("url", "bytes", "etag")):
        raise ValueError("Changed Iranian archive URL/size/strong ETag")


def validate_metadata(document, provinces, snapshot):
    expected = {p["id"]: p for p in provinces}
    elements = document.get("elements", [])
    if len(expected) != len(provinces) or len(elements) != len(provinces):
        raise ValueError("Missing/duplicate/extra Iranian province metadata")
    seen = set()
    for element in elements:
        identifier = element.get("id")
        if identifier not in expected or identifier in seen:
            raise ValueError("Unexpected/duplicate Iranian province identity")
        seen.add(identifier)
        p = expected[identifier]
        tags = element.get("tags", {})
        timestamp = element.get("timestamp", "")
        if (element.get("type") != "relation" or element.get("version") != p["version"]
                or timestamp != p["timestamp"] or timestamp > snapshot
                or tags.get("name") != p["name"] or tags.get("boundary") != "administrative"
                or tags.get("admin_level") != "4" or tags.get("ISO3166-2") != p["iso3166_2"]
                or not p["iso3166_2"].startswith("IR-")):
            raise ValueError("Changed Iranian province tags/version/snapshot")
        members = [{k: m[k] for k in ("type", "ref", "role")} for m in element.get("members", [])]
        semantic = {k: element[k] for k in ("type", "id", "version", "timestamp", "tags")}
        semantic["members"] = members
        payload = json.dumps(semantic, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf8")
        if core.digest(payload) != p["semantic_sha256"]:
            raise ValueError("Changed Iranian province semantic fingerprint")


def member_plan(archive, recipe):
    specs = recipe["members"] + [recipe["readme"]]
    selected = core.admin_members(archive.infolist()) + [i for i in archive.infolist() if i.filename == "README"]
    if sorted(i.filename for i in selected) != sorted(s["name"] for s in specs):
        raise ValueError("Missing/extra/duplicate pinned Iranian ZIP members")
    by_name = {i.filename: i for i in selected}
    result = []
    for spec in specs:
        info = by_name[spec["name"]]
        if (info.file_size != spec["bytes"] or info.compress_size != spec["compressed_bytes"]
                or f"{info.CRC:08x}" != spec["crc32"] or info.flag_bits & 1):
            raise ValueError("Changed Iranian member size/compression/CRC/encryption")
        result.append((info, spec))
    return result


def _verify_file(path, spec):
    sha = hashlib.sha256()
    crc = size = 0
    with path.open("rb") as stream:
        while chunk := stream.read(1048576):
            size += len(chunk)
            sha.update(chunk)
            crc = zlib.crc32(chunk, crc)
    if size != spec["bytes"] or sha.hexdigest() != spec["sha256"] or f"{crc:08x}" != spec["crc32"]:
        raise ValueError("Changed Iranian raw member bytes/SHA/CRC: " + path.name)


def stage_member(archive, info, directory, expected):
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / expected["name"]
    receipt_path = path.with_suffix(path.suffix + ".receipt.json")
    if path.exists():
        _verify_file(path, expected)
        if not receipt_path.exists():
            # A crash can occur after the verified-body rename and before its
            # receipt. Reconstruct integrity only; never invent HTTP evidence.
            record = {**expected, "receipt_origin": "integrity_reconstructed_from_exact_pinned_member_bytes"}
            core.write_json(receipt_path, record)
            return record
        record = json.loads(receipt_path.read_text(encoding="utf8"))
        if any(record.get(k) != v for k, v in expected.items()):
            raise ValueError("Changed original Iranian member receipt")
        return record
    temporary = path.with_suffix(path.suffix + ".partial")
    with archive.open(info) as source, temporary.open("wb") as output:
        while chunk := source.read(1048576):
            output.write(chunk)
            if output.tell() > expected["bytes"]:
                raise ValueError("Oversized Iranian member stream")
    _verify_file(temporary, expected)  # ZipExtFile also verifies the original CRC.
    temporary.replace(path)
    core.write_json(receipt_path, expected)
    return dict(expected)


class TransferBudget:
    """Durable conservative upper bound; failed/incomplete attempts keep reservations.

    Charged bytes are not reported as actual transfer measurements. Successful
    bodies use their measured size; failures retain at least their reservation.
    """
    def __init__(self, directory, limit, initial_bytes=0):
        self.path = Path(directory) / "transfer-budget.json"
        if self.path.exists():
            self.state = json.loads(self.path.read_text(encoding="utf8"))
            if self.state.get("limit_bytes") != limit:
                raise ValueError("Changed persisted transfer budget")
        else:
            self.state = {"schema": 1, "limit_bytes": limit, "initial_cached_bytes": initial_bytes, "events": []}
        if not 0 <= self.charged_bytes <= limit:
            raise ValueError("Iran raw transfer budget exceeded")

    @property
    def charged_bytes(self):
        return self.state["initial_cached_bytes"] + sum(e["charged_bytes"] for e in self.state["events"])

    def reserve(self, amount, kind, key):
        if amount < 0 or self.charged_bytes + amount > self.state["limit_bytes"]:
            raise ValueError("Iran raw transfer budget would be exceeded")
        ticket = len(self.state["events"])
        self.state["events"].append({"kind": kind, "key": key, "reserved_bytes": amount,
                                      "charged_bytes": amount, "status": "pending"})
        core.write_json(self.path, self.state)
        return ticket

    def finish(self, ticket, actual_saved_bytes, success):
        event = self.state["events"][ticket]
        if event["status"] != "pending" or actual_saved_bytes < 0:
            raise ValueError("Invalid transfer-budget completion")
        event.update(status="success" if success else "failed", saved_body_bytes=actual_saved_bytes,
                     charged_bytes=actual_saved_bytes if success else max(actual_saved_bytes, event["reserved_bytes"]))
        core.write_json(self.path, self.state)
        if self.charged_bytes > self.state["limit_bytes"]:
            raise ValueError("Iran raw transfer budget exceeded")


def validate_cached_range(receipt, data, start, end, recipe):
    pin = recipe["archive"]
    if (receipt.get("url") != pin["url"] or receipt.get("etag") != pin["etag"]
            or receipt.get("start") != start or receipt.get("end") != end
            or receipt.get("bytes") != len(data) or receipt.get("sha256") != core.digest(data)
            or not 0 <= start <= end < pin["bytes"]
            or len(data) > recipe["maximum_single_range_bytes"]):
        raise ValueError("Changed cached Iranian HTTP-range provenance")
    core.validate_range(receipt["headers"], start, end, pin["bytes"], pin["etag"], len(data))


def _cached_ranges(directory, recipe):
    records = []
    for path in sorted((directory / "ranges").glob("*.receipt.json")):
        match = re.fullmatch(r"(\d+)-(\d+)\.receipt\.json", path.name)
        if not match:
            raise ValueError("Unrecognized Iranian range receipt")
        start, end = map(int, match.groups())
        record = json.loads(path.read_text(encoding="utf8"))
        validate_cached_range(record, path.with_name(f"{start}-{end}.bin").read_bytes(), start, end, recipe)
        records.append(record)
    return records


def _metadata_record(directory, recipe, *, repair_missing=False):
    path = directory / "regions-original-tags.json"
    if path.stat().st_size > recipe["maximum_metadata_bytes"]:
        raise ValueError("Oversized cached Iranian province metadata")
    payload = path.read_bytes()
    receipt_path = path.with_suffix(".receipt.json")
    if not receipt_path.exists() and repair_missing:
        validate_metadata(json.loads(payload), recipe["provinces"], recipe["snapshot"])
        record = {"url": province_url(recipe["provinces"]), "bytes": len(payload), "sha256": core.digest(payload),
                  "receipt_origin": "integrity_reconstructed_from_exact_pinned_relation_elements",
                  "url_role": "reproduction_locator_only_original_transport_receipt_missing"}
        core.write_json(receipt_path, record)
    record = json.loads(receipt_path.read_text(encoding="utf8"))
    prefix = "https://api.openstreetmap.org/api/0.6/relations.json?relations="
    query = record.get("url", "")
    legacy_ids = {str(p["id"]) for p in recipe["provinces"]}
    is_legacy_original = query.startswith(prefix) and set(query[len(prefix):].split(",")) == legacy_ids
    if (query != province_url(recipe["provinces"]) and not is_legacy_original
            or record.get("bytes") != len(payload) or record.get("sha256") != core.digest(payload)
            or len(payload) > recipe["maximum_metadata_bytes"]):
        raise ValueError("Changed original Iranian metadata provenance/hash")
    validate_metadata(json.loads(payload), recipe["provinces"], recipe["snapshot"])
    return record


def _complete(directory, recipe):
    stage = json.loads((directory / "staging-receipt.json").read_text(encoding="utf8"))
    validate_snapshot(stage.get("snapshot", {}), recipe)
    if (stage.get("status") != "complete-cache-only" or stage.get("url") != recipe["archive"]["url"]
            or stage.get("osm_timestamp") != recipe["snapshot"]):
        raise ValueError("Changed completed Iranian raw-stage identity")
    actual = stage.get("members", []) + [stage.get("readme", {})]
    expected = recipe["members"] + [recipe["readme"]]
    if len(actual) != len(expected):
        raise ValueError("Changed completed Iranian member count")
    for spec in expected:
        matches = [r for r in actual if r.get("name") == spec["name"]]
        if len(matches) != 1 or any(matches[0].get(k) != v for k, v in spec.items()):
            raise ValueError("Changed completed Iranian member inventory")
        _verify_file(directory / "members" / spec["name"], spec)
    metadata = _metadata_record(directory, recipe)
    ranges = _cached_ranges(directory, recipe)
    total = sum(r["bytes"] for r in ranges)
    if total != stage["total_range_bytes"] or total + metadata["bytes"] > recipe["budget_bytes"]:
        raise ValueError("Changed Iranian raw-stage byte total/budget")
    TransferBudget(directory, recipe["budget_bytes"], total + metadata["bytes"])
    return {**stage, "reused": True, "new_request_body_bytes": 0}


def fetch_metadata(url, body, headers, maximum):
    result = subprocess.run(["curl.exe", "--fail", "--location", "--silent", "--show-error",
        "--connect-timeout", "20", "--max-time", "90", "--max-filesize", str(maximum),
        "--dump-header", str(headers), "--output", str(body), url], capture_output=True, text=True)
    return result.returncode, result.stderr


@contextmanager
def _exclusive_stage(directory):
    directory.mkdir(parents=True, exist_ok=True)
    lock = directory / ".raw-stage.lock"
    with lock.open("x", encoding="ascii") as output:
        output.write("Exclusive Iran raw preparation; remove only after verifying its process has stopped.\n")
    try:
        yield
    finally:
        lock.unlink()


def stage_sources(cache, *, check_only=False, recipe=None, remote_factory=None, metadata_fetcher=None):
    recipe = load_recipe() if recipe is None else recipe
    directory = Path(cache) / RAW
    if (directory / "staging-receipt.json").exists():
        return _complete(directory, recipe)  # Fully read-only, including original legacy receipts.
    if check_only:
        raise FileNotFoundError("No complete pinned Iranian raw stage")
    remote_factory = remote_factory or core.RangeSource
    metadata_fetcher = metadata_fetcher or fetch_metadata
    with _exclusive_stage(directory):
        remote = remote_factory(directory, recipe["archive"]["url"])
        validate_snapshot(remote.snapshot, recipe)  # Must precede all ZIP-body reads.
        cached = _cached_ranges(directory, recipe)
        existing_metadata = directory / "regions-original-tags.json"
        metadata = _metadata_record(directory, recipe, repair_missing=True) if existing_metadata.exists() else None
        initial = sum(r["bytes"] for r in cached) + (metadata["bytes"] if metadata else 0)
        initial += sum(p.stat().st_size for p in directory.rglob("*.partial"))
        budget = TransferBudget(directory, recipe["budget_bytes"], initial)
        new_bytes = 0

        def fetch(start, end):
            nonlocal new_bytes
            parts = []
            for position in range(start, end + 1, recipe["maximum_single_range_bytes"]):
                last = min(end, position + recipe["maximum_single_range_bytes"] - 1)
                path = directory / "ranges" / f"{position}-{last}.bin"
                receipt_path = path.with_suffix(".receipt.json")
                if receipt_path.exists():
                    body = path.read_bytes()
                    validate_cached_range(json.loads(receipt_path.read_text(encoding="utf8")), body, position, last, recipe)
                else:
                    ticket = budget.reserve(last - position + 1, "range", f"{position}-{last}")
                    try:
                        body = remote.fetch(position, last)
                        record = json.loads(receipt_path.read_text(encoding="utf8"))
                        validate_cached_range(record, body, position, last, recipe)
                    except Exception:
                        saved = path if path.exists() else path.with_suffix(".partial")
                        budget.finish(ticket, saved.stat().st_size if saved.exists() else 0, False)
                        raise
                    budget.finish(ticket, len(body), True)
                    new_bytes += len(body)
                parts.append(body)
            return b"".join(parts)

        with zipfile.ZipFile(core.RemoteZip(remote.snapshot["bytes"], fetch)) as archive:
            records = [stage_member(archive, info, directory / "members", spec)
                       for info, spec in member_plan(archive, recipe)]
        readme = (directory / "members" / "README").read_text(encoding="utf8")
        if "data as of " + recipe["snapshot"] not in readme:
            raise ValueError("Changed pinned Iranian README snapshot")
        if metadata is None:
            path = directory / "regions-original-tags.json"
            partial = path.with_suffix(".partial")
            headers = path.with_suffix(".headers.txt")
            url = province_url(recipe["provinces"])
            ticket = budget.reserve(recipe["maximum_metadata_bytes"], "metadata", url)
            try:
                result, error = metadata_fetcher(url, partial, headers, recipe["maximum_metadata_bytes"])
                if result or core.parse_headers(headers.read_text(encoding="iso-8859-1")).get("status") != 200:
                    raise RuntimeError("Fixed-version province metadata request failed: " + error.strip())
                body = partial.read_bytes()
                if len(body) > recipe["maximum_metadata_bytes"]:
                    raise ValueError("Oversized Iranian province metadata")
                validate_metadata(json.loads(body), recipe["provinces"], recipe["snapshot"])
            except Exception:
                budget.finish(ticket, partial.stat().st_size if partial.exists() else 0, False)
                raise
            budget.finish(ticket, len(body), True)
            new_bytes += len(body)
            partial.replace(path)
            metadata = {"url": url, "bytes": len(body), "sha256": core.digest(body),
                        "semantic_fingerprints": "tools/fixtures/iran-stage-20261108.json"}
            core.write_json(path.with_suffix(".receipt.json"), metadata)
        ranges = _cached_ranges(directory, recipe)
        stage = {"status": "complete-cache-only", "url": recipe["archive"]["url"],
                 "snapshot": remote.snapshot, "osm_timestamp": recipe["snapshot"],
                 "members": [r for r in records if r["name"] != "README"],
                 "readme": next(r for r in records if r["name"] == "README"),
                 "total_range_bytes": sum(r["bytes"] for r in ranges),
                 "budget_bytes": recipe["budget_bytes"], "budget_charged_upper_bound": budget.charged_bytes,
                 "raw_only": True, "normalization_performed": False,
                 "territorial_assignment_performed": False}
        core.write_json(directory / "staging-receipt.json", stage)
        _complete(directory, recipe)
        return {**stage, "reused": False, "new_request_body_bytes": new_bytes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=ROOT / ".tools/atlas_sources")
    parser.add_argument("--check-only", action="store_true", help="Validate complete raw inputs read-only; never fetch")
    args = parser.parse_args()
    result = stage_sources(args.cache, check_only=args.check_only)
    print(json.dumps({k: result[k] for k in ("status", "reused", "new_request_body_bytes", "total_range_bytes")}, indent=2))
    print("Raw inputs verified. Normalization is a separate explicit atlas_iran_sources.py command.")


if __name__ == "__main__":
    main()
