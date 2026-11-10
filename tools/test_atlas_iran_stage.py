"""Small offline fixtures for exact Iran raw preparation; no geometry work."""
from copy import deepcopy
import hashlib
import importlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile


def digest(data):return hashlib.sha256(data).hexdigest()


def semantic(element):
    return {key:element[key] for key in ('type','id','version','timestamp','tags','members')}


def metadata_fixture():
    element={'type':'relation','id':42,'version':3,'timestamp':'2026-01-01T00:00:00Z',
             'tags':{'boundary':'administrative','admin_level':'4','name':'استان نمونه','ISO3166-2':'IR-01'},
             'members':[{'type':'way','ref':100,'role':'outer'}]}
    expected={'id':42,'version':3,'timestamp':element['timestamp'],'name':element['tags']['name'],
              'iso3166_2':'IR-01','semantic_sha256':digest(json.dumps(semantic(element),ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf8'))}
    return {'version':'0.6','generator':'volatile server','elements':[element]},[expected]


def archive_fixture():
    payloads={f'gis_osm_adminareas_a_free_1.{ext}':('small-'+ext).encode() for ext in ['shp','shx','dbf','prj','cpg']}
    payloads['README']=b'data as of 2026-11-08T21:21:00Z\n'
    output=io.BytesIO()
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
        for name,payload in payloads.items():z.writestr(name,payload)
    data=output.getvalue();members=[]
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for info in z.infolist():
            members.append({'name':info.filename,'bytes':info.file_size,'compressed_bytes':info.compress_size,
                            'crc32':f'{info.CRC:08x}','sha256':digest(payloads[info.filename])})
    metadata,provinces=metadata_fixture()
    recipe={'schema':1,'snapshot':'2026-11-08T21:21:00Z','archive':{'url':'https://example.invalid/pinned.zip','bytes':len(data),'etag':'"fixed"'},
            'members':[r for r in members if r['name']!='README'],'readme':next(r for r in members if r['name']=='README'),
            'maximum_single_range_bytes':1048576,'maximum_metadata_bytes':500000,'budget_bytes':30000000,'provinces':provinces}
    return data,payloads,recipe


class IranStagerTests(unittest.TestCase):
    def module(self):
        self.assertIsNotNone(importlib.util.find_spec('atlas_iran_stage'),'Bounded Iran raw stager is absent')
        return importlib.import_module('atlas_iran_stage')

    def test_public_recipe_pins_existing_archive_and_exact_thirty_versions(self):
        m=self.module();r=m.load_recipe()
        self.assertEqual(r['archive']['bytes'],447069064)
        self.assertEqual(r['archive']['etag'],'"1aa5bb88-65fcd02ef5191"')
        self.assertEqual(len(r['provinces']),30)
        url=m.province_url(r['provinces'])
        for p in r['provinces']:self.assertIn(str(p['id'])+'v'+str(p['version']),url)
        self.assertNotIn('/full',url)

    def test_recipe_pin_survives_normal_git_line_ending_conversion(self):
        m=self.module();payload=m.RECIPE.read_bytes().replace(b'\r\n',b'\n')
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'recipe.json'
            with patch.object(m,'RECIPE',path):
                for body in [payload,payload.replace(b'\n',b'\r\n')]:
                    path.write_bytes(body)
                    self.assertEqual(len(m.load_recipe()['provinces']),30)
                path.write_bytes(payload.replace(b'447069064',b'447069065'))
                with self.assertRaises(ValueError):m.load_recipe()

    def test_archive_pin_is_checked_before_member_fetch(self):
        m=self.module();_,_,r=archive_fixture()
        for patch in [{'bytes':r['archive']['bytes']+1},{'etag':'"different"'},{'url':'https://example.invalid/latest.zip'}]:
            with self.assertRaisesRegex(ValueError,'archive'):
                m.validate_snapshot({**r['archive'],**patch},r)

    def test_metadata_accepts_same_fixed_elements_with_changed_envelope(self):
        m=self.module();a,p=metadata_fixture();a['generator']='different API host'
        m.validate_metadata(a,p,'2026-11-08T21:21:00Z')

    def test_metadata_rejects_wrong_version_missing_extra_and_changed_members(self):
        m=self.module();a,p=metadata_fixture();cases=[]
        wrong=deepcopy(a);wrong['elements'][0]['version']=4;cases.append(wrong)
        wrong=deepcopy(a);wrong['elements']=[];cases.append(wrong)
        wrong=deepcopy(a);wrong['elements'].append(deepcopy(a['elements'][0]));cases.append(wrong)
        wrong=deepcopy(a);wrong['elements'][0]['members'][0]['ref']=101;cases.append(wrong)
        wrong=deepcopy(a);wrong['elements'][0]['tags']['ISO3166-2']='IQ-01';cases.append(wrong)
        for wrong in cases:
            with self.assertRaises(ValueError):m.validate_metadata(wrong,p,'2026-11-08T21:21:00Z')

    def test_member_plan_does_not_admit_an_additional_admin_set(self):
        m=self.module();data,_,r=archive_fixture()
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            self.assertEqual(len(m.member_plan(z,r)),6)
            z.infolist().append(zipfile.ZipInfo('gis_osm_adminareas_a_free_2.dbf'))
            with self.assertRaises(ValueError):m.member_plan(z,r)

    def test_small_zip_stream_checks_sha_and_keeps_existing_file_unchanged(self):
        m=self.module();data,payloads,r=archive_fixture()
        with tempfile.TemporaryDirectory() as tmp,zipfile.ZipFile(io.BytesIO(data)) as z:
            directory=Path(tmp);spec=r['members'][0]
            first=m.stage_member(z,z.getinfo(spec['name']),directory,spec)
            p=directory/spec['name'];before=p.stat().st_mtime_ns
            second=m.stage_member(z,z.getinfo(spec['name']),directory,spec)
            self.assertEqual(first,second);self.assertEqual(p.read_bytes(),payloads[spec['name']]);self.assertEqual(p.stat().st_mtime_ns,before)

    def test_changed_member_hash_does_not_finalize_a_file(self):
        m=self.module();data,_,r=archive_fixture()
        with tempfile.TemporaryDirectory() as tmp,zipfile.ZipFile(io.BytesIO(data)) as z:
            spec={**r['members'][0],'sha256':'0'*64};directory=Path(tmp)
            with self.assertRaises(ValueError):m.stage_member(z,z.getinfo(spec['name']),directory,spec)
            self.assertFalse((directory/spec['name']).exists())

    def test_finished_member_without_receipt_recovers_a_labelled_integrity_record(self):
        m=self.module();data,payloads,r=archive_fixture()
        with tempfile.TemporaryDirectory() as tmp,zipfile.ZipFile(io.BytesIO(data)) as z:
            directory=Path(tmp);spec=r['members'][0];path=directory/spec['name']
            path.write_bytes(payloads[spec['name']]);before=path.stat().st_mtime_ns
            result=m.stage_member(z,z.getinfo(spec['name']),directory,spec)
            self.assertIn('reconstructed',result['receipt_origin'])
            self.assertEqual(path.stat().st_mtime_ns,before)
            self.assertEqual(result['sha256'],spec['sha256'])

    def test_fixed_metadata_without_transport_receipt_recovers_only_when_explicit(self):
        m=self.module();document,provinces=metadata_fixture();_,_,r=archive_fixture();r['provinces']=provinces
        with tempfile.TemporaryDirectory() as tmp:
            directory=Path(tmp);path=directory/'regions-original-tags.json'
            body=json.dumps(document).encode();path.write_bytes(body);before=path.stat().st_mtime_ns
            with self.assertRaises(FileNotFoundError):m._metadata_record(directory,r)
            record=m._metadata_record(directory,r,repair_missing=True)
            self.assertIn('reconstructed',record['receipt_origin'])
            self.assertEqual(record['url_role'],'reproduction_locator_only_original_transport_receipt_missing')
            self.assertEqual(record['sha256'],digest(body))
            self.assertEqual(path.stat().st_mtime_ns,before)
            self.assertNotIn('headers',record)

    def test_budget_reservation_includes_failed_attempts_and_survives_reopen(self):
        m=self.module()
        with tempfile.TemporaryDirectory() as tmp:
            b=m.TransferBudget(Path(tmp),100,initial_bytes=10)
            t=b.reserve(60,'range','first');b.finish(t,20,False)
            self.assertEqual(b.charged_bytes,70)
            b=m.TransferBudget(Path(tmp),100,initial_bytes=0)
            with self.assertRaises(ValueError):b.reserve(31,'metadata','next')

    def test_successful_request_charges_actual_body_and_cached_data_count(self):
        m=self.module()
        with tempfile.TemporaryDirectory() as tmp:
            b=m.TransferBudget(Path(tmp),100,initial_bytes=20)
            t=b.reserve(50,'metadata','fixed');b.finish(t,30,True)
            self.assertEqual(b.charged_bytes,50)

    def test_cached_range_receipt_checks_separate_provenance_fields(self):
        m=self.module();_,_,r=archive_fixture();data=b'xyz'
        receipt={'url':r['archive']['url'],'etag':'"fixed"','start':1,'end':3,'bytes':3,'sha256':digest(data),
                 'headers':{'status':206,'etag':'"fixed"','content-range':f"bytes 1-3/{r['archive']['bytes']}"}}
        m.validate_cached_range(receipt,data,1,3,r)
        for key,value in [('url','https://example.invalid/other'),('start',2),('end',4),('bytes',4)]:
            with self.assertRaises(ValueError):m.validate_cached_range({**receipt,key:value},data,1,3,r)

    def test_complete_tiny_stage_then_read_only_replay_never_calls_network(self):
        m=self.module();data,payloads,r=archive_fixture();metadata,_=metadata_fixture();calls=[]
        class MemorySource:
            def __init__(self,directory,url):
                self.directory=directory;self.url=url;self.snapshot=r['archive'];self.receipts={}
                m.core.write_json(directory/'snapshot.json',self.snapshot)
            def fetch(self,start,end):
                calls.append((start,end));body=data[start:end+1]
                receipt={'url':self.url,'etag':r['archive']['etag'],'start':start,'end':end,'bytes':len(body),
                         'sha256':digest(body),'headers':{'status':206,'etag':r['archive']['etag'],
                             'content-range':f'bytes {start}-{end}/{len(data)}'}}
                directory=self.directory/'ranges';directory.mkdir(exist_ok=True)
                (directory/f'{start}-{end}.bin').write_bytes(body)
                m.core.write_json(directory/f'{start}-{end}.receipt.json',receipt)
                return body
        def metadata_fetch(url,body,headers,maximum):
            calls.append('metadata');body.write_bytes(json.dumps(metadata).encode())
            headers.write_text('HTTP/1.1 200 OK\nContent-Type: application/json\n')
            return 0,''
        def forbidden(*args,**kwargs):raise AssertionError('read-only replay used network')
        with tempfile.TemporaryDirectory() as tmp:
            cache=Path(tmp)
            first=m.stage_sources(cache,recipe=r,remote_factory=MemorySource,metadata_fetcher=metadata_fetch)
            self.assertEqual(first['status'],'complete-cache-only');self.assertTrue(calls)
            timestamps={p:p.stat().st_mtime_ns for p in cache.rglob('*') if p.is_file()}
            second=m.stage_sources(cache,recipe=r,remote_factory=forbidden,metadata_fetcher=forbidden)
            self.assertTrue(second['reused']);self.assertEqual(second['new_request_body_bytes'],0)
            self.assertEqual(timestamps,{p:p.stat().st_mtime_ns for p in cache.rglob('*') if p.is_file()})
            raw=cache/m.RAW
            (raw/'members'/r['members'][0]['name']).write_bytes(b'changed')
            with self.assertRaises(ValueError):m.stage_sources(cache,recipe=r,remote_factory=forbidden)

    def test_check_only_missing_cache_creates_nothing(self):
        m=self.module();_,_,r=archive_fixture()
        with tempfile.TemporaryDirectory() as tmp:
            cache=Path(tmp)/'not-created'
            with self.assertRaises(FileNotFoundError):m.stage_sources(cache,recipe=r,check_only=True)
            self.assertFalse(cache.exists())


if __name__=='__main__':unittest.main()
