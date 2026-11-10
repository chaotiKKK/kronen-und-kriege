import copy
import hashlib
import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import zipfile
from shapely.geometry import box, mapping

import atlas_jordan_sources as jordan


class JordanTerminalAdministrationTests(unittest.TestCase):
    def properties(self):
        return {"osm_id": "13376111", "code": 1205, "fclass": "admin_level5", "name": "لواء الرويشد"}

    def test_only_verified_terminal_liwa_has_an_explicit_nonmunicipal_role(self):
        geometry = box(37.2, 31.8, 39.1, 33.3)
        row = jordan.normalize_terminal_liwa(self.properties(), geometry)
        self.assertEqual(row["kind"], "district")
        self.assertEqual(row["unit_type"], "Liwa / dekonzentrierter Verwaltungsbezirk")
        self.assertEqual(row["local_government_role"], "local_admin")
        self.assertEqual(row["geometry"], geometry)
        self.assertTrue(row["local_government_role_evidence"].startswith("https://"))
        self.assertEqual(row["municipal_boundary_status"], "not-established-by-this-source")
        self.assertEqual(row["terminal_scope"], "Ruwaished Liwa; atlas intersection north of 33 degrees")

    def test_another_liwa_cannot_inherit_the_exception(self):
        for changed in ({"osm_id": "13376110"}, {"name": "لواء المفرق"},
                        {"code": 1206, "fclass": "admin_level6"}):
            with self.subTest(changed=changed):
                with self.assertRaises(ValueError):
                    jordan.normalize_terminal_liwa({**self.properties(), **changed}, box(37, 32, 39, 34))

    def test_duplicate_old_qadaa_is_not_a_second_local_authority(self):
        old = {"osm_id": "13376112", "code": 1206, "fclass": "admin_level6", "name": "Rwaished Sub-District"}
        with self.assertRaises(ValueError):
            jordan.normalize_terminal_liwa(old, box(37, 32, 39, 34))

    def test_invalid_and_wrong_territory_geometry_is_not_accepted(self):
        for geometry in (box(0, 0, 1, 1), box(37.2, 31.8, 39.1, 32.8)):
            with self.subTest(geometry=geometry):
                with self.assertRaises(ValueError):
                    jordan.normalize_terminal_liwa(self.properties(), geometry)

    def test_preserves_original_properties_without_mutation(self):
        properties = self.properties()
        before = copy.deepcopy(properties)
        row = jordan.normalize_terminal_liwa(properties, box(37.2, 31.8, 39.1, 33.3))
        self.assertEqual(row["original_properties"], before)
        self.assertEqual(properties, before)

    def source_fixture(self, directory):
        feature = {"type": "Feature", "properties": {"original_properties": self.properties()},
                   "geometry": mapping(box(37.2, 31.8, 39.1, 33.3))}
        raw = json.dumps({"type": "FeatureCollection", "features": [feature]}).encode()
        Path(directory, "source.json").write_bytes(raw)
        return {"id": jordan.SOURCE_ID, "country": "JO", "kind": "district", "source_unit_count": 1,
                "expected_unit_count": 1, "cache_file": "source.json", "bytes": len(raw),
                "sha256": hashlib.sha256(raw).hexdigest()}

    def test_reader_does_not_accept_a_municipality_claim_in_manifest(self):
        with TemporaryDirectory() as directory:
            source = self.source_fixture(directory)
            source["kind"] = "municipality"
            with self.assertRaises(ValueError):
                list(jordan.iter_boundaries(Path(directory), [source]))

    def test_reader_requires_unchanged_source_bytes_and_own_country(self):
        with TemporaryDirectory() as directory:
            source = self.source_fixture(directory)
            rows = list(jordan.iter_boundaries(Path(directory), [source]))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["kind"], "district")
            with self.assertRaises(ValueError):
                list(jordan.iter_boundaries(Path(directory), [{**source, "country": "AZ"}]))
            with Path(directory, "source.json").open("ab") as stream:
                stream.write(b" ")
            with self.assertRaises(ValueError):
                list(jordan.iter_boundaries(Path(directory), [source]))

    def test_fresh_cache_can_restore_original_members_using_the_actual_range_fetch_contract(self):
        archive = io.BytesIO()
        receipts = {}
        with zipfile.ZipFile(archive, "w") as writer:
            for ext in ("shp", "dbf", "shx", "prj", "cpg"):
                raw = ("source-" + ext).encode()
                writer.writestr("gis_osm_adminareas_a_free_1." + ext, raw)
                receipts[ext] = (len(raw), hashlib.sha256(raw).hexdigest())
        remote = SimpleNamespace(snapshot={"bytes": 60584695, "etag": '"39c72f7-65fce84d0def6"'},
                                 fetch=lambda _start, _end: b"")
        with TemporaryDirectory() as directory:
            with patch.object(jordan, "MEMBERS", receipts), \
                 patch("atlas_geofabrik_sources.RangeSource", return_value=remote), \
                 patch("atlas_geofabrik_sources.RemoteZip", return_value=io.BytesIO(archive.getvalue())):
                members = jordan._verified_members(Path(directory))
            for ext in receipts:
                self.assertEqual((members / ("gis_osm_adminareas_a_free_1." + ext)).read_bytes(),
                                 ("source-" + ext).encode())


if __name__ == "__main__":
    unittest.main()
