from copy import deepcopy
import importlib
import importlib.util
import unittest


UNITS={"3389541":("Атырау қалалық әкімдігі","214834"),
       "3767383":("Орал қалалық әкімдігі","215441"),
       "5515125":("Ақтау қалалық әкімдігі","215686")}


def fixture(identifier="3389541"):
    name,parent=UNITS[identifier]
    return {"id":f"geofabrik:KZ:6:{identifier}","country":"KZ","kind":"district",
            "source":"geofabrik-KZ-admin6-district","admin_level":6,
            "original_source_id":identifier,"name":name,"original_name":name,
            "unit_type":"Audan","native_type":"Audan","parent_id":f"geofabrik:KZ:4:{parent}",
            "original_properties":{"osm_id":identifier,"code":1206,"fclass":"admin_level6","name":name},
            "geometry":{"keep":"every coordinate"}}


class KazakhstanCityAdministrationTests(unittest.TestCase):
    def qualify(self,row):
        self.assertIsNotNone(importlib.util.find_spec("atlas_kazakhstan_qualification"),
                             "Exact KZ city-administration qualifier is absent")
        return importlib.import_module("atlas_kazakhstan_qualification").qualify_row(row)

    def test_exact_three_city_administrations_keep_district_geometry_and_get_local_role(self):
        for identifier in UNITS:
            row=fixture(identifier);before=deepcopy(row);new=self.qualify(row)
            self.assertEqual(new["kind"],"district")
            self.assertEqual(new["unit_type"],"Қалалық әкімдік / City administration")
            self.assertEqual(new["local_government_role"],"local_admin")
            self.assertEqual(new["geometry"],row["geometry"])
            self.assertEqual(new["original_properties"],row["original_properties"])
            self.assertEqual(row,before)

    def test_other_audans_are_not_promoted(self):
        row={**fixture(),"original_source_id":"42","id":"geofabrik:KZ:6:42","name":"Audan"}
        self.assertEqual(self.qualify(row),row)

    def test_name_identity_is_guarded(self):
        with self.assertRaisesRegex(ValueError,"identity"):
            self.qualify({**fixture(),"name":"Other"})

    def test_original_dbf_identity_is_guarded(self):
        row=fixture();row["original_properties"]["code"]=1207
        with self.assertRaisesRegex(ValueError,"identity"):self.qualify(row)

    def test_territorial_parent_is_guarded(self):
        with self.assertRaisesRegex(ValueError,"parent"):
            self.qualify({**fixture(),"parent_id":"country:KZ"})

    def test_foreign_country_is_unchanged(self):
        row={**fixture(),"country":"RU"};self.assertEqual(self.qualify(row),row)

    def test_repeated_qualification_is_idempotent(self):
        row=self.qualify(fixture());self.assertEqual(self.qualify(row),row)


if __name__=="__main__":unittest.main()
