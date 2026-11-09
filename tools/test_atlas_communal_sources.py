"""Tests for real, semantically selected communal source imports."""
from __future__ import annotations

import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/atlas_communal_sources.py"
if MODULE_PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_communal_sources", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
else:
    module = None


class CommunalSourceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(module, "Der landesspezifische Kommunalimport fehlt.")

    def source(self):
        return {"id": "gbOpen-FRA-ADM5", "country": "FR", "country_iso3": "FRA",
                "admin_level": 5, "unit_type": "Commune / arrondissement municipal"}

    def feature(self):
        return {"type": "Feature", "properties": {"shapeID": "00001-ABC", "shapeName": "Évry-Courcouronnes", "shapeGroup": "FRA", "shapeType": "ADM5"},
                "geometry": {"type": "Polygon", "coordinates": [[[2, 48], [3, 48], [3, 49], [2, 48]]]}}

    def test_france_uses_communes_not_departments(self):
        metadata = [{"boundaryISO": "FRA", "boundaryType": "ADM2", "admUnitCount": "96"},
                    {"boundaryISO": "FRA", "boundaryType": "ADM5", "admUnitCount": "35010",
                     "boundaryYearRepresented": "2020", "boundaryLicense": "Open Data Commons Attribution License 1.0",
                     "boundarySource": "ARCEP", "boundaryCanonical": "Commune simple, Arrondissement municipal",
                     "simplifiedGeometryGeoJSON": "https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FRA/ADM5/geoBoundaries-FRA-ADM5_simplified.geojson"}]
        source = module.select_source(metadata, "FR")
        self.assertEqual(source["admin_level"], 5)
        self.assertEqual(source["expected_unit_count"], 35010)
        self.assertEqual(source["date"], "2020")
        self.assertEqual(source["license"], "Open Data Commons Attribution License 1.0")

    def test_british_counties_cannot_be_relabelled_municipalities(self):
        with self.assertRaises(ValueError):
            module.select_source([{"boundaryISO": "GBR", "boundaryType": "ADM3", "admUnitCount": "216"}], "GB")

    def test_additional_countries_select_documented_local_roles(self):
        cases = [("BE", "BEL", 4, 589, "2018", "Gemeente / commune / Gemeinde"),
                 ("LU", "LUX", 3, 102, "2018", "Commune"),
                 ("LT", "LTU", 2, 60, "2017", "Savivaldybė"),
                 ("ME", "MNE", 1, 23, "2017", "Opština / capital city"),
                 ("RS", "SRB", 2, 145, "2017", "Opština / grad"),
                 ("XK", "XKX", 2, 38, "2017", "Komuna / opština"),
                 ("LI", "LIE", 1, 11, "2017", "Gemeinde"),
                 ("SM", "SMR", 1, 9, "2017", "Castello"),
                 ("SI", "SVN", 2, 213, "2017", "Občina / mestna občina"),
                 ("BA", "BIH", 3, 142, "2013", "Općina / opština / grad")]
        for country, iso3, level, count, year, role in cases:
            with self.subTest(country=country):
                metadata = [{"boundaryISO": iso3, "boundaryType": f"ADM{level}",
                             "admUnitCount": str(count), "boundaryYearRepresented": year,
                             "boundaryLicense": "Open Data Commons Open Database License 1.0",
                             "simplifiedGeometryGeoJSON": f"https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/{iso3}/ADM{level}/geoBoundaries-{iso3}-ADM{level}_simplified.geojson"}]
                selected = module.select_source(metadata, country)
                self.assertEqual(selected["admin_level"], level)
                self.assertEqual(selected["expected_unit_count"], count)
                self.assertEqual(selected["date"], year)
                self.assertEqual(selected["unit_type"], role)
                self.assertTrue(selected["unit_semantics"]["evidence_urls"])

    def test_belgian_arrondissements_cannot_replace_communes(self):
        with self.assertRaises(ValueError):
            module.select_source([{"boundaryISO": "BEL", "boundaryType": "ADM3", "admUnitCount": "43"}], "BE")

    def test_unverified_hungarian_count_is_not_automatically_municipal(self):
        with self.assertRaises(ValueError):
            module.select_source([{"boundaryISO": "HUN", "boundaryType": "ADM3", "admUnitCount": "3357"}], "HU")

    def test_unadmitted_candidates_expose_evidence_instead_of_silent_coverage(self):
        candidates = module.unadmitted_candidates()
        self.assertIn("214", candidates["EE"]["reason"])
        self.assertIn("copyright", candidates["MT"]["reason"])
        self.assertTrue(candidates["MT"]["evidence_urls"])
        self.assertFalse(set(candidates) & set(module.SOURCE_DEFINITIONS))

    def test_known_metadata_counts_keep_declaration_and_actual_separate(self):
        for country, iso3, level, declared, actual in [("PL", "POL", 3, 2480, 2478), ("IR", "IRN", 4, 2815, 2772),
                                                     ("CY", "CYP", 2, 612, 610)]:
            with self.subTest(country=country):
                metadata = [{"boundaryISO": iso3, "boundaryType": f"ADM{level}", "admUnitCount": str(declared),
                             "boundaryYearRepresented": {"IR": "2021", "CY": "2009"}.get(country, "2017"),
                             "boundaryLicense": "Creative Commons Attribution-ShareAlike 2.0",
                             "simplifiedGeometryGeoJSON": f"https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/{iso3}/ADM{level}/geoBoundaries-{iso3}-ADM{level}_simplified.geojson"}]
                source = module.select_source(metadata, country)
                self.assertEqual(source["expected_unit_count"], actual)
                self.assertEqual(source["declared_unit_count"], declared)
                self.assertEqual(source["original_metadata"]["admUnitCount"], str(declared))
                self.assertTrue(source["metadata_discrepancy"])
                if country == "IR":
                    self.assertTrue(source["blocks_full_coverage_claim"])
                if country == "CY":
                    self.assertTrue(source["blocks_full_coverage_claim"])
                    self.assertEqual(source["scope_countries"], ["CY", "CYN", "ESB", "WSB", "CNM"])

    def test_cyprus_buffer_scope_keeps_historical_source_identity(self):
        metadata = [{"boundaryISO": "CYP", "boundaryType": "ADM2", "admUnitCount": "612",
                     "boundaryYearRepresented": "2009", "boundaryLicense": "Public Domain",
                     "simplifiedGeometryGeoJSON": "https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/CYP/ADM2/geoBoundaries-CYP-ADM2_simplified.geojson"}]
        source = module.select_source(metadata, "CY")
        self.assertIn("CNM", source["scope_countries"])
        self.assertIn("historical", source["territorial_scope_note"].lower())
        self.assertTrue(source["blocks_full_coverage_claim"])
        self.assertEqual(source["date"], "2009")
        feature = self.feature()
        feature["properties"].update({"shapeGroup": "CYP", "shapeType": "ADM2"})
        record = module.normalize_feature(feature, source)
        self.assertEqual(record["country"], "CY")
        self.assertEqual(record["source"], "gbOpen-CYP-ADM2")
        self.assertEqual(record["id"], "gbOpen:CYP:ADM2:00001-ABC")
        self.assertNotIn("territorial_part", record)
        self.assertTrue(record["geometry"].equals(module.shape(feature["geometry"])))

    def test_armenian_emergency_regions_cannot_claim_current_municipal_coverage(self):
        metadata = [{"boundaryISO": "ARM", "boundaryType": "ADM2", "admUnitCount": "39",
                     "boundaryYearRepresented": "2020", "boundaryCanonical": "Municipal Communities",
                     "boundaryLicense": "Creative Commons Attribution 3.0 Intergovernmental Organisations (CC BY 3.0 IGO)",
                     "simplifiedGeometryGeoJSON": "https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/ARM/ADM2/geoBoundaries-ARM-ADM2_simplified.geojson"}]
        source = module.select_source(metadata, "AM")
        self.assertIs(source["administrative_geometry_eligible"], False)
        self.assertTrue(source["blocks_full_coverage_claim"])
        self.assertIn("not an official administrative level", source["administrative_ineligibility_note"])
        self.assertTrue(source["administrative_ineligibility_evidence_urls"])
        self.assertEqual(source["original_metadata"]["boundaryCanonical"], "Municipal Communities")
        self.assertEqual(source["expected_unit_count"], 39)
        self.assertEqual(source["id"], "gbOpen-ARM-ADM2")

    def test_brcko_keeps_its_special_local_role(self):
        metadata = [{"boundaryISO": "BIH", "boundaryType": "ADM3", "admUnitCount": "142",
                     "boundaryYearRepresented": "2013", "boundaryLicense": "Public Domain",
                     "simplifiedGeometryGeoJSON": "https://github.com/wmgeolab/geoBoundaries/raw/f549eab/releaseData/gbOpen/BIH/ADM3/geoBoundaries-BIH-ADM3_simplified.geojson"}]
        source = module.select_source(metadata, "BA")
        feature = self.feature()
        feature["properties"].update({"shapeID": "43093233B82378099338701", "shapeName": "Brcko District", "shapeGroup": "BIH", "shapeType": "ADM3"})
        self.assertEqual(module.normalize_feature(feature, source)["unit_type"], "Brčko District")

    def test_normalization_preserves_identifier_unicode_and_hierarchy(self):
        record = module.normalize_feature(self.feature(), self.source())
        self.assertEqual(record["id"], "gbOpen:FRA:ADM5:00001-ABC")
        self.assertEqual(record["name"], "Évry-Courcouronnes")
        self.assertEqual(record["country"], "FR")
        self.assertEqual(record["kind"], "municipality")
        self.assertEqual(record["parent_id"], "country:FR")
        self.assertEqual(record["source"], "gbOpen-FRA-ADM5")
        self.assertAlmostEqual(record["geometry"].area, 0.5)

    def test_missing_geometry_is_rejected(self):
        feature = self.feature()
        feature["geometry"] = None
        with self.assertRaises(ValueError):
            module.normalize_feature(feature, self.source())

    def test_missing_source_name_keeps_real_boundary_with_explicit_gap(self):
        feature = self.feature()
        feature["properties"]["shapeName"] = None
        try:
            record = module.normalize_feature(feature, self.source())
        except ValueError as error:
            self.fail("A missing name must not discard a real named-key boundary: " + str(error))
        self.assertFalse(record["name_known"])
        self.assertIsNone(record["original_name"])
        self.assertTrue(record["name"])
        self.assertEqual(record["id"], "gbOpen:FRA:ADM5:00001-ABC")
        self.assertGreater(record["geometry"].area, 0)

    def test_wrong_country_or_level_cannot_silently_enter_source(self):
        for key, value in [("shapeGroup", "GBR"), ("shapeType", "ADM3")]:
            with self.subTest(key=key):
                feature = self.feature()
                feature["properties"][key] = value
                with self.assertRaises(ValueError):
                    module.normalize_feature(feature, self.source())

    def test_degenerate_polygon_cannot_claim_communal_land(self):
        feature = self.feature()
        feature["geometry"] = {"type": "Polygon", "coordinates": [[[2, 48], [3, 48], [4, 48], [2, 48]]]}
        with self.assertRaises(ValueError):
            module.normalize_feature(feature, self.source())

    def test_source_hash_detects_changed_cached_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "source.geojson"
            path.write_bytes(b"abc")
            source = {"sha256": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "bytes": 3}
            module.verify_source(path, source)
            path.write_bytes(b"abd")
            with self.assertRaises(ValueError):
                module.verify_source(path, source)

    def test_iterator_yields_actual_geojson_polygon(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            source = self.source()
            source["cache_file"] = "communal/fra.geojson"
            path = cache / source["cache_file"]
            path.parent.mkdir()
            path.write_text(json.dumps({"type": "FeatureCollection", "features": [self.feature()]}), encoding="utf-8")
            source.update({"sha256": module.sha256_file(path), "bytes": path.stat().st_size, "expected_unit_count": 1})
            records = list(module.iter_boundaries(cache, [source]))
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0]["geometry"].geom_type, "Polygon")
            self.assertEqual(records[0]["id"], "gbOpen:FRA:ADM5:00001-ABC")

    def test_verified_parts_form_one_municipality_without_losing_source_area(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            source = {"id": "gbOpen-SVN-ADM2", "country": "SI", "country_iso3": "SVN", "admin_level": 2,
                      "unit_type": "Občina / mestna občina", "cache_file": "si.geojson", "expected_unit_count": 3,
                      "component_groups": {"001-main": ["001-main", "002-part"]}}
            rows = []
            for identifier, name, left in [("001-main", "Maribor", 0), ("002-part", "Maribor", 1), ("003-other", "Other", 3)]:
                rows.append({"properties": {"shapeID": identifier, "shapeName": name, "shapeGroup": "SVN", "shapeType": "ADM2"},
                             "geometry": {"type": "Polygon", "coordinates": [[[left, 0], [left + 1, 0], [left + 1, 1], [left, 1], [left, 0]]]}})
            path = cache / "si.geojson"
            path.write_text(json.dumps({"type": "FeatureCollection", "features": rows}), encoding="utf-8")
            source.update({"sha256": module.sha256_file(path), "bytes": path.stat().st_size})
            normalized = list(module.iter_boundaries(cache, [source]))
            self.assertEqual(len(normalized), 2)
            combined = next(row for row in normalized if row["name"] == "Maribor")
            self.assertEqual(combined["id"], "gbOpen:SVN:ADM2:001-main")
            self.assertEqual(combined["source_part_ids"], ["001-main", "002-part"])
            self.assertAlmostEqual(combined["geometry"].area, 2)
            self.assertEqual(module.sha256_file(path), source["sha256"])

    def test_simplification_losing_units_uses_pinned_original(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            base = "https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FRA/ADM5/geoBoundaries-FRA-ADM5"
            source = {**self.source(), "url": base + "_simplified.geojson", "original_url": base + ".geojson",
                      "pinnedmetadataURL": base + "-metaData.json", "expected_unit_count": 2,
                      "cache_file": "communal/geoBoundaries-FRA-ADM5_simplified.geojson"}
            second = self.feature()
            second["properties"]["shapeID"] = "00002-ABC"
            files = [("_simplified.geojson", {"type": "FeatureCollection", "features": [self.feature()]}),
                     (".geojson", {"type": "FeatureCollection", "features": [self.feature(), second]}),
                     ("-metaData.json", {"boundaryISO": "FRA", "boundaryType": "ADM5", "admUnitCount": "2"})]
            for suffix, document in files:
                path = cache / ("communal/geoBoundaries-FRA-ADM5" + suffix)
                path.parent.mkdir(parents=True, exist_ok=True)
                raw = json.dumps(document).encode("utf-8")
                path.write_bytes(raw)
                path.with_suffix(path.suffix + ".receipt.json").write_text(json.dumps({"url": base + suffix, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}), encoding="utf-8")
            try:
                prepared = module._prepare_one(cache, source)
            except ValueError as error:
                self.fail("A complete pinned original must replace an incomplete simplified source: " + str(error))
            self.assertEqual(prepared["url"], base + ".geojson")
            self.assertEqual(prepared["source_unit_count"], 2)
            self.assertEqual(prepared["geometry_variant"], "original")


if __name__ == "__main__":
    unittest.main()
