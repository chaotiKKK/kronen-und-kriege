"""Behavioral checks for documented terminal administrations, never geometry."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/atlas_terminal_authorities.py"
if MODULE_PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_terminal_authorities", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
else:
    module = None


class TerminalAuthorityTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(module, "Die belegte Klassifikation terminaler Verwaltungen fehlt.")

    def inputs(self):
        features = [{"id": "country:" + code, "country": code, "kind": "country",
                     "name": code, "source": "natural-earth-countries", "rings": [[0, 1, 2]]}
                    for code in ("MC", "VA", "GI", "FR")]
        coverage = {code: {"fraction": 0.0, "land_area_km2": 12.5,
                           "covered_land_area_km2": 0.0, "status": "gap", "sources": [],
                           "threshold": 0.95, "measurement": "actual polygon union"}
                    for code in ("MC", "VA", "GI", "FR")}
        sources = {"natural-earth-countries": {"id": "natural-earth-countries"}}
        return features, coverage, sources

    def test_terminal_status_does_not_fabricate_measured_coverage(self):
        features, coverage, sources = self.inputs()
        coverage["MC"]["fraction"] = 0.27
        before = copy.deepcopy(coverage)
        applied = module.apply_scopes(features, coverage, sources)
        self.assertEqual(set(applied), {"MC", "VA", "GI"})
        for code in ("MC", "VA", "GI"):
            with self.subTest(country=code):
                row = coverage[code]
                self.assertEqual(row["status"], "single_jurisdiction")
                self.assertFalse(row["measurement_applicable"])
                self.assertFalse(row["classification_is_geometric_coverage"])
                for field in ("fraction", "land_area_km2", "covered_land_area_km2", "threshold", "measurement", "sources"):
                    self.assertEqual(row[field], before[code][field])
                self.assertTrue(row["authority_evidence"])

    def test_native_roles_distinguish_commune_from_central_administration(self):
        features, coverage, sources = self.inputs()
        module.apply_scopes(features, coverage, sources)
        expected = {"MC": ("municipality", 1), "VA": ("central_state_administration", None),
                    "GI": ("territorial_government", None)}
        for code, (role, count) in expected.items():
            with self.subTest(country=code):
                self.assertEqual(coverage[code]["native_scope"]["authority_role"], role)
                self.assertEqual(coverage[code]["native_scope"]["municipality_count"], count)

    def test_monaco_annotates_existing_country_without_creating_a_feature(self):
        features, coverage, sources = self.inputs()
        before = copy.deepcopy(features)
        module.apply_scopes(features, coverage, sources)
        self.assertEqual([row["id"] for row in features], [row["id"] for row in before])
        for row, original in zip(features, before):
            self.assertEqual(row["kind"], original["kind"])
            self.assertEqual(row["rings"], original["rings"])
            self.assertEqual(row["source"], original["source"])
        roles = features[0]["additional_authority_roles"]
        self.assertEqual(len(roles), 1)
        self.assertEqual(roles[0]["authority_name"], "Commune de Monaco")
        self.assertEqual(roles[0]["authority_role"], "municipality")
        self.assertEqual(roles[0]["scope"], "countrywide")
        self.assertFalse(roles[0]["geometry_created"])

    def test_vatican_and_gibraltar_do_not_become_municipal_features(self):
        features, coverage, sources = self.inputs()
        before = copy.deepcopy(features[1:])
        module.apply_scopes(features, coverage, sources)
        self.assertEqual(features[1:], before)

    def test_unknown_countries_remain_untouched(self):
        features, coverage, sources = self.inputs()
        fr = copy.deepcopy(coverage["FR"])
        module.apply_scopes(features, coverage, sources)
        self.assertEqual(coverage["FR"], fr)

    def test_no_coverage_or_country_is_synthesized(self):
        features, coverage, sources = self.inputs()
        features = [features[-1]]
        coverage = {"FR": coverage["FR"]}
        before = copy.deepcopy((features, coverage, sources))
        self.assertEqual(module.apply_scopes(features, coverage, sources), {})
        self.assertEqual((features, coverage, sources), before)

    def test_missing_monaco_reference_does_not_create_municipal_geometry(self):
        features, coverage, sources = self.inputs()
        features = features[1:]
        module.apply_scopes(features, coverage, sources)
        self.assertEqual(len(features), 3)
        self.assertFalse(any(row["country"] == "MC" for row in features))
        self.assertEqual(coverage["MC"]["status"], "single_jurisdiction")

    def test_repeated_application_preserves_existing_roles_and_is_idempotent(self):
        features, coverage, sources = self.inputs()
        features[0]["additional_authority_roles"] = [{"authority_role": "existing_annotation"}]
        module.apply_scopes(features, coverage, sources)
        before = copy.deepcopy((features, coverage, sources))
        module.apply_scopes(features, coverage, sources)
        self.assertEqual((features, coverage, sources), before)
        self.assertEqual(len(features[0]["additional_authority_roles"]), 2)

    def test_existing_geometry_source_is_not_relabelled_as_legal_evidence(self):
        features, coverage, sources = self.inputs()
        original = copy.deepcopy(sources["natural-earth-countries"])
        module.apply_scopes(features, coverage, sources)
        self.assertEqual(sources["natural-earth-countries"], original)
        source = sources["atlas-terminal-authorities"]
        self.assertFalse(source["geometry_source"])
        self.assertFalse(source["classification_is_geometric_coverage"])
        self.assertEqual(set(source["scope_countries"]), {"MC", "VA", "GI"})

    def test_manifest_keeps_evidence_receipts_out_of_runtime_legal_text(self):
        manifest = module.load_manifest()
        self.assertEqual({row["country"] for row in manifest["authorities"]}, {"MC", "VA", "GI"})
        self.assertFalse(manifest["classification_is_geometric_coverage"])
        self.assertEqual(len(module.verify_evidence_receipts(manifest)), 3)
        for row in manifest["authorities"]:
            self.assertTrue(row["uncertainty"])
            self.assertTrue(row["checked_at"])
            for evidence in row["evidence"]:
                self.assertTrue(evidence["url"].startswith("https://"))
                self.assertTrue(evidence["provisions"])
                self.assertTrue(evidence["cache_receipt"])
                self.assertNotIn("raw_text", evidence)

    def test_tampered_cached_evidence_is_rejected(self):
        manifest = module.load_manifest()
        evidence = manifest["authorities"][0]["evidence"][0]
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            source_cache = ROOT / ".tools/atlas_sources"
            for row in manifest["authorities"]:
                for item in row["evidence"]:
                    relative = Path(item["cache_receipt"])
                    receipt = json.loads((source_cache / relative).read_text(encoding="utf-8"))
                    raw_relative = relative.parent / receipt["raw_file"]
                    for rel in (relative, raw_relative):
                        target = cache / rel
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes((source_cache / rel).read_bytes())
            receipt = json.loads((cache / evidence["cache_receipt"]).read_text(encoding="utf-8"))
            raw = (cache / evidence["cache_receipt"]).parent / receipt["raw_file"]
            raw.write_bytes(raw.read_bytes() + b"tampered")
            with self.assertRaisesRegex(ValueError, "SHA|hash|Hash"):
                module.verify_evidence_receipts(manifest, cache)

    def test_unreviewed_country_cannot_be_added_by_manifest(self):
        manifest = module.load_manifest()
        manifest["authorities"][0]["country"] = "FR"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "unsupported.json"
            path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "country|Country|Land|Länder"):
                module.load_manifest(path)


if __name__ == "__main__":
    unittest.main()
