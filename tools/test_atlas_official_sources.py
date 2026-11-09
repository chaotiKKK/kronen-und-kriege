"""Official local-government source normalization and completeness tests."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "tools/atlas_official_sources.py"
if PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_official_sources", PATH)
    official = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(official)
else:
    official = None


class OfficialMunicipalSourcesTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(official, "Die amtlichen kommunalen Quellen fehlen.")

    def geometry(self):
        return {"type": "Polygon", "coordinates": [[[24, 63], [25, 63], [25, 64], [24, 63]]]}

    def test_finnish_code_and_unicode_survive_without_numeric_adm_invention(self):
        feature = {"type": "Feature", "properties": {"kunta": "005", "vuosi": 2026, "nimi": "Alajärvi", "namn": "Alajärvi"}, "geometry": self.geometry()}
        row = official.normalize_finnish(feature)
        self.assertEqual(row["id"], "statfi:kunta:2026:005")
        self.assertEqual(row["name"], "Alajärvi")
        self.assertEqual(row["municipality_code"], "005")
        self.assertEqual(row["country"], "FI")
        self.assertIsNone(row["admin_level"])
        self.assertEqual(row["native_level"], "kunta")
        self.assertEqual(row["kind"], "municipality")

    def test_year_mismatch_cannot_enter_finnish_2026_source(self):
        feature = {"properties": {"kunta": "005", "vuosi": 2025, "nimi": "Alajärvi"}, "geometry": self.geometry()}
        with self.assertRaises(ValueError):
            official.normalize_finnish(feature)

    def test_aland_country_assignment_uses_official_code_and_keeps_whole_polygon(self):
        feature = {"properties": {"kunta": "035", "vuosi": 2026, "nimi": "Brändö"}, "geometry": self.geometry()}
        row = official.normalize_finnish(feature)
        self.assertEqual(row["country"], "AX")
        self.assertEqual(row["parent_id"], "country:AX")
        self.assertEqual(row["original_source_country"], "FI")
        self.assertEqual(row["country_assignment_method"], "official_code")
        self.assertEqual(row["id"], "statfi:kunta:2026:035")
        self.assertAlmostEqual(row["geometry"].area, 0.5)

    def test_finnish_official_correspondence_uses_nuts3_not_centroid(self):
        def entry(code, nuts):
            return {"correspondenceTable": {"sourceClassification": "kunta_1_20260101", "targetClassification": "nuts_2_20260101"},
                    "sourceItem": {"code": code}, "targetItem": {"code": nuts, "level": 3.0}}
        rows = [entry("035", "FI200"), entry("005", "FI199")]
        self.assertEqual(official.finnish_territory_codes(rows), {"035": "AX", "005": "FI"})
        with self.assertRaises(ValueError):
            official.finnish_territory_codes(rows + [entry("035", "FI199")])

    def test_finnish_correspondence_for_another_year_is_rejected(self):
        rows = [{"correspondenceTable": {"sourceClassification": "kunta_1_20250101", "targetClassification": "nuts_2_20260101"},
                 "sourceItem": {"code": "035"}, "targetItem": {"code": "FI200", "level": 3.0}}]
        with self.assertRaises(ValueError):
            official.finnish_territory_codes(rows)

    def test_aland_10k_keeps_native_code_swedish_name_and_marine_extent_explicit(self):
        feature = {"properties": {"NATCODE": "035", "NAMEFIN": "Brändö", "NAMESWE": "Brändö",
                                  "LANDAREA": 108.28, "FRESHWAREA": 0.24, "SEAWAREA": 1534.76},
                   "geometry": self.geometry()}
        row = official.normalize_mml_aland(feature)
        self.assertEqual(row["id"], "mml:kunta:2025:035")
        self.assertEqual(row["country"], "AX")
        self.assertEqual(row["municipality_code"], "035")
        self.assertEqual(row["country_assignment_method"], "official_code")
        self.assertEqual(row["source_year"], 2025)
        self.assertEqual(row["merge_priority"], 4)
        self.assertTrue(row["geometry_includes_marine_area"])
        self.assertEqual(row["source_area_km2"]["sea"], 1534.76)
        self.assertAlmostEqual(row["geometry"].area, 0.5)
        self.assertIsNone(row["admin_level"])

    def test_aland_10k_cannot_admit_a_mainland_code_or_missing_boundary(self):
        with self.assertRaises(ValueError):
            official.normalize_mml_aland({"properties": {"NATCODE": "005", "NAMEFIN": "Alajärvi"},
                                          "geometry": self.geometry()})
        with self.assertRaises(ValueError):
            official.normalize_mml_aland({"properties": {"NATCODE": "035", "NAMEFIN": "Brändö"},
                                          "geometry": None})

    def test_luxembourg_commune_keeps_lau_and_historical_district_is_not_current_parent(self):
        feature = {"properties": {"COMMUNE": "Hesperange", "LAU2": "0303", "CANTON": "Luxembourg", "DISTRICT": "Luxembourg"},
                   "geometry": self.geometry()}
        row = official.normalize_luxembourg(feature, {"0303": "Hesperange"})
        self.assertEqual(row["id"], "act:LU:commune:0303")
        self.assertEqual(row["municipality_code"], "0303")
        self.assertEqual(row["country"], "LU")
        self.assertEqual(row["parent_id"], "country:LU")
        self.assertEqual(row["kind"], "municipality")
        self.assertEqual(row["merge_priority"], 4)
        self.assertNotIn("district", row)
        with self.assertRaises(ValueError):
            official.normalize_luxembourg(feature, {"0303": "Falscher Name"})

    def test_luxembourg_current_canton_keeps_original_lau1_and_drops_historical_district(self):
        feature = {"properties": {"CANTON": "Luxembourg", "LAU1": "03", "DISTRICT": "Luxembourg"},
                   "geometry": self.geometry()}
        row = official.normalize_luxembourg_canton(feature)
        self.assertEqual(row["id"], "act:LU:canton:03")
        self.assertEqual(row["canton_code"], "03")
        self.assertEqual(row["kind"], "district")
        self.assertEqual(row["unit_type"], "Canton")
        self.assertEqual(row["parent_id"], "country:LU")
        self.assertNotIn("district", row)
        with self.assertRaises(ValueError):
            official.normalize_luxembourg_canton({"properties": {"DISTRICT": "Luxembourg"}, "geometry": self.geometry()})

    def test_luxembourg_communal_parent_joins_native_canton_name_and_lau_prefix(self):
        feature = {"properties": {"COMMUNE": "Hesperange", "LAU2": "0303", "CANTON": "Luxembourg", "DISTRICT": "Luxembourg"},
                   "geometry": self.geometry()}
        row = official.normalize_luxembourg(feature, {"0303": "Hesperange"}, cantons={"Luxembourg": "03"})
        self.assertEqual(row["parent_id"], "act:LU:canton:03")
        self.assertEqual(row["native_canton_code"], "03")
        for wrong in [{}, {"Luxembourg": "04"}]:
            with self.assertRaises(ValueError):
                official.normalize_luxembourg(feature, {"0303": "Hesperange"}, cantons=wrong)

    def test_luxembourg_canton_join_rejects_ambiguous_original_codes(self):
        features = [{"properties": {"CANTON": "Capellen", "LAU1": "01"}},
                    {"properties": {"CANTON": "Luxembourg", "LAU1": "03"}}]
        self.assertEqual(official.luxembourg_canton_codes(features), {"Capellen": "01", "Luxembourg": "03"})
        with self.assertRaises(ValueError):
            official.luxembourg_canton_codes(features + [{"properties": {"CANTON": "Capellen", "LAU1": "02"}}])

    def test_ons_accepts_real_local_authorities_across_all_four_nations(self):
        cases = [("E06000001", "Unitary authority"), ("E07000001", "Non-metropolitan district"),
                 ("E08000001", "Metropolitan district"), ("E09000002", "London borough"),
                 ("S12000033", "Council area"), ("W06000001", "Principal area"),
                 ("N09000001", "Local government district")]
        for code, role in cases:
            with self.subTest(code=code):
                row = official.normalize_british({"properties": {"LAD25CD": code, "LAD25NM": "Official area name"}, "geometry": self.geometry()})
                self.assertEqual(row["id"], "ons:LAD25:" + code)
                self.assertEqual(row["country"], "GB")
                self.assertEqual(row["unit_type"], role)
                self.assertIsNone(row["admin_level"])

    def test_city_of_london_is_not_renamed_as_a_borough(self):
        row = official.normalize_british({"properties": {"LAD25CD": "E09000001", "LAD25NM": "City of London"}, "geometry": self.geometry()})
        self.assertEqual(row["unit_type"], "City of London")

    def test_irish_authority_keeps_native_guid_and_unicode(self):
        feature = {"properties": {"GUID": "00000001-0002-0003-0004-000000000005", "ENGLISH": "DÚN LAOGHAIRE-RATHDOWN COUNTY COUNCIL"}, "geometry": self.geometry()}
        row = official.normalize_irish(feature)
        self.assertEqual(row["id"], "tailte:local-authority:2019:00000001-0002-0003-0004-000000000005")
        self.assertEqual(row["name"], feature["properties"]["ENGLISH"])
        self.assertEqual(row["country"], "IE")
        self.assertEqual(row["unit_type"], "County council")
        self.assertIsNone(row["admin_level"])

    def test_irish_city_and_combined_councils_are_distinguished(self):
        for name, role in [("DUBLIN CITY COUNCIL", "City council"), ("LIMERICK CITY AND COUNTY COUNCIL", "City and county council")]:
            with self.subTest(name=name):
                row = official.normalize_irish({"properties": {"GUID": "00000001-0002-0003-0004-000000000005", "ENGLISH": name}, "geometry": self.geometry()})
                self.assertEqual(row["unit_type"], role)

    def test_traditional_irish_county_is_not_presented_as_local_authority(self):
        with self.assertRaises(ValueError):
            official.normalize_irish({"properties": {"GUID": "00000001-0002-0003-0004-000000000005", "ENGLISH": "DUBLIN"}, "geometry": self.geometry()})

    def test_county_is_not_renamed_as_local_authority_district(self):
        with self.assertRaises(ValueError):
            official.normalize_british({"properties": {"LAD25CD": "E10000003", "LAD25NM": "County"}, "geometry": self.geometry()})

    def test_missing_geometry_fails_closed(self):
        for normalizer, properties in [(official.normalize_finnish, {"kunta": "005", "vuosi": 2026, "nimi": "Name"}),
                                       (official.normalize_british, {"LAD25CD": "E06000001", "LAD25NM": "Name"})]:
            with self.subTest(normalizer=normalizer.__name__):
                with self.assertRaises(ValueError):
                    normalizer({"properties": properties, "geometry": None})

    def test_partial_arcgis_page_cannot_claim_all_authorities(self):
        with self.assertRaises(ValueError):
            official.validate_feature_collection({"type": "FeatureCollection", "features": [1]}, 361)
        with self.assertRaises(ValueError):
            official.validate_feature_collection({"type": "FeatureCollection", "features": [1, 2], "exceededTransferLimit": True}, 2)

    def test_finnish_declared_response_count_matches_returned_features(self):
        with self.assertRaises(ValueError):
            official.validate_feature_collection({"type": "FeatureCollection", "features": [1, 2], "numberMatched": 308}, 308)

    def test_all_arcgis_pages_are_required_without_losing_transfer_evidence(self):
        pages = [{"type": "FeatureCollection", "features": [{"properties": {"FID": 1}}, {"properties": {"FID": 2}}],
                  "properties": {"exceededTransferLimit": True}},
                 {"type": "FeatureCollection", "features": [{"properties": {"FID": 3}}]}]
        combined = official.combine_arcgis_pages(pages, 3, 2)
        self.assertEqual(len(combined["features"]), 3)
        self.assertTrue(combined["properties"]["assembled_from_pages"])
        self.assertTrue(pages[0]["properties"]["exceededTransferLimit"])
        with self.assertRaises(ValueError):
            official.combine_arcgis_pages(pages[:1], 3, 2)

    def test_arcgis_duplicate_object_id_cannot_replace_a_missing_feature(self):
        pages = [{"type": "FeatureCollection", "features": [{"properties": {"FID": 1}}]},
                 {"type": "FeatureCollection", "features": [{"properties": {"FID": 1}}]}]
        with self.assertRaises(ValueError):
            official.combine_arcgis_pages(pages, 2, 1)


if __name__ == "__main__":
    unittest.main()
