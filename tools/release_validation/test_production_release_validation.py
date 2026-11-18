"""Adversarial package contract checks without Godot or release artifacts."""
import io
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


if __name__ == "__main__":
    unittest.main()
