import importlib
import importlib.util
import io
import tempfile
import unittest
import zipfile
from pathlib import Path

from shapely.geometry import Polygon


def square():
    return Polygon([(30.1, 40.5), (30.2, 40.5), (30.2, 40.6), (30.1, 40.6), (30.1, 40.5)])


class SakaryaSourceTests(unittest.TestCase):
    def module(self):
        self.assertIsNotNone(importlib.util.find_spec('atlas_sakarya_sources'),
                             'Isolated original Sakarya provider is missing')
        return importlib.import_module('atlas_sakarya_sources')

    def row(self):
        return {'placemark_id': 'ID_001', 'name': 'ÖRNEK', 'geometry': square(),
                'original_properties': {'objectid': '99999', 'ad': 'ÖRNEK', 'ilce': 'Karasu',
                                        'a_tarihi': '15.05.2024'}}

    def parents(self):
        return {'Karasu': {'id': 'geofabrik:TR:6:42', 'name': 'Karasu', 'country': 'TR',
                           'kind': 'district', 'parent_id': 'geofabrik:TR:4:223462'}}

    def test_mahalle_keeps_native_identity_geometry_and_local_role(self):
        m = self.module(); original = self.row(); result = m.qualify_record(original, self.parents())
        self.assertEqual(result['kind'], 'local_admin')
        self.assertEqual(result['unit_type'], 'Mahalle')
        self.assertEqual(result['id'], 'sakarya:mahalle:99999')
        self.assertEqual(result['parent_id'], 'geofabrik:TR:6:42')
        self.assertEqual(result['original_source_id'], '99999')
        self.assertEqual(result['source_date'], '2024-05-15')
        self.assertEqual(result['geometry'].wkb, original['geometry'].wkb)
        self.assertFalse(result['official_national_code_known'])

    def test_five_pinned_osb_objects_are_not_promoted_to_mahalle(self):
        m = self.module()
        for oid, name in m.EXCLUDED_OSB.items():
            row = self.row(); row['name'] = name
            row['original_properties'].update(objectid=oid, ad=name)
            self.assertIsNone(m.qualify_record(row, self.parents()))

    def test_changed_osb_identity_fails_closed(self):
        m = self.module(); row = self.row()
        row['original_properties']['objectid'] = '11634'
        with self.assertRaisesRegex(ValueError, 'OSB'):
            m.qualify_record(row, self.parents())

    def test_lake_sounding_real_mahalle_is_not_excluded(self):
        m = self.module(); row = self.row(); row['name'] = 'AKGÖL'
        row['original_properties']['ad'] = 'AKGÖL'
        self.assertIsNotNone(m.qualify_record(row, self.parents()))

    def test_exact_unresolved_hastahane_is_kept_out_not_duplicated_over_fallback(self):
        m = self.module(); row = self.row(); row['name'] = 'HASTAHANE'
        row['original_properties'].update(objectid='13252', ad='HASTAHANE', ilce='Akyazı')
        parents = {'Akyazı':{**self.parents()['Karasu'],'name':'Akyazı'}}
        self.assertIsNone(m.qualify_record(row, parents))

    def test_pending_identity_exclusion_cannot_expand_by_name_alone(self):
        m = self.module(); row = self.row(); row['name'] = 'HASTAHANE'
        row['original_properties']['ad'] = 'HASTAHANE'
        self.assertIsNotNone(m.qualify_record(row, self.parents()))

    def test_prepared_real_snapshot_has_only_individual_positive_replacements(self):
        m = self.module(); cache = m.ROOT/'.tools/atlas_sources'
        manifest = m.ROOT/'data/atlas_sakarya_sources.json'
        if not manifest.exists(): self.skipTest('Prepared original Sakarya snapshot is absent')
        import json
        source = json.loads(manifest.read_text(encoding='utf8'))['sources'][0]
        rows = list(m.iter_boundaries(cache,[source])); by_id = {r['id']:r for r in rows}
        self.assertEqual(len(rows),662)
        self.assertNotIn('sakarya:mahalle:13252',by_id)
        self.assertNotIn('sakarya:mahalle:13375',by_id)
        self.assertEqual(len(source['replaces_feature_ids']),189)
        self.assertNotIn('geofabrik:TR:8:13999454',source['replaces_feature_ids'])
        self.assertNotIn('geofabrik:TR:8:12715208',source['replaces_feature_ids'])
        self.assertEqual({target for r in rows for target in r.get('replaces_feature_ids',[])},
                         set(source['replaces_feature_ids']))
        evidence = source['feature_replacement_evidence']
        self.assertEqual(len(evidence),189)
        for proof in evidence:
            row = by_id[proof['source_unit_id']]
            self.assertEqual(row['original_source_id'],proof['original_source_id'])
            self.assertEqual(row['replaces_feature_ids'],[proof['replaces_feature_id']])
            self.assertTrue(proof['evidence_urls'])
        self.assertEqual(len(source['geometry_conflict_feature_ids']),5)
        self.assertTrue(source['blocks_full_coverage_claim'])
        audit=json.loads((cache/source['qualification_audit_file']).read_text(encoding='utf8'))
        self.assertEqual(audit['conflict_quarantine']['excluded_new_count'],7)
        self.assertEqual(len(audit['conflict_quarantine']['retained_gf_ids']),9)
        self.assertEqual(audit['conflict_quarantine']['remaining_conflict_count'],0)
        self.assertEqual(len(audit['excluded_unchanged_originals']),15)
        for step in audit['conflict_quarantine']['steps']:
            self.assertNotIn(step['excluded_source_id'],by_id)
            self.assertNotIn(step['new_retained_gf_id'],source['replaces_feature_ids'])

    def test_invalid_original_is_excluded_without_buffer_or_repair(self):
        m = self.module(); row = self.row()
        row['geometry'] = Polygon([(30,40),(31,41),(30,41),(31,40),(30,40)])
        before = row['geometry'].wkb
        self.assertIsNone(m.qualify_record(row, self.parents()))
        self.assertEqual(row['geometry'].wkb, before)

    def test_missing_or_foreign_district_does_not_assign_country_by_dataset(self):
        m = self.module()
        with self.assertRaisesRegex(ValueError, 'district'):
            m.qualify_record(self.row(), {})
        parents = self.parents(); parents['Karasu']['country'] = 'BG'
        with self.assertRaisesRegex(ValueError, 'district'):
            m.qualify_record(self.row(), parents)

    def test_source_name_and_native_property_must_agree(self):
        m = self.module(); row = self.row(); row['original_properties']['ad'] = 'OTHER'
        with self.assertRaisesRegex(ValueError, 'identity'):
            m.qualify_record(row, self.parents())

    def test_name_matching_keeps_turkish_letters_and_only_explicit_suffixes(self):
        m = self.module()
        self.assertEqual(m.name_key('ORTA'), m.name_key('Orta Mahalle'))
        self.assertEqual(m.name_key('İNCİLLİ'), m.name_key('İncilli Mahallesi'))
        self.assertNotEqual(m.name_key('ÇATALÖVEZ'), m.name_key('Çatalüvez Mahallesi'))
        self.assertNotEqual(m.name_key('HASTAHANE'), m.name_key('Hastane Mahallesi'))
        self.assertNotEqual(m.name_key('DAMLIK'), m.name_key('Esentepe Mahallesi'))

    def test_exact_replacement_requires_same_district_and_valid_original(self):
        m = self.module(); row = m.qualify_record(self.row(), self.parents())
        old = {'id':'geofabrik:TR:8:99','name':'Örnek Mahallesi','kind':'local_admin',
               'country':'TR','parent_id':row['parent_id'],'geometry':square()}
        binding = m.identity_binding(row, old)
        self.assertEqual(binding['target_id'], old['id'])
        self.assertEqual(binding['geometry_intersection_over_union'], 1.0)
        old['parent_id'] = 'geofabrik:TR:6:other'
        self.assertIsNone(m.identity_binding(row, old))

    def test_spatial_overlap_alone_does_not_invent_spelling_or_rename_alias(self):
        m = self.module(); row = m.qualify_record(self.row(), self.parents())
        old = {'id':'geofabrik:TR:8:99','name':'OTHER','kind':'local_admin',
               'country':'TR','parent_id':row['parent_id'],'geometry':square()}
        self.assertIsNone(m.identity_binding(row, old))

    def test_only_the_exact_documented_rename_has_an_alias(self):
        m = self.module(); row = self.row(); row['name'] = 'DAMLIK'
        row['original_properties'].update(objectid='12233', ad='DAMLIK', ilce='Ferizli')
        parents = self.parents(); parents['Ferizli'] = {**parents['Karasu'], 'id':'geofabrik:TR:6:ferizli', 'name':'Ferizli'}
        new = m.qualify_record(row, parents)
        old = {'id':'geofabrik:TR:8:13763940','name':'Esentepe Mahallesi', 'kind':'local_admin',
               'country':'TR','parent_id':new['parent_id'],'geometry':square()}
        binding = m.identity_binding(new, old)
        self.assertEqual(binding['identity_method'], 'explicit-primary-name-variant')
        self.assertIn('adalet.gov.tr', binding['evidence_urls'][0])
        old['id'] = 'geofabrik:TR:8:other'
        self.assertIsNone(m.identity_binding(new, old))

    def test_raw_parser_preserves_multipolygons_holes_and_original_properties(self):
        m = self.module()
        kml = '''<kml xmlns="http://www.opengis.net/kml/2.2"><Document><Placemark id="ID_1"><name>ÖRNEK</name><description><![CDATA[<table><tr><td>Mahalle</td></tr><tr><td>objectid</td><td>9</td></tr><tr><td>ad</td><td>ÖRNEK</td></tr></table>]]></description><MultiGeometry>
        <Polygon><outerBoundaryIs><LinearRing><coordinates>30,40,0 31,40,0 31,41,0 30,41,0 30,40,0</coordinates></LinearRing></outerBoundaryIs><innerBoundaryIs><LinearRing><coordinates>30.1,40.1,0 30.2,40.1,0 30.2,40.2,0 30.1,40.2,0 30.1,40.1,0</coordinates></LinearRing></innerBoundaryIs></Polygon>
        <Polygon><outerBoundaryIs><LinearRing><coordinates>32,40,0 33,40,0 33,41,0 32,41,0 32,40,0</coordinates></LinearRing></outerBoundaryIs></Polygon>
        </MultiGeometry></Placemark></Document></kml>'''
        rows = m.parse_kml(kml.encode('utf8'))
        self.assertEqual(rows[0]['original_properties'], {'objectid':'9','ad':'ÖRNEK'})
        self.assertEqual(rows[0]['geometry'].geom_type, 'MultiPolygon')
        self.assertEqual(len(rows[0]['geometry'].geoms[0].interiors), 1)
        self.assertEqual(tuple(rows[0]['geometry'].geoms[0].exterior.coords)[1], (31.0,40.0))

    def test_raw_parser_refuses_unclosed_ring_instead_of_closing_it(self):
        m = self.module()
        data = b'<kml xmlns="http://www.opengis.net/kml/2.2"><Placemark id="1"><name>A</name><Polygon><outerBoundaryIs><LinearRing><coordinates>30,40,0 31,40,0 31,41,0</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark></kml>'
        with self.assertRaisesRegex(ValueError, 'closed'):
            m.parse_kml(data)

    def test_kmz_pin_rejects_a_valid_but_unreviewed_archive(self):
        m = self.module(); buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as z: z.writestr('doc.kml', '<kml/>')
        with self.assertRaisesRegex(ValueError, 'pinned'):
            m.read_pinned_kmz(buffer.getvalue())

    def test_real_admitted_geometries_exactly_preserve_each_original_polygon(self):
        m=self.module(); cache=m.ROOT/'.tools/atlas_sources'; raw=cache/m.RAW/'TR-Sakarya-kmz-bounded47.body'
        if not raw.exists(): self.skipTest('Pinned original Sakarya KMZ is absent')
        original={r['original_properties']['objectid']:r for r in m.read_pinned_kmz(raw.read_bytes())}
        source=m.prepare_sources(cache)[0]
        self.assertEqual(len(original),677)
        self.assertEqual(sum(not r['geometry'].is_valid for r in original.values()),2)
        for row in m.iter_boundaries(cache,[source]):
            rawrow=original[row['original_source_id']]
            self.assertEqual(row['geometry'].wkb,rawrow['geometry'].wkb)
            self.assertEqual(row['original_properties'],rawrow['original_properties'])
        audit=__import__('json').loads((cache/source['qualification_audit_file']).read_text(encoding='utf8'))
        from shapely.geometry import shape
        for row in audit['excluded_unchanged_originals']:
            oid=row['original_properties']['objectid']
            self.assertEqual(shape(row['geometry']).wkb,original[oid]['geometry'].wkb)

    def test_prepared_cache_rejects_changed_normalized_bytes_before_yielding(self):
        m=self.module()
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'boundaries.gz').write_bytes(b'changed')
            source={'id':m.SOURCE_ID,'kind':'local_admin','country':'TR','cache_file':'boundaries.gz',
                    'bytes':7,'sha256':m.digest(b'original'),'expected_unit_count':1}
            with self.assertRaisesRegex(ValueError,'immutable'):
                next(m.iter_boundaries(root,[source]))

    def test_changed_qualification_audit_prevents_cache_reuse(self):
        m=self.module()
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); (root/'boundaries.gz').write_bytes(b'original')
            (root/'audit.json').write_bytes(b'changed audit')
            source={'cache_file':'boundaries.gz','bytes':8,'sha256':m.digest(b'original'),
                    'qualification_audit_file':'audit.json',
                    'qualification_audit_sha256':m.digest(b'original audit')}
            with self.assertRaisesRegex(ValueError,'audit'):
                m._verify(root,source)

    def test_missing_qualification_audit_prevents_cache_reuse(self):
        m=self.module()
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); (root/'boundaries.gz').write_bytes(b'original')
            source={'cache_file':'boundaries.gz','bytes':8,'sha256':m.digest(b'original'),
                    'qualification_audit_file':'missing-audit.json',
                    'qualification_audit_sha256':m.digest(b'original audit')}
            with self.assertRaisesRegex(ValueError,'audit'):
                m._verify(root,source)

    def test_immutable_file_cannot_be_overwritten(self):
        m = self.module()
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory)/'record'
            m.write_immutable(p, b'original')
            m.write_immutable(p, b'original')
            with self.assertRaisesRegex(ValueError, 'Immutable'):
                m.write_immutable(p, b'changed')
            self.assertEqual(p.read_bytes(), b'original')

    def conflict_fixture(self):
        from shapely.geometry import box
        def row(i, g):
            return {'id':i,'geometry':g,'name':i,'original_properties':{'ilce':'Test'}}
        rows = [row('new-a',box(.98,0,1.98,1)),row('new-b',box(1.98,0,2.98,1)),row('new-clear',box(4,0,5,1))]
        old = [row('old-start',box(0,0,1,1)),row('old-a',box(1,0,2,1)),row('old-b',box(2,0,3,1))]
        bindings = [{'replacement_id':'new-a','target_id':'old-a'}, {'replacement_id':'new-b','target_id':'old-b'}]
        return rows,old,bindings

    def conflict_module(self):
        m=self.module()
        self.assertTrue(hasattr(m,'conflict_quarantine'),'Bounded iterative source conflict quarantine is missing')
        return m

    def test_conflict_quarantine_is_iterative_and_preserves_unmodified_originals(self):
        m=self.conflict_module(); rows,old,bindings=self.conflict_fixture()
        before={r['id']:r['geometry'].wkb for r in rows+old}
        eligible,active,audit=m.conflict_quarantine(rows,old,bindings,{'old-start'})
        self.assertEqual([r['id'] for r in eligible],['new-clear'])
        self.assertEqual(active,[])
        self.assertEqual([r['excluded_source_id'] for r in audit['steps']],['new-a','new-b'])
        self.assertEqual(audit['retained_gf_ids'],['old-a','old-b','old-start'])
        self.assertEqual(audit['remaining_conflict_count'],0)
        self.assertEqual({r['id']:r['geometry'].wkb for r in rows+old},before)

    def test_conflict_quarantine_refuses_unbounded_spread(self):
        m=self.conflict_module(); rows,old,bindings=self.conflict_fixture()
        with self.assertRaisesRegex(ValueError,'limit'):
            m.conflict_quarantine(rows,old,bindings,{'old-start'},limit=1)

    def test_small_edges_under_one_percent_are_documented_and_retained(self):
        m=self.conflict_module(); rows,old,bindings=self.conflict_fixture()
        from shapely.geometry import box
        rows[0]['geometry']=box(.995,0,1.995,1)
        eligible,active,audit=m.conflict_quarantine(rows[:1],old,bindings[:1],{'old-start'})
        self.assertEqual(len(eligible),1)
        self.assertEqual(len(active),1)
        self.assertEqual(len(audit['remaining_small_overlaps']),1)

    def test_numerical_specks_cannot_trigger_a_territorial_quarantine(self):
        m=self.conflict_module(); rows,old,_=self.conflict_fixture()
        from shapely.geometry import box
        rows[0]['geometry']=box(0,0,.000001,.000001)
        eligible,active,audit=m.conflict_quarantine(rows[:1],old,[],{'old-start'})
        self.assertEqual(len(eligible),1)

    def test_missing_fallback_identity_is_not_silently_ignored(self):
        m=self.conflict_module(); rows,old,bindings=self.conflict_fixture()
        with self.assertRaisesRegex(ValueError,'fallback'):
            m.conflict_quarantine(rows,old,bindings,{'unknown'})


if __name__ == '__main__': unittest.main()
