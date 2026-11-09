"""Pinned Moroccan geometry must join real HCP commune codes and licenses."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

PATH = Path(__file__).resolve().with_name("atlas_morocco_sources.py")
if PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_morocco_sources", PATH)
    morocco = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(morocco)
else:
    morocco = None


class MoroccoCommuneSourceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(morocco, "Der belegte marokkanische Kommunalimport fehlt.")

    def topology(self, reverse=False):
        return {"type": "Topology", "transform": {"scale": [0.5, 0.5], "translate": [-5, 34]},
                "arcs": [[[0, 0], [2, 0], [0, 2], [-2, 0], [0, -2]]],
                "objects": {"communes": {"type": "GeometryCollection", "geometries": [
                    {"type": "Polygon", "arcs": [[-1 if reverse else 0]], "properties": {"code": "001511010"}}]}}}

    def attributes(self):
        return {"001511010": {"code": "01.511.01.0", "codeDigits": "001511010", "name": {"fr": "Tanger", "ar": "طنجة"},
                              "type": "urban", "parents": {"region": "01", "province": "01.511"},
                              "osm": {"relationId": 2758781}, "provenance": {"name": "hcp-2024", "geometry": "osm-odbl"}}}

    def test_delta_transform_and_negative_arc_keep_real_coordinates(self):
        for reverse in (False, True):
            with self.subTest(reverse=reverse):
                feature = next(morocco.iter_topology(self.topology(reverse)))
                row = morocco.normalize_feature(feature, self.attributes())
                self.assertAlmostEqual(row["geometry"].area, 1)
                self.assertEqual(row["geometry"].bounds, (-5, 34, -4, 35))

    def test_native_dotted_code_leading_zero_arabic_and_osm_identity_survive(self):
        row = morocco.normalize_feature(next(morocco.iter_topology(self.topology())), self.attributes())
        self.assertEqual(row["id"], "hcp:MA:commune:01.511.01.0")
        self.assertEqual(row["municipality_code"], "001511010")
        self.assertEqual(row["source_names"]["ar"], "طنجة")
        self.assertEqual(row["osm_relation_id"], 2758781)
        self.assertEqual(row["unit_type"], "Commune urbaine")

    def test_unmatched_geometry_and_noncommunal_unit_are_rejected(self):
        feature = next(morocco.iter_topology(self.topology()))
        with self.assertRaises(ValueError):
            morocco.normalize_feature(feature, {})
        attributes = self.attributes()
        attributes["001511010"]["type"] = "arrondissement"
        with self.assertRaises(ValueError):
            morocco.normalize_feature(feature, attributes)

    def test_missing_boundary_is_catalog_gap_and_never_fake_geometry(self):
        attributes = self.attributes()
        attributes["042810511"] = {"code": "04.281.05.11", "codeDigits": "042810511", "name": {"fr": "Sidi Mohamed Benmansour"}, "bbox": None, "centroid": None}
        gaps = morocco.boundary_gaps(attributes, {"001511010"})
        self.assertEqual([row["code"] for row in gaps], ["04.281.05.11"])
        self.assertIsNone(gaps[0]["bbox"])
        self.assertNotIn("geometry", gaps[0])

    def test_topology_holes_are_retained(self):
        topology = self.topology()
        topology["arcs"] = [[[0, 0], [4, 0], [0, 4], [-4, 0], [0, -4]], [[1, 1], [2, 0], [0, 2], [-2, 0], [0, -2]]]
        topology["objects"]["communes"]["geometries"][0]["arcs"] = [[0], [-2]]
        row = morocco.normalize_feature(next(morocco.iter_topology(topology)), self.attributes())
        self.assertAlmostEqual(row["geometry"].area, 3)
        self.assertEqual(len(row["geometry"].interiors), 1)

    def test_multipolygon_islands_are_retained(self):
        topology = self.topology()
        topology["arcs"].append([[4, 0], [2, 0], [0, 2], [-2, 0], [0, -2]])
        geometry = topology["objects"]["communes"]["geometries"][0]
        geometry["type"] = "MultiPolygon"
        geometry["arcs"] = [[[0]], [[1]]]
        row = morocco.normalize_feature(next(morocco.iter_topology(topology)), self.attributes())
        self.assertEqual(row["geometry"].geom_type, "MultiPolygon")
        self.assertEqual(len(row["geometry"].geoms), 2)
        self.assertAlmostEqual(row["geometry"].area, 2)

    def test_invalid_arc_reference_is_an_explicit_source_error(self):
        topology = self.topology()
        topology["objects"]["communes"]["geometries"][0]["arcs"] = [["0"]]
        with self.assertRaisesRegex(ValueError, "arc reference"):
            list(morocco.iter_topology(topology))

    def test_changed_raw_input_is_rejected_before_geometry_import(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            (cache / "attributes.json").write_text("[]", encoding="utf-8")
            source = {"id": morocco.SOURCE_ID, "source_commit": morocco.COMMIT,
                      "files": [{"cache_file": "attributes.json", "bytes": 2, "sha256": "0" * 64}]}
            with self.assertRaisesRegex(ValueError, "(?i)integrity|hash|sha|digest"):
                list(morocco.iter_boundaries(cache, [source]))


if __name__ == "__main__":
    unittest.main()
