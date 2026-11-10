import importlib
import importlib.util
import json
from pathlib import Path
import unittest
from shapely.geometry import Polygon


def box(a=45,b=35,c=46,d=36):return Polygon([(a,b),(c,b),(c,d),(a,d),(a,b)])


class IranCurrentSourceTests(unittest.TestCase):
    def module(self):
        self.assertIsNotNone(importlib.util.find_spec('atlas_iran_sources'),'Current typed Iran provider is absent')
        return importlib.import_module('atlas_iran_sources')

    def test_only_formal_explicit_dehestan_is_a_local_administrative_candidate(self):
        m=self.module()
        self.assertEqual(m.candidate_role({'fclass':'admin_level7','code':1207,'name':'دهستان نمونه'}),('local_admin','Dehestan / دهستان'))
        for row in [{'fclass':'admin_level7','code':1207,'name':'شهر نمونه'},
                    {'fclass':'admin_level7','code':1207,'name':'شهرک نمونه'},
                    {'fclass':'admin_level7','code':1207,'name':'Unknown'},
                    {'fclass':'admin_level11','code':1211,'name':'دهستان نمونه'},
                    {'fclass':'admin_level7','code':999,'name':'دهستان نمونه'}]:
            self.assertIsNone(m.candidate_role(row))

    def region(self):
        return {'properties':{'osm_id':'42','fclass':'admin_level4','code':1204,'name':'استان نمونه'},'geometry':box()}

    def metadata(self):
        return {'elements':[{'type':'relation','id':42,'version':3,'timestamp':'2026-01-01T00:00:00Z',
                'tags':{'boundary':'administrative','admin_level':'4','name':'استان نمونه','ISO3166-2':'IR-01'}}]}

    def test_province_scope_requires_matching_native_iso_name_and_snapshot(self):
        m=self.module();scope,proof=m.verified_scope([self.region()],self.metadata())
        self.assertTrue(scope.equals(box()));self.assertEqual(proof[0]['iso3166_2'],'IR-01')

    def test_foreign_or_future_province_is_not_accepted(self):
        m=self.module()
        for key,value in [('timestamp','2026-11-09T00:00:00Z')]:
            meta=self.metadata();meta['elements'][0][key]=value
            with self.assertRaises(ValueError):m.verified_scope([self.region()],meta)
        meta=self.metadata();meta['elements'][0]['tags']['ISO3166-2']='IQ-01'
        with self.assertRaises(ValueError):m.verified_scope([self.region()],meta)

    def test_typed_area_inside_verified_province_preserves_coordinates(self):
        m=self.module();g=box(45.1,35.1,45.2,35.2)
        row=m.normalize_candidate({'osm_id':'99','fclass':'admin_level7','code':1207,'name':'دهستان نمونه'},g,box())
        self.assertEqual(row['kind'],'local_admin');self.assertEqual(row['country'],'IR')
        self.assertTrue(row['geometry'].equals_exact(g,0));self.assertEqual(row['original_source_id'],'99')
        self.assertEqual(row['parent_id'],'country:IR')

    def test_area_outside_verified_scope_is_not_assigned_iran_by_archive_name(self):
        m=self.module()
        row=m.normalize_candidate({'osm_id':'99','fclass':'admin_level7','code':1207,'name':'دهستان نمونه'},box(47,35,48,36),box())
        self.assertIsNone(row)

    def test_place_names_do_not_override_missing_positive_native_type(self):
        m=self.module()
        self.assertIsNone(m.normalize_candidate({'osm_id':'99','fclass':'admin_level7','code':1207,'name':'Tehran'},box(),box()))

    def test_real_prepared_inventory_has_only_typed_unmodified_administrative_areas(self):
        m=self.module();root=Path(__file__).resolve().parents[1]
        manifest=root/'data/atlas_iran_sources.json'
        if not manifest.exists():
            self.skipTest('Prepared real Iranian source cache is not present in this checkout')
        sources=json.loads(manifest.read_text(encoding='utf8'))['sources']
        source=sources[0]
        self.assertEqual(source['raw_positive_type_count'],2731)
        self.assertEqual(source['expected_unit_count'],2679)
        self.assertEqual(source['kind'],'local_admin')
        self.assertFalse(source['blocks_full_coverage_claim'])
        rows=list(m.iter_boundaries(root/'.tools/atlas_sources',sources))
        self.assertEqual(len(rows),2679)
        self.assertEqual(len({r['id'] for r in rows}),2679)
        self.assertTrue(all(r['geometry'].is_valid and not r['geometry'].is_empty for r in rows))
        self.assertTrue(all(r['name'].startswith('دهستان ') and r['admin_level']==7 for r in rows))
        self.assertTrue(all(r['country_assignment_fraction']>=.999 for r in rows))
        self.assertTrue(all(r['parent_id']=='country:IR' for r in rows))

    def test_bbox_specific_coverage_metadata_preserves_national_limits(self):
        m=self.module();root=Path(__file__).resolve().parents[1]
        source=json.loads((root/'data/atlas_iran_sources.json').read_text(encoding='utf8'))['sources'][0]
        self.assertFalse(source['blocks_full_coverage_claim'])
        self.assertIn('97,597428',source['coverage_note'])
        self.assertIn('2,402572',source['coverage_note'])
        self.assertIn('2.679',source['coverage_note'])
        self.assertIn('52',source['territorial_scope_note'])
        self.assertIn('33',source['territorial_scope_note'])
        self.assertIn('keine',source['coverage_note'].lower())
        cached=m.prepare_sources(root/'.tools/atlas_sources')[0]
        self.assertEqual(cached['coverage_note'],source['coverage_note'])
        self.assertEqual(cached['territorial_scope_note'],source['territorial_scope_note'])

    def test_bbox_qualification_never_applies_to_a_changed_normalized_population(self):
        m=self.module();root=Path(__file__).resolve().parents[1]
        source=json.loads((root/'data/atlas_iran_sources.json').read_text(encoding='utf8'))['sources'][0]
        self.assertTrue(hasattr(m,'qualify_coverage_metadata'))
        with self.assertRaises(ValueError):m.qualify_coverage_metadata({**source,'sha256':'0'*64})


if __name__=='__main__':unittest.main()
