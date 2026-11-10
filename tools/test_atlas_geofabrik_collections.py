import importlib.util
from pathlib import Path
import unittest
import tempfile
import json

PATH = Path(__file__).with_name("atlas_geofabrik_collections.py")
module = None
if PATH.exists():
    spec = importlib.util.spec_from_file_location("atlas_geofabrik_collections",PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)


class CollectionTests(unittest.TestCase):
    def setUp(self): self.assertIsNotNone(module,"Länderspezifische Geofabrik-Aufbereitung fehlt.")

    def props(self,level,name="Test",identifier="1"):
        return {"fclass":f"admin_level{level}","code":1200+level,"name":name,"osm_id":identifier}

    def test_municipal_level_is_country_specific(self):
        for country,level in [("CZ",8),("EE",7),("NO",7),("AL",7),("MK",7),("MD",8),("GG",8),("JE",8),("FO",7)]:
            with self.subTest(country=country):
                self.assertEqual(module.classify_role(country,self.props(level))[0],"municipality")
        self.assertIsNone(module.classify_role("EE",self.props(8)))
        self.assertIsNone(module.classify_role("MK",self.props(8)))
        self.assertIsNone(module.classify_role("IM",self.props(8,"Laxey")))

    def test_underlying_administrations_remain_distinct_from_municipalities(self):
        for country,level in [("AL",8),("JE",9),("MD",7),("TR",8)]:
            self.assertEqual(module.classify_role(country,self.props(level))[0],"local_admin")
        self.assertEqual(module.classify_role("MK",self.props(6,"Град Скопје"))[0],"region")

    def test_slovak_military_area_never_becomes_a_municipality(self):
        properties = self.props(8,"Lešť (vojenský obvod)","2265034")
        tags = {"boundary":"administrative","admin_level":"8","border_type":"military_area","place":"military_area"}
        self.assertEqual(module.classify_role("SK",properties,tags)[0],"local_admin")
        with self.assertRaisesRegex(ValueError,"qualification|Qualification"):
            module.classify_role("SK",properties)
        self.assertEqual(module.classify_role("SK",self.props(8,"Bzince pod Javorinou"))[0],"municipality")

    def test_slovak_capital_level_five_requires_positive_native_city_tags(self):
        properties = self.props(5,"Bratislava","1702499")
        self.assertIsNone(module.classify_role("SK",properties))
        tags = {"border_type":"city","official_status":"sk:mesto","admin_level":"5","boundary":"administrative"}
        self.assertEqual(module.classify_role("SK",properties,tags),("municipality","Mesto"))

    def test_czech_military_area_is_excluded_even_when_exported_on_level_eight(self):
        properties=self.props(8,"Vojenský újezd Boletice","438525")
        tags={"border_type":"military_area","official_status":"cz:vojenský újezd","admin_level":"8","boundary":"administrative"}
        self.assertEqual(module.classify_role("CZ",properties,tags),("local_admin","Vojenský újezd"))
        with self.assertRaisesRegex(ValueError,"qualification|Qualification"):
            module.classify_role("CZ",properties)

    def test_no_national_feature_is_imported_as_another_country(self):
        self.assertIsNone(module.classify_role("SK",{"fclass":"national","code":1202,"name":"Slovensko","osm_id":"14296"}))

    def test_russian_municipal_and_submunicipal_levels_keep_separate_roles(self):
        self.assertEqual(module.classify_role("RU",self.props(8))[0],"municipality")
        self.assertEqual(module.classify_role("RU",self.props(9))[0],"local_admin")
        self.assertEqual(module.classify_role("RU",self.props(6))[0],"district")
        self.assertIsNone(module.classify_role("RU",self.props(7)))

    def test_overlapping_regional_extracts_keep_one_entity_and_both_provenances(self):
        from shapely.geometry import box
        merger = getattr(module,"merge_by_id",None)
        self.assertTrue(callable(merger))
        rows = [{"id":"same","country":"CZ","kind":"municipality","name":"Town","geometry":box(0,0,1,1),"source_snapshots":["regionA"]},
                {"id":"same","country":"CZ","kind":"municipality","name":"Town","geometry":box(1,0,2,1),"source_snapshots":["regionB"]}]
        merged = merger(rows)
        self.assertEqual(len(merged),1)
        self.assertAlmostEqual(merged[0]["geometry"].area,2)
        self.assertEqual(merged[0]["source_snapshots"],["regionA","regionB"])

    def test_same_native_level_with_military_and_municipal_roles_has_separate_source_counts(self):
        grouper = getattr(module,"source_groups",None)
        self.assertTrue(callable(grouper))
        rows=[{"country":"SK","admin_level":8,"kind":"municipality"},
              {"country":"SK","admin_level":8,"kind":"local_admin"}]
        groups=grouper(rows)
        self.assertEqual(len(groups),2)
        self.assertEqual({tuple(row["kind"] for row in group) for group in groups.values()},
                         {("municipality",),("local_admin",)})

    def test_official_manx_mergers_use_only_the_documented_constituents(self):
        from shapely.geometry import box
        merger=getattr(module,"current_manx_authorities",None)
        self.assertTrue(callable(merger))
        ids=[("1061137","Laxey"),("1061136","Lonan"),("1061140","Maughold"),("1029669","Arbory"),("1029670","Rushen")]
        rows=[{"id":identifier,"original_source_id":identifier,"country":"IM","name":name,"kind":"local_admin", "admin_level":8,
            "geometry":box(index,0,index+1,1),"source_snapshots":["same"]} for index,(identifier,name) in enumerate(ids)]
        rows.append({"id":"onchan","original_source_id":"1061142","country":"IM","name":"Onchan","kind":"local_admin","admin_level":8,
            "geometry":box(20,0,21,1),"source_snapshots":["same"]})
        output=merger(rows)
        self.assertEqual({row["name"] for row in output},{"Garff","Arbory and Rushen","Onchan"})
        garff=next(row for row in output if row["name"]=="Garff")
        self.assertAlmostEqual(garff["geometry"].area,3)
        self.assertEqual(garff["constituent_source_ids"],["1061136","1061137","1061140"])
        self.assertEqual(garff["kind"],"municipality")

    def test_separate_osm_api_supplement_keeps_its_own_provider_attribution(self):
        row={"country":"JE","admin_level":8,"kind":"municipality","provider_source_id":"osm-JE-Grouville-snapshot"}
        groups=module.source_groups([row])
        self.assertEqual(list(groups),["osm-JE-Grouville-snapshot"])

    def test_verified_regional_iso_scope_excludes_neighbor_and_unqualified_shapes(self):
        from shapely.geometry import box
        builder=getattr(module,"regional_iso_scope",None)
        self.assertTrue(callable(builder))
        rows=[{"geometry":box(0,0,1,1),"name":"Own region","tags":{"name":"Own region","boundary":"administrative","ISO3166-2":"CZ-01"}},
              {"geometry":box(1,0,2,1),"name":"Neighbor","tags":{"name":"Neighbor","boundary":"administrative","ISO3166-2":"SK-01"}},
              {"geometry":box(2,0,3,1),"name":"Unknown","tags":{"name":"Unknown","boundary":"administrative"}}]
        geometry,selected=builder(rows,"CZ")
        self.assertAlmostEqual(geometry.area,1)
        self.assertEqual(selected,["CZ-01"])

    def test_fast_contained_territory_path_retains_the_reference_disagreement(self):
        from shapely.geometry import box
        assigner=getattr(module,"assign_scoped_country",None)
        self.assertTrue(callable(assigner))
        geometry=box(0,0,1,1)
        refs={"CZ":box(0,0,.2,1),"SK":box(.2,0,1,1)}
        country,detail=assigner(geometry,"CZ",box(0,0,2,2),refs)
        self.assertEqual(country,"CZ")
        self.assertTrue(detail["independent_land_disagreement"])
        self.assertEqual(detail["territorial_fraction"],1.0)

    def test_worker_prepares_its_own_scope_without_mutating_shared_geometry(self):
        import shapely
        from shapely.geometry import box
        clone=getattr(module,"worker_scope",None)
        self.assertTrue(callable(clone))
        original=box(0,0,2,2)
        owned=clone(original.wkb)
        self.assertIsNot(owned,original)
        self.assertTrue(shapely.is_prepared(owned))
        self.assertFalse(shapely.is_prepared(original))
        self.assertTrue(owned.equals(original))

    def test_api_region_retains_own_source_and_requires_matching_native_role(self):
        from shapely.geometry import box
        builder=getattr(module,"regional_api_row",None)
        self.assertTrue(callable(builder))
        proof={"relation_id":406567,"relation_version":87,"snapshot":"2026-11-08T21:21:00Z",
            "source_url":"https://api.openstreetmap.org/api/0.6/relation/406567/full.json","source_sha256":"a"*64}
        relation={"type":"relation","id":406567,"version":87,"timestamp":"2026-08-29T12:39:03Z",
            "tags":{"name":"Trøndelag","boundary":"administrative","admin_level":"4","ISO3166-2":"NO-50"}}
        row=builder("NO",box(0,0,1,1),proof,relation)
        self.assertEqual((row["kind"],row["unit_type"],row["original_source_version"]),("region","Fylke",87))
        self.assertTrue(row["provider_source_id"].startswith("osm-NO-"))
        self.assertEqual(row["source_metadata_override"]["provider"],"OpenStreetMap API")
        with self.assertRaisesRegex(ValueError,"ISO|role"):
            builder("CZ",box(0,0,1,1),proof,relation)

    def test_api_region_never_accepts_a_national_boundary_or_post_snapshot_relation(self):
        from shapely.geometry import box
        builder=getattr(module,"regional_api_row",None)
        self.assertTrue(callable(builder))
        proof={"relation_id":1,"relation_version":1,"snapshot":"2026-11-08T21:21:00Z","source_url":"https://example.test/1","source_sha256":"a"*64}
        relation={"type":"relation","id":1,"version":1,"timestamp":"2026-11-08T21:00:00Z",
            "tags":{"name":"National","boundary":"administrative","admin_level":"2","ISO3166-2":"NO-50"}}
        with self.assertRaisesRegex(ValueError,"role"):
            builder("NO",box(0,0,1,1),proof,relation)
        relation["tags"]["admin_level"]="4"
        relation["timestamp"]="2026-11-09T00:00:00Z"
        with self.assertRaisesRegex(ValueError,"snapshot"):
            builder("NO",box(0,0,1,1),proof,relation)

    def test_zero_point_source_polygon_is_an_explicit_unlocated_defect(self):
        decoder=getattr(module,"staged_polygon",None)
        self.assertTrue(callable(decoder))
        polygon=module.core._shapefile().Shape(shapeType=5)
        polygon.parts=[0]
        polygon.points=[]
        geometry,defect=decoder(polygon,self.props(8,"Bölme Mahallesi","20574952"))
        self.assertIsNone(geometry)
        self.assertEqual(defect["original_source_id"],"20574952")
        self.assertEqual(defect["reason"],"zero-point-source-polygon")
        self.assertEqual(defect["country_assignment"],"unresolved-no-geometry")

    def test_valid_source_polygon_is_not_discarded_or_replaced(self):
        decoder=getattr(module,"staged_polygon",None)
        self.assertTrue(callable(decoder))
        polygon=module.core._shapefile().Shape(shapeType=5)
        polygon.parts=[0]
        polygon.points=[[0,0],[0,1],[1,1],[1,0],[0,0]]
        geometry,defect=decoder(polygon,self.props(8))
        self.assertIsNone(defect)
        self.assertAlmostEqual(geometry.area,1)

    def test_capital_role_and_prague_obvod_use_verified_native_tags(self):
        from shapely.geometry import box
        qualifier=getattr(module,"apply_regional_qualifications",None)
        self.assertTrue(callable(qualifier))
        rows=[{"country":"CZ","admin_level":4,"name":"Praha","kind":"region","original_source_id":"435514","geometry":box(0,0,1,1)},
            {"country":"CZ","admin_level":5,"name":"obvod Praha 1","kind":"district","original_source_id":"17444551","geometry":box(0,0,.1,1)}]
        proofs={"435514":{"tags":{"name":"Praha","boundary":"administrative","admin_level":"4","official_status":"cz:hlavní město","border_type":"city"},"government_evidence_url":"https://apl2.czso.cz/iSMS/cisinfo.jsp?kodcis=69"},
            "17444551":{"tags":{"name":"obvod Praha 1","boundary":"administrative","admin_level":"5","official_status":"cz:obvod","border_type":"district"}}}
        qualifier(rows,proofs)
        self.assertEqual(rows[0]["local_government_role"],"municipality")
        self.assertEqual(rows[1]["unit_type"],"Obvod hlavního města")
        self.assertEqual(len(rows),2)

    def test_norwegian_api_municipality_requires_the_independent_ssb_code(self):
        from shapely.geometry import box
        proof={"relation_id":406493,"relation_version":23,"snapshot":"2026-11-08T21:21:00Z",
            "source_url":"https://api.openstreetmap.org/api/0.6/relation/406493/full.json","source_sha256":"a"*64,
            "validation":{"ssb2026_municipality_code":"5025","ssb2026_primary_url":"https://data.ssb.no/api/klass/v1/versions/3262"}}
        relation={"type":"relation","id":406493,"version":23,"timestamp":"2026-02-09T16:35:56Z",
            "tags":{"name":"Røros","boundary":"administrative","admin_level":"7","ref":"5025","place":"municipality"}}
        row=module.regional_api_row("NO",box(0,0,1,1),proof,relation,level=7)
        self.assertEqual((row["kind"],row["unit_type"],row["official_municipality_id"]),("municipality","Kommune","5025"))
        relation["tags"]["ref"]="9999"
        with self.assertRaisesRegex(ValueError,"role"):
            module.regional_api_row("NO",box(0,0,1,1),proof,relation,level=7)

    def test_country_replacement_requires_the_complete_positive_name_identity_audit(self):
        qualifier=getattr(module,"verified_country_replacement",None)
        self.assertTrue(callable(qualifier))
        rows=[{"original_source_id":str(i),"name":f"Unit{i}","kind":"municipality"} for i in range(78)]
        audit={"official_count":78,"matched_count":78,"missing":[],"extra":[],
            "matches":[{"original_source_id":r["original_source_id"],"osm_name":r["name"]} for r in rows]}
        self.assertEqual(qualifier(rows,audit)["replacement_scope"],"country")
        audit["matches"][0]["original_source_id"]="foreign-id"
        with self.assertRaisesRegex(ValueError,"audit"):
            qualifier(rows,audit)

    def test_remaining_country_roles_never_promote_nahiya_sector_or_cadastre_to_municipality(self):
        for country,level,kind in [('LB',7,'municipality'),('BY',8,'municipality'),('KZ',8,'municipality'),
                ('AZ',8,'municipality'),('IL',8,'municipality'),('IQ',7,'local_admin'),('SY',6,'local_admin'),
                ('TN',6,'local_admin'),('JO',4,'region'),('LY',4,'region')]:
            with self.subTest(country=country):
                self.assertEqual(module.classify_role(country,self.props(level))[0],kind)
        for country,level in [('LB',8),('BY',10),('TN',8),('JO',6),('LY',6),('AZ',6)]:
            with self.subTest(rejected=(country,level)):
                self.assertIsNone(module.classify_role(country,self.props(level)))
        self.assertEqual(module.classify_role('LB',self.props(5))[1],'Qadaa')

    def test_czech_api_municipality_requires_matching_official_district_and_civil_code(self):
        from shapely.geometry import box
        proof={"relation_id":439527,"relation_version":23,"snapshot":"2026-11-08T21:21:00Z","source_url":"https://example.test/439527","source_sha256":"a"*64,
            "municipality_code":"545538","district_code":"CZ0421","validation":{"ref_matches_official_CISOB_and_OKRES":True}}
        relation={"type":"relation","id":439527,"version":23,"timestamp":"2026-05-29T19:40:58Z",
            "tags":{"name":"Starý Šachov","boundary":"administrative","admin_level":"8","ref":"CZ0421545538","border_type":"municipality"}}
        row=module.regional_api_row('CZ',box(0,0,1,1),proof,relation,level=8)
        self.assertEqual(row['official_municipality_id'],'545538')
        relation['tags']['ref']='CZ9999545538'
        with self.assertRaisesRegex(ValueError,'role'):
            module.regional_api_row('CZ',box(0,0,1,1),proof,relation,level=8)

    def test_terminal_sark_alderney_keep_their_regions_and_never_duplicate_guernsey_parishes(self):
        from shapely.geometry import box
        annotate=getattr(module,'annotate_guernsey_terminal_roles',None)
        self.assertTrue(callable(annotate))
        rows=[{'id':f'geofabrik:GG:4:{identifier}','country':'GG','kind':'region','admin_level':4,'unit_type':'Jurisdiction','name':name,'geometry':box(index,0,index+1,1)}
            for index,(identifier,name) in enumerate([('1711291','Guernsey'),('1973199','Sark'),('1973200','Alderney')])]
        before=[(r['id'],r['name'],r['kind'],r['unit_type'],r['geometry'].wkb) for r in rows]
        annotate(rows)
        self.assertEqual(before,[(r['id'],r['name'],r['kind'],r['unit_type'],r['geometry'].wkb) for r in rows])
        self.assertNotIn('local_government_role',rows[0])
        self.assertEqual([r['local_government_role'] for r in rows[1:]],['local_admin','local_admin'])
        self.assertEqual(rows[1]['local_government_role_evidence'],'https://sarkgov.co.uk/living-on-sark')
        self.assertEqual(rows[2]['local_government_role_evidence'],'https://www.alderneyelections.gg/how-government-works/structure/')
        rows[1]['name']='Guernsey'
        with self.assertRaisesRegex(ValueError,'identity'):
            annotate(rows)

    def test_metropolitan_province_role_requires_exact_approved_iso_identity(self):
        from shapely.geometry import box
        annotate=getattr(module,'annotate_turkish_metropolitan_roles',None)
        self.assertTrue(callable(annotate))
        rows=[{'id':'geofabrik:TR:4:223422','country':'TR','kind':'region','admin_level':4,'unit_type':'İl','name':'Ankara','original_source_id':'223422','geometry':box(0,0,1,1)},
            {'id':'geofabrik:TR:4:154449','country':'TR','kind':'region','admin_level':4,'unit_type':'İl','name':'Nevşehir','original_source_id':'154449','geometry':box(2,0,3,1)}]
        proof={'matches':[{'id':rows[0]['id'],'original_source_id':'223422','name':'Ankara','iso_3166_2':'TR-06','authority_name':'Ankara Büyükşehir Belediyesi'}],
            'law_evidence_url':'https://official.example/law','identity_evidence_url':'https://official.example/authorities'}
        annotate(rows,proof)
        self.assertEqual(rows[0]['local_government_role'],'municipality')
        self.assertEqual(rows[0]['kind'],'region')
        self.assertNotIn('local_government_role',rows[1])
        proof['matches'][0]['name']='Başka'
        with self.assertRaisesRegex(ValueError,'identity'):
            annotate(rows,proof)

    def test_former_metropolitan_belde_is_quarantined_without_type_or_geometry_relabeling(self):
        from shapely.geometry import box
        quarantine=getattr(module,'quarantine_turkish_former_beldes',None)
        self.assertTrue(callable(quarantine))
        parent={'id':'province','country':'TR','name':'Ankara','kind':'region','admin_level':4,'geometry':box(0,0,3,3),'local_government_role':'municipality'}
        child={'id':'belde','country':'TR','name':'Hasanoğlan','kind':'municipality','admin_level':7,'unit_type':'Belde','geometry':box(1,1,2,2)}
        before=child['geometry'].wkb
        proof={'matches':[{'id':'belde','name':'Hasanoğlan','metropolitan_parent':'province','province_name':'Ankara','province_iso_3166_2':'TR-06'}],
            'law_evidence_url':'https://official.example/6360','act_number':'6360','article':'1(3)','act_adopted_date':'2012-11-12','review_date':'2026-11-09'}
        quarantine([parent,child],proof)
        self.assertIs(child['administrative_geometry_eligible'],False)
        self.assertEqual((child['kind'],child['unit_type'],child['geometry'].wkb),('municipality','Belde',before))
        self.assertEqual(child['administrative_ineligibility_metropolitan_parent_id'],'province')
        self.assertNotIn('administrative_geometry_eligible',parent)
        proof['matches'][0]['name']='Fremder Ort'
        with self.assertRaisesRegex(ValueError,'identity'):
            quarantine([parent,child],proof)

    def test_azerbaijan_preparation_cannot_reactivate_obsolete_unqualified_r3_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache=Path(temporary)
            stage=cache/'stage';stage.mkdir()
            data=stage/'immutable.bin';data.write_bytes(b'verified source bytes')
            for revision,identifier in [('r3','unqualified-old'),('r4-role-review','quarantined-reviewed')]:
                receipt={'sources':[{'id':identifier,'cache_file':'stage/immutable.bin','sha256':module.core.digest(data.read_bytes())}]}
                (stage/f'normalized-AZ-v4-{revision}.receipt.json').write_text(json.dumps(receipt),encoding='utf-8')
            prepared=module.prepare_country(cache,'AZ',stage)
            self.assertEqual(prepared['sources'][0]['id'],'quarantined-reviewed')

    def test_lebanon_preparation_cannot_reactivate_twelve_false_beirut_municipalities(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache=Path(temporary)
            stage=cache/'stage';stage.mkdir()
            data=stage/'immutable.bin';data.write_bytes(b'verified source bytes')
            for revision,identifier in [('r3','unqualified-old'),('r4-beirut-role-review','one-beirut-municipality')]:
                receipt={'sources':[{'id':identifier,'cache_file':'stage/immutable.bin','sha256':module.core.digest(data.read_bytes())}]}
                (stage/f'normalized-LB-v4-{revision}.receipt.json').write_text(json.dumps(receipt),encoding='utf-8')
            prepared=module.prepare_country(cache,'LB',stage)
            self.assertEqual(prepared['sources'][0]['id'],'one-beirut-municipality')

    def test_kazakhstan_preparation_retains_reviewed_city_administration_roles(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache=Path(temporary)
            stage=cache/'stage';stage.mkdir()
            data=stage/'immutable.bin';data.write_bytes(b'verified source bytes')
            for revision,identifier in [('r3','generic-audans'),('r4-city-administrations','qualified-city-administrations')]:
                receipt={'sources':[{'id':identifier,'cache_file':'stage/immutable.bin','sha256':module.core.digest(data.read_bytes())}]}
                (stage/f'normalized-KZ-v4-{revision}.receipt.json').write_text(json.dumps(receipt),encoding='utf-8')
            prepared=module.prepare_country(cache,'KZ',stage)
            self.assertEqual(prepared['sources'][0]['id'],'qualified-city-administrations')
