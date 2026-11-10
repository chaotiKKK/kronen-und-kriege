"""Freeze and inspect native Banger Queens candidates, without launching Godot.

All output must be below project/build/verify. Source data and candidates are read
only. The PCK reader targets the real unencrypted Godot 4.5 format-3 export.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE_IDS = (
    "DLS-CY-reform2024-CYSTAT20260609",
    "geofabrik-CYN-261108-law15-2022",
    "geofabrik-JO-Ruwaished-terminal-20261108",
    "geofabrik-IR-Dehestan-20261108",
    "DLS-SBA-overlapping-local-areas-2024-CYSTAT20260609",
    "gbOpen-IRN-ADM4",
)
SAMPLE_COUNTRIES = ("CY", "CYN", "JO", "IR", "ESB")
SAMPLE_SOURCE_BY_COUNTRY = dict(zip(SAMPLE_COUNTRIES, SOURCE_IDS[:-1], strict=True))
SBA_SOURCE_ID = SAMPLE_SOURCE_BY_COUNTRY["ESB"]
FORBIDDEN = {"reference", "tests", "tools", "docs", ".tools", "build", "preview"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def file_record(path):
    with path.open("rb") as stream:
        sha = hashlib.file_digest(stream, "sha256").hexdigest()
    return {"bytes": path.stat().st_size, "sha256": sha}


def safe_output(project, output):
    output = output.resolve()
    require(output.is_relative_to((project / "build/verify").resolve()), "Output must be below build/verify")
    output.mkdir(parents=True, exist_ok=True)
    return output


def forbidden(names):
    bad = []
    for name in names:
        name = name.removeprefix("res://").replace("\\", "/").removeprefix("assets/")
        parts = PurePosixPath(name).parts
        if parts and (parts[0] in FORBIDDEN or name.lower().endswith((".keystore", ".jks"))):
            bad.append(name)
    return bad


class EmbeddedPack:
    def __init__(self, path):
        self.path = path
        self.stream = path.open("rb")
        self.length = path.stat().st_size
        self.stream.seek(-12, 2)
        pack_size, magic = struct.unpack("<QI", self.stream.read(12))
        require(magic == 0x43504447 and 112 < pack_size < self.length, "Missing embedded PCK footer")
        self.base = self.length - 12 - pack_size
        self.stream.seek(self.base)
        header = self.stream.read(112)
        magic, format_version, major, minor, patch, flags, file_base, directory = struct.unpack_from("<6IQQ", header)
        require((magic, format_version, major, minor) == (0x43504447, 3, 4, 5), "Expected actual Godot 4.5 format-3 embedded PCK")
        require(flags == 2, "Expected a relative, unencrypted PCK directory")
        require(112 <= directory < pack_size, "Invalid PCK directory offset")
        self.header = dict(format=format_version, engine=f"{major}.{minor}.{patch}", flags=flags,
                           pack_base=self.base, file_base=file_base, directory=directory, pack_bytes=pack_size)
        self.stream.seek(self.base + directory)
        count, = struct.unpack("<I", self.stream.read(4))
        require(0 < count < 100000, "Invalid PCK entry count")
        self.entries = {}
        for _ in range(count):
            size, = struct.unpack("<I", self.stream.read(4))
            require(0 < size <= 16384, "Invalid PCK path length")
            name = self.stream.read(size).rstrip(b"\0").decode("utf-8").removeprefix("res://")
            offset, length = struct.unpack("<QQ", self.stream.read(16))
            md5 = self.stream.read(16).hex()
            file_flags, = struct.unpack("<I", self.stream.read(4))
            require(file_flags == 0, f"Encrypted/removed PCK entry: {name}")
            require(name not in self.entries and ".." not in PurePosixPath(name).parts, f"Duplicate/unsafe PCK entry: {name}")
            absolute = self.base + file_base + offset
            require(self.base + 112 <= absolute <= absolute + length <= self.base + directory,
                    f"PCK payload outside data area: {name}")
            self.entries[name] = dict(offset=absolute, bytes=length, md5=md5)
        require(self.stream.tell() <= self.length - 12, "PCK directory outside declared pack")

    def read(self, name):
        entry = self.entries[name]
        self.stream.seek(entry["offset"])
        raw = self.stream.read(entry["bytes"])
        require(len(raw) == entry["bytes"], f"Truncated PCK payload: {name}")
        return raw

    def close(self):
        self.stream.close()


def prepare(args):
    project = args.project.resolve()
    output = safe_output(project, args.output)
    require(not (output / "frozen-data.json").exists(), "Use a new output directory; frozen snapshot already exists")
    atlas = json.loads((project / "data/atlas.json").read_text(encoding="utf-8"))
    version_match = re.search(r'^config/version="([^"]+)"', (project / "project.godot").read_text(encoding="utf-8"), re.M)
    require(version_match is not None and version_match.group(1) == args.version, "Expected version differs from the actual project version")
    actual_version = version_match.group(1)
    require(len([f for f in atlas["features"] if f.get("country") == "CYN" and f.get("kind") == "municipality"]) == 18,
            "Expected eighteen northern municipalities")
    require(len([f for f in atlas["features"] if f.get("country") == "CY" and f.get("kind") == "municipality"]) == 20,
            "Expected twenty CY municipalities")
    selected = {s["id"]: s for s in atlas["sources"] if s["id"] in SOURCE_IDS}
    require(set(selected) == set(SOURCE_IDS), "Missing qualified/quarantined source metadata")
    records = {"res://" + path.relative_to(project).as_posix(): file_record(path)
               for path in sorted((project / "data").iterdir()) if path.suffix in (".json", ".bin")}
    source_features = {identifier: [f for f in atlas["features"] if f.get("source") == identifier]
                       for identifier in SOURCE_IDS}
    sba_source = selected[SBA_SOURCE_ID]
    sba_features = source_features[SBA_SOURCE_ID]
    require(sba_source.get("country") == "ESB" and sba_source.get("scope_countries") == ["ESB"], "Additive SBA source must have ESB-only scope")
    require(sba_source.get("kind") == "local_admin" and sba_source.get("replacement_scope") == "feature", "SBA source must be additive feature-scope local administration")
    require(sba_source.get("municipal_authorities_created") == 0, "SBA addition must not create municipalities")
    require(len(sba_features) == 2 and {f.get("name") for f in sba_features} == {"Lysi", "Ammochostos"}, "Expected exactly two original SBA names: Lysi and Ammochostos")
    require(all(f.get("country") == "ESB" and f.get("kind") == "local_admin" and f.get("original_name") == f.get("name") for f in sba_features),
            "SBA original identities must remain ESB-only local_admin, without CY/CYN imports")
    sba_notice = sba_source.get("territorial_scope_note", "")
    require(all(token in sba_notice for token in ("Crown", "Militär", "keine neuen", "CYN", "außerhalb ESB")), "German SBA Crown/military/territorial caveats are incomplete")
    sba_fields = ("id", "name", "original_name", "country", "kind", "source", "territorial_scope_note", "actual_unrestricted_exercise_of_powers_verified")
    expectations = {
        "version": actual_version,
        "android_version_code": args.android_code,
        "files": records,
        "feature_count": len(atlas["features"]),
        "kind_counts": dict(Counter(f["kind"] for f in atlas["features"])),
        "country_kind_counts": {c: dict(Counter(f["kind"] for f in atlas["features"] if f.get("country") == c))
                                for c in SAMPLE_COUNTRIES},
        "sources": selected,
        "coverage": {c: atlas["administrative_coverage"][c] for c in ("CY", "CYN", "CNM", "ESB", "WSB", "JO", "IR")},
        "sample_ids": {c: next(f["id"] for f in source_features[identifier] if f.get("country") == c)
                       for c, identifier in SAMPLE_SOURCE_BY_COUNTRY.items()},
        "sba_source_id": SBA_SOURCE_ID,
        "sba_features": [{key: feature[key] for key in sba_fields if key in feature} for feature in sba_features],
        "forbidden_roots": sorted(FORBIDDEN),
        "output": output.as_posix(),
        "sandbox": (output / "sandbox").as_posix(),
        "frozen_at": datetime.now(timezone.utc).isoformat(),
    }
    (output / "frozen-data.json").write_text(json.dumps(expectations, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    template = Path(__file__).with_name("atlas-release-smoke.gd.in").read_text(encoding="utf-8")
    # JSON object/array/boolean/null syntax is parsed at runtime, not as GDScript.
    payload = json.dumps(json.dumps(expectations, ensure_ascii=True, separators=(",", ":")))
    (output / "packaged-smoke.gd").write_text(template.replace("__EXPECTATIONS_JSON__", payload), encoding="utf-8")
    print(json.dumps({"stage": "frozen", "output": str(output), "features": expectations["feature_count"], "files": records}, ensure_ascii=True))


def static(args):
    project = args.project.resolve()
    output = safe_output(project, args.output)
    frozen = json.loads(args.frozen.read_text(encoding="utf-8"))
    for name, expected in frozen["files"].items():
        require(file_record(project / name.removeprefix("res://")) == expected, f"Frozen source drift: {name}")
    artifact_records = {str(path.resolve()): file_record(path) for path in (args.exe, args.apk)}
    report = {"stage": "static-package-verified", "version": frozen["version"], "files": frozen["files"], "artifacts": artifact_records}
    pack = EmbeddedPack(args.exe)
    try:
        require(not forbidden(pack.entries), "Forbidden embedded paths: " + repr(forbidden(pack.entries)))
        for name, entry in pack.entries.items():
            require(hashlib.md5(pack.read(name)).hexdigest() == entry["md5"], f"PCK payload checksum mismatch: {name}")
        for resource, expected in frozen["files"].items():
            name = resource.removeprefix("res://")
            require(name in pack.entries, f"Missing PCK data: {name}")
            raw = pack.read(name)
            require({"bytes": len(raw), "sha256": digest(raw)} == expected, f"PCK actual byte mismatch: {name}")
        report["windows_pack"] = {**pack.header, "entries": len(pack.entries), "all_entry_md5_valid": True, "forbidden_paths": []}
    finally:
        pack.close()
    spec = importlib.util.spec_from_file_location("native_template_reader", project / "tools/prepare_windows_export_template.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    pe = module.inspect_pe(args.exe.read_bytes())
    versions = [module.version_info(raw) for key, raw in pe["resources"].items() if key[0] == 16]
    require(versions and all(v["file_version"] == frozen["version"] + ".0" and v["product_version"] == frozen["version"] + ".0" for v in versions),
            "Native EXE version differs from frozen expected release")
    manifests = [raw for key, raw in pe["resources"].items() if key[0] == 24]
    require(len(manifests) == 1, "Expected one original native manifest")
    module.validate_manifest(manifests[0])
    report["windows_resources"] = {"versions": versions, "manifest": {"bytes": len(manifests[0]), "sha256": digest(manifests[0])}}
    template_path = project / ".tools/windows-export-template/banger-queens-windows-release-x86_64.exe"
    template_receipt = json.loads(template_path.with_suffix(".receipt.json").read_text(encoding="utf-8"))
    require(digest(template_path.read_bytes()) == template_receipt["output_sha256"], "Prepared native template drift")
    require(report["windows_resources"]["manifest"]["sha256"] == template_receipt["manifest_sha256"], "Original prepared manifest bytes changed in final EXE")
    prepared_pe = module.inspect_pe(template_path.read_bytes(), require_unpacked=True)
    require(pe["resources"] == prepared_pe["resources"], "Final native EXE resources differ from the prepared branding/icon/manifest")
    require(pe["code_sections"] == prepared_pe["code_sections"], "Final native executable code differs from the prepared Godot template")
    report["windows_resources"]["matches_prepared_template_resources_and_code"] = True
    with zipfile.ZipFile(args.apk) as package:
        names = package.namelist()
        require(len(names) == len(set(names)), "Duplicate APK ZIP entries")
        require(not forbidden(n for n in names if n.startswith("assets/")), "Forbidden APK assets")
        for resource, expected in frozen["files"].items():
            name = "assets/" + resource.removeprefix("res://")
            raw = package.read(name)
            require({"bytes": len(raw), "sha256": digest(raw)} == expected, f"APK actual byte mismatch: {name}")
        bad_crc = package.testzip()
        require(bad_crc is None, f"APK ZIP CRC failure: {bad_crc}")
        report["android_zip"] = {"entries": len(names), "all_entry_crc_valid": True, "forbidden_paths": []}
    sdk = args.android_sdk.resolve()
    build_tools = sdk / "build-tools" / args.android_build_tools
    java = project / ".tools/jdk17/bin/java.exe"
    sdk_env = dict(os.environ, JAVA_HOME=str(java.parents[1]))
    def sdk_run(label, argv):
        result = subprocess.run([str(value) for value in argv], capture_output=True, text=True, encoding="utf-8",
                                errors="replace", timeout=120, cwd=output, env=sdk_env)
        (output / (label + ".txt")).write_text(result.stdout + result.stderr, encoding="utf-8")
        require(result.returncode == 0, f"Android SDK {label} failed: {result.stdout[-1200:]}{result.stderr[-1200:]}")
        return result.stdout + result.stderr
    signature = sdk_run("apk-signature", [java, "-jar", build_tools / "lib/apksigner.jar", "verify", "--verbose", "--print-certs", args.apk.resolve()])
    require("Verified using v2 scheme (APK Signature Scheme v2): true" in signature and "Number of signers: 1" in signature,
            "APK requires a valid v2 signature and one signer")
    certificate = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-f]+)", signature)
    require(certificate is not None, "APK signer certificate digest missing")
    badging = sdk_run("apk-badging", [build_tools / "aapt.exe", "dump", "badging", args.apk.resolve()])
    require(re.search(r"^package: name='org\.example\.kronen' versionCode='" + str(frozen["android_version_code"]) + r"' versionName='" + re.escape(frozen["version"]) + "'", badging, re.M),
            "APK package name/versionCode/versionName differ from frozen release")
    for expression in (r"^sdkVersion:'24'", r"^targetSdkVersion:'35'", r"^launchable-activity: name='com\.godot\.game\.GodotApp'", r"^native-code: 'arm64-v8a' 'armeabi-v7a'"):
        require(re.search(expression, badging, re.M), "APK badging contract mismatch: " + expression)
    sdk_run("apk-zipalign", [build_tools / "zipalign.exe", "-c", "-v", "4", args.apk.resolve()])
    report["android_sdk"] = {"version_name": frozen["version"], "version_code": frozen["android_version_code"],
                             "signature_scheme": "V2", "signer_count": 1, "signer_certificate_sha256": certificate.group(1),
                             "zipaligned": True, "min_sdk": 24, "target_sdk": 35, "abis": ["arm64-v8a", "armeabi-v7a"]}
    require({str(path.resolve()): file_record(path) for path in (args.exe, args.apk)} == artifact_records,
            "Candidate artifacts changed while they were being inspected")
    report["physical_android_test"] = False
    report["checked_at"] = datetime.now(timezone.utc).isoformat()
    (output / "static-package-receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    commands = parser.add_subparsers(dest="command", required=True)
    prep = commands.add_parser("prepare")
    prep.add_argument("--output", type=Path, required=True)
    prep.add_argument("--version", default="1.6.1")
    prep.add_argument("--android-code", type=int, default=10)
    check = commands.add_parser("static")
    check.add_argument("--frozen", type=Path, required=True)
    check.add_argument("--exe", type=Path, required=True)
    check.add_argument("--apk", type=Path, required=True)
    check.add_argument("--output", type=Path, required=True)
    check.add_argument("--android-sdk", type=Path, default=Path("C:/Users/HP/AppData/Local/Android/Sdk"))
    check.add_argument("--android-build-tools", default="36.1.0")
    args = parser.parse_args()
    (prepare if args.command == "prepare" else static)(args)


if __name__ == "__main__":
    main()
