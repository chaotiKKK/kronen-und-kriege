"""Behavioral tests for current Armenian roles and original source geometry."""
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from shapely.geometry import Polygon, box, mapping

SPEC = importlib.util.find_spec('atlas_armenia_sources')
if SPEC:
    import atlas_armenia_sources as provider
else:
    provider = None


def member_payload():
    stamp='2026-11-06T14:28:51Z'
    nodes=[{'type':'node','id':i+1,'version':1,'timestamp':stamp,'lon':x,'lat':y}
           for i,(x,y) in enumerate([(45,40),(46,40),(46,41),(45,41),(45.2,40.2),(45.4,40.2),(45.4,40.4),(45.2,40.4)])]
    return {'elements':nodes+[
        {'type':'way','id':1,'version':2,'timestamp':stamp,'nodes':[1,2,3,4,1]},
        {'type':'way','id':2,'version':2,'timestamp':stamp,'nodes':[5,6,7,8,5]},
        {'type':'relation','id':10853047,'version':34,'timestamp':stamp,
         'tags':{'name':'Ճամբարակ համայնք','boundary':'administrative','admin_level':'5','type':'boundary'},
         'members':[{'type':'way','ref':1,'role':'outer'},{'type':'way','ref':2,'role':'inner'}]}]}


def local_row(identifier,name,geometry):
    return {'id':str(identifier),'osm_relation_id':identifier,'name':name,'kind':'municipality',
            'geometry':geometry,'osm_relation_version':2,'source_timestamp':'2026-11-01T00:00:00Z'}


class ArmeniaSourceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(provider,'The authorized Armenian provider has not been implemented yet')

    def test_reviewed_identity_sources_use_the_conservative_physical_land_reassessment(self):
        manifest=json.loads((Path(__file__).resolve().parents[1]/'data/atlas_armenia_sources.json').read_text(encoding='utf-8'))
        self.assertEqual(sum(s['municipal_authorities'] for s in manifest['sources']),62)
        for entry in manifest['sources']:
            self.assertIs(entry['blocks_full_coverage_claim'],False)
            assessment=entry['coverage_reassessment']
            self.assertEqual(assessment['land_reference_source_id'],'ne-physical-water-AM-20261108')
            self.assertFalse(assessment['national_territorial_baseline_changed'])
            self.assertAlmostEqual(assessment['fraction'],0.97340036,places=8)

    def test_law_parser_reads_municipal_column_instead_of_settlement_names(self):
        document='<TABLE><TR><TD>Համայնքի անվանումը</TD><TD>Բնակավայրի անվանումը</TD></TR><TR><TD>1. Արարատ</TD><TD>Վեդի քաղաք</TD></TR><TR><TD></TD><TD>Ավշար գյուղ</TD></TR></TABLE>'
        self.assertEqual([r['name'] for r in provider.parse_official_communities(document)],['Արարատ','Երևան'])

    def test_level_five_yerevan_district_is_not_a_municipality(self):
        properties={'osm_id':'13404250','code':1205,'fclass':'admin_level5','name':'Ավան'}
        relation={'id':13404250,'version':2,'timestamp':'2026-01-01T00:00:00Z','tags':{'name':'Ավան','name:en':'Avan','boundary':'administrative','admin_level':'5'}}
        self.assertEqual(provider.qualify_record(properties,relation,{'Ավան'}, {'Avan'}),('local_admin','Ավան'))

    def test_current_community_matches_positive_legal_identity(self):
        p={'osm_id':'10852605','code':1205,'fclass':'admin_level5','name':'Արարատ համայնք'}
        r={'id':10852605,'version':2,'timestamp':'2026-01-01T00:00:00Z','tags':{'name':p['name'],'boundary':'administrative','admin_level':'5'}}
        self.assertEqual(provider.qualify_record(p,r,{'Արարատ'},set()),('municipality','Արարատ'))

    def test_arbitrary_level_five_name_is_not_admitted_as_a_community(self):
        p={'osm_id':'99999','code':1205,'fclass':'admin_level5','name':'Unknown համայնք'}
        r={'id':99999,'version':1,'timestamp':'2026-01-01T00:00:00Z','tags':{'name':p['name'],'boundary':'administrative','admin_level':'5'}}
        with self.assertRaises(ValueError):provider.qualify_record(p,r,{'Արարատ'},set())

    def test_source_country_and_level_contradictions_are_rejected(self):
        p={'osm_id':'10852605','code':1205,'fclass':'admin_level5','name':'Արարատ համայնք'}
        r={'id':10852605,'version':2,'timestamp':'2026-01-01T00:00:00Z','tags':{'name':p['name'],'boundary':'administrative','admin_level':'5','is_in:country_code':'AZ'}}
        with self.assertRaises(ValueError):provider.qualify_record(p,r,{'Արարատ'},set())
        r['tags'].pop('is_in:country_code');r['tags']['admin_level']='6'
        with self.assertRaises(ValueError):provider.qualify_record(p,r,{'Արարատ'},set())

    def test_legal_merger_unites_original_components_and_retains_source_ids(self):
        a=local_row(10852605,'Արարատ',box(44,39,45,40))
        b=local_row(10852606,'Վեդի',box(45,39,46,40))
        rows=provider.merge_current_geometries([a,b])
        self.assertEqual(len(rows),1)
        self.assertEqual(rows[0]['name'],'Արարատ')
        self.assertTrue(rows[0]['geometry'].equals(box(44,39,46,40)))
        self.assertEqual(rows[0]['source_part_ids'],['r10852605','r10852606'])
        self.assertEqual(rows[0]['merger_effective_date'],'2026-09-19')
        self.assertTrue(rows[0].get('geometry_modified_by_importer'))

    def test_legal_merger_does_not_fill_real_geometry_holes(self):
        outer=Polygon([(44,39),(45,39),(45,40),(44,40)],holes=[[(44.2,39.2),(44.4,39.2),(44.4,39.4),(44.2,39.4)]])
        rows=provider.merge_current_geometries([local_row(10852605,'Արարատ',outer),local_row(10852606,'Վեդի',box(45,39,46,40))])
        self.assertAlmostEqual(rows[0]['geometry'].area,1.96)

    def test_missing_legal_merger_component_is_not_silently_discarded(self):
        with self.assertRaises(ValueError):provider.merge_current_geometries([local_row(10852605,'Արարատ',box(44,39,45,40))])

    def test_chambarak_api_geometry_preserves_inner_rings(self):
        geometry,relation=provider.api_polygon(member_payload())
        self.assertEqual(relation['id'],10853047)
        self.assertAlmostEqual(geometry.area,.96)
        self.assertEqual(len(geometry.interiors),1)

    def test_api_supplement_refuses_newer_or_missing_actual_members(self):
        payload=member_payload();payload['elements'][0]['timestamp']='2026-11-09T00:00:00Z'
        with self.assertRaises(ValueError):provider.api_polygon(payload)
        payload=member_payload();payload['elements'].pop(0)
        with self.assertRaises(ValueError):provider.api_polygon(payload)

    def test_cache_tamper_is_rejected_even_when_json_still_parses(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'source.json';p.write_bytes(b'{"id":1}')
            receipt={'bytes':8,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
            provider.verify_file(p,receipt)
            p.write_bytes(b'{"id":2}')
            with self.assertRaises(ValueError):provider.verify_file(p,receipt)

    def test_source_cache_path_cannot_leave_declared_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):provider.cache_path(Path(tmp),'../outside.json')

    def test_yerevan_replaces_only_the_same_verified_ne_capital_identity(self):
        r={'id':364087,'version':7,'timestamp':'2026-01-01T00:00:00Z',
           'tags':{'name':'Երևան','admin_level':'4','boundary':'administrative','ISO3166-2':'AM-ER'}}
        row=provider._row(364087,box(44.4,40.1,44.6,40.3),r,'region','Երևան',provider.SOURCE_ID)
        self.assertEqual(row.get('replaces_reference_features'),['region:ARM-1675'])
        self.assertEqual(row.get('replacement_evidence_url'),'https://www.arlis.am/hy/acts/231073')
        self.assertEqual(row.get('source_iso_3166_2'),'AM-ER')
        r['tags']['ISO3166-2']='AM-XX'
        with self.assertRaises(ValueError):
            provider._row(364087,box(44.4,40.1,44.6,40.3),r,'region','Երևան',provider.SOURCE_ID)


if __name__=='__main__':
    unittest.main(verbosity=2)
