import json
import inspect
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import patch

from shapely.geometry import box
from atlas_administration import land_coverage, natural_earth_role
import atlas_administration as administration
from atlas_administration import supplement
from build_atlas_data import GeometryPool, ProvinceIndex, feature_record

ROOT = Path(__file__).resolve().parents[1]


class AdministrativeMeaningTests(unittest.TestCase):
    def test_proven_dual_role_requires_evidence_and_no_duplicate_municipality(self):
        classify = getattr(administration, "is_local_coverage_area", None)
        self.assertTrue(callable(classify), "Proven combined county/city authorities must be represented without fake extra polygons")
        self.assertTrue(classify({"kind": "region", "local_government_role": "municipality", "local_government_role_evidence": "https://official.example/authority"}))
        self.assertFalse(classify({"kind": "region", "local_government_role": "municipality"}))
        self.assertFalse(classify({"kind": "region", "local_government_role": "municipality", "local_government_role_evidence": "https://official.example/authority", "local_government_represented_by": "municipality:existing"}))
        self.assertTrue(classify({"kind": "municipality"}))

    def test_unincorporated_bkg_land_is_not_a_municipal_government(self):
        classify = getattr(administration, "bkg_unit_role", None)
        self.assertTrue(callable(classify), "BKG's explicit local-area types must be preserved")
        self.assertEqual(classify("municipality", {"bez": "Gemeindefreies Gebiet"}),
                         ("local_admin", "Gemeindefreies Gebiet"))
        self.assertEqual(classify("municipality", {"bez": "Stadt"}), ("municipality", "Stadt"))
        self.assertEqual(classify("region", {"bez": "Land"}), ("region", "Land"))

    def test_local_councils_are_not_mislabeled_as_states(self):
        self.assertEqual(natural_earth_role("MT", {"type_en": None})[0], "municipality")
        self.assertEqual(natural_earth_role("LI", {"type_en": None})[0], "municipality")
        self.assertEqual(natural_earth_role("AD", {"type_en": None})[0], "municipality")
        self.assertEqual(natural_earth_role("SM", {"type_en": None})[0], "municipality")

    def test_provinces_and_departments_are_not_states_or_communes(self):
        self.assertEqual(natural_earth_role("FR", {"type_en": "Metropolitan department"})[0], "district")
        self.assertEqual(natural_earth_role("IT", {"type_en": "Province"})[0], "district")
        self.assertEqual(natural_earth_role("PT", {"type_en": "District"})[0], "district")
        self.assertEqual(natural_earth_role("ES", {"adm1_code": "ESP-001", "iso_3166_2": "ES-HU",
                                                 "name": "Huesca", "type_en": "Autonomous Community"}),
                         ("district", "Provincia"))

    def test_abolished_luxembourg_districts_are_not_current_regions(self):
        self.assertIsNone(natural_earth_role("LU", {"type_en": "District"})[0],
                          "The three administrative districts abolished in 2015 must not survive as current regions")

    def test_unknown_administrative_data_are_not_claimed_as_municipal(self):
        self.assertNotEqual(natural_earth_role("RU", {"type_en": "District"})[0], "municipality")
        self.assertNotEqual(natural_earth_role("TR", {"type_en": "Province"})[0], "municipality")

    def test_known_natural_earth_role_errors_do_not_inflate_local_coverage(self):
        # Original NE mislabels BY-MI oblast and EE-74 county as municipalities.
        self.assertEqual(natural_earth_role("BY", {"iso_3166_2": "BY-MI", "type": "Gorod", "type_en": "Municipality"}),
                         ("region", "Woblast"))
        self.assertEqual(natural_earth_role("EE", {"iso_3166_2": "EE-74", "type": "Novads", "type_en": "Municipality"}),
                         ("region", "Maakond"))

    def test_union_coverage_does_not_count_overlapping_units_twice(self):
        result = land_coverage(box(0, 40, 2, 42), [box(0, 40, 1, 42), box(0, 40, 1, 42)])
        self.assertAlmostEqual(result["fraction"], 0.5, places=6)
        self.assertGreater(result["land_area_km2"], 0)

    def test_foreign_land_cannot_fill_a_domestic_gap(self):
        result = land_coverage(box(0, 40, 2, 42), [box(2, 40, 4, 42)])
        self.assertEqual(result["fraction"], 0.0)

    def test_full_and_empty_land_coverage(self):
        land = box(0, 40, 2, 42)
        self.assertAlmostEqual(land_coverage(land, [land])["fraction"], 1.0, places=6)
        self.assertEqual(land_coverage(land, [])["fraction"], 0.0)


class CrossCountryOutputTests(unittest.TestCase):
    def test_real_regional_frames_are_distinct_from_provinces_and_local_units(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        features = data["features"]
        for country, expected in [("FR", 13), ("IT", 20), ("ES", 18), ("GB", 4)]:
            with self.subTest(country=country):
                regions = [f for f in features if f.get("country") == country and f["kind"] == "region"]
                self.assertEqual(len(regions), expected)
                self.assertTrue(all(f["source"] != "natural-earth-regions" for f in regions))
                self.assertGreater(sum(f.get("country") == country and f["kind"] == "municipality" for f in features), 300)
        self.assertGreater(sum(f.get("country") == "ES" and f["kind"] == "district" for f in features), 45)
        self.assertGreater(sum(f.get("country") == "FR" and f["kind"] == "district" for f in features), 90)

    def test_eastern_local_areas_and_proven_aliases_are_embedded(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        features = data["features"]
        with self.subTest(country="RU"):
            self.assertGreater(sum(f.get("country") == "RU" and f["kind"] == "municipality" for f in features), 6000)
        with self.subTest(country="TR"):
            self.assertGreater(sum(f.get("country") == "TR" and f["kind"] == "local_admin" for f in features), 10000)
            self.assertEqual(sum(f.get("country") == "TR" and f["kind"] == "region" and f.get("local_government_role") == "municipality" for f in features), 30)
            excluded = data["administrative_coverage"]["TR"]["excluded_administrative_units"]
            self.assertEqual(len(excluded), 11)
            self.assertTrue(all(item["id"] not in {f["id"] for f in features} and item["evidence"].startswith("https://") for item in excluded))
        with self.subTest(country="CZ"):
            civil = sum(f.get("country") == "CZ" and administration.is_local_coverage_area(f)
                        and (f["kind"] == "municipality" or f.get("local_government_role") == "municipality")
                        for f in features)
            self.assertEqual(civil, 6254)
        with self.subTest(country="FO"):
            self.assertEqual(data["administrative_coverage"]["FO"]["land_reference_source"], "us-physical-islands-FO-20261109")
            self.assertGreater(data["administrative_coverage"]["FO"]["fraction"], 0.995)
        with self.subTest(country="AM"):
            municipalities = [f for f in features if f.get("country") == "AM" and f["kind"] == "municipality"]
            self.assertEqual(len(municipalities), 61)
            self.assertEqual(sum(f.get("country") == "AM" and f.get("local_government_role") == "municipality" for f in features), 1)
            self.assertFalse(any(f["source"] == "gbOpen-ARM-ADM2" or f["id"] == "region:ARM-1675" for f in features))
            self.assertIn("gbOpen-ARM-ADM2", data["administrative_coverage"]["AM"]["excluded_administrative_sources"])
        with self.subTest(country="TN"):
            self.assertEqual(sum(f["source"] == "map-tunisia-municipalities-OSM20261016" and f["kind"] == "municipality" for f in features), 335)
        with self.subTest(country="CNM"):
            parts = [f for f in features if f.get("country") == "CNM" and f["kind"] == "municipality"]
            self.assertGreater(len(parts), 50)
            self.assertTrue(all(f.get("source_country") == "CY" for f in parts))
            self.assertEqual(data["administrative_coverage"]["CNM"]["status"], "source_review")
        for country, reference in [("EE", "maaruum-physical-land-EE-20261101"),
                                   ("GG", "eea-physical-islands-GG-v3-2017"), ("JE", "eea-physical-islands-JE-v3-2017")]:
            with self.subTest(country=country):
                self.assertEqual(data["administrative_coverage"][country]["land_reference_source"], reference)
                self.assertGreater(data["administrative_coverage"][country]["fraction"], 0.95)
        with self.subTest(contract="attested source aliases"):
            aliases = [alias for feature in features for alias in feature.get("source_aliases", [])]
            self.assertEqual(len(aliases), 136)
            ids = {feature["id"] for feature in features}
            self.assertTrue(all(alias["id"] not in ids for alias in aliases))
            for feature in features:
                if feature.get("source_aliases"):
                    self.assertTrue(feature["osm_record_id"].startswith("r"))
                    self.assertNotEqual(feature["parent_id"], "country:" + feature["country"])

    def test_verified_new_local_sources_survive_the_final_merge(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        features = data["features"]
        with self.subTest(country="LU"):
            communes = [f for f in features if f.get("country") == "LU" and f["kind"] == "municipality"]
            cantons = [f for f in features if f.get("country") == "LU" and f["kind"] == "district"]
            self.assertEqual(len(communes), 100)
            self.assertEqual(len(cantons), 12)
            self.assertTrue(all(f["source"] == "act-LU-communes-20261105" for f in communes))
            self.assertTrue(all(f["parent_id"] in {c["id"] for c in cantons} for f in communes))
            self.assertFalse(any(f.get("country") == "LU" and f["source"] == "natural-earth-regions" for f in features))
        with self.subTest(country="NO"):
            communes = [f for f in features if f.get("country") == "NO" and f["kind"] == "municipality"]
            self.assertEqual(len(communes), 357)
            self.assertEqual(sum(f["name"] == "Røros" for f in communes), 1)
            self.assertEqual(sum(f["name"] == "Oslo" for f in communes), 1)
        with self.subTest(country="CZ"):
            praha = [f for f in features if f.get("country") == "CZ" and f["name"] == "Praha" and f["kind"] == "region"]
            self.assertEqual(len(praha), 1)
            self.assertEqual(praha[0].get("local_government_role"), "municipality")
            self.assertTrue(praha[0].get("local_government_role_evidence"))
        with self.subTest(country="EE"):
            self.assertEqual(sum(f.get("country") == "EE" and f["kind"] == "municipality" for f in features), 78)
        with self.subTest(country="BY"):
            self.assertFalse(any(f["id"] == "region:BLR-2345" and f["kind"] == "municipality" for f in features))

    def test_terminal_jurisdictions_are_explained_without_fabricated_subdivisions(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        for country in ("MC", "VA", "GI"):
            entry = data["administrative_coverage"][country]
            self.assertEqual(entry["status"], "single_jurisdiction")
            self.assertFalse(entry["measurement_applicable"])
            self.assertFalse(entry["classification_is_geometric_coverage"])
            self.assertTrue(entry["authority_evidence"])

    def test_precise_aland_and_german_local_types_are_embedded_without_duplicates(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        aland = [f for f in data["features"] if f.get("country") == "AX" and f["kind"] == "municipality"]
        self.assertEqual(len(aland), 16)
        self.assertTrue(all(f["source"] == "mml-AX-kunta-2025-10k" for f in aland))
        self.assertTrue(all(f.get("display_clip_source") == "syke-physical-land-AX-MML2025" for f in aland))
        self.assertGreater(data["administrative_coverage"]["AX"]["fraction"], 0.995)
        de = [f for f in data["features"] if f.get("country") == "DE"]
        self.assertEqual(sum(f["kind"] == "municipality" for f in de), 10751)
        self.assertEqual(sum(f["kind"] == "local_admin" for f in de), 198)

    def test_verified_hungarian_municipalities_and_budapest_districts_are_embedded(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        hu = [feature for feature in data["features"] if feature.get("country") == "HU"]
        self.assertEqual(sum(f["kind"] == "municipality" for f in hu), 3155)
        self.assertEqual(sum(f["kind"] == "local_admin" for f in hu), 23)
        self.assertEqual(sum(f["kind"] == "region" for f in hu), 20)
        self.assertEqual(sum(f["kind"] == "district" for f in hu), 174)

    def test_small_country_audit_uses_independent_reviewed_geometry(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        for country, source in [("LI", "swisstopo-land-LI-2026"), ("SM", "istat-italy-enclave-SM-2023")]:
            national = next(f for f in data["features"] if f["id"] == "country:" + country)
            self.assertEqual(national["source"], source, "The inaccurate generalised country mask still overrides authentic small-country geometry")
            entry = data["administrative_coverage"][country]
            self.assertEqual(entry.get("land_reference_source"), source)
            self.assertGreater(entry["fraction"], 0.95)

    def test_real_neighboring_municipalities_are_embedded(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        for country, lower_bound in [("FR", 30000), ("IT", 7000), ("ES", 7000), ("PL", 2400), ("AT", 2000), ("CH", 2000)]:
            count = sum(f["kind"] == "municipality" and f.get("country") == country for f in data["features"])
            self.assertGreater(count, lower_bound, f"Echte Gemeindeebene fehlt weiterhin für {country}")

    def test_prepared_irish_and_moroccan_local_authorities_are_embedded(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        for country, minimum in [("IE", 31), ("MA", 600)]:
            municipalities = [f for f in data["features"] if f.get("country") == country and f["kind"] == "municipality"]
            self.assertGreaterEqual(len(municipalities), minimum,
                                    f"Prepared genuine local government source not merged for {country}")

    def test_all_countries_have_an_explicit_measured_coverage_status(self):
        data = json.loads((ROOT / "data/atlas.json").read_text(encoding="utf-8"))
        countries = {f["country"] for f in data["features"] if f["kind"] == "country"}
        coverage = data.get("administrative_coverage", {})
        self.assertEqual(set(coverage), countries)
        for country, entry in coverage.items():
            self.assertIn("fraction", entry)
            self.assertTrue(0 <= entry["fraction"] <= 1)
            if entry.get("status") == "complete":
                self.assertGreaterEqual(entry["fraction"], 0.95, country)
                self.assertFalse(entry.get("blocks_full_coverage_claim", False), country)


class MultiTerritorySourceTests(unittest.TestCase):
    def test_one_disproved_local_unit_does_not_quarantine_its_valid_neighbors(self):
        land = box(30, 40, 32, 41)
        rows = [dict(id="valid:1", country="TR", source="mixed", name="Echte Gemeinde", kind="municipality", geometry=box(30, 40, 31, 41)),
                dict(id="obsolete:2", country="TR", source="mixed", name="Aufgehobene Belde", kind="municipality", geometry=box(31, 40, 32, 41),
                     administrative_geometry_eligible=False, administrative_ineligibility_note="Rechtspersönlichkeit aufgehoben.",
                     administrative_ineligibility_evidence_url="https://official.example/abolition", administrative_ineligibility_act="6360")]
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        features = [feature_record(pool, provinces, land, feature_id="country:TR", name="TR", kind="country", parent_id="", country="TR", source="land", tolerance=0)]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_geofabrik_sources.json").write_text(json.dumps({"sources": [dict(id="mixed", country="TR", kind="municipality")]}))
            reader = SimpleNamespace(__name__="atlas_geofabrik_sources", iter_boundaries=lambda *_: iter(rows))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                _, coverage, _ = supplement(features, pool, provinces, feature_record, {"TR": land}, [], root, root)
        self.assertEqual([f["id"] for f in features if f["kind"] == "municipality"], ["valid:1"])
        self.assertAlmostEqual(coverage["TR"]["fraction"], 0.5)
        self.assertEqual(coverage["TR"]["status"], "source_review")
        self.assertNotIn("mixed", coverage["TR"].get("excluded_administrative_sources", []))
        self.assertEqual(coverage["TR"]["excluded_administrative_units"][0]["id"], "obsolete:2")
        self.assertEqual(coverage["TR"]["excluded_administrative_units"][0]["evidence"], "https://official.example/abolition")
        self.assertEqual(coverage["TR"]["excluded_administrative_units"][0]["review"]["administrative_ineligibility_act"], "6360")

    def _merge_regional_frame_fixture(self, replace_kinds=None):
        land = box(-4, 40, -2, 42)
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        features = [feature_record(pool, provinces, land, feature_id=identifier, name=identifier,
                    kind=kind, parent_id="" if kind == "country" else "country:ES", country="ES", source=source, tolerance=0)
                    for identifier, kind, source in [("country:ES", "country", "land"),
                        ("ne:region", "region", "natural-earth-regions"), ("ne:province", "district", "natural-earth-regions"),
                        ("retained:municipality", "municipality", "qualified-local")]]
        source = dict(id="current-regions", country="ES", kind="region",
                      replace_natural_earth_kinds=["region"] if replace_kinds is None else replace_kinds)
        row = dict(id="current:region", country="ES", source="current-regions", name="Autonomía", kind="region", geometry=land)
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_regional_sources.json").write_text(json.dumps({"sources": [source]}))
            reader = SimpleNamespace(__name__="atlas_regional_sources", iter_boundaries=lambda *_: iter([row]))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                supplement(features, pool, provinces, feature_record, {"ES": land}, [], root, root)
        return features

    def test_complete_regional_frame_keeps_real_provinces_and_municipalities(self):
        features = self._merge_regional_frame_fixture()
        self.assertEqual({f["id"] for f in features}, {"country:ES", "ne:province", "retained:municipality", "current:region"})

    def test_regional_frame_cannot_request_erasure_of_local_authorities(self):
        with self.assertRaisesRegex(ValueError, "regional frame"):
            self._merge_regional_frame_fixture(replace_kinds=["municipality"])

    def _merge_capital_reference_fixture(self, old_source="natural-earth-regions"):
        land = box(44, 40, 46, 41)
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        features = [feature_record(pool, provinces, shape, feature_id=identifier, name=identifier,
                    kind=kind, parent_id="" if kind == "country" else "country:AM", country="AM", source=source, tolerance=0)
                    for identifier, kind, source, shape in [("country:AM", "country", "land", land),
                        ("ne:capital", "region", old_source, box(44, 40, 45, 41)),
                        ("ne:neighbor", "region", "natural-earth-regions", box(45, 40, 46, 41))]]
        features.append(feature_record(pool, provinces, box(44.1, 40.1, 44.2, 40.2), feature_id="retained:district",
                        name="Bezirk", kind="district", parent_id="ne:capital", country="AM", source="qualified-district", tolerance=0))
        row = dict(id="new:capital", country="AM", source="qualified", name="Yerevan", kind="region",
                   geometry=box(44, 40, 45, 41), replaces_reference_features=["ne:capital"],
                   replacement_evidence_url="https://official.example/capital-identity")
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_armenia_sources.json").write_text(json.dumps({"sources": [dict(id="qualified", country="AM", kind="region")]}))
            reader = SimpleNamespace(__name__="atlas_armenia_sources", iter_boundaries=lambda *_: iter([row]))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                supplement(features, pool, provinces, feature_record, {"AM": land}, [], root, root)
        return features

    def test_one_verified_capital_replaces_only_its_coarse_reference(self):
        features = self._merge_capital_reference_fixture()
        self.assertEqual({f["id"] for f in features}, {"country:AM", "ne:neighbor", "new:capital", "retained:district"})
        capital = next(f for f in features if f["id"] == "new:capital")
        self.assertEqual(capital["replaced_reference_features"][0]["id"], "ne:capital")
        self.assertEqual(capital["replaced_reference_features"][0]["source"], "natural-earth-regions")
        self.assertEqual(next(f for f in features if f["id"] == "retained:district")["parent_id"], "new:capital")

    def test_reference_replacement_cannot_erase_another_qualified_provider(self):
        with self.assertRaisesRegex(ValueError, "reference"):
            self._merge_capital_reference_fixture(old_source="another-qualified-provider")

    def test_qualified_armenian_units_replace_no_unproven_reference_geometry(self):
        land = box(44, 40, 45, 41)
        old = dict(id="old:42", country="AM", source="old", name="Notfallregion", kind="municipality", geometry=land)
        current = dict(id="current:42", country="AM", source="current", name="Echte Gemeinde", kind="municipality", geometry=land)
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        features = [feature_record(pool, provinces, land, feature_id="country:AM", name="AM",
                    kind="country", parent_id="", country="AM", source="land", tolerance=0)]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            entries = [("atlas_communal_sources", "old", False), ("atlas_armenia_sources", "current", True)]
            for module, identifier, eligible in entries:
                (root / ("data/%s.json" % module)).write_text(json.dumps({"sources": [dict(
                    id=identifier, country="AM", kind="municipality", administrative_geometry_eligible=eligible)]}))
            readers = {"atlas_communal_sources": SimpleNamespace(__name__="atlas_communal_sources", iter_boundaries=lambda *_: iter([old])),
                       "atlas_armenia_sources": SimpleNamespace(__name__="atlas_armenia_sources", iter_boundaries=lambda *_: iter([current]))}
            with patch("atlas_administration.importlib.import_module", side_effect=lambda name: readers[name]):
                _, coverage, _ = supplement(features, pool, provinces, feature_record, {"AM": land}, [], root, root)
        self.assertEqual([f["id"] for f in features if f["kind"] == "municipality"], ["current:42"])
        self.assertEqual(coverage["AM"]["status"], "complete")
        self.assertEqual(coverage["AM"]["excluded_administrative_sources"], ["old"])

    def test_unproven_administrative_role_is_quarantined_without_invented_relabeling(self):
        land = box(44, 40, 45, 41)
        row = dict(id="reference:42", country="AM", source="reference", name="Notfallregion",
                   kind="municipality", geometry=land)
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        features = [feature_record(pool, provinces, land, feature_id="country:AM", name="AM",
                    kind="country", parent_id="", country="AM", source="land", tolerance=0)]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_communal_sources.json").write_text(json.dumps({"sources": [
                dict(id="reference", country="AM", kind="municipality", administrative_geometry_eligible=False,
                     administrative_ineligibility_note="Producer: not an official administrative level")]}))
            reader = SimpleNamespace(__name__="atlas_communal_sources", iter_boundaries=lambda *_: iter([row]))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                sources, coverage, _ = supplement(features, pool, provinces, feature_record, {"AM": land}, [], root, root)
        self.assertEqual([f["id"] for f in features], ["country:AM"])
        self.assertEqual(coverage["AM"]["fraction"], 0.0)
        self.assertEqual(coverage["AM"]["status"], "source_review")
        self.assertEqual(coverage["AM"]["excluded_administrative_sources"], ["reference"])
        self.assertEqual(sources[0]["administrative_geometry_eligible"], False)

    def test_municipal_boundary_layer_without_admin_level_is_imported_as_proven_role(self):
        land = box(10, 36, 11, 37)
        row = dict(id="tn:42", country="TN", source="tn", name="Gemeinde", kind="municipality",
                   unit_type="Commune", source_admin_type="boundary=municipality", geometry=land)
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        features = [feature_record(pool, provinces, land, feature_id="country:TN", name="TN",
                    kind="country", parent_id="", country="TN", source="land", tolerance=0)]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_tunisia_sources.json").write_text(json.dumps({"sources": [
                dict(id="tn", country="TN", kind="municipality")]}))
            reader = SimpleNamespace(__name__="atlas_tunisia_sources", iter_boundaries=lambda *_: iter([row]))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                _, coverage, _ = supplement(features, pool, provinces, feature_record, {"TN": land}, [], root, root)
        local = [f for f in features if f["kind"] == "municipality"]
        self.assertEqual(len(local), 1, "A real independent municipal layer must not be lost merely because OSM has no numeric admin_level")
        self.assertEqual(local[0]["source_admin_type"], "boundary=municipality")
        self.assertAlmostEqual(coverage["TN"]["fraction"], 1.0)

    def _merge_osm_alias_fixture(self, alias=None, *, target_name="Quellort", target_version=3,
                                 target_geometry=None, include_target=True, include_child=False,
                                 include_parent=False, target_source_blocked=False, target_record_override=None):
        land = box(30, 40, 31, 41)
        target_geometry = target_geometry if target_geometry is not None else box(30, 40, 30.9995, 41)
        rows = [dict(id="gf:42", country="TR", source="gf", name="Quellort", original_name="Quellort",
                     kind="local_admin", source_admin_level=8, original_source_id="42", geometry=land)]
        if alias is not None:
            rows[0]["verified_source_alias"] = alias
        if include_child:
            rows.append(dict(id="gf:child", country="TR", source="gf", name="Ortsteil",
                             kind="local_admin", source_admin_level=9, parent_id="gf:42", geometry=box(30.1, 40.1, 30.2, 40.2)))
        if include_parent:
            rows[0].update(parent_id="gf:district", parent_relationship="inferred-area-containment", parent_overlap_fraction=1.0)
            rows.append(dict(id="gf:district", country="TR", source="gf", name="Bezirk", kind="district", geometry=land))
        target = dict(id="osm:relation:42", country="TR", source="osm", name=target_name,
                      original_name=target_name, kind="local_admin", source_admin_level="8",
                      osm_relation_id=42, osm_relation_version=target_version,
                      osm_record_id=target_record_override or "r42@%s" % target_version, geometry=target_geometry,
                      parent_relationship="query-country-scope")
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        features = [feature_record(pool, provinces, land, feature_id="country:TR", name="TR",
                    kind="country", parent_id="", country="TR", source="land", tolerance=0)]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            for module, source in [("atlas_geofabrik_sources", "gf"), ("atlas_osm_sources", "osm")]:
                (root / ("data/%s.json" % module)).write_text(json.dumps({"sources": [
                    {"id": source, "country": "TR", "kind": "local_admin", "replacement_scope": "feature",
                     "blocks_full_coverage_claim": source == "osm" and target_source_blocked}]}))
            readers = {
                "atlas_geofabrik_sources": SimpleNamespace(__name__="atlas_geofabrik_sources", iter_boundaries=lambda *_: iter(rows)),
                "atlas_osm_sources": SimpleNamespace(__name__="atlas_osm_sources", iter_boundaries=lambda *_: iter([target] if include_target else [])),
            }
            with patch("atlas_administration.importlib.import_module", side_effect=lambda name: readers[name]):
                _, coverage, _ = supplement(features, pool, provinces, feature_record, {"TR": land}, [], root, root)
        return features, coverage

    @staticmethod
    def _alias_fixture():
        return dict(target_id="osm:relation:42", target_record_id="r42@3", target_source="osm",
                    common_id="42", country="TR", admin_level=8, original_name="Quellort",
                    geometry_intersection_over_union=0.9995, audit_file="audit/fixture.json",
                    audit_sha256="a" * 64, geofabrik_cache_sha256="b" * 64)

    def test_verified_geometry_alias_keeps_versioned_osm_and_its_actual_coverage(self):
        features, coverage = self._merge_osm_alias_fixture(self._alias_fixture())
        local = [f for f in features if f["kind"] == "local_admin"]
        self.assertEqual([f["id"] for f in local], ["osm:relation:42"], "A proven second representation must not appear as another local government")
        self.assertEqual(local[0]["osm_record_id"], "r42@3")
        self.assertEqual(local[0]["source_aliases"][0]["id"], "gf:42")
        self.assertEqual(local[0]["source_aliases"][0]["source"], "gf")
        self.assertAlmostEqual(coverage["TR"]["fraction"], 0.9995, places=7,
                               msg="Discarded alias geometry must not inflate the chosen source's coverage")

    def test_shared_common_id_without_verified_alias_does_not_merge_units(self):
        features, _ = self._merge_osm_alias_fixture()
        self.assertEqual({f["id"] for f in features if f["kind"] == "local_admin"}, {"gf:42", "osm:relation:42"})

    def test_alias_preserves_real_child_parent_relationship(self):
        features, _ = self._merge_osm_alias_fixture(self._alias_fixture(), include_child=True)
        child = next(f for f in features if f["id"] == "gf:child")
        self.assertEqual(child["parent_id"], "osm:relation:42", "The child of an aliased authority must retain its real parent instead of falling back to the whole country")

    def test_alias_preserves_qualified_parent_instead_of_query_country_scope(self):
        features, _ = self._merge_osm_alias_fixture(self._alias_fixture(), include_parent=True)
        target = next(f for f in features if f["id"] == "osm:relation:42")
        self.assertEqual(target["parent_id"], "gf:district")
        self.assertEqual(target["original_parent_id"], "country:TR")
        self.assertEqual(target["parent_relationship"], "inferred-area-containment")
        self.assertEqual(target["parent_overlap_fraction"], 1.0)
        self.assertEqual(target["parent_source_alias"], "gf:42")

    def test_alias_transfers_only_proven_unit_qualification_to_chosen_geometry(self):
        features, coverage = self._merge_osm_alias_fixture(self._alias_fixture(), target_source_blocked=True)
        self.assertEqual(coverage["TR"]["status"], "complete", "A country-incomplete OSM sample must not erase the same unit's independent GF qualification")
        self.assertAlmostEqual(coverage["TR"]["unblocked_source_fraction"], 0.9995, places=7)
        target = next(f for f in features if f["id"] == "osm:relation:42")
        self.assertEqual(target.get("coverage_qualification_source_aliases"), ["gf:42"])

    def test_verified_alias_rejects_changed_identity_version_or_geometry(self):
        for change in [dict(target_name="Anderer Ort"), dict(target_version=4),
                       dict(target_version=4, target_record_override="r42@3"),
                       dict(target_geometry=box(30, 40, 30.9, 41)), dict(include_target=False)]:
            with self.subTest(change=change):
                with self.assertRaisesRegex(ValueError, "alias"):
                    self._merge_osm_alias_fixture(self._alias_fixture(), **change)

    def test_marine_admin_geometry_is_displayed_only_on_verified_physical_land(self):
        self.assertIn("independent_reference_ids", inspect.signature(supplement).parameters,
                      "Physical display clipping must verify its independent land source")
        land = box(20, 60, 21, 61)
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        source = {"id": "marine", "country": "AX", "kind": "municipality", "requires_physical_land_clip": True,
                  "land_reference_source_id": "physical-AX"}
        row = {"id": "marine:42", "country": "AX", "source": "marine", "name": "AX", "kind": "municipality",
               "geometry": box(19, 59, 22, 62)}
        features = [feature_record(pool, provinces, land, feature_id="country:AX", name="AX",
            kind="country", parent_id="", country="AX", source="physical-AX", tolerance=0)]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_official_sources.json").write_text(json.dumps({"sources": [source]}))
            reader = SimpleNamespace(__name__="atlas_official_sources", iter_boundaries=lambda *_: iter([row]))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                _, coverage, _ = supplement(features, pool, provinces, feature_record, {"AX": land}, [], root, root,
                    independent_reference_ids={"AX": "physical-AX"})
        feature = next(f for f in features if f["id"] == row["id"])
        self.assertAlmostEqual(feature["bounds"][2], 1200 / 64, places=4,
                               msg="Sea administration must not be drawn as municipal land")
        self.assertEqual(feature.get("display_clip_source"), "physical-AX")
        self.assertAlmostEqual(coverage["AX"]["fraction"], 1.0)

    def test_precise_local_source_replaces_only_its_country_part_of_shared_provider(self):
        lands = {"FI": box(20, 60, 21, 61), "AX": box(21, 60, 22, 61)}
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        sources = [{"id": "general", "country": "FI", "scope_countries": ["FI", "AX"], "kind": "municipality"},
                   {"id": "precise-AX", "country": "AX", "kind": "municipality", "merge_priority": 4}]
        rows = [{"id": "general:" + country, "country": country, "country_assignment_method": "official_code",
                 "source": "general", "name": country, "kind": "municipality", "geometry": land}
                for country, land in lands.items()]
        rows.append({"id": "precise:AX", "country": "AX", "source": "precise-AX", "name": "AX",
                     "kind": "municipality", "geometry": lands["AX"]})
        features = [feature_record(pool, provinces, land, feature_id="country:" + country, name=country,
            kind="country", parent_id="", country=country, source="land", tolerance=0) for country, land in lands.items()]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_official_sources.json").write_text(json.dumps({"sources": sources}))
            reader = SimpleNamespace(__name__="atlas_official_sources", iter_boundaries=lambda *_: iter(rows))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                supplement(features, pool, provinces, feature_record, lands, [], root, root)
        ids = {feature["id"] for feature in features if feature["kind"] == "municipality"}
        self.assertEqual(ids, {"general:FI", "precise:AX"}, "The same local units are duplicated or the unrelated mainland source is removed")

    def test_generalised_country_mask_does_not_erase_authentic_single_country_geometry(self):
        land = box(30, 50, 31, 51)
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        row = {"id": "official:42", "name": "Quellgemeinde", "kind": "municipality", "country": "LI",
               "parent_id": "country:LI", "source": "fixture", "geometry": box(29.9, 50, 31.1, 51)}
        features = [feature_record(pool, provinces, land, feature_id="country:LI", name="LI",
            kind="country", parent_id="", country="LI", source="fixture-land", tolerance=0)]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_official_sources.json").write_text(json.dumps({"sources": [
                {"id": "fixture", "kind": "municipality", "country": "LI"}]}))
            reader = SimpleNamespace(__name__="atlas_official_sources", iter_boundaries=lambda *_: iter([row]))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                supplement(features, pool, provinces, feature_record, {"LI": land}, [], root, root)
        original = next(feature for feature in features if feature["id"] == row["id"])
        self.assertAlmostEqual(original["bounds"][2], 1.2 * 1200 / 64, places=4,
            msg="A cartographically generalised mask must not cut away the original administrative polygon")

    def test_partial_provider_adds_real_features_without_replacing_existing_country_units(self):
        land = box(30, 50, 31, 51)
        pool = GeometryPool()
        provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
        country = feature_record(pool, provinces, land, feature_id="country:RU", name="RU",
            kind="country", parent_id="", country="RU", source="fixture-land", tolerance=0)
        existing = feature_record(pool, provinces, land, feature_id="existing:local", name="Bestand",
            kind="municipality", parent_id="country:RU", country="RU", source="natural-earth-regions", tolerance=0)
        source = {"id": "partial-osm", "country": "RU", "kind": "municipality",
                  "replacement_scope": "feature", "blocks_full_coverage_claim": True}
        row = {"id": "osm:r42", "name": "Zusätzliche Fläche", "kind": "municipality", "country": "RU",
               "parent_id": "country:RU", "source": source["id"], "geometry": box(30, 50, 30.5, 51)}
        features = [country, existing]
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            (root / "data/atlas_osm_sources.json").write_text(json.dumps({"sources": [source]}))
            reader = SimpleNamespace(__name__="atlas_osm_sources", iter_boundaries=lambda *_: iter([row]))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                _, coverage, _ = supplement(features, pool, provinces, feature_record, {"RU": land},
                           [("RU", land, "natural-earth-regions")], root, root)
        self.assertIn("osm:r42", {feature["id"] for feature in features}, "The prepared OSM provider is ignored")
        self.assertIn("existing:local", {feature["id"] for feature in features}, "A partial scan erased the country's existing local layer")
        self.assertEqual(coverage["RU"]["status"], "complete",
                         "A partial enrichment must not invalidate independently complete trusted coverage")

    def test_source_polygon_parts_are_retained_on_each_actual_country_land_mask(self):
        lands = {"CY": box(33, 35, 34, 36), "CYN": box(34, 35, 35, 36)}
        row = {"id": "source:municipality-42", "name": "Quellgemeinde", "kind": "municipality",
               "country": "CY", "parent_id": "country:CY", "source": "fixture",
               "geometry": box(33.5, 35, 34.5, 36)}
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "data").mkdir()
            source = {"id": "fixture", "kind": "municipality", "country": "CY",
                      "scope_countries": ["CY", "CYN"]}
            (root / "data/atlas_official_sources.json").write_text(json.dumps({"sources": [source]}))
            pool = GeometryPool()
            provinces = ProvinceIndex(ROOT / "data/europe_geometry.json")
            features = [feature_record(pool, provinces, land, feature_id="country:" + country,
                name=country, kind="country", parent_id="", country=country,
                source="fixture-land", tolerance=0) for country, land in lands.items()]
            reader = SimpleNamespace(__name__="atlas_official_sources", iter_boundaries=lambda *_: iter([row]))
            with patch("atlas_administration.importlib.import_module", return_value=reader):
                _, coverage, _ = supplement(features, pool, provinces, feature_record, lands, [], root, root)
        units = [feature for feature in features if feature["kind"] == "municipality"]
        self.assertEqual({unit["country"] for unit in units}, {"CY", "CYN"},
                         "Largest-intersection assignment must not discard genuine parts on the other land mask")
        self.assertEqual(len({unit["id"] for unit in units}), 2)
        self.assertTrue(all(unit.get("source_unit_id") == row["id"] for unit in units))
        for country in lands:
            self.assertAlmostEqual(coverage[country]["fraction"], 0.5, places=6)


if __name__ == "__main__":
    unittest.main()
