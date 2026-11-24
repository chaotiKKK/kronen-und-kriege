"""Adversarial package contract checks without Godot or release artifacts."""
import io
from contextlib import redirect_stderr
from pathlib import Path
import tempfile
import unittest
import zipfile
import production_release_validation as verifier


class Pack:
    def __init__(self, entries):
        self.entries = entries

    def read(self, name):
        return self.entries[name]


class PackageContract(unittest.TestCase):
    def setUp(self):
        self.sources = ["scripts/Game.gd", "scripts/RegionalProduction.gd"]
        self.entries = {}
        for i, source in enumerate(self.sources):
            target = f".godot/exported/test/{i}.gdc"
            self.entries[target] = b"bytecode" + bytes([i])
            self.entries[source + ".remap"] = f'[remap]\npath="res://{target}"\n'.encode()

    def inspect(self, apk_changes=None, pck_changes=None):
        apk_entries = {"assets/" + key: value for key, value in self.entries.items()}
        apk_entries.update(apk_changes or {})
        pck_entries = dict(self.entries)
        pck_entries.update(pck_changes or {})
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as archive:
            for name, raw in apk_entries.items():
                archive.writestr(name, raw)
        with zipfile.ZipFile(output) as archive:
            result = verifier.parity(Pack(pck_entries), archive, self.sources)
            verifier.resource_parity(Pack(pck_entries), archive, {})
            return result

    def test_exact_complete_bijection(self):
        result = self.inspect()
        self.assertTrue(result["bijective"])
        self.assertEqual(result["script_count"], 2)

    def test_platform_byte_drift(self):
        with self.assertRaisesRegex(ValueError, "Different/empty"):
            self.inspect({"assets/.godot/exported/test/0.gdc": b"other"})

    def test_unaccounted_compiled_module(self):
        with self.assertRaisesRegex(ValueError, "sets differ"):
            self.inspect({"assets/unregistered.gdc": b"new"})

    def test_two_sources_cannot_alias_one_module(self):
        self.entries[self.sources[1] + ".remap"] = self.entries[self.sources[0] + ".remap"]
        with self.assertRaisesRegex(ValueError, "not bijective"):
            self.inspect()

    def test_forbidden_native_runtime(self):
        with self.assertRaisesRegex(ValueError, "Compatibility runtime"):
            self.inspect({"lib/arm64-v8a/libwine.so": b"native"})

    def test_wine_components(self):
        for name in ("wineserver", "libwined3d.so", "wineboot", "libbox64.so"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "Compatibility runtime"):
                self.inspect({"lib/arm64-v8a/" + name: b"native"})

    def test_remap_defaults_are_not_explicit_bindings(self):
        self.entries[self.sources[0] + ".remap"] = b'[DEFAULT]\npath="res://.godot/exported/test/0.gdc"\n[remap]\n'
        with self.assertRaisesRegex(ValueError, "remap structure"):
            self.inspect()

    def test_remap_key_case_is_exact(self):
        self.entries[self.sources[0] + ".remap"] = b'[remap]\nPath="res://.godot/exported/test/0.gdc"\n'
        with self.assertRaisesRegex(ValueError, "remap structure"):
            self.inspect()

    def test_scene_payload_drift(self):
        self.entries["scenes/Main.tscn"] = b"original scene"
        with self.assertRaisesRegex(ValueError, "payload differs"):
            self.inspect({"assets/scenes/Main.tscn": b"different scene"})

    def test_embedded_development_driver(self):
        with self.assertRaisesRegex(ValueError, "Development files"):
            self.inspect({"assets/tests/driver.gdc": b"test"})

    def test_android_gradle_metadata_is_not_a_development_resource(self):
        self.assertTrue(self.inspect({"META-INF/com/android/build/gradle/app-metadata.properties": b"appMetadataVersion=1.1\n"})["bijective"])

    def test_path_traversal(self):
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            self.inspect({"assets/../escape": b"unsafe"})

    def test_unverified_plain_source(self):
        with self.assertRaisesRegex(ValueError, "Unverified source"):
            self.inspect({"assets/scripts/hidden.gd": b"code"})


class CanonicalManifestContract(unittest.TestCase):
    def setUp(self):
        self.files = {f"data/{i}.json": {"bytes": i, "sha256": str(i)} for i in range(24)}
        self.metadata = {"version": "1.9.1", "android_version_code": 20, "lan_enabled": True,
                         "files": {"res://" + key: value for key, value in self.files.items()}}

    def test_valid_complete_manifest(self):
        verifier.data_contract(self.metadata, self.files)

    def test_stale_code(self):
        self.metadata["android_version_code"] = 19
        with self.assertRaisesRegex(ValueError, "contradicts"):
            verifier.data_contract(self.metadata, self.files)

    def test_disabled_lan(self):
        self.metadata["lan_enabled"] = False
        with self.assertRaisesRegex(ValueError, "contradicts"):
            verifier.data_contract(self.metadata, self.files)

    def test_changed_data(self):
        self.metadata["files"]["res://data/0.json"] = {"bytes": 999, "sha256": "other"}
        with self.assertRaisesRegex(ValueError, "differs"):
            verifier.data_contract(self.metadata, self.files)

    def test_explicit_code21_manifest_is_accepted(self):
        self.metadata["android_version_code"] = 21
        try:
            verifier.data_contract(self.metadata, self.files, android_code=21)
        except (TypeError, ValueError) as exc:
            self.fail(f"Explicit expected code21 must accept matching metadata: {exc}")

    def test_code21_is_not_inferred_from_metadata(self):
        self.metadata["android_version_code"] = 21
        with self.assertRaisesRegex(ValueError, "contradicts"):
            verifier.data_contract(self.metadata, self.files)

    def test_code20_metadata_cannot_satisfy_code21(self):
        try:
            with self.assertRaisesRegex(ValueError, "contradicts"):
                verifier.data_contract(self.metadata, self.files, android_code=21)
        except TypeError as exc:
            self.fail(f"Expected code must be checked against actual metadata: {exc}")


class ExplicitAndroidReleaseCode(unittest.TestCase):
    def call(self, name, *args, **kwargs):
        function = getattr(verifier, name, None)
        self.assertTrue(callable(function), f"Missing release-code behavior: {name}")
        return function(*args, **kwargs)

    def test_cli_defaults_to_previous_code20(self):
        args = self.call("parse_args", ["freeze", "--output", "unused"])
        self.assertEqual(args.android_code, 20)

    def test_cli_accepts_explicit_code21(self):
        args = self.call("parse_args", ["inspect", "--output", "unused", "--android-code", "21"])
        self.assertEqual(args.android_code, 21)

    def test_cli_preserves_previous_artifact_defaults(self):
        args = self.call("parse_args", ["inspect", "--output", "unused"])
        self.assertEqual(getattr(args, "exe", None), verifier.ROOT / "build/exports/banger-queens-1.9.1-production.exe")
        self.assertEqual(getattr(args, "apk", None), verifier.ROOT / "build/exports/banger-queens-1.9.1-production.apk")

    def test_cli_selects_explicit_compact_artifacts(self):
        with tempfile.TemporaryDirectory() as directory:
            exe = Path(directory) / "banger-queens-1.9.1-compact.exe"
            apk = Path(directory) / "banger-queens-1.9.1-compact.apk"
            try:
                args = self.call("parse_args", ["inspect", "--output", "unused", "--android-code", "21", "--exe", str(exe), "--apk", str(apk)])
            except SystemExit as exc:
                self.fail(f"Explicit artifact selection must be accepted: {exc}")
            self.assertEqual((args.exe, args.apk, args.android_code), (exe, apk, 21))

    def test_cli_rejects_invalid_codes_before_creating_evidence(self):
        for invalid in ("0", "-1", "1.5", "true", "", "2147483648"):
            with self.subTest(code=invalid), tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / "must-not-exist"
                with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as failure:
                    self.call("parse_args", ["freeze", "--output", str(output), "--android-code", invalid])
                self.assertEqual(failure.exception.code, 2)
                self.assertFalse(output.exists())

    def test_frozen_code21_must_match_explicit_expectation(self):
        frozen = {"version": "1.9.1", "schema": 17, "code": 21}
        self.call("frozen_contract", frozen, android_code=21)
        with self.assertRaisesRegex(ValueError, "Frozen.*code"):
            self.call("frozen_contract", frozen)

    def test_frozen_code20_cannot_satisfy_code21(self):
        frozen = {"version": "1.9.1", "schema": 17, "code": 20}
        self.call("frozen_contract", frozen)
        with self.assertRaisesRegex(ValueError, "Frozen.*code"):
            self.call("frozen_contract", frozen, android_code=21)

    def test_actual_apk_receipt_code_must_match_expectation(self):
        actual = {"version": "1.9.1", "android_sdk": {"version_name": "1.9.1", "version_code": 21}}
        self.call("package_contract", actual, android_code=21)
        with self.assertRaisesRegex(ValueError, "Actual package.*code"):
            self.call("package_contract", actual)
        actual["android_sdk"]["version_code"] = 20
        self.call("package_contract", actual)
        with self.assertRaisesRegex(ValueError, "Actual package.*code"):
            self.call("package_contract", actual, android_code=21)

    def test_expected_code_rejects_boolean_fraction_and_nonpositive(self):
        for invalid in (True, 21.0, "21", 0, -1, 2147483648):
            with self.subTest(code=invalid), self.assertRaisesRegex(ValueError, "positive.*integer"):
                self.call("frozen_contract", {"version": "1.9.1", "schema": 17, "code": 21}, android_code=invalid)


class ExportPresetCodeContract(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.previous_root = verifier.ROOT
        verifier.ROOT = self.root
        self.addCleanup(setattr, verifier, "ROOT", self.previous_root)
        self.files = {source: {} for source in verifier.BASE_MODULES | verifier.NEW_MODULES}
        self.files.update({f"data/{index}.json": {} for index in range(24)})
        self.files["assets/ui/chaotiKKK_logo.png"] = {"sha256": "980c3f40982e4872ed77d5dee3e068f2abae677d31020a901fddb04691db352c"}
        for source in verifier.BASE_MODULES | verifier.NEW_MODULES:
            path = self.root / source
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("const CURRENT_VERSION := 17\n" if source == "scripts/SaveGame.gd" else "", encoding="utf-8")

    def preset(self, code):
        (self.root / "export_presets.cfg").write_text(f'version/code={code}\nversion/name="1.9.1"\n', encoding="utf-8")

    def inspect(self, **kwargs):
        try:
            return verifier.contract(self.files, **kwargs)
        except TypeError as exc:
            self.fail(f"Export configuration must use the explicit expected code: {exc}")

    def test_default20_presets_remain_accepted(self):
        self.preset(20)
        scripts, data = self.inspect()
        self.assertEqual((len(scripts), len(data)), (55, 24))

    def test_matching_code21_presets_are_accepted_only_explicitly(self):
        self.preset(21)
        scripts, data = self.inspect(android_code=21)
        self.assertEqual((len(scripts), len(data)), (55, 24))
        with self.assertRaisesRegex(ValueError, "Android code"):
            self.inspect()

    def test_code20_presets_cannot_satisfy_code21(self):
        self.preset(20)
        with self.assertRaisesRegex(ValueError, "Android code"):
            self.inspect(android_code=21)

    def trade_sources(self):
        # Literal expected names, independent of the verifier's required set.
        for source in ("scripts/MaterialTrade.gd", "scripts/MaterialTradePanel.gd"):
            (self.root / source).write_text("", encoding="utf-8")
            self.files[source] = {}

    def source_schema(self, schema):
        (self.root / "scripts/SaveGame.gd").write_text(f"const CURRENT_VERSION := {schema}\n", encoding="utf-8")

    def test_schema18_requires_explicit_source_expectation_and_both_trade_modules(self):
        self.preset(22)
        self.source_schema(18)
        self.trade_sources()
        scripts, data = self.inspect(android_code=22, schema=18)
        self.assertEqual((len(scripts), len(data)), (57, 24))
        with self.assertRaisesRegex(ValueError, "source schema"):
            self.inspect(android_code=22)

    def test_schema17_source_cannot_satisfy_explicit18(self):
        self.preset(22)
        self.trade_sources()
        with self.assertRaisesRegex(ValueError, "source schema"):
            self.inspect(android_code=22, schema=18)

    def test_each_trade_module_is_required_for18(self):
        self.preset(22)
        self.source_schema(18)
        self.trade_sources()
        for source in ("scripts/MaterialTrade.gd", "scripts/MaterialTradePanel.gd"):
            with self.subTest(missing=source):
                info = self.files.pop(source)
                (self.root / source).unlink()
                try:
                    with self.assertRaisesRegex(ValueError, "material.trade"):
                        self.inspect(android_code=22, schema=18)
                finally:
                    self.files[source] = info
                    (self.root / source).write_text("", encoding="utf-8")

    def test_schema18_still_requires_original_production_module(self):
        self.preset(22)
        self.source_schema(18)
        self.trade_sources()
        self.files.pop("scripts/RegionalProduction.gd")
        (self.root / "scripts/RegionalProduction.gd").unlink()
        with self.assertRaisesRegex(ValueError, "original.*production"):
            self.inspect(android_code=22, schema=18)

    def test_legacy17_does_not_require_future_trade_files(self):
        self.preset(20)
        scripts, _ = self.inspect(schema=17)
        self.assertEqual(len(scripts), 55)


class ExplicitSaveSchema(unittest.TestCase):
    def call(self, name, *args, **kwargs):
        function = getattr(verifier, name, None)
        self.assertTrue(callable(function), f"Missing explicit save-schema behavior: {name}")
        try:
            return function(*args, **kwargs)
        except TypeError as exc:
            self.fail(f"Explicit expected schema must be supported by {name}: {exc}")

    def test_cli_defaults_to_previous_schema17(self):
        args = self.call("parse_args", ["freeze", "--output", "unused"])
        self.assertEqual(getattr(args, "schema", None), 17)

    def test_cli_accepts_explicit18_with_code22(self):
        try:
            args = self.call("parse_args", ["inspect", "--output", "unused", "--android-code", "22", "--schema", "18"])
        except SystemExit as exc:
            self.fail(f"Explicit schema18 must be accepted independently of artifacts: {exc}")
        self.assertEqual((args.schema, args.android_code), (18, 22))

    def test_cli_accepts_explicit19_with_code26(self):
        args = self.call("parse_args", ["freeze", "--output", "unused", "--schema", "19", "--android-code", "26"])
        self.assertEqual((args.schema, args.android_code), (19, 26))

    def test_cli_rejects_invalid_schemas_before_evidence(self):
        for invalid in ("0", "-1", "18.0", "1.5", "true", "NaN", "inf", "", "2147483648", "20"):
            with self.subTest(schema=invalid), tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / "must-not-exist"
                with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as failure:
                    self.call("parse_args", ["freeze", "--output", str(output), "--schema", invalid])
                self.assertEqual(failure.exception.code, 2)
                self.assertFalse(output.exists())

    def test_expected_schema_rejects_boolean_float_nan_and_unknown(self):
        for invalid in (True, False, 18.0, 18.5, float("nan"), float("inf"), "18", None, 0, -1, 2147483648, 20):
            with self.subTest(schema=invalid), self.assertRaisesRegex(ValueError, "schema"):
                self.call("require_schema", invalid)

    def test_frozen18_matches_only_explicit18(self):
        frozen = {"version": "1.9.1", "schema": 18, "code": 22}
        self.call("frozen_contract", frozen, android_code=22, schema=18)
        with self.assertRaisesRegex(ValueError, "Frozen.*schema"):
            self.call("frozen_contract", frozen, android_code=22)

    def test_frozen17_cannot_be_relabelled18(self):
        frozen = {"version": "1.9.1", "schema": 17, "code": 22}
        self.call("frozen_contract", frozen, android_code=22)
        with self.assertRaisesRegex(ValueError, "Frozen.*schema"):
            self.call("frozen_contract", frozen, android_code=22, schema=18)

    def test_frozen_schema_is_an_actual_integer(self):
        for invalid in (True, 18.0, "18", float("nan"), None):
            with self.subTest(schema=invalid), self.assertRaisesRegex(ValueError, "Frozen.*schema"):
                self.call("frozen_contract", {"version": "1.9.1", "schema": invalid, "code": 22}, android_code=22, schema=18)

    def test_static_schema_receipt_must_match_explicit_expectation(self):
        receipt = {"source_schema": 18, "schema_runtime_observed": False}
        self.call("source_schema_contract", receipt, schema=18)
        with self.assertRaisesRegex(ValueError, "receipt.*schema"):
            self.call("source_schema_contract", receipt)
        self.call("source_schema_contract", {"source_schema": 17, "schema_runtime_observed": False})

    def test_static_receipt_cannot_claim_unobserved_runtime_schema(self):
        for receipt in ({"source_schema": 18.0, "schema_runtime_observed": False},
                        {"source_schema": 18, "schema_runtime_observed": True},
                        {"source_schema": 18}):
            with self.subTest(receipt=receipt), self.assertRaisesRegex(ValueError, "schema"):
                self.call("source_schema_contract", receipt, schema=18)


if __name__ == "__main__":
    unittest.main()
