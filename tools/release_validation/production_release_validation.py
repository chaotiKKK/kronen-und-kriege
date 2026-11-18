"""Freeze and inspect the production release; never build, install or launch it.

The frozen source inventory, not a previous release's script count, determines
the complete source/remap/bytecode bijection. Canonical data/native/signature
checks remain owned by atlas_release_validation.py.
"""
from __future__ import annotations

import argparse
import configparser
from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import struct
from types import SimpleNamespace
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION, CODE, SCHEMA = "1.9.1", 20, 17
CERT = "298739811808ab3c59ef84fd3a0db8bf44f574840c0166b35585079b1c3f6677"
LOGO = "assets/ui/chaotiKKK_logo.png"
LOGO_HASH = "980c3f40982e4872ed77d5dee3e068f2abae677d31020a901fddb04691db352c"
NEW_MODULES = {f"scripts/{name}.gd" for name in (
    "RegionalProduction", "MaterialTransport", "DepotSupply", "EconomyPlanner", "ProductionNetworkReport")}
BASE_MODULES = {f"scripts/{name}.gd" for name in (
    "AcceptanceDriver", "ArmyRecovery", "AtlasBoundaries", "AtlasData",
    "AtlasLayer", "AtlasSearch", "BannerGenerator", "BannerPreview",
    "CampaignCalendar", "CampaignLimits", "ChronicleChart", "CourtManagementPanel",
    "Data", "EventArtFallback", "EventDirector", "FamilyTree", "FieldBattleRules",
    "Game", "GameRegionCatalog", "GameRegionData", "HouseDesign", "HouseDesignerDialog",
    "Infrastructure", "LanAuthority", "LanDiscovery", "LanMenu", "LanProtocol",
    "LanSession", "Loading", "Main", "MapBase", "MapModes", "MapView",
    "ModernInterface", "NavalCampaign", "NavalRoutes", "NavalTransport",
    "ProvinceEconomy", "ProvinceInspector", "RegionMigration", "ResearchPanel",
    "SaveGame", "SaveStore", "SiegeRules", "SupplyNetwork", "SystemicResolver",
    "UiKernel", "ViewModelBuilder", "WoodGrain", "WorldMiniMap")}


def require(value, message):
    if not value:
        raise ValueError(message)


def require_android_code(code):
    require(type(code) is int and 0 < code <= 2147483647,
            "Expected Android code must be a positive 32-bit integer")


def android_code_argument(value):
    if not re.fullmatch(r"[0-9]+", value):
        raise argparse.ArgumentTypeError("Android code must be a positive 32-bit integer")
    code = int(value)
    try:
        require_android_code(code)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc
    return code


def record(path):
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    return {"bytes": path.stat().st_size, "sha256": digest}


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def validator():
    spec = importlib.util.spec_from_file_location("production_atlas_reader", ROOT / "tools/release_validation/atlas_release_validation.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fresh(path):
    path = path.resolve()
    require(path.is_relative_to((ROOT / "build/verify").resolve()) and not path.exists(), "Use a fresh evidence directory under build/verify")
    path.mkdir(parents=True)
    return path


def inventory():
    files = set()
    for directory in ("scripts", "tests", "data", "scenes", "assets", "fonts", "shaders", "android/build/src", "android/build/res", "android/build/libs", "android/build/gradle"):
        for path in (ROOT / directory).rglob("*"):
            if path.is_file():
                files.add(path.relative_to(ROOT).as_posix())
    files.update(path.name for path in ROOT.glob("icon*") if path.is_file())
    files.update(path.relative_to(ROOT).as_posix() for path in (ROOT / "android/build").iterdir()
                 if path.is_file() and (path.suffix in (".gradle", ".properties", ".xml") or path.name in ("gradlew", "gradlew.bat")))
    files.update(("project.godot", "export_presets.cfg", "export_windows.sh", "export_android.sh", "tools/run_all_tests.sh", "tools/release_validation/production_release_validation.py", "tools/release_validation/test_production_release_validation.py", "tools/release_validation/run_exported_production.ps1", "tools/release_validation/exported-campaign.gd.in", "tools/release_validation/atlas_release_validation.py", "tools/prepare_windows_export_template.py", ".tools/godot.exe", ".tools/godot_console.exe", ".tools/windows-export-template/banger-queens-windows-release-x86_64.exe", ".tools/windows-export-template/banger-queens-windows-release-x86_64.receipt.json"))
    return {name: record(ROOT / name) for name in sorted(files)}


def contract(files, android_code=CODE):
    require_android_code(android_code)
    scripts = sorted(name for name in files if name.startswith("scripts/") and name.endswith(".gd"))
    require(set(scripts) >= BASE_MODULES | NEW_MODULES, "Frozen source must include the original modules and every required production module")
    require(scripts == sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "scripts").rglob("*.gd")), "Frozen runtime source inventory is incomplete")
    data = sorted(name for name in files if name.startswith("data/") and Path(name).suffix in (".json", ".bin"))
    require(len(data) == 24, "Expected the complete twenty-four shipping data files")
    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8-sig")
    require(re.findall(r"^version/code=(\d+)$", presets, re.M) == [str(android_code)], f"Android code differs from expected {android_code}")
    require(re.findall(r'^version/name="([^"\r\n]+)"$', presets, re.M) == [VERSION], "Version differs from1.9.1")
    require(re.findall(r"^const CURRENT_VERSION\s*:=\s*(\d+)\s*$", (ROOT / "scripts/SaveGame.gd").read_text(encoding="utf-8-sig"), re.M) == [str(SCHEMA)], "Save source schema differs from17")
    require(files[LOGO]["sha256"] == LOGO_HASH, "Original studio logo changed")
    return scripts, data


def parity(pack, apk, scripts):
    pck = set(pack.entries)
    names = apk.namelist()
    require(len(names) == len(set(names)), "Duplicate APK entries")
    for name in (*pck, *names):
        parts = PurePosixPath(name.replace("\\", "/")).parts
        lower = [part.casefold() for part in parts]
        resource_parts = lower[1:] if lower[:1] == ["assets"] else lower
        require(not (name.startswith("/") or ".." in parts or re.match(r"^[A-Za-z]:", name)), "Unsafe package path: " + name)
        require(not set(lower).intersection({"tests", "tools", ".tools"}) and not (resource_parts and resource_parts[0] in {"docs", "build", "preview", "reference"}), "Development files in package: " + name)
        require(not any(re.match(r"^(?:lib)?(?:wine(?:32|64|server|d3d|boot|cfg)?|box(?:64|86))(?:[._-]|$)", part) for part in lower), "Compatibility runtime in native package: " + name)
        require(not name.lower().endswith((".jks", ".keystore", ".gd")), "Unverified source/key in package: " + name)
    compiled = {name for name in pck if name.endswith(".gdc")}
    require(compiled == {name.removeprefix("assets/") for name in names if name.endswith(".gdc")} and len(compiled) == len(scripts), "Complete compiled-module sets differ")
    remaps = {source + ".remap" for source in scripts}
    require(remaps == {name for name in pck if name.endswith(".gd.remap")} == {name.removeprefix("assets/") for name in names if name.endswith(".gd.remap")}, "Complete remap sets differ from frozen sources")
    mapping, payloads = {}, {}
    for name in compiled | remaps:
        raw = pack.read(name)
        require(bool(raw) and raw == apk.read("assets/" + name), "Different/empty platform script payload: " + name)
        payloads[name] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
        if name in remaps:
            config = configparser.ConfigParser(interpolation=None, strict=True)
            config.optionxform = str
            config.read_string(raw.decode("utf-8-sig"))
            require(not config.defaults() and config.sections() == ["remap"] and set(config["remap"]) == {"path"}, "Unexpected remap structure")
            target = re.fullmatch(r'"res://([^"\r\n]+)"', config["remap"]["path"])
            require(target is not None and target[1] in compiled, "Invalid compiled remap")
            mapping[name.removesuffix(".remap")] = target[1]
    require(set(mapping.values()) == compiled and len(set(mapping.values())) == len(mapping), "Source/remap/bytecode mapping is not bijective")
    return {"script_count": len(scripts), "mapping": mapping, "payloads": payloads, "bijective": True}


def resource_parity(pack, apk, files):
    # Platform-specific texture containers/import routing and Android's launch/
    # sparse-index metadata are excluded explicitly. Other compiled scenes,
    # samples, shaders, raw resources and project settings must match exactly.
    def independent(name):
        return not name.endswith((".ctex", ".import")) and name not in ("_cl_", "assets.sparsepck")
    left = {name for name in pack.entries if independent(name)}
    right = {name.removeprefix("assets/") for name in apk.namelist() if name.startswith("assets/") and independent(name.removeprefix("assets/"))}
    require(left == right, "Platform-independent resource inventories differ")
    result = {}
    for name in sorted(left):
        raw = pack.read(name)
        require(raw == apk.read("assets/" + name), "Platform-independent payload differs: " + name)
        info = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
        if name in files:
            require(info == files[name], "Raw shipped resource differs from frozen input: " + name)
        result[name] = info
    for name in files:
        if name.startswith("scenes/") and name.endswith(".tscn"):
            require(name in left or name + ".remap" in left, "Frozen scene missing from packages: " + name)
        if name.startswith("shaders/") and name.endswith(".gdshader"):
            require(name in left, "Frozen shader missing from packages: " + name)
    return result


def data_contract(metadata, files, android_code=CODE):
    require_android_code(android_code)
    expected = {"res://" + name: info for name, info in files.items() if name.startswith("data/") and Path(name).suffix in (".json", ".bin")}
    require(metadata.get("version") == VERSION and type(metadata.get("android_version_code")) is int and metadata.get("android_version_code") == android_code and metadata.get("lan_enabled") is True, "Canonical data manifest contradicts production version/code/LAN contract")
    require(len(expected) == 24 and metadata.get("files") == expected, "Canonical data manifest differs from all frozen data inputs")


def frozen_contract(frozen, android_code=CODE):
    require_android_code(android_code)
    require(frozen.get("version") == VERSION and frozen.get("schema") == SCHEMA
            and type(frozen.get("code")) is int and frozen.get("code") == android_code,
            "Frozen source manifest contradicts expected version/code/schema contract")


def package_contract(actual, android_code=CODE):
    require_android_code(android_code)
    sdk = actual.get("android_sdk", {})
    require(actual.get("version") == VERSION and sdk.get("version_name") == VERSION
            and type(sdk.get("version_code")) is int and sdk.get("version_code") == android_code,
            "Actual package version/code contradicts production contract")


def native_libraries(apk):
    expected = {f"lib/{abi}/{library}" for abi in ("arm64-v8a", "armeabi-v7a") for library in ("libgodot_android.so", "libc++_shared.so")}
    require({name for name in apk.namelist() if name.startswith("lib/")} == expected, "Unexpected Android native-library inventory")
    result = {}
    with zipfile.ZipFile(ROOT / "android/build/libs/debug/godot-lib.template_debug.aar") as template:
        for name in sorted(expected):
            raw = apk.read(name)
            require(raw == template.read("jni/" + name.removeprefix("lib/")), "Actual native library differs from frozen Godot AAR: " + name)
            abi64 = name.startswith("lib/arm64-v8a/")
            require(len(raw) > 20 and raw[:4] == b"\x7fELF" and raw[4] == (2 if abi64 else 1) and raw[5] == 1 and struct.unpack_from("<H", raw, 18)[0] == (183 if abi64 else 40), "Actual native ELF architecture differs from ABI: " + name)
            result[name] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
    return result


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("freeze", "inspect"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--frozen", type=Path)
    parser.add_argument("--android-code", type=android_code_argument, default=CODE,
                        help="Explicit expected Android version code (default: 20); never inferred from a package")
    parser.add_argument("--exe", type=Path, default=ROOT / "build/exports/banger-queens-1.9.1-production.exe",
                        help="Windows artifact to inspect (default: previous production EXE)")
    parser.add_argument("--apk", type=Path, default=ROOT / "build/exports/banger-queens-1.9.1-production.apk",
                        help="Android artifact to inspect (default: previous production APK)")
    return parser.parse_args(argv)


def main():
    args = parse_args()
    out = fresh(args.output)
    api = validator()
    if args.stage == "freeze":
        files = inventory()
        scripts, data = contract(files, args.android_code)
        with redirect_stdout(io.StringIO()):
            api.prepare(SimpleNamespace(project=ROOT, output=out / "data", version=VERSION, android_code=args.android_code, with_lan=True))
        data_path = out / "data/frozen-data.json"
        data_contract(read(data_path), files, args.android_code)
        require(files == inventory(), "Build inputs changed while freezing")
        write(out / "source-manifest.json", {"files": files, "runtime_scripts": scripts, "data": data, "version": VERSION, "code": args.android_code, "schema": SCHEMA, "canonical_data_manifest": record(data_path)})
        print(json.dumps({"files": len(files), "scripts": len(scripts), "data": len(data), "manifest": str(out / "source-manifest.json")}))
        return
    require(args.frozen is not None, "Inspection requires an explicit frozen manifest")
    manifest_record = record(args.frozen)
    frozen = read(args.frozen)
    frozen_contract(frozen, args.android_code)
    require(frozen["files"] == inventory(), "Sources changed since freeze")
    data_path = args.frozen.parent / "data/frozen-data.json"
    require(record(data_path) == frozen["canonical_data_manifest"], "Canonical data manifest changed since freeze")
    data_contract(read(data_path), frozen["files"], args.android_code)
    scripts, _ = contract(frozen["files"], args.android_code)
    exe, apk = args.exe.resolve(), args.apk.resolve()
    artifacts = {str(path): record(path) for path in (exe, apk)}
    capture = io.StringIO()
    with redirect_stdout(capture):
        api.static(SimpleNamespace(project=ROOT, output=out, frozen=data_path, exe=exe, apk=apk, android_sdk=Path("C:/Users/HP/AppData/Local/Android/Sdk"), android_build_tools="36.1.0"))
    (out / "static-stdout.log").write_text(capture.getvalue(), encoding="utf-8")
    static = read(out / "static-package-receipt.json")
    require(static["android_sdk"]["signer_certificate_sha256"] == CERT, "APK signer changed")
    package_contract(static, args.android_code)
    require(static["files"] == read(data_path)["files"], "Actual canonical resource receipts differ from frozen data")
    require(set(static.get("android_lan_permissions", [])) == {"android.permission." + name for name in ("INTERNET", "ACCESS_NETWORK_STATE", "ACCESS_WIFI_STATE", "CHANGE_WIFI_MULTICAST_STATE")}, "Actual APK lacks required LAN permissions")
    pack = api.EmbeddedPack(exe)
    try:
        with zipfile.ZipFile(apk) as package:
            result = parity(pack, package, scripts)
            result["platform_independent_resources"] = resource_parity(pack, package, frozen["files"])
            result["native_libraries"] = native_libraries(package)
            logo = (ROOT / LOGO).read_bytes()
            require(pack.read(LOGO) == logo == package.read("assets/" + LOGO), "Original studio logo differs in packages")
    finally:
        pack.close()
    require(manifest_record == record(args.frozen) and record(data_path) == frozen["canonical_data_manifest"] and frozen["files"] == inventory() and artifacts == {str(path): record(path) for path in (exe, apk)}, "Inputs changed during inspection")
    result.update({"passed": True, "artifacts": artifacts, "source_manifest": record(args.frozen), "files_verified": len(frozen["files"]), "data_count": 24, "code": args.android_code, "source_schema": SCHEMA, "schema_runtime_observed": False, "runtime_test": False})
    write(out / "production-static-review.json", result)
    print(json.dumps({key: result[key] for key in ("passed", "script_count", "files_verified", "code")}))


if __name__ == "__main__":
    main()
