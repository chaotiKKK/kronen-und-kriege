from __future__ import annotations

from copy import deepcopy
import hashlib
import importlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from shapely.geometry import GeometryCollection, LineString, Polygon
from shapely.ops import unary_union


def fixture():
    return {
        "realms": {"test": {"name": "Testreich", "provinces": {
            "left": {"parts": [[[0, 0], [10, 0], [10, 10], [0, 10]]], "label": [5, 5]},
            "right": {"parts": [[[10, 0], [20, 0], [20, 10], [10, 10]]], "label": [15, 5]},
        }}},
    }


class RegionBuildTest(unittest.TestCase):
    def module(self):
        self.assertIsNotNone(importlib.util.find_spec("tools.game_regions"), "Regionsgenerator fehlt")
        return importlib.import_module("tools.game_regions")

    def inputs(self, module, europe=None):
        return module.FrozenInputs(
            europe_geometry=europe or fixture(),
            cities=[{"id": "a", "name": "Links", "point": [5, 5], "population": 100},
                    {"id": "b", "name": "Rechts", "point": [15, 5], "population": 90}],
            atlas_edges=[{"id": "official", "points": [[10, 0], [10, 10]], "source": "fixture"}],
            source_status={"AZ": "gap", "TR": "source_review"},
            input_hashes={"fixture": "abc"},
        )

    def config(self, module, count=2, area=100):
        return module.RegionBuildConfig(target_count=count, minimum_count=count,
                                        maximum_count=count, target_area=area, minimum_per_realm=1)

    def test_largest_remainder_preserves_total_and_minimum(self):
        module = self.module()
        self.assertEqual(module.allocate_realm_counts({"a": 60, "b": 30, "c": 10}, 10),
                         {"a": 6, "b": 3, "c": 1})
        with self.assertRaises(ValueError):
            module.allocate_realm_counts({"a": 1, "b": 2}, 1)

    def test_two_regions_cover_fixture_and_use_real_names(self):
        module = self.module()
        config = self.config(module)
        result = module.build_regions(self.inputs(module), config)
        self.assertEqual(module.validate_manifest(result.manifest, result.frame, config), [])
        self.assertEqual([r["name"] for r in result.manifest["regions"]], ["Links", "Rechts"])
        self.assertEqual(result.audit["qualified_boundary_length"], 10.0)
        self.assertTrue(all(r["kind"] == "game_region" for r in result.manifest["regions"]))

    def test_build_is_byte_identical_and_both_migration_denominators_sum_to_one(self):
        module = self.module()
        inputs = self.inputs(module)
        config = self.config(module, 4, 50)
        first = module.build_regions(inputs, config)
        second = module.build_regions(inputs, config)
        self.assertEqual(module.canonical_json_bytes(first.manifest), module.canonical_json_bytes(second.manifest))
        self.assertEqual(first.geometry, second.geometry)
        totals = {"left": 0.0, "right": 0.0}
        for r in first.manifest["regions"]:
            self.assertAlmostEqual(sum(r["legacy_region_shares"].values()), 1.0)
            for parent, share in r["legacy_parent_shares"].items():
                self.assertGreater(share, 0)
                totals[parent] += share
        self.assertAlmostEqual(totals["left"], 1)
        self.assertAlmostEqual(totals["right"], 1)

    def test_nearby_qualified_edge_replaces_artificial_divide_without_area_loss(self):
        module = self.module()
        inputs = self.inputs(module)
        inputs.atlas_edges[0]["points"] = [[9, 0], [9, 10]]
        config = self.config(module)
        result = module.build_regions(inputs, config)
        self.assertEqual(module.validate_manifest(result.manifest, result.frame, config), [])
        self.assertEqual(result.audit["qualified_boundary_length"], 10.0)
        self.assertEqual([r["area"] for r in result.manifest["regions"]], [90.0, 110.0])

    def test_partial_official_boundary_is_connected_to_cell_endpoints(self):
        module = self.module()
        inputs = self.inputs(module)
        inputs.atlas_edges[0]["points"] = [[9, 2], [9, 8]]
        config = self.config(module)
        result = module.build_regions(inputs, config)
        self.assertEqual(module.validate_manifest(result.manifest, result.frame, config), [])
        self.assertGreaterEqual(result.audit["qualified_boundary_length"], 6.0)
        self.assertAlmostEqual(sum(r["area"] for r in result.manifest["regions"]), 200)

    def test_overlap_is_repaired_and_reported_without_negative_shares(self):
        module = self.module()
        europe = {"realms": {"a": {"provinces": {"old_a": {
            "parts": [[[0, 0], [10, 0], [10, 10], [0, 10]]], "label": [5, 5]}}},
            "b": {"provinces": {"old_b": {
                "parts": [[[9, 0], [20, 0], [20, 10], [9, 10]]], "label": [15, 5]}}}}}
        config = self.config(module)
        result = module.build_regions(self.inputs(module, europe), config)
        self.assertEqual(module.validate_manifest(result.manifest, result.frame, config), [])
        self.assertAlmostEqual(sum(r["area"] for r in result.manifest["regions"]), 200)
        self.assertAlmostEqual(result.audit["realm_overlap_area_removed"], 10)

    def test_clustered_anchors_are_relaxed_to_balanced_cells(self):
        module = self.module()
        europe = {"realms": {"long": {"provinces": {"parent": {
            "parts": [[[0, 0], [100, 0], [100, 10], [0, 10]]], "label": [1, 5]}}}}}
        inputs = self.inputs(module, europe)
        result = module.build_regions(inputs, self.config(module, 4, 250))
        self.assertTrue(all(.45 <= r["area_ratio"] <= 1.8 for r in result.manifest["regions"]))

    def test_validator_rejects_missing_parent_and_fabricated_exception(self):
        module = self.module()
        config = self.config(module)
        result = module.build_regions(self.inputs(module), config)
        bad = deepcopy(result.manifest)
        bad["regions"][0]["legacy_region_shares"] = {"left": .3}
        bad["regions"][0]["exception_reason"] = "irgendein Grund"
        errors = module.validate_manifest(bad, result.frame, config)
        self.assertTrue(any("Regionsanteile" in e for e in errors), errors)
        self.assertTrue(any("Ausnahme" in e for e in errors), errors)

    def test_canonical_json_rejects_nonfinite_and_is_order_independent(self):
        module = self.module()
        self.assertEqual(module.canonical_json_bytes({"b": 1, "a": 2}), b'{"a":2,"b":1}')
        with self.assertRaises(ValueError):
            module.canonical_json_bytes({"bad": float("nan")})

    def test_detached_mainland_fragment_is_transferred_to_touching_region(self):
        module = self.module()
        repair = getattr(module, "repair_connected_partition", None)
        self.assertTrue(callable(repair), "Festlandreparatur fehlt")
        frame = Polygon([[0, 0], [10, 0], [10, 10], [0, 10]])
        left = Polygon([[0, 0], [4, 0], [4, 10], [0, 10]])
        middle = Polygon([[4, 0], [8, 0], [8, 10], [4, 10]])
        detached = Polygon([[8, 0], [10, 0], [10, 10], [8, 10]])
        cells, transfers = repair(frame, [unary_union([left, detached]), middle])
        self.assertEqual(transfers, 1)
        self.assertEqual([c.geom_type for c in cells], ["Polygon", "Polygon"])
        self.assertEqual([c.area for c in cells], [40.0, 60.0])
        self.assertEqual(unary_union(cells).symmetric_difference(frame).area, 0)

    def test_separate_islands_remain_valid_when_component_intersection_is_empty(self):
        module = self.module()
        first = Polygon([[0, 0], [2, 0], [2, 2], [0, 2]])
        second = Polygon([[10, 0], [12, 0], [12, 2], [10, 2]])
        cells, transfers = module.repair_connected_partition(unary_union([first, second]), [first, second])
        self.assertEqual(transfers, 0)
        self.assertEqual([cell.area for cell in cells], [4.0, 4.0])

    def test_fragment_repair_tolerates_overlay_roundoff_at_shared_boundary(self):
        module = self.module()
        frame = Polygon([[0, 0], [10, 0], [10, 10], [0, 10]])
        left = Polygon([[0, 0], [4, 0], [4, 10], [0, 10]])
        middle = Polygon([[4, 0], [8 - 1e-10, 0], [8 - 1e-10, 10], [4, 10]])
        detached = Polygon([[8, 0], [10, 0], [10, 10], [8, 10]])
        cells, transfers = module.repair_connected_partition(frame, [unary_union([left, detached]), middle])
        self.assertEqual(transfers, 1)
        self.assertEqual([cell.geom_type for cell in cells], ["Polygon", "Polygon"])
        self.assertLess(unary_union(cells).symmetric_difference(frame).area, 1e-7)

    def test_zero_area_overlay_remnants_do_not_enter_region_boundary(self):
        module = self.module()
        frame = Polygon([[0, 0], [10, 0], [10, 10], [0, 10]])
        cells, _ = module.repair_connected_partition(frame, [GeometryCollection([frame, LineString([[0, 0], [1, 1]])])])
        self.assertEqual(cells[0].geom_type, "Polygon")
        self.assertEqual(cells[0].boundary.length, 40)

    def test_writer_hash_matches_runtime_manifest_and_returns_stored_hash(self):
        module = self.module()
        result = module.build_regions(self.inputs(module), self.config(module))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            written_hash = module.write_outputs(result, root, root / "receipt.json")
            stored = json.loads((root / "game_regions.json").read_text(encoding="utf-8"))
            geometry = (root / "game_region_geometry.bin").read_bytes()
            self.assertEqual(stored.pop("catalog_hash"), written_hash)
            self.assertEqual(hashlib.sha256(module.canonical_json_bytes(stored) + geometry).hexdigest(), written_hash)
            self.assertEqual(result.manifest["catalog_hash"], written_hash)
            self.assertEqual(stored["source_status"], {"AZ": "gap", "TR": "source_review"})
            self.assertTrue(all("parts" not in r for r in stored["regions"]))
            for r in stored["regions"]:
                self.assertTrue(r["geometry_refs"])


if __name__ == "__main__":
    unittest.main()
