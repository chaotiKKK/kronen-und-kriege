"""Current Cyprus identities, actual component geometry and territorial roles."""
import importlib.util
import hashlib
import json
from pathlib import Path
import io
import tempfile
import zipfile
import unittest

from shapely.geometry import Polygon, box

SPEC = importlib.util.find_spec('atlas_cyprus_sources')
if SPEC:
    import atlas_cyprus_sources as source
else:
    source = None


class CyprusSourceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(source, 'The qualified Cyprus provider is not implemented')

    def test_municipal_quarter_is_not_promoted_to_independent_municipality(self):
        record = {'code':'41054215','role':'MUNICIPAL QUARTER','name':'Kornos',
                  'previous_code':'4215','territorial_note':''}
        row = source.qualify_unit(record, box(33,34,34,35))
        self.assertEqual(row['kind'],'local_admin')
        self.assertEqual(row['parent_id'],'dls:CY:municipality:41050000')
        self.assertEqual(row['previous_geographical_code'],'4215')
        self.assertNotIn('local_government_role',row)

    def test_territorial_community_does_not_claim_an_independent_elected_council(self):
        record={'code':'52005368','role':'COMMUNITY','name':'Chandria','previous_code':'5368'}
        row=source.qualify_unit(record,box(33,34,34,35))
        self.assertEqual(row['kind'],'local_admin')
        self.assertIn('Not inferred',row['independent_council_status'])

    def test_reform_unites_only_actual_components_and_preserves_a_hole(self):
        record={'code':'41050000','role':'MUNICIPALITY','name':'Lefkara','previous_code':'n.a.'}
        hole=Polygon([(33,34),(34,34),(34,35),(33,35)],holes=[[(33.2,34.2),(33.4,34.2),(33.4,34.4),(33.2,34.4)]])
        parts=[{'previous_code':'4215','geometry':hole},{'previous_code':'4216','geometry':box(34,34,35,35)}]
        index={'OBJECTID':40,'NAME_GR':'Δήμος Λευκάρων','NAME_ENG':'Dimos Lefkaron'}
        row=source.assemble_municipality(record,parts,index)
        self.assertEqual(row['kind'],'municipality')
        self.assertAlmostEqual(row['geometry'].area,1.96)
        self.assertEqual(row['source_part_ids'],['dls:CY:old:4215','dls:CY:old:4216'])

    def test_service_complex_or_northern_claim_cannot_become_current_municipality(self):
        record={'code':'41050000','role':'MUNICIPALITY','name':'Lefkara','previous_code':'n.a.'}
        part=[{'previous_code':'4215','geometry':box(33,34,34,35)}]
        with self.assertRaises(ValueError):
            source.assemble_municipality(record,part,{'OBJECTID':12,'NAME_ENG':'Oreini Larnaka'})
        record['code']='21012000'
        with self.assertRaises(ValueError):
            source.assemble_municipality(record,part,{'OBJECTID':40,'NAME_ENG':'Dimos Lefkaron'})

    def test_xlsx_uses_current_eight_digit_codes_and_keeps_previous_code(self):
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w') as z:
            z.writestr('xl/workbook.xml','<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="GEOCODES_8 digits_All Districts" r:id="rId1"/></sheets></workbook>')
            z.writestr('xl/_rels/workbook.xml.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>')
            z.writestr('xl/worksheets/sheet1.xml','<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="2"><c r="A2"><v>41054215</v></c><c r="B2" t="inlineStr"><is><t>MUNICIPAL QUARTER</t></is></c><c r="C2" t="inlineStr"><is><t>Kornos</t></is></c><c r="D2"><v>4215</v></c></row></sheetData></worksheet>')
        rows=source.read_geocodes(stream.getvalue())
        self.assertEqual([(r['code'],r['role'],r['name'],r['previous_code']) for r in rows],
                         [('41054215','MUNICIPAL QUARTER','Kornos','4215')])

    def test_missing_official_geometry_component_is_an_error(self):
        municipality={'code':'41050000','role':'MUNICIPALITY','name':'Lefkara','previous_code':'n.a.'}
        quarter={'code':'41054215','role':'MUNICIPAL QUARTER','name':'Kornos','previous_code':'4215'}
        with self.assertRaisesRegex(ValueError,'4215'):
            source.components_for(municipality,[municipality,quarter],{})

    def test_published_review_blocks_only_unresolved_buffer_zone_scope(self):
        manifest=json.loads((Path(__file__).resolve().parents[1]/'data/atlas_cyprus_sources.json').read_text(encoding='utf-8'))
        entry=manifest['sources'][0]
        self.assertIs(entry['blocks_full_coverage_claim'],False)
        self.assertEqual(entry['blocks_full_coverage_claim_countries'],['CNM'])
        self.assertEqual(set(entry['scope_countries']),{'CY','CNM','ESB','WSB'})

    def test_changed_or_escaping_source_cache_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);path=root/'original.json';path.write_bytes(b'{"id":1}')
            receipt={'cache_file':'original.json','bytes':8,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
            source.verified_file(root,receipt)
            path.write_bytes(b'{"id":2}')
            with self.assertRaises(ValueError):source.verified_file(root,receipt)
            receipt['cache_file']='../outside.json'
            with self.assertRaises(ValueError):source.verified_file(root,receipt)

    def test_sba_overlap_is_local_territory_and_preserves_original_geometry(self):
        record={'code':'31063202','role':'MUNICIPALITY','name':'Lysi',
                'previous_code':'3202','territorial_note':'Partly occupied'}
        geometry=Polygon([(33,34),(34,34),(34,35),(33,35)],
                         holes=[[(33.2,34.2),(33.4,34.2),(33.4,34.4),(33.2,34.4)]])
        original={'geometry':geometry,'properties':{'DIST_CODE':3,'VIL_CODE':202,'VIL_NM_G':'Λύση'}}
        row=source.qualify_sba_overlap(record,original)
        self.assertEqual((row['country'],row['kind'],row['parent_id']),('ESB','local_admin','country:ESB'))
        self.assertEqual(row['source_country'],'CY')
        self.assertEqual(row['geographical_code'],'31063202')
        self.assertEqual(row['previous_geographical_code'],'3202')
        self.assertEqual(row['source_role'],'MUNICIPALITY')
        self.assertIs(row['geometry'],geometry)
        self.assertFalse(row['geometry_modified_by_importer'])
        self.assertNotIn('local_government_role',row)

    def test_sba_role_requires_exact_positive_identity_and_original_code(self):
        record={'code':'31033000','role':'MUNICIPALITY','name':'Ammochostos','previous_code':'3000'}
        original={'geometry':box(33,34,34,35),'properties':{'DIST_CODE':3,'VIL_CODE':0,'VIL_NM_G':'Αμμόχωστος'}}
        source.qualify_sba_overlap(record,original)
        for key,value in [('code','31010000'),('role','COMMUNITY'),('name','Unknown'),('previous_code','3999')]:
            with self.subTest(key=key),self.assertRaises(ValueError):
                source.qualify_sba_overlap({**record,key:value},original)
        with self.assertRaises(ValueError):
            source.qualify_sba_overlap(record,{**original,'properties':{'DIST_CODE':3,'VIL_CODE':202}})

    def test_sba_invalid_original_is_not_repaired(self):
        record={'code':'31033000','role':'MUNICIPALITY','name':'Ammochostos','previous_code':'3000'}
        original={'geometry':Polygon([(0,0),(2,2),(0,2),(2,0),(0,0)]),
                  'properties':{'DIST_CODE':3,'VIL_CODE':0}}
        with self.assertRaises(ValueError):source.qualify_sba_overlap(record,original)

    def test_sba_source_scope_clips_only_esb_without_importing_cyn(self):
        from atlas_administration import _territory_rows
        record={'code':'31033000','role':'MUNICIPALITY','name':'Ammochostos','previous_code':'3000'}
        geometry=box(0,0,3,1)
        row=source.qualify_sba_overlap(record,{'geometry':geometry,'properties':{'DIST_CODE':3,'VIL_CODE':0}})
        entry=source._sba_source_record([row])
        self.assertEqual(entry['scope_countries'],['ESB'])
        self.assertIs(entry['clip_to_scope'],True)
        self.assertNotEqual(entry.get('replacement_scope'),'country')
        parts=list(_territory_rows([row],{entry['id']:entry},
                   {'ESB':box(0,0,1,1),'CYN':box(1,0,2,1),'CY':box(2,0,3,1)}))
        self.assertEqual(len(parts),1)
        self.assertEqual(parts[0]['country'],'ESB')
        self.assertTrue(parts[0]['geometry'].equals(box(0,0,1,1)))
        self.assertEqual(parts[0]['parent_id'],'country:ESB')
        self.assertIs(parts[0]['source_geometry_clipped_to_scope'],True)
        self.assertTrue(row['geometry'].equals(geometry))

    def test_sba_german_source_notice_states_concrete_legal_limits(self):
        entry=source._sba_source_record([])
        text=entry['territorial_scope_note']
        for phrase in ['ESB','§§ 2, 6, 42, 43 und 155','§§ 160–161','Crown','Militär','keine']:
            self.assertIn(phrase,text)
        self.assertIn(source.SBA_MUNICIPALITIES,entry['role_evidence_urls'])
        self.assertEqual(entry['kind'],'local_admin')

    def test_published_sba_source_is_separate_and_keeps_existing_cy_roles(self):
        manifest=json.loads((Path(__file__).resolve().parents[1]/'data/atlas_cyprus_sources.json').read_text(encoding='utf-8'))
        self.assertEqual(len(manifest['sources']),2)
        current,overlap=manifest['sources']
        self.assertEqual(current['role_counts'],{'municipality':20,'local_admin':602})
        self.assertEqual(current['blocks_full_coverage_claim_countries'],['CNM'])
        self.assertEqual(overlap['scope_countries'],['ESB'])
        self.assertEqual(overlap['role_counts'],{'local_admin':2})
        self.assertEqual(overlap['municipal_authorities_created'],0)

    def test_existing_cy_source_notice_is_german_and_does_not_publish_stale_esb_coverage(self):
        entry=source._source_record([])
        self.assertIn('UN-Puffer',entry['territorial_scope_note'])
        self.assertIn('keine',entry['territorial_scope_note'])
        self.assertIn('CYN',entry['territorial_scope_note'])
        self.assertNotIn('Original DLS local territories',entry['territorial_scope_note'])
        self.assertIn('Originaldatenvergleich',entry['coverage_note'])
        self.assertNotIn('94.5011',entry['coverage_note'])
        self.assertNotIn('94.5011',entry['unit_semantics']['coverage_status'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
