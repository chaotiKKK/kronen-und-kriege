import copy
import unittest

from shapely.geometry import box, mapping

import atlas_azerbaijan_qualification as qualification


class AzerbaijanQualificationTests(unittest.TestCase):
    def row(self, unit_id="11825936", name="Binəqədi rayonu"):
        return {"id": "geofabrik:AZ:8:" + unit_id, "country": "AZ", "kind": "municipality",
                "source": "geofabrik-AZ-admin8-municipality", "admin_level": 8,
                "name": name, "original_name": name, "original_source_id": unit_id,
                "unit_type": "Belediyye", "geometry": mapping(box(49, 40, 49.1, 40.1)),
                "original_properties": {"osm_id": unit_id, "code": 1208,
                                        "fclass": "admin_level8", "name": name}}

    def test_city_district_does_not_become_a_municipality(self):
        row = self.row()
        before = copy.deepcopy(row)
        result = qualification.qualify_row(row)
        self.assertIs(result["administrative_geometry_eligible"], False)
        self.assertIn("district", result["administrative_ineligibility_note"])
        self.assertTrue(result["administrative_ineligibility_evidence_url"].startswith("https://"))
        self.assertEqual(row, before)
        for key, value in before.items():
            self.assertEqual(result[key], value, key)

    def test_coarse_land_overlap_cannot_turn_foreign_village_into_az_municipality(self):
        result = qualification.qualify_row(self.row("17032156", "آقاحسن بیگلو"))
        self.assertFalse(result["administrative_geometry_eligible"])
        self.assertIn("country", result["administrative_ineligibility_note"])

    def test_independent_city_identity_does_not_prove_municipal_boundary(self):
        result = qualification.qualify_row(self.row("3912206", "Sumqayıt"))
        self.assertFalse(result["administrative_geometry_eligible"])
        self.assertIn("coextensive", result["administrative_ineligibility_note"])

    def test_changed_identity_is_not_silently_requalified(self):
        for changed in ({"name": "Different"}, {"country": "IR"},
                        {"original_source_id": "999"}, {"admin_level": 6}):
            with self.subTest(changed=changed):
                with self.assertRaises(ValueError):
                    qualification.qualify_row({**self.row(), **changed})

    def test_new_source_object_requires_positive_review(self):
        with self.assertRaises(ValueError):
            qualification.qualify_row(self.row("99999999", "New bələdiyyə"))

    def test_original_dbf_identity_must_match(self):
        row = self.row()
        row["original_properties"]["osm_id"] = "999"
        with self.assertRaises(ValueError):
            qualification.qualify_row(row)


if __name__ == "__main__":
    unittest.main()
