"""Real upper regional roles must not be confused with districts or macroareas."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from shapely.geometry import box, mapping

PATH = Path(__file__).with_name("atlas_regional_sources.py")
if PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_regional_sources", PATH)
    regional = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(regional)
else:
    regional = None


class RegionalSourceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(regional, "Der qualifizierte Regionalprovider fehlt.")

    def metadata(self, iso="ITA", level=2, count=20, license_name="Creative Commons Attribution 3.0 License"):
        return {"boundaryISO": iso, "boundaryType": f"ADM{level}", "admUnitCount": str(count),
                "boundaryYearRepresented": "2023", "boundarySource": "ISTAT", "boundaryLicense": license_name,
                "simplifiedGeometryGeoJSON": f"https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/{iso}/ADM{level}/geoBoundaries-{iso}-ADM{level}_simplified.geojson"}

    def feature(self, iso="ITA", level=2, name="Valle d'Aosta"):
        return {"type": "Feature", "properties": {"shapeID": "0001-ABC", "shapeGroup": iso,
                "shapeType": f"ADM{level}", "shapeName": name}, "geometry": mapping(box(7, 45, 7.1, 45.1))}

    def test_italy_uses_twenty_regions_not_five_statistical_macroareas(self):
        source = regional.select_source([self.metadata(level=1, count=5), self.metadata()], "IT")
        self.assertEqual(source["admin_level"], 2)
        self.assertEqual(source["expected_unit_count"], 20)
        self.assertEqual(source["unit_type"], "Regione")
        self.assertEqual(source["replace_natural_earth_kinds"], ["region"])
        with self.assertRaises(ValueError):
            regional.select_source([self.metadata(level=1, count=5)], "IT")

    def test_france_uses_metropolitan_regions_and_individual_etalab_license(self):
        source = regional.select_source([self.metadata("FRA", 1, 13, "Etalab Open License 2.0")], "FR")
        self.assertEqual(source["expected_unit_count"], 13)
        self.assertEqual(source["license"], "Etalab Open License 2.0")
        self.assertIn("etalab", source["license_url"])
        row = regional.normalize_feature(self.feature("FRA", 1, "Corse"), source)
        self.assertEqual(row["unit_type"], "Collectivité de Corse")
        self.assertEqual(row["kind"], "region")

    def test_spain_keeps_autonomous_cities_distinct_from_communities(self):
        source = regional.select_source([self.metadata("ESP", 1, 19, "Creative Commons Attribution 4.0 International (CC BY 4.0)")], "ES")
        city = regional.normalize_feature(self.feature("ESP", 1, "Ciudad Autónoma de Ceuta"), source)
        community = regional.normalize_feature(self.feature("ESP", 1, "Canarias"), source)
        self.assertEqual(city["unit_type"], "Ciudad autónoma")
        self.assertEqual(community["unit_type"], "Comunidad autónoma")
        self.assertGreater(community["geometry"].area, 0)  # Country clipping belongs to the merger.

    def test_gb_gisco_source_is_not_admitted_by_a_generic_cc_by_label(self):
        with self.assertRaises(ValueError):
            regional.select_source([self.metadata("GBR", 1, 4, "Creative Commons Attribution 4.0 International (CC BY 4.0)")], "GB")

    def test_changed_pin_or_unreviewed_license_is_rejected(self):
        for changed in [dict(self.metadata(), boundaryLicense="Unknown"),
                        dict(self.metadata(), simplifiedGeometryGeoJSON=self.metadata()["simplifiedGeometryGeoJSON"].replace("9469f09", "main"))]:
            with self.assertRaises(ValueError):
                regional.select_source([changed], "IT")

    def test_regional_feature_preserves_native_identity_and_parent(self):
        source = regional.select_source([self.metadata()], "IT")
        row = regional.normalize_feature(self.feature(), source)
        self.assertEqual(row["id"], "gbOpen:ITA:ADM2:0001-ABC")
        self.assertEqual(row["parent_id"], "country:IT")
        self.assertEqual(row["name"], "Valle d'Aosta")
        self.assertEqual(row["kind"], "region")
        self.assertEqual(row["admin_level"], 2)

    def test_missing_geometry_or_wrong_source_role_is_rejected(self):
        source = regional.select_source([self.metadata()], "IT")
        for feature in [{**self.feature(), "geometry": None}, self.feature("ITA", 1), self.feature("FRA", 2)]:
            with self.assertRaises(ValueError):
                regional.normalize_feature(feature, source)

    def test_gb_constituent_country_uses_official_stable_code(self):
        source = {"id": "ons-CTRY24-UK-BGC", "country": "GB", "source_type": "ons-countries-2024"}
        feature = {"properties": {"CTRY24CD": "S92000003", "CTRY24NM": "Scotland"},
                   "geometry": mapping(box(-4, 56, -3, 57))}
        row = regional.normalize_feature(feature, source)
        self.assertEqual(row["id"], "ons:GB:country:S92000003")
        self.assertEqual(row["unit_type"], "Constituent country")
        self.assertIsNone(row["admin_level"])
        self.assertEqual(row["parent_id"], "country:GB")
        with self.assertRaises(ValueError):
            regional.normalize_feature({**feature, "properties": {"CTRY24CD": "E12000001", "CTRY24NM": "North East"}}, source)

    def test_gb_source_identity_requires_ons_owner_service_and_original_rights(self):
        item = {"id": "0139831c7166457ab1f7b3ab1f919cba", "owner": "ONSGeography_data",
                "title": "Countries (December 2024) Boundaries UK BGC", "licenseInfo": "https://www.ons.gov.uk/methodology/geography/licences",
                "description": "Contains both Ordnance Survey and ONS Intellectual Property Rights."}
        regional.validate_ons_item(item)
        for invalid in [{**item, "owner": "unrelated"}, {**item, "licenseInfo": ""}]:
            with self.assertRaises(ValueError):
                regional.validate_ons_item(invalid)

    def test_iterator_checks_original_hash_and_actual_count(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            path = cache / "regions.geojson"
            path.write_text(json.dumps({"type": "FeatureCollection", "features": [self.feature()]}), encoding="utf-8")
            source = regional.select_source([self.metadata()], "IT")
            source.update({"cache_file": path.name, "bytes": path.stat().st_size,
                           "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "expected_unit_count": 1})
            self.assertEqual(len(list(regional.iter_boundaries(cache, [source]))), 1)
            path.write_text("{}", encoding="utf-8")
            with self.assertRaises(ValueError):
                list(regional.iter_boundaries(cache, [source]))


if __name__ == "__main__":
    unittest.main()
