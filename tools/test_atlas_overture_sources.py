"""Behavioral contracts for the pinned Overture frame reader."""
from __future__ import annotations

import importlib.util
import gzip
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "tools/atlas_overture_sources.py"
if PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_overture_sources", PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
else:
    module = None


class OvertureSourceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(module, "Der getrennte Overture-Rahmenimport fehlt.")

    def raw(self, **changes):
        row = {"division_id": "county-alpha", "area_id": "area-alpha", "country": "FR",
               "subtype": "county", "admin_level": 2, "name": "Département témoin",
               "is_land": True, "is_territorial": True, "parent_division_id": "region-alpha",
               "local_type": {"en": "department"}, "sources": [{"dataset": "OpenStreetMap", "record_id": "r123@4"}],
               "geometry": {"type": "Polygon", "coordinates": [[[2,48],[3,48],[3,49],[2,48]]]}}
        row.update(changes)
        return row

    def test_actual_national_role_overrides_generic_county_enum(self):
        self.assertEqual(module.role_for("NO", "county"), ("municipality", "Kommune"))
        self.assertEqual(module.role_for("DK", "county"), ("municipality", "Kommune"))
        self.assertEqual(module.role_for("GB", "county"), ("district", "Overture county"))
        self.assertEqual(module.role_for("FI", "county"), ("district", "Subregion"))

    def test_validated_czech_and_slovak_localadmin_are_communal(self):
        for country in ["CZ", "SK"]:
            self.assertEqual(module.role_for(country, "localadmin"), ("municipality", "Obec"))
        self.assertIsNone(module.role_for("FR", "localadmin"))

    def test_native_communal_type_overrides_region_or_county_render_role(self):
        for country, subtype, native_type in [("LT", "county", "municipality"),
                                               ("EE", "county", "municipality"),
                                               ("AL", "county", "municipality"),
                                               ("LV", "region", "Municipality"),
                                               ("GB", "county", "civil_parish"),
                                               ("MT", "region", "local council"),
                                               ("FR", "county", "commune")]:
            with self.subTest(country=country, subtype=subtype, native_type=native_type):
                row = module.normalize_feature(self.raw(country=country, subtype=subtype,
                                                        local_type={"en": native_type}))
                self.assertEqual(row["kind"], "municipality")
                self.assertEqual(row["raw_subtype"], subtype)
                self.assertEqual(row["local_type"], {"en": native_type})

    def test_native_noncommunal_types_do_not_gain_a_communal_role(self):
        for country, native_type in [("FR", "department"), ("FI", "subregion"),
                                      ("RU", "district"), ("TR", "district")]:
            with self.subTest(country=country):
                row = module.normalize_feature(self.raw(country=country,
                                                        local_type={"en": native_type}))
                self.assertEqual(row["kind"], "district")

    def test_verified_jersey_parishes_and_subparish_units_keep_distinct_roles(self):
        parish = module.normalize_feature(self.raw(country="JE", subtype="region",
            local_type={"en":"parish"}))
        self.assertEqual(parish["kind"], "municipality")
        for native_type in ("vingtaine", "cueillette"):
            with self.subTest(native_type=native_type):
                row = module.normalize_feature(self.raw(country="JE", subtype="county",
                    local_type={"en":native_type}))
                self.assertEqual(row["kind"], "local_admin")
                self.assertEqual(row["unit_type"], native_type)

    def test_manx_historic_parish_is_not_assumed_to_be_a_current_local_authority(self):
        row = module.normalize_feature(self.raw(country="IM", subtype="region",
            local_type={"en":"parish"}))
        self.assertEqual(row["kind"], "region")

    def test_guernsey_native_civil_parish_county_has_a_communal_role(self):
        row = module.normalize_feature(self.raw(country="GG", subtype="county",
            local_type={"en":"parish"}))
        self.assertEqual(row["kind"], "municipality")
        self.assertEqual(row["unit_type"], "parish")

    def test_populated_places_are_never_promoted_to_municipalities(self):
        for country in ["RU", "TR", "GB", "FI", "DE", "CZ"]:
            self.assertIsNone(module.role_for(country, "locality"))
        self.assertIsNone(module.normalize_feature(self.raw(country="RU", subtype="locality", local_type={"en":"municipality"})))

    def test_existing_german_bkg_frame_is_preserved(self):
        self.assertIsNone(module.role_for("DE", "region"))
        self.assertIsNone(module.normalize_feature(self.raw(country="DE")))

    def test_water_variant_is_rejected_even_when_territorial(self):
        self.assertIsNone(module.normalize_feature(self.raw(is_land=False, is_territorial=True)))
        self.assertIsNotNone(module.normalize_feature(self.raw(is_land=True, is_territorial=False)))

    def test_real_geographic_geometry_and_source_ids_survive_normalization(self):
        row = module.normalize_feature(self.raw())
        self.assertEqual(row["id"], "overture:county-alpha")
        self.assertEqual(row["parent_id"], "overture:region-alpha")
        self.assertEqual(row["name"], "Département témoin")
        self.assertEqual(row["kind"], "district")
        self.assertEqual(row["original_source_records"][0]["record_id"], "r123@4")
        self.assertAlmostEqual(row["geometry"].area, 0.5)

    def test_null_normalized_level_is_not_invented_as_an_adm_number(self):
        row = module.normalize_feature(self.raw(country="CZ", subtype="localadmin", admin_level=None))
        self.assertIsNone(row["admin_level"])
        self.assertEqual(row["kind"], "municipality")

    def test_known_country_parent_becomes_existing_country_identifier(self):
        raw = self.raw(parent_division_id="fr-country-uuid", parent_kind="country")
        row = module.normalize_feature(raw)
        self.assertEqual(row["parent_id"], "country:FR")

    def test_missing_parent_is_explicitly_unresolved_not_a_fabricated_relation(self):
        row = module.normalize_feature(self.raw(parent_division_id=None))
        self.assertEqual(row["parent_id"], "country:FR")
        self.assertEqual(row["parent_relationship"], "unresolved-source-parent")

    def test_non_area_geometry_is_rejected(self):
        with self.assertRaises(ValueError):
            module.normalize_feature(self.raw(geometry={"type":"Point","coordinates":[2,48]}))

    def test_duplicate_division_parts_are_united_without_losing_islands(self):
        a = module.normalize_feature(self.raw())
        b = module.normalize_feature(self.raw(area_id="area-beta", geometry={"type":"Polygon","coordinates":[[[4,48],[5,48],[5,49],[4,48]]]}))
        rows = module.deduplicate_records([a,b])
        self.assertEqual(len(rows), 1)
        self.assertAlmostEqual(rows[0]["geometry"].area, 1.0)
        self.assertEqual(sorted(rows[0]["original_area_ids"]), ["area-alpha","area-beta"])

    def test_cache_hash_failure_does_not_launch_a_new_download(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            directory = cache / "overture-2026-10-21.0"
            directory.mkdir()
            (directory / "frame.geojsonl.gz").write_bytes(b"changed")
            receipt = {"release":"2026-10-21.0", "cache_file":"overture-2026-10-21.0/frame.geojsonl.gz", "sha256":"0"*64,"bytes":7,"sources":[]}
            (directory / "receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "hash|Hash"):
                module.prepare_sources(cache)

    def test_another_active_extraction_does_not_start_a_second_writer(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            directory = cache / "overture-2026-10-21.0"
            directory.mkdir()
            (directory / "raw-extract.lock").write_text("another writer", encoding="ascii")
            with patch.object(module.subprocess, "run", side_effect=RuntimeError("unexpected network extraction")):
                with self.assertRaisesRegex(RuntimeError, "in progress"):
                    module.prepare_sources(cache)

    def test_cached_reader_preserves_country_region_district_hierarchy(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            directory = cache / "overture-2026-10-21.0"
            directory.mkdir()
            region = self.raw(division_id="region-alpha", area_id="region-area", subtype="region", admin_level=1,
                              parent_division_id="country-fr", parent_kind="country", name="Région témoin")
            county = self.raw()
            raw_path = directory / "raw.geojsonl.gz"
            with gzip.open(raw_path, "wt", encoding="utf-8") as stream:
                for raw in [region, county]:
                    stream.write(json.dumps(raw) + "\n")
            receipt = {"release":"2026-10-21.0", "cache_file":"overture-2026-10-21.0/raw.geojsonl.gz",
                       "sha256":hashlib.sha256(raw_path.read_bytes()).hexdigest(), "requested_countries":["FR"],
                       "area_files":[], "division_files":[]}
            (directory / "raw-receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
            prepared = module._prepare_cache(cache)
            rows = list(module.iter_boundaries(cache, prepared["sources"]))
            by_id = {row["id"]: row for row in rows}
            self.assertEqual(by_id["overture:region-alpha"]["parent_id"], "country:FR")
            self.assertEqual(by_id["overture:county-alpha"]["parent_id"], "overture:region-alpha")
            self.assertEqual(by_id["overture:county-alpha"]["name"], "Département témoin")
            self.assertAlmostEqual(by_id["overture:county-alpha"]["geometry"].area, 0.5)
            self.assertEqual(sum(item["source_unit_count"] for item in prepared["sources"]), 2)

    def test_cache_metadata_keeps_distinct_native_types_within_one_render_role(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            directory = cache / module.DIRECTORY
            directory.mkdir()
            raw_path = directory / "raw.geojsonl.gz"
            with gzip.open(raw_path, "wt", encoding="utf-8") as stream:
                for division, native_type in [("one", "municipality"), ("two", "commune")]:
                    stream.write(json.dumps(self.raw(division_id=division,
                        local_type={"en":native_type})) + "\n")
            receipt = {"release":module.RELEASE, "cache_file":raw_path.relative_to(cache).as_posix(),
                       "sha256":hashlib.sha256(raw_path.read_bytes()).hexdigest(), "requested_countries":["FR"],
                       "area_files":[], "division_files":[]}
            (directory / "raw-receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
            sources = module._prepare_cache(cache)["sources"]
            self.assertEqual(len(sources), 1)
            self.assertEqual(sources[0]["kind"], "municipality")
            self.assertEqual(sources[0].get("unit_types"), ["commune", "municipality"])

    def test_old_normalizer_cache_is_rebuilt_from_raw_without_another_download(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            (cache / "docs").mkdir()
            directory = cache / module.DIRECTORY
            directory.mkdir()
            raw_path = directory / "raw.geojsonl.gz"
            with gzip.open(raw_path, "wt", encoding="utf-8") as stream:
                stream.write(json.dumps(self.raw(country="LT", local_type={"en":"municipality"})) + "\n")
            raw_receipt = {"release":module.RELEASE, "cache_file":raw_path.relative_to(cache).as_posix(),
                           "sha256":hashlib.sha256(raw_path.read_bytes()).hexdigest(), "requested_countries":["LT"],
                           "area_files":[], "division_files":[]}
            (directory / "raw-receipt.json").write_text(json.dumps(raw_receipt), encoding="utf-8")
            prepared = module._prepare_cache(cache)
            frame_path = cache / prepared["cache_file"]
            with gzip.open(frame_path, "rt", encoding="utf-8") as stream:
                row = json.loads(stream.readline())
            row["kind"] = "district"
            with gzip.open(frame_path, "wt", encoding="utf-8") as stream:
                stream.write(json.dumps(row) + "\n")
            prepared.update(normalizer_version=0, sha256=module.sha256_file(frame_path), bytes=frame_path.stat().st_size)
            for source in prepared["sources"]:
                source.update(sha256=prepared["sha256"], bytes=prepared["bytes"])
            (directory / "receipt.json").write_text(json.dumps(prepared), encoding="utf-8")
            with patch.object(module, "ROOT", cache), patch.object(module.subprocess, "run", side_effect=AssertionError("unexpected remote extraction")):
                sources = module.prepare_sources(cache)
            rows = list(module.iter_boundaries(cache, sources))
            self.assertEqual(rows[0]["kind"], "municipality")

    def test_only_verified_completed_parts_can_resume_the_same_source_selection(self):
        reader = getattr(module, "completed_part", None)
        self.assertTrue(callable(reader), "Einzelteile brauchen einen geprüften Wiederaufnahmepunkt.")
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            data_path = cache / "part.jsonl.gz"
            data_path.write_bytes(b"completed bytes")
            receipt_path = cache / "part.receipt.json"
            receipt = {"release":module.RELEASE, "extraction_version":2, "url":"https://example.invalid/part.parquet",
                       "countries":["CZ","SK"], "bounds":module.BOUNDS,
                       "cache_file":"part.jsonl.gz", "bytes":data_path.stat().st_size,
                       "sha256":module.sha256_file(data_path), "raw_counts":{"CZ:localadmin":1}}
            receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
            self.assertEqual(reader(cache, receipt_path, receipt["url"], ["CZ","SK"]), receipt)
            with self.assertRaisesRegex(ValueError, "selection|Selection|scope|Scope"):
                reader(cache, receipt_path, receipt["url"], ["CZ"])
            data_path.write_bytes(b"interrupted overwrite")
            with self.assertRaisesRegex(ValueError, "hash|Hash"):
                reader(cache, receipt_path, receipt["url"], ["CZ","SK"])

    def test_separate_raw_parts_are_normalized_as_one_verified_hierarchy(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            directory = cache / module.DIRECTORY
            directory.mkdir()
            parts = []
            for index, raw in enumerate([
                self.raw(division_id="region-alpha", subtype="region", parent_kind="country", parent_division_id="country-fr"),
                self.raw()
            ]):
                path = directory / f"part-{index}.jsonl.gz"
                with gzip.open(path, "wt", encoding="utf-8") as stream:
                    stream.write(json.dumps(raw) + "\n")
                parts.append({"cache_file":path.relative_to(cache).as_posix(), "sha256":module.sha256_file(path), "bytes":path.stat().st_size})
            receipt = {"release":module.RELEASE, "parts":parts, "requested_countries":["FR"], "area_files":[], "division_files":[]}
            (directory / "raw-receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
            try:
                prepared = module._prepare_cache(cache)
            except KeyError as error:
                self.fail("Getrennte Rohteile werden noch nicht unterstützt: " + str(error))
            rows = list(module.iter_boundaries(cache, prepared["sources"]))
            self.assertEqual(len(rows), 2)
            self.assertEqual({row["id"]: row["parent_id"] for row in rows}["overture:county-alpha"], "overture:region-alpha")


if __name__ == "__main__":
    unittest.main()
