"""Remote ZIP integrity and country-role contracts for the HU pilot."""
from __future__ import annotations
import importlib.util
import io
from pathlib import Path
import unittest
import zipfile
import tempfile
import json
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "tools/atlas_geofabrik_sources.py"
module = None
if PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_geofabrik_sources", PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)


class GeofabrikTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(module, "Der selektive Geofabrik-Leser fehlt.")

    def test_central_directory_and_selected_member_do_not_fetch_road_payload(self):
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w") as writer:
            writer.writestr("roads.bin", b"R"*200000, compress_type=zipfile.ZIP_STORED)
            writer.writestr("gis_osm_adminareas_a_free_1.dbf", b"verified administrative attributes", compress_type=zipfile.ZIP_DEFLATED)
        data = archive.getvalue()
        calls = []
        def fetch(start, end):
            calls.append((start,end))
            return data[start:end+1]
        with zipfile.ZipFile(module.RemoteZip(len(data), fetch)) as reader:
            member = module.admin_members(reader.infolist())[0]
            self.assertEqual(reader.read(member), b"verified administrative attributes")
        self.assertTrue(calls)
        self.assertFalse(any(start < 200000 and end >= 40 for start,end in calls))
        self.assertLess(sum(end-start+1 for start,end in calls), 2000)

    def test_remote_reader_refuses_unbounded_whole_archive_read(self):
        reader = module.RemoteZip(700_000_000, lambda start,end: b"")
        with self.assertRaisesRegex(ValueError, "budget|Budget|limit|Limit"):
            reader.read()

    def test_only_verified_range_snapshot_is_accepted(self):
        good = {"status":206,"content-range":"bytes 4-8/20","etag":"\"same\""}
        module.validate_range(good, 4, 8, 20, '"same"', 5)
        for changed in [{**good,"status":200},{**good,"etag":'"changed"'},
                        {**good,"content-range":"bytes 4-9/20"}]:
            with self.assertRaises(ValueError):
                module.validate_range(changed, 4, 8, 20, '"same"', 5)

    def test_only_country_specific_formal_administrative_roles_are_imported(self):
        self.assertEqual(module.role_for("HU", "admin_level8", 1208), ("municipality","Település"))
        self.assertEqual(module.role_for("HU", "admin_level9", 1209), ("local_admin","Kerület"))
        self.assertIsNone(module.role_for("HU", "national", 1202))
        self.assertIsNone(module.role_for("RU", "admin_level8", 1208))
        self.assertIsNone(module.role_for("HU", "village", 1004))

    def test_country_is_assigned_by_independent_majority_not_archive_name(self):
        from shapely.geometry import box
        country, detail = module.assign_country(box(0,0,10,10), {"HU":box(0,0,4,10),"AT":box(4,0,10,10)})
        self.assertEqual(country, "AT")
        self.assertAlmostEqual(detail["fraction"], .6)
        self.assertTrue(detail["ambiguous"])
        country, detail = module.assign_country(box(0,0,10,10), {"HU":box(0,0,5,10),"AT":box(5,0,10,10)})
        self.assertIsNone(country)
        self.assertTrue(detail["ambiguous"])

    def test_traversal_members_are_not_extracted(self):
        selected = module.admin_members([zipfile.ZipInfo("../gis_osm_adminareas_a_free_1.shp"),
            zipfile.ZipInfo("gis_osm_adminareas_a_free_1.shp"),zipfile.ZipInfo("gis_osm_roads_free_1.shp")])
        self.assertEqual([item.filename for item in selected], ["gis_osm_adminareas_a_free_1.shp"])

    def test_corrupt_member_is_rejected_before_receipt_or_output(self):
        import tempfile
        extractor = getattr(module,"extract_admin_members",None)
        self.assertTrue(callable(extractor),"CRC-geprüfte Mitgliedsextraktion fehlt.")
        buffer = io.BytesIO()
        name = "gis_osm_adminareas_a_free_1.dbf"
        with zipfile.ZipFile(buffer,"w") as writer:
            writer.writestr(name,b"administrative data",compress_type=zipfile.ZIP_STORED)
        data = bytearray(buffer.getvalue())
        data[30+len(name)] ^= 1
        with tempfile.TemporaryDirectory() as temporary:
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                with self.assertRaises(zipfile.BadZipFile):
                    extractor(archive,Path(temporary))
            self.assertFalse((Path(temporary)/name).exists())

    def test_buffer_feature_never_inherits_the_hungarian_archive_country(self):
        from shapely.geometry import box
        normalizer = getattr(module,"normalize_record",None)
        self.assertTrue(callable(normalizer),"Länderzuordnung muss vor der Rollenzuordnung erfolgen.")
        properties = {"osm_id":"109523","fclass":"admin_level8","code":1208,"name":"Ritzing"}
        self.assertIsNone(normalizer(properties,box(0,0,1,1),"AT",{"fraction":1,"ambiguous":False}))
        row = normalizer({**properties,"name":"Telki"},box(0,0,1,1),"HU",{"fraction":1,"ambiguous":False})
        self.assertEqual(row["country"],"HU")
        self.assertEqual(row["kind"],"municipality")
        self.assertEqual(row["original_source_id"],"109523")
        self.assertIsNone(row["original_source_version"])

    def test_parent_is_explicitly_inferred_from_unambiguous_area_containment(self):
        from shapely.geometry import box
        linker = getattr(module,"infer_parents",None)
        self.assertTrue(callable(linker),"Die Quelle besitzt keine codierte Elternhierarchie.")
        rows = [{"id":"region","admin_level":6,"country":"HU","geometry":box(0,0,10,10)},
                {"id":"district","admin_level":7,"country":"HU","geometry":box(0,0,5,10)},
                {"id":"town","admin_level":8,"country":"HU","geometry":box(1,1,2,2)}]
        linker(rows)
        self.assertEqual(rows[2]["parent_id"],"district")
        self.assertEqual(rows[2]["parent_relationship"],"inferred-area-containment")

    def test_verified_territory_resolves_coarse_land_reference_border_error(self):
        from shapely.geometry import box
        assigner = getattr(module,"assign_verified_territory",None)
        self.assertTrue(callable(assigner),"Belegte territoriale Zuordnung muss von der Landmaske getrennt sein.")
        country,detail = assigner(box(0,0,1,1),"HU",box(0,0,2,2),{"HU":box(0,0,.2,1),"SK":box(.2,0,1,1)})
        self.assertEqual(country,"HU")
        self.assertAlmostEqual(detail["territorial_fraction"],1.0)
        self.assertTrue(detail["independent_land_disagreement"])

    def test_country_identity_must_match_iso_tags_and_archive_snapshot(self):
        checker = getattr(module,"validate_country_identity",None)
        self.assertTrue(callable(checker),"Snapshot-kompatibler ISO-Länderbeleg fehlt.")
        properties = {"osm_id":"21335","name":"Magyarország","fclass":"national","code":1202}
        relation = {"type":"relation","id":21335,"timestamp":"2026-11-02T06:53:02Z",
            "tags":{"name":"Magyarország","ISO3166-1:alpha2":"HU","admin_level":"2","boundary":"administrative"}}
        checker(properties,relation,"HU","2026-11-08T21:21:00Z")
        with self.assertRaises(ValueError):
            checker(properties,{**relation,"timestamp":"2026-11-09T18:24:38Z"},"HU","2026-11-08T21:21:00Z")

    def test_capital_retains_both_region_and_proven_local_government_role(self):
        from shapely.geometry import box
        row = module.normalize_record({"osm_id":"37244","fclass":"admin_level6","code":1206,"name":"Budapest"},
            box(0,0,1,1),"HU",{"fraction":1,"ambiguous":False})
        self.assertEqual(row["kind"],"region")
        self.assertEqual(row.get("local_government_role"),"municipality")

    def test_explicit_capital_municipality_is_not_counted_again_on_its_region(self):
        from shapely.geometry import box
        reconciler = getattr(module,"reconcile_local_roles",None)
        self.assertTrue(callable(reconciler),"Explizite Gemeinde und Zusatzrolle dürfen keine doppelte Körperschaft erzeugen.")
        rows = [{"id":"region","name":"Budapest","country":"HU","kind":"region","geometry":box(0,0,1,1),
                 "local_government_role":"municipality"},
                {"id":"city","name":"Budapest","country":"HU","kind":"municipality","geometry":box(0,0,1,1)}]
        reconciler(rows)
        self.assertNotIn("local_government_role",rows[0])
        self.assertEqual(rows[0]["local_government_represented_by"],"city")

    def test_prepared_country_collection_is_loaded_without_replacing_it_with_hu_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache=Path(temporary)
            path=cache/"verified.bin"
            path.write_bytes(b"verified completed cache")
            sources=[{"id":"source-"+country,"country":country,"cache_file":"verified.bin",
                      "sha256":module.digest(path.read_bytes()),"bytes":path.stat().st_size} for country in ["HU","EE"]]
            (cache/"geofabrik-collection-v4.json").write_text(json.dumps({"collection_version":4,"source_groups_version":3,"sources":sources}),encoding="utf-8")
            with patch.object(module,"ROOT",cache),patch.object(module.subprocess,"run",side_effect=AssertionError("unexpected remote download")):
                try:
                    loaded=module.prepare_sources(cache)
                except (AssertionError,FileNotFoundError) as error:
                    self.fail("Der fertige Mehrländer-Cache wurde nicht geladen: "+str(error))
            self.assertEqual({source["country"] for source in loaded},{"HU","EE"})

    def test_verified_alias_retains_exact_target_version_and_rejects_common_id_only(self):
        helper=getattr(module,"verified_source_alias",None)
        self.assertTrue(callable(helper))
        row={"id":"geofabrik:TR:8:123","source":"gf","original_source_id":"123","country":"TR","admin_level":8,"original_name":"Native","kind":"local_admin"}
        source={"sha256":"a"*64}
        proof={"geofabrik_id":row["id"],"geofabrik_source":"gf","geofabrik_original_source_id":"123","country":"TR","admin_level":8,
            "geofabrik_name":"Native","osm_name":"Native","geofabrik_kind":"local_admin","osm_kind":"local_admin","name_match":True,"kind_match":True,
            "geometry_intersection_over_union":1.0,"geofabrik_cache_sha256":"a"*64,"osm_id":"osm:relation:123","osm_source":"osm","osm_record_id":"r123@7"}
        alias=helper(row,source,proof,{"file":"audit.json","sha256":"b"*64})
        self.assertEqual(alias["target_record_id"],"r123@7")
        self.assertEqual(alias["audit_sha256"],"b"*64)
        proof["name_match"]=False
        with self.assertRaisesRegex(ValueError,"alias"):
            helper(row,source,proof,{"file":"audit.json","sha256":"b"*64})

    def test_shared_alias_audit_does_not_override_another_sources_new_cache_revision(self):
        import gzip
        from shapely.geometry import box,mapping
        with tempfile.TemporaryDirectory() as temporary:
            cache=Path(temporary)
            rows=[dict(id='gf:'+country,source='gf-'+country,country=country,admin_level=8,kind='local_admin',original_source_id=str(index),original_name=country,geometry=mapping(box(0,0,1,1))) for index,country in enumerate(('TR','RU'),1)]
            path=cache/'rows.gz'
            with gzip.open(path,'wt',encoding='utf-8') as out:
                for row in rows:out.write(json.dumps(row)+'\n')
            sha=module.digest(path.read_bytes())
            proofs=[]
            for row in rows:
                proofs.append(dict(geofabrik_id=row['id'],geofabrik_source=row['source'],geofabrik_original_source_id=row['original_source_id'],country=row['country'],admin_level=8,
                    geofabrik_name=row['original_name'],osm_name=row['original_name'],geofabrik_kind='local_admin',osm_kind='local_admin',name_match=True,kind_match=True,
                    geometry_intersection_over_union=1.,geofabrik_cache_sha256=sha,osm_id='osm:relation:'+row['original_source_id'],osm_source='osm',osm_record_id='r'+row['original_source_id']+'@1'))
            old_tr={**proofs[0],'geofabrik_cache_sha256':'0'*64}
            sources=[]
            for country,audit_rows in [('TR',[proofs[0]]),('RU',[old_tr,proofs[1]])]:
                audit=cache/(country+'.json');audit.write_text(json.dumps({'candidate_pairs':audit_rows}),encoding='utf-8')
                sources.append(dict(id='gf-'+country,country=country,cache_file=path.name,sha256=sha,source_unit_count=1,
                    verified_source_alias_audit=dict(file=audit.name,sha256=module.digest(audit.read_bytes()),bytes=audit.stat().st_size)))
            loaded=list(module.iter_boundaries(cache,sources))
            self.assertEqual(len(loaded),2)
            self.assertTrue(all(r['verified_source_alias']['geofabrik_cache_sha256']==sha for r in loaded))


if __name__ == "__main__":
    unittest.main()
