"""Real data and compact atlas pipeline checks; no network requests in tests."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import struct
import unittest

from shapely.geometry import Polygon, mapping, shape

ROOT = Path(__file__).resolve().parents[1]
PIPELINE = ROOT / "tools/build_atlas_data.py"
if PIPELINE.exists():
    spec = importlib.util.spec_from_file_location("build_atlas_data", PIPELINE)
    atlas = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(atlas)
else:
    atlas = None


class AtlasPipelineUnitTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(atlas, "Die Atlas-Datenpipeline fehlt noch.")

    def test_projection_corners_and_known_cities(self):
        self.assertEqual(atlas.project(-12, 72), (0.0, 0.0))
        self.assertEqual(atlas.project(52, 33), (1200.0, 760.0))
        x, y = atlas.project(8.23976, 50.08258)
        self.assertAlmostEqual(x, 379.4955, places=3)
        self.assertAlmostEqual(y, 427.1087, places=3)
        berlin = atlas.project(13.41053, 52.52437)
        self.assertTrue(470 < berlin[0] < 485 and 375 < berlin[1] < 385)

    def test_projection_rejects_nonfinite_coordinate(self):
        with self.assertRaises(ValueError):
            atlas.project(float("nan"), 50)

    def test_country_codes_ignore_natural_earth_missing_value_sentinels(self):
        self.assertTrue(hasattr(atlas, "country_code"), "Fehlende Länderkennungen benötigen eine echte ADM0-Zuordnung.")
        self.assertEqual(atlas.country_code({"iso_a2_eh": "-1", "iso_a2": "-99", "adm0_a3": "ESB"}), "ESB")
        self.assertEqual(atlas.country_code({"iso_a2_eh": "FR", "adm0_a3": "FRA"}), "FR")

    def test_german_city_aliases_use_the_source_country(self):
        cases = [("Brussels", "BE", "Brüssel"), ("Liège", "BE", "Lüttich"),
                 ("Strasbourg", "FR", "Straßburg"), ("Saint Petersburg", "RU", "Sankt Petersburg")]
        for original, country, expected in cases:
            with self.subTest(original=original, country=country):
                normalize = getattr(atlas, "normalise_city_name", None)
                self.assertTrue(callable(normalize), "Ländergebundene deutsche Ortsnamen fehlen noch.")
                self.assertEqual(normalize(original, country), expected)

    def test_city_aliases_preserve_namesakes_in_other_countries(self):
        normalize = getattr(atlas, "normalise_city_name", None)
        self.assertTrue(callable(normalize), "Ortsalias-Regeln müssen das Land berücksichtigen.")
        for original, country in [("Rome", "US"), ("Brussels", "CA"), ("Vienna", "FR"),
                                  ("Berlin", "US"), ("Cologne", "IT")]:
            with self.subTest(original=original, country=country):
                self.assertEqual(normalize(original, country), original)

    def test_ags_fragments_merge_without_losing_leading_zero(self):
        raw = []
        for x in (0, 1):
            raw.append({"type": "Feature", "properties": {"ags": "01001", "gen": "Flensburg"},
                        "geometry": mapping(Polygon([(x, 0), (x + 1, 0), (x + 1, 1), (x, 1)]))})
        merged = atlas.merge_ags_features(raw, width=5)
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["properties"]["ags"], "01001")
        self.assertEqual(merged[0]["properties"]["gen"], "Flensburg")
        self.assertAlmostEqual(shape(merged[0]["geometry"]).area, 2.0)

    def test_ags_width_and_administrative_parent(self):
        self.assertEqual(atlas.administrative_id("region", "6"), "region:DE-06")
        self.assertEqual(atlas.administrative_id("district", "06414"), "district:DE-06414")
        self.assertEqual(atlas.administrative_parent_id("region", "06"), "country:DE")
        self.assertEqual(atlas.administrative_parent_id("district", "06414"), "region:DE-06")
        self.assertEqual(atlas.administrative_parent_id("municipality", "06414000"), "district:DE-06414")

    def test_water_parts_do_not_extend_land_boundaries_into_the_sea(self):
        raw = [
            {"type": "Feature", "properties": {"ags": "01", "gen": "Schleswig-Holstein", "gf": 4},
             "geometry": mapping(Polygon([(0, 0), (1, 0), (1, 1), (0, 1)]))},
            {"type": "Feature", "properties": {"ags": "01", "gen": "Schleswig-Holstein", "gf": 2},
             "geometry": mapping(Polygon([(1, 0), (2, 0), (2, 1), (1, 1)]))},
        ]
        merged = atlas.merge_ags_features(raw, width=2)
        self.assertEqual(len(merged), 1)
        self.assertAlmostEqual(shape(merged[0]["geometry"]).area, 1.0)

    def test_geometry_pool_offsets_are_points_not_bytes(self):
        pool = atlas.GeometryPool()
        first = pool.add_path([(10, 20), (30, 40), (50, 60)])
        second = pool.add_path([(70, 80), (90, 100)])
        self.assertEqual(first, [0, 3])
        self.assertEqual(second, [3, 2])
        self.assertEqual(len(pool.data), 5 * 8)
        self.assertEqual(struct.unpack_from("<ff", pool.data, second[0] * 8), (70.0, 80.0))

    def test_geometry_pool_rejects_short_and_nonfinite_paths(self):
        pool = atlas.GeometryPool()
        self.assertIsNone(pool.add_path([(1, 2)]))
        with self.assertRaises(ValueError):
            pool.add_path([(1, 2), (float("inf"), 3)])
        self.assertEqual(len(pool.data), 0)


class AtlasRealOutputTests(unittest.TestCase):
    def setUp(self):
        self.path = ROOT / "data/atlas.json"
        self.assertTrue(self.path.exists(), "Der echte Offline-Atlas wurde noch nicht gebaut.")
        self.data = json.loads(self.path.read_text(encoding="utf-8"))
        self.binary = (ROOT / "data/atlas_geometry.bin").read_bytes()

    def test_contract_and_all_path_offsets(self):
        self.assertEqual(self.data["schema"], 1)
        self.assertEqual(self.data["projection"]["size"], [1200, 760])
        self.assertEqual(self.data["projection"]["bounds"], [-12, 33, 52, 72])
        self.assertEqual(self.data["geometry"], "res://data/atlas_geometry.bin")
        self.assertEqual(len(self.binary) % 8, 0)
        point_count = len(self.binary) // 8
        self.assertLess(len(self.binary), 100_000_000)
        self.assertLess(self.path.stat().st_size, 15_000_000)
        entities = self.data["features"] + self.data["rivers"]
        self.assertGreater(len(entities), 10_000)
        for entity in entities:
            self.assertGreater(len(entity["paths"]), 0)
            for offset, count in entity["paths"]:
                self.assertGreaterEqual(offset, 0)
                self.assertGreaterEqual(count, 2)
                self.assertLessEqual(offset + count, point_count)
                for i in (offset, offset + count - 1):
                    x, y = struct.unpack_from("<ff", self.binary, i * 8)
                    self.assertTrue(-0.001 <= x <= 1200.001 and -0.001 <= y <= 760.001)

    def test_real_german_administrative_hierarchy(self):
        fs = self.data["features"]
        regions = [f for f in fs if f["kind"] == "region" and f.get("country") == "DE"]
        self.assertEqual(len(regions), 16)
        self.assertEqual(len({f["ags"] for f in regions}), 16)
        self.assertEqual({f["id"] for f in regions}, {"region:DE-%02d" % i for i in range(1, 17)})
        districts = [f for f in fs if f["kind"] == "district"]
        municipalities = [f for f in fs if f["kind"] == "municipality"]
        self.assertGreater(len(districts), 390)
        self.assertGreater(len(municipalities), 10_000)
        ids = {f["id"] for f in fs}
        for f in districts + municipalities:
            self.assertIn(f["parent_id"], ids)
            self.assertEqual(len(f["ags"]), 5 if f["kind"] == "district" else 8)

    def test_berlin_wiesbaden_and_existing_game_province_links(self):
        cities = {c["name"]: c for c in self.data["cities"] if c["country"] == "DE"}
        self.assertIn("Wiesbaden", cities)
        self.assertIn("Berlin", cities)
        self.assertTrue(377 < cities["Wiesbaden"]["point"][0] < 382)
        self.assertTrue(424 < cities["Wiesbaden"]["point"][1] < 430)
        self.assertTrue(470 < cities["Berlin"]["point"][0] < 485)
        self.assertTrue(375 < cities["Berlin"]["point"][1] < 385)
        geometry = json.loads((ROOT / "data/europe_geometry.json").read_text(encoding="utf-8"))
        known_ids = {pid for r in geometry["realms"].values() for pid in r["provinces"]}
        for city in (cities["Wiesbaden"], cities["Berlin"]):
            self.assertIn(city["province_id"], known_ids)
        self.assertGreater(len(self.data["cities"]), 3_000)

    def test_real_rivers_and_hashed_sources(self):
        names = {r["name"].casefold() for r in self.data["rivers"]}
        self.assertTrue(names.intersection({"rhine", "rhein"}))
        self.assertTrue(names.intersection({"danube", "donau"}))
        self.assertGreater(len(self.data["rivers"]), 100)
        for source in self.data["sources"]:
            self.assertTrue(source["url"].startswith("https://"))
            self.assertRegex(source["sha256"], r"^[a-f0-9]{64}$")
            self.assertTrue(source["license"])
            self.assertTrue(source["date"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
