"""Exact Beirut identity guards: one municipality, not twelve municipal councils."""
from copy import deepcopy
import importlib
import importlib.util
import unittest


NAMES = {
    "3074290": "الأشرفية", "3074291": "باشورة", "3074292": "دار المريسة",
    "3074293": "مزرعة", "3074294": "مدور", "3074295": "ميناء الحصن",
    "3074296": "مصيطبة", "3074297": "المرفأ", "3074298": "رأس بيروت",
    "3074299": "الرميل", "3074300": "الصيفي", "3074301": "زقاق البلاط",
}


def fixture(identifier="3074290"):
    region = identifier == "316552"
    level, kind = (4, "region") if region else (7, "municipality")
    name = "محافظة بيروت" if region else NAMES[identifier]
    return {
        "id": f"geofabrik:LB:{level}:{identifier}", "country": "LB",
        "original_source_id": identifier, "admin_level": level,
        "kind": kind, "name": name, "original_name": name,
        "source": f"geofabrik-LB-admin{level}-{kind}",
        "unit_type": "Mouhafazah" if region else "Baladiya",
        "parent_id": "country:LB" if region else "geofabrik:LB:4:316552",
        "original_properties": {"osm_id": identifier, "code": 1200+level,
                                "fclass": f"admin_level{level}", "name": name},
        "geometry": {"type": "Polygon", "coordinates": [[[35,33],[36,33],[36,34],[35,33]]]},
    }


class LebanonQualificationTests(unittest.TestCase):
    def qualify(self, row):
        self.assertIsNotNone(importlib.util.find_spec("atlas_lebanon_qualification"),
                             "Lebanese special-role qualification is not implemented")
        return importlib.import_module("atlas_lebanon_qualification").qualify_row(row)

    def test_twelve_exact_quarters_are_retained_but_not_counted_as_independent_municipalities(self):
        for identifier in NAMES:
            with self.subTest(identifier=identifier):
                old = fixture(identifier); untouched = deepcopy(old)
                new = self.qualify(old)
                self.assertIs(new["administrative_geometry_eligible"], False)
                self.assertEqual(new["kind"], "municipality")
                self.assertEqual(new["geometry"], old["geometry"])
                self.assertEqual(new["original_properties"], old["original_properties"])
                self.assertEqual(new["source_role_qualification"]["actual_identity"], "Beirut quarter; not an independent Baladiya")
                self.assertIn("moim.gov.lb", new["administrative_ineligibility_evidence_url"])
                self.assertEqual(old, untouched)

    def test_existing_beirut_region_gets_one_secondary_municipality_role(self):
        old = fixture("316552"); new = self.qualify(old)
        self.assertEqual(new["local_government_role"], "municipality")
        self.assertEqual(new["kind"], "region")
        self.assertEqual(new["id"], old["id"])
        self.assertEqual(new["geometry"], old["geometry"])
        self.assertIn("moim.gov.lb", str(new["local_government_role_evidence"]))

    def test_known_id_with_changed_name_is_rejected(self):
        row = fixture(); row["name"] = "Other place"
        with self.assertRaisesRegex(ValueError, "identity"):
            self.qualify(row)

    def test_known_id_with_foreign_parent_is_rejected(self):
        row = fixture(); row["parent_id"] = "geofabrik:LB:4:12903506"
        with self.assertRaisesRegex(ValueError, "parent"):
            self.qualify(row)

    def test_original_dbf_identity_is_checked(self):
        row = fixture(); row["original_properties"]["osm_id"] = "42"
        with self.assertRaisesRegex(ValueError, "identity"):
            self.qualify(row)

    def test_nonmatching_country_or_identifier_is_unchanged(self):
        for row in [{**fixture(), "country": "SY"}, {**fixture(), "original_source_id": "999"}]:
            self.assertEqual(self.qualify(row), row)

    def test_requalification_is_idempotent(self):
        for identifier in ["316552", "3074298"]:
            row = self.qualify(fixture(identifier))
            self.assertEqual(self.qualify(row), row)


if __name__ == "__main__":
    unittest.main()
