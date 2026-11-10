"""Positive northern municipal identities and immutable source contracts."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

from shapely.geometry import Polygon, box

if importlib.util.find_spec('atlas_north_cyprus_sources'):
    import atlas_north_cyprus_sources as source
else:
    source = None


class NorthCyprusTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(source, 'The northern municipality provider is missing')
        self.properties = {'osm_id':'16264705', 'code':1207,
                           'fclass':'admin_level7', 'name':'Lefke Belediyesi'}
        self.relation = {'type':'relation', 'id':16264705, 'version':5,
                         'timestamp':'2026-05-27T14:51:23Z',
                         'tags':{'boundary':'administrative', 'admin_level':'7',
                                 'name':'Lefke Belediyesi', 'type':'boundary'}}
        self.legal = {'schedule_number':6, 'legal_name':'LEFKE BELEDİYESİ',
                      'villages':['Lefke', 'Erenköy'], 'count':2}

    def test_positive_identity_preserves_original_polygon_hole_and_native_role(self):
        polygon=Polygon([(32,35),(33,35),(33,36),(32,36)],
                        holes=[[(32.2,35.2),(32.4,35.2),(32.4,35.4),(32.2,35.4)]])
        row=source.qualify_municipality(self.properties, polygon, self.relation, self.legal)
        self.assertIs(row['geometry'],polygon)
        self.assertEqual(len(row['geometry'].interiors),1)
        self.assertEqual(row['country'],'CYN')
        self.assertEqual(row['kind'],'municipality')
        self.assertEqual(row['unit_type'],'Belediye')
        self.assertEqual(row['osm_version'],5)
        self.assertEqual(row['legal_settlements'],['Lefke','Erenköy'])
        self.assertFalse(row['geometry_modified_by_importer'])

    def test_level_seven_without_positive_identity_is_rejected(self):
        self.properties.update(osm_id='99999',name='Invented Belediyesi')
        self.relation.update(id=99999)
        self.relation['tags']['name']='Invented Belediyesi'
        with self.assertRaises(ValueError):
            source.qualify_municipality(self.properties,box(32,35,33,36),self.relation,self.legal)

    def test_rep_cy_claim_name_or_wrong_legal_schedule_is_rejected(self):
        self.legal['legal_name']='LEFKOŞA TÜRK BELEDİYESİ'
        with self.assertRaises(ValueError):
            source.qualify_municipality(self.properties,box(32,35,33,36),self.relation,self.legal)

    def test_original_tags_and_snapshot_version_are_checked(self):
        for mutate in ('name','admin_level','future','version'):
            relation=copy.deepcopy(self.relation)
            if mutate=='name':relation['tags']['name']='Lefke District'
            elif mutate=='admin_level':relation['tags']['admin_level']='6'
            elif mutate=='future':relation['timestamp']='2026-11-09T00:00:00Z'
            else:relation['version']=6
            with self.subTest(mutate=mutate),self.assertRaises(ValueError):
                source.qualify_municipality(self.properties,box(32,35,33,36),relation,self.legal)

    def test_invalid_original_geometry_is_never_repaired(self):
        invalid=Polygon([(32,35),(33,36),(33,35),(32,36),(32,35)])
        with self.assertRaises(ValueError):
            source.qualify_municipality(self.properties,invalid,self.relation,self.legal)

    def test_schedule_parser_keeps_page_break_and_settlement_count(self):
        text='BELEDİYELER VE BELEDİYELERE BAĞLI YERLEŞİM YERLERİ\n6- LEFKE BELEDİYESİ:\nLefke, Erenköy (2 köy)\n7- DEĞİRMENLİK - AKINCILAR BELEDİYESİ:\n14\nMerkezi Mevzuat Dairesi\nhttps://mevzuat.gov.ct.tr/\nTel: 227 17 01\nDeğirmenlik, Akıncılar (2 köy)'
        schedules=source.parse_schedule_text(text)
        self.assertEqual(schedules[6]['villages'],['Lefke','Erenköy'])
        self.assertEqual(schedules[7]['count'],2)
        with self.assertRaises(ValueError):source.parse_schedule_text(text.replace('(2 köy)','(3 köy)',1))

    def test_settlement_audit_does_not_invent_an_alias_or_a_missing_polygon(self):
        rows=[({'osm_id':'1','name':'Lefke','fclass':'admin_level8'},box(32,35,32.1,35.1)),
              ({'osm_id':'2','name':'Margo','fclass':'admin_level8'},box(32.2,35.2,32.3,35.3))]
        legal={'villages':['Lefke','Dereliköy']}
        audit=source.settlement_audit(legal,box(32,35,33,36),rows)
        self.assertEqual(audit['unmatched_legal_names'],['Dereliköy'])
        self.assertEqual(audit['exact_match_count'],1)
        self.assertEqual(audit['additional_spatial_names'][0]['name'],'Margo')

    def test_changed_or_escaping_cache_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);p=root/'original';p.write_bytes(b'original')
            pin={'cache_file':'original','bytes':8,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
            source.verified_file(root,pin)
            p.write_bytes(b'modified')
            with self.assertRaises(ValueError):source.verified_file(root,pin)
            pin['cache_file']='../original'
            with self.assertRaises(ValueError):source.verified_file(root,pin)

    def test_selective_reproducer_uses_fetch_and_checks_original_member_bytes(self):
        payload=b'original member';stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('gis_osm_adminareas_a_free_1.shp',payload)
        raw=stream.getvalue();calls=[]
        remote=SimpleNamespace(snapshot={'bytes':len(raw),'etag':source.ARCHIVE_ETAG},
                               fetch=lambda first,last:(calls.append((first,last)) or raw[first:last+1]))
        pin={'cache_file':'selected/original.shp','archive_member':'gis_osm_adminareas_a_free_1.shp',
             'url':source.ARCHIVE,'bytes':len(payload),'sha256':hashlib.sha256(payload).hexdigest()}
        with tempfile.TemporaryDirectory() as temporary,patch.object(source,'PINNED_INPUTS',[pin]), \
                patch.object(source,'ARCHIVE_BYTES',len(raw)),patch.object(source,'RangeSource',return_value=remote):
            root=Path(temporary);source._download_missing(root)
            self.assertEqual(source.verified_file(root,pin).read_bytes(),payload)
            self.assertTrue(calls)
            with patch.object(source,'RangeSource',side_effect=AssertionError('Unexpected network')):
                source._download_missing(root)

    def test_published_scope_never_transfers_northern_powers_to_buffer_or_bases(self):
        path=Path(__file__).resolve().parents[1]/'data/atlas_north_cyprus_sources.json'
        manifest=json.loads(path.read_text(encoding='utf-8'))
        row=manifest['sources'][0]
        self.assertEqual(row['scope_countries'],['CYN'])
        self.assertIs(row['clip_to_scope'],True)
        self.assertIn('not certified state boundary',row['scope_clip_basis'])
        self.assertEqual(row['object_count'],18)
        self.assertEqual(row['settlement_qualification']['unmatched_name_count'],4)
        self.assertEqual(row['license'],'ODbL-1.0')


if __name__=='__main__':
    unittest.main(verbosity=2)
