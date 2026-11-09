"""Tunisian municipalities must remain their real, non-admin-level source units."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from shapely.geometry import box, mapping, Polygon, MultiPolygon

ROOT = Path(__file__).resolve().parents[1]
PATH = Path(__file__).with_name("atlas_tunisia_sources.py")
if PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_tunisia_sources", PATH)
    tunisia = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tunisia)
else:
    tunisia = None


class TunisiaMunicipalitySourceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(tunisia, "The verified Tunisian municipal polygon reader is missing")

    @staticmethod
    def attributes():
        return {"municipality-7209947": {
            "id": "municipality-7209947", "governorate": "TN-13", "name_en": "Fouchana",
            "name_fr": "Fouchana", "name_ar": "فوشانة", "wikidata": "", "osm_relation": "7209947"}}

    @staticmethod
    def feature(geometry=None):
        return {"type": "Feature", "properties": {
            "municipality": "municipality-7209947", "governorate": "TN-13"},
            "geometry": mapping(geometry if geometry is not None else box(10, 36, 10.1, 36.1))}

    def test_boundary_role_retains_real_relation_identity_without_invented_admin_level(self):
        row = tunisia.normalize_feature(self.feature(), self.attributes())
        self.assertEqual(row["id"], "map-tunisia:municipality:7209947")
        self.assertEqual(row["osm_relation_id"], 7209947)
        self.assertEqual(row["source_unit_id"], "municipality-7209947")
        self.assertEqual(row["source_boundary"], "municipality")
        self.assertEqual(row["kind"], "municipality")
        self.assertEqual(row["parent_id"], "country:TN")
        self.assertEqual(row["source_governorate"], "TN-13")
        self.assertEqual(row["source_names"]["ar"], "فوشانة")
        self.assertNotIn("admin_level", row)
        self.assertNotIn("osm_relation_version", row)
        self.assertIn("ODbL", row["source_license"])
        self.assertIn("OpenStreetMap", row["source_attribution"])

    def test_holes_and_islands_pass_through_without_added_or_removed_area(self):
        outer = [(10, 36), (10.3, 36), (10.3, 36.3), (10, 36.3), (10, 36)]
        hole = [(10.1, 36.1), (10.2, 36.1), (10.2, 36.2), (10.1, 36.2), (10.1, 36.1)]
        geometry = MultiPolygon([Polygon(outer, [hole]), box(10.4, 36, 10.5, 36.1)])
        row = tunisia.normalize_feature(self.feature(geometry), self.attributes())
        self.assertTrue(row["geometry"].equals_exact(geometry, 0))
        self.assertAlmostEqual(row["geometry"].area, 0.09)
        self.assertEqual(len(row["geometry"].geoms), 2)
        self.assertEqual(len(row["geometry"].geoms[0].interiors), 1)

    def test_missing_or_changed_catalogue_identity_is_rejected(self):
        for change in [None, {"osm_relation": "999"}, {"governorate": "TN-11"}, {"id": "municipality-999"}]:
            attributes = self.attributes()
            if change is None:
                attributes = {}
            else:
                attributes["municipality-7209947"].update(change)
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, "identity|catalogue|governorate"):
                tunisia.normalize_feature(self.feature(), attributes)

    def test_invalid_polygon_is_rejected_without_geometry_repair(self):
        crossed = Polygon([(10, 36), (10.1, 36.1), (10.1, 36), (10, 36.1), (10, 36)])
        with self.assertRaisesRegex(ValueError, "geometry|polygon"):
            tunisia.normalize_feature(self.feature(crossed), self.attributes())

    def test_changed_raw_input_is_rejected_before_import(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            raw = cache / "changed.json"
            raw.write_text("[]", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "integrity|hash|SHA"):
                tunisia.verify_file(raw, {"bytes": 2, "sha256": "0" * 64})


class TunisiaPinnedSourceIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(tunisia, "The verified Tunisian municipal polygon reader is missing")
        self.cache = ROOT / ".tools/atlas_sources"
        if not (self.cache / "audit/tunisia-municipal-2026/producer/data/source/tunisia-municipalities.geojson").exists():
            self.skipTest("The independently staged pinned source files are not present")

    def prepared(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            with patch.object(tunisia, "ROOT", output):
                sources = tunisia.prepare_sources(self.cache)
            manifest = json.loads((output / "data/atlas_tunisia_sources.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["sources"], sources)
        return sources

    def test_pinned_import_keeps_all338_source_units_and_reports335_atlas_intersections(self):
        sources = self.prepared()
        rows = list(tunisia.iter_boundaries(self.cache, sources))
        self.assertEqual(len(rows), 338)
        self.assertEqual(len({row["id"] for row in rows}), 338)
        self.assertEqual(sum(row["geometry"].intersection(box(-12, 33, 52, 72)).area > 0 for row in rows), 335)
        self.assertEqual(sources[0]["source_unit_count"], 338)
        self.assertEqual(sources[0]["units_intersecting_atlas_bbox"], 335)
        self.assertEqual(sources[0]["osm_timestamp"], "2026-10-16T20:21:21Z")
        self.assertTrue(sources[0]["blocks_full_coverage_claim"])
        self.assertNotIn("expected_unit_count", sources[0])
        self.assertNotIn("admin_level", sources[0])
        self.assertTrue(all(row["geometry"].is_valid for row in rows))

    def test_duplicate_source_names_remain_distinct_real_relation_units(self):
        sources = self.prepared()
        rows = list(tunisia.iter_boundaries(self.cache, sources))
        named = {name: sorted(row["osm_relation_id"] for row in rows if row["name"] == name)
                 for name in ("Ben Arous", "Fouchana")}
        self.assertEqual(named, {"Ben Arous": [7209941, 7304421], "Fouchana": [7209947, 7209948]})
        self.assertEqual(len(sources[0]["source_name_duplicate_groups"]), 2)
        self.assertEqual(len(sources[0]["upstream_geometry_corrections"]), 1)

    def test_changed_manifest_hash_or_commit_cannot_admit_replaced_sources(self):
        for field in ("sha256", "source_commit"):
            sources = self.prepared()
            sources[0][field] = "0" * (64 if field == "sha256" else 40)
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "integrity|hash|SHA|commit|source"):
                list(tunisia.iter_boundaries(self.cache, sources))


if __name__ == "__main__":
    unittest.main()
