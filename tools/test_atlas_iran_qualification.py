"""Damaged producer labels stay explicit unknowns; no invented Persian names."""
from copy import deepcopy
import importlib
import importlib.util
import unittest


SOURCE = {"id":"gbOpen-IRN-ADM4", "country":"IR", "source_commit":"9469f09",
          "sha256":"89d50a325cda34b4420b8b10ecbebe585825011a3c5969a3a813ef5ac386185c"}


def fixture(name="?????? ?????? ????"):
    return {"id":"gbOpen:IRN:ADM4:25652852B52430274796162", "country":"IR",
            "source":"gbOpen-IRN-ADM4", "name":name,"original_name":name,
            "name_known":True,"kind":"municipality","geometry":{"unchanged":True}}


class IranNameQualificationTests(unittest.TestCase):
    def qualify(self, row, source=None):
        self.assertIsNotNone(importlib.util.find_spec("atlas_iran_qualification"),
                             "IR producer-name qualification is not implemented")
        return importlib.import_module("atlas_iran_qualification").qualify_row(row, SOURCE if source is None else source)

    def test_questionmark_only_label_is_unknown_without_changing_original_evidence(self):
        old=fixture(); original=deepcopy(old); new=self.qualify(old)
        self.assertIs(new["name_known"],False)
        self.assertEqual(new["original_name"],old["original_name"])
        self.assertEqual(new["name"],"Verwaltungsgebiet (Name in Quelle beschädigt)")
        self.assertEqual(new["name_quality"],"source-name-corrupted")
        self.assertEqual(new["kind"],old["kind"])
        self.assertEqual(new["geometry"],old["geometry"])
        self.assertEqual(old,original)

    def test_partly_destroyed_label_is_not_silently_repaired(self):
        new=self.qualify(fixture("???? Rural District"))
        self.assertFalse(new["name_known"])
        self.assertEqual(new["original_name"],"???? Rural District")

    def test_undamaged_name_is_preserved(self):
        row=fixture("Tehran"); self.assertEqual(self.qualify(row),row)

    def test_scope_is_exact_pinned_iran_source(self):
        row={**fixture(),"source":"other"}
        self.assertEqual(self.qualify(row),row)
        self.assertEqual(self.qualify(fixture(),{**SOURCE,"country":"LB"}),fixture())

    def test_changed_pinned_bytes_are_not_implicitly_qualified(self):
        with self.assertRaisesRegex(ValueError,"pinned"):
            self.qualify(fixture(),{**SOURCE,"sha256":"changed"})

    def test_foreign_identifier_is_rejected(self):
        with self.assertRaisesRegex(ValueError,"identity"):
            self.qualify({**fixture(),"id":"gbOpen:ARM:ADM4:42"})

    def test_requalification_is_idempotent(self):
        row=self.qualify(fixture());self.assertEqual(self.qualify(row),row)


if __name__=="__main__":unittest.main()
