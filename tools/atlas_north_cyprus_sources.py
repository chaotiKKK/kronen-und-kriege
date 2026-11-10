"""Eighteen northern Belediye identities, separately from Republic CY claims.

Original Geofabrik/OSM polygons are admitted only through the named schedule in
the consolidated Law 15/2022. The ordinary admin-level number proves no role on
its own. Preparation can reproduce the small selective original-source capture;
iteration verifies it offline. The merger must intersect display geometry with
the existing CYN reference, without assigning powers in the buffer or SBA.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import unicodedata
import zipfile

from shapely.geometry import shape

from atlas_geofabrik_sources import RangeSource, RemoteZip, _shapefile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT/'.tools/atlas_sources'
DIRECTORY = 'audit/cy-ir-ma-current-20261110'
GF_DIRECTORY = DIRECTORY+'/geofabrik-cyprus-261108'
ARCHIVE = 'https://download.geofabrik.de/europe/cyprus-261108-free.shp.zip'
SNAPSHOT = '2026-11-08T21:21:00Z'
ARCHIVE_BYTES = 81025074
ARCHIVE_ETAG = '"4d45832-65fcf8bfead0f"'
LAW = 'https://mevzuat.gov.ct.tr/Portals/48/15-2022%20Belediyelerin%20Birlestirilmesine%20Iliskin%20%28Ozel%29%20Yasa.pdf'
NE_REFERENCE = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson'
SOURCE_ID = 'geofabrik-CYN-261108-law15-2022'
# Positive identities: original OSM relation -> legal schedule number, version,
# and unmodified producer name. Repeated or renamed levels cannot enter by rank.
IDENTITIES = {
    '16283722':(1,14,'Lefkoşa Türk Belediyesi'),
    '16301094':(2,8,'Gazimağusa Belediyesi'),
    '16272379':(3,5,'Girne Belediyesi'),
    '16268774':(4,3,'Güzelyurt Belediyesi'),
    '16306104':(5,4,'İskele Belediyesi'),
    '16264705':(6,5,'Lefke Belediyesi'),
    '16283807':(7,10,'Değirmenlik-Akıncılar Belediyesi'),
    '16272281':(8,4,'Lapta-Alsancak-Çamlıbel Belediyesi'),
    '16337159':(9,8,'Erenköy-Karpaz Belediyesi'),
    '16335158':(10,3,'Mehmetçik-Büyükkonuk Belediyesi'),
    '16300875':(11,4,'Geçitkale-Serdarlı Belediyesi'),
    '16301043':(12,6,'Mesarya Belediyesi'),
    '16283617':(13,8,'Gönyeli-Alayköy Belediyesi'),
    '16300958':(14,6,'Yeniboğaziçi Belediyesi'),
    '16272365':(15,5,'Çatalköy-Esentepe Belediyesi'),
    '16272310':(16,7,'Dikmen Belediyesi'),
    '16300858':(17,2,'Tatlısu Belediyesi'),
    '16301085':(18,9,'Beyarmudu Belediyesi'),
}
PINNED_INPUTS = [{'cache_file': 'audit/cy-ir-ma-current-20261110/geofabrik-cyprus-261108/gis_osm_adminareas_a_free_1.cpg',
  'archive_member': 'gis_osm_adminareas_a_free_1.cpg',
  'url': 'https://download.geofabrik.de/europe/cyprus-261108-free.shp.zip',
  'bytes': 6,
  'sha256': '146d6789ffe033a5297c1ad046e6a62ee35319b86b021444f05b6ea2aa8a1f4a',
  'crc32': '59b2d65b'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/geofabrik-cyprus-261108/gis_osm_adminareas_a_free_1.dbf',
  'archive_member': 'gis_osm_adminareas_a_free_1.dbf',
  'url': 'https://download.geofabrik.de/europe/cyprus-261108-free.shp.zip',
  'bytes': 136897,
  'sha256': '4fe306ab9a6f37db341b18ce32849d5ebb3e2240de88f71a9f05d82e4144313e',
  'crc32': 'd82a4b53'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/geofabrik-cyprus-261108/gis_osm_adminareas_a_free_1.prj',
  'archive_member': 'gis_osm_adminareas_a_free_1.prj',
  'url': 'https://download.geofabrik.de/europe/cyprus-261108-free.shp.zip',
  'bytes': 144,
  'sha256': 'ffc9162903c37f0867d1e7f36c20036a165f7aa555dda24c1ae0ee4328d2977f',
  'crc32': '0bbee490'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/geofabrik-cyprus-261108/gis_osm_adminareas_a_free_1.shp',
  'archive_member': 'gis_osm_adminareas_a_free_1.shp',
  'url': 'https://download.geofabrik.de/europe/cyprus-261108-free.shp.zip',
  'bytes': 10515356,
  'sha256': 'facdee5e637b7d95133734fab96b86f1dbc5b200a4bcd85c837809e362bde02a',
  'crc32': 'e7dc743c'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/geofabrik-cyprus-261108/gis_osm_adminareas_a_free_1.shx',
  'archive_member': 'gis_osm_adminareas_a_free_1.shx',
  'url': 'https://download.geofabrik.de/europe/cyprus-261108-free.shp.zip',
  'bytes': 7644,
  'sha256': '26c5028a8e9b364e5bff74de72d01ac8bfe5e5ed056df6da7295db4fcfb933d6',
  'crc32': 'b96d95ef'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/geofabrik-cyprus-261108/README',
  'url': 'https://download.geofabrik.de/europe/cyprus-261108-free.shp.zip',
  'bytes': 653,
  'sha256': 'a4547a0e98dff8848dc2b64ec0e10b40bfe6856d7d7619419257b549dda70413',
  'archive_member': 'README'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CYN-merger-law-2022.pdf',
  'url': 'https://mevzuat.gov.ct.tr/Portals/48/15-2022%20Belediyelerin%20Birlestirilmesine%20Iliskin%20%28Ozel%29%20Yasa.pdf',
  'bytes': 517088,
  'sha256': 'f35b25b03a5b7d58468b071c23e88c6a78558370389e05ccdf5ffb0f5b60fc58'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CYN-osm-relations-fixed-versions.json',
  'url': 'https://api.openstreetmap.org/api/0.6/relations.json?relations=16283722v14,16301094v8,16272379v5,16268774v3,16306104v4,16264705v5,16283807v10,16272281v4,16337159v8,16335158v3,16300875v4,16301043v6,16283617v8,16300958v6,16272365v5,16272310v7,16300858v2,16301085v9',
  'bytes': 36719,
  'sha256': '2287902399dbb6af521cfe34af592bee7a8ce2eeb3ae5bcb5f6fdcbc84ba24a4'}]


def normalized_name(value: str) -> str:
    """Transparent case/spacing/diacritic normalization; no inferred aliases."""
    value=value.replace('ı','i').replace('İ','I')
    latin=unicodedata.normalize('NFKD',value).encode('ascii','ignore').decode().lower()
    return re.sub('[^a-z0-9]','',latin)


def parse_schedule_text(text: str) -> dict:
    title='BELEDİYELER VE BELEDİYELERE BAĞLI YERLEŞİM YERLERİ'
    if title not in text:
        raise ValueError('Missing enacted northern municipality schedule')
    text=text.rsplit(title,1)[1]
    text='\n'.join(line for line in text.splitlines() if not re.match(
        r'^\s*(?:\d+\s*$|Merkezi Mevzuat Dairesi|https://|Tel:)',line))
    schedules={}
    for match in re.finditer(r'(\d+)-\s*(.*?BELEDİYESİ)\s*:\s*(.*?)(?=\n\d+-\s|\Z)',text,re.S):
        number=int(match[1]);body=match[3]
        count=re.search(r'\((\d+)\s*köy\)',body)
        if not count or number in schedules:
            raise ValueError('Missing/duplicate legal settlement inventory')
        villages=[' '.join(v.split()).rstrip('.') for v in body[:count.start()].split(',')]
        if len(villages)!=int(count[1]) or any(not v for v in villages):
            raise ValueError('Legal settlement names do not match the printed count')
        schedules[number]={'schedule_number':number,'legal_name':' '.join(match[2].split()),
                           'villages':villages,'count':int(count[1])}
    if not schedules:
        raise ValueError('No enacted northern municipal identities parsed')
    return schedules


def qualify_municipality(properties: dict, geometry, relation: dict, legal: dict) -> dict:
    rid=properties.get('osm_id');identity=IDENTITIES.get(rid);tags=relation.get('tags',{})
    if (identity is None or properties.get('code')!=1207 or properties.get('fclass')!='admin_level7'
            or properties.get('name')!=identity[2] or legal.get('schedule_number')!=identity[0]
            or normalized_name(legal.get('legal_name',''))!=normalized_name(identity[2])
            or relation.get('type')!='relation' or str(relation.get('id'))!=rid
            or relation.get('version')!=identity[1] or not relation.get('timestamp')
            or relation['timestamp']>SNAPSHOT or tags.get('boundary')!='administrative'
            or tags.get('admin_level')!='7' or tags.get('name')!=identity[2]
            or tags.get('type')!='boundary'):
        raise ValueError('Northern municipality lacks its positive law/OSM identity join')
    if geometry.is_empty or not geometry.is_valid or geometry.geom_type not in ('Polygon','MultiPolygon'):
        raise ValueError('Invalid original northern municipal polygon; no repair is authorized')
    return {'id':'geofabrik:CYN:7:'+rid,'country':'CYN','name':identity[2],
            'original_name':identity[2],'name_known':True,'kind':'municipality',
            'parent_id':'country:CYN','source':SOURCE_ID,'geometry':geometry,
            'unit_type':'Belediye','source_role':'Belediye under consolidated Law 15/2022, second schedule',
            'source_extract_country':'CY','country_assignment_method':'positive_northern_municipal_identity',
            'osm_type':'relation','osm_id':int(rid),'osm_version':relation['version'],
            'osm_timestamp':relation['timestamp'],'osm_tags':tags,
            'source_osm_url':'https://www.openstreetmap.org/relation/'+rid+'/history/'+str(identity[1]),
            'source_date':SNAPSHOT,'role_evidence_url':LAW,'legal_schedule_number':identity[0],
            'legal_name':legal['legal_name'],'legal_settlements':legal['villages'],
            'legal_settlement_count':legal['count'],'geometry_modified_by_importer':False,
            'geometry_origin':'Unmodified original Geofabrik administrative shapefile polygon; OSM relation identity independently verified',
            'territorial_authority_note':'Native northern municipal role only. Display intersection with CYN does not certify a state boundary or confer powers in CNM/ESB/WSB.'}


def settlement_audit(legal: dict, municipality, features: list) -> dict:
    inside=[p for p,g in features if p.get('fclass')=='admin_level8'
            and not g.is_empty and municipality.covers(g.representative_point())]
    names={}
    for p in inside:
        names.setdefault(normalized_name(p['name']),[]).append(p)
    expected={normalized_name(name) for name in legal['villages']}
    matches=[];missing=[]
    for name in legal['villages']:
        candidates=names.get(normalized_name(name),[])
        if len(candidates)==1:
            matches.append({'legal_name':name,'osm_id':candidates[0]['osm_id'],
                            'source_name':candidates[0]['name']})
        else:
            missing.append(name)
    return {'method':'Exact normalized native name and original village representative point inside the original municipality; no alias inference',
            'exact_match_count':len(matches),'exact_matches':matches,
            'unmatched_legal_names':missing,
            'additional_spatial_names':[{'osm_id':p['osm_id'],'name':p['name']}
                for p in inside if normalized_name(p['name']) not in expected]}


def verified_file(cache: Path, pin: dict) -> Path:
    root=Path(cache).resolve();path=(root/pin['cache_file']).resolve()
    if not path.is_relative_to(root):
        raise ValueError('Northern Cyprus input path leaves its declared cache')
    raw=path.read_bytes()
    if len(raw)!=pin['bytes'] or hashlib.sha256(raw).hexdigest()!=pin['sha256']:
        raise ValueError('Changed original northern Cyprus bytes/hash: '+path.name)
    return path


def _read_rows(cache: Path):
    files={Path(pin['cache_file']).name:verified_file(cache,pin) for pin in PINNED_INPUTS}
    readme=files['README'].read_text(encoding='utf-8')
    if 'data as of '+SNAPSHOT not in readme or 'Open Database 1.0 License' not in readme:
        raise ValueError('Unexpected Geofabrik OSM snapshot/license statement')
    from pypdf import PdfReader
    text='\n'.join(page.extract_text() or '' for page in PdfReader(io.BytesIO(
        files['CYN-merger-law-2022.pdf'].read_bytes())).pages)
    schedules=parse_schedule_text(text)
    if set(schedules)!=set(range(1,19)) or sum(x['count'] for x in schedules.values())!=213:
        raise ValueError('The original enacted 18-municipality/213-settlement inventory changed')
    metadata=json.loads(files['CYN-osm-relations-fixed-versions.json'].read_text(encoding='utf-8'))
    relations={str(x['id']):x for x in metadata['elements'] if x.get('type')=='relation'}
    if set(relations)!=set(IDENTITIES) or len(metadata['elements'])!=18:
        raise ValueError('Missing/duplicate original OSM northern municipal metadata')
    reader=_shapefile().Reader(str(files['gis_osm_adminareas_a_free_1.shp']),encoding='utf-8')
    features=[(f.record.as_dict(),shape(f.shape.__geo_interface__)) for f in reader.iterShapeRecords()]
    if len(features)!=943:
        raise ValueError('Unexpected original Cyprus adminarea inventory')
    rows=[];seen=set()
    for properties,geometry in features:
        rid=properties.get('osm_id')
        if rid not in IDENTITIES:
            continue
        if rid in seen:
            raise ValueError('Duplicate original northern municipality')
        seen.add(rid);legal=schedules[IDENTITIES[rid][0]]
        row=qualify_municipality(properties,geometry,relations[rid],legal)
        row['settlement_name_audit']=settlement_audit(legal,geometry,features)
        rows.append(row)
    if seen!=set(IDENTITIES):
        raise ValueError('Missing positive northern municipal source polygon')
    rows.sort(key=lambda row:row['legal_schedule_number'])
    return rows


def _source_record(rows: list) -> dict:
    canonical=json.dumps(PINNED_INPUTS,sort_keys=True,separators=(',',':')).encode('utf-8')
    unresolved=[{'municipality_id':r['id'],'names':r['settlement_name_audit']['unmatched_legal_names']}
                for r in rows if r['settlement_name_audit']['unmatched_legal_names']]
    return {'id':SOURCE_ID,'country':'CYN','scope_countries':['CYN'],
            'kind':'municipality','replacement_scope':'country','merge_priority':5,
            'clip_to_scope':True,
            'scope_clip_basis':'display/intersection against the existing atlas territorial reference, not certified state boundary',
            'scope_clip_evidence_url':NE_REFERENCE,'scope_clip_reference_source':'natural-earth-countries',
            'url':ARCHIVE,'metadata_url':LAW,'date':SNAPSHOT,
            'license':'ODbL-1.0','license_url':'https://opendatacommons.org/licenses/odbl/1-0/',
            'license_evidence_url':'https://www.openstreetmap.org/copyright',
            'attribution':'© OpenStreetMap contributors; Geofabrik GmbH. ODbL 1.0. Rollen nach konsolidiertem Gesetz 15/2022 geprüft; Gebietsanzeige am bestehenden Atlasrahmen geschnitten. Keine amtliche Grenzzertifizierung.',
            'unit_type':'Belediye','role_evidence_urls':[LAW],
            'files':PINNED_INPUTS,'bytes':sum(p['bytes'] for p in PINNED_INPUTS),
            'sha256':hashlib.sha256(canonical).hexdigest(),
            'hash_scope':'Canonical ordered original input receipts; every original file is individually pinned',
            'object_count':len(rows),'source_unit_count':len(rows),'normalized_unit_count':len(rows),
            'role_counts':dict(Counter(r['kind'] for r in rows)),
            'blocks_full_coverage_claim':False,
            'coverage_note':'18 nach Gesetz 15/2022 eindeutig geprüfte Gemeinden; 209 von 213 gesetzlichen Ortsnamen räumlich zugeordnet, die Zuordnung von vier Ortsnamen bleibt offen. Rund 95,17 % der bestehenden Landreferenz sind bedeckt; rund 160,36 km² bleiben ungefüllt. Dies ist kein amtlicher Kataster- oder Vollständigkeitsnachweis.',
            'territorial_scope_note':'Die Anzeige ist auf den bestehenden Kartenraum Nordzypern (CYN) begrenzt. Daraus werden keine nördlichen Gemeindebefugnisse in der UN-Pufferzone oder den britischen Basen abgeleitet. Die ursprünglichen Quellpolygone bleiben unverändert nachprüfbar.',
            'settlement_qualification':{'legal_settlement_count':213,
                'exact_normalized_name_matches':sum(r['settlement_name_audit']['exact_match_count'] for r in rows),
                'unmatched_name_count':sum(len(r['names']) for r in unresolved),'unmatched_names':unresolved,
                'meaning':'All 18 municipality identities match the enacted schedule. 209 village names match independently; four unjoined names are disclosed, not treated as proof of four missing municipal polygons.'},
            'unit_semantics':{'render_role':'18 actual northern municipalities under their native names',
                'geometry':'Original dated OSM/Geofabrik polygons. Only display intersection with the existing independent CYN reference is authorized; no union, repair, gap fill or transfer to other territories.',
                'coverage_status':'Unchanged NE-v5.1.2 CYN reference: 95.1691459% covered; land 3319.450567 km², covered 3159.092754 km². Residual 160.357813 km² remains unfilled. Original source polygons include 92.547417 km² outside that display reference; no northern municipal powers in buffer or bases are inferred.',
                'role_date':'Consolidated Law 15/2022 including 2023/2024 amendments; geometry snapshot 2026-11-08',
                'political_scope':'Separate native northern administration. No substitution of Republic CY claimed municipalities, international recognition statement, or certified effective-control boundary is inferred.'}}


def _download_missing(cache: Path):
    missing=[p for p in PINNED_INPUTS if not (cache/p['cache_file']).exists()]
    members=[p for p in missing if p.get('archive_member')]
    if members:
        remote=RangeSource(cache/GF_DIRECTORY,ARCHIVE)
        if remote.snapshot['bytes']!=ARCHIVE_BYTES or remote.snapshot['etag']!=ARCHIVE_ETAG:
            raise ValueError('Changed dated Geofabrik archive snapshot')
        with zipfile.ZipFile(RemoteZip(remote.snapshot['bytes'],remote.fetch)) as archive:
            for pin in members:
                raw=archive.read(pin['archive_member']) # ZIP CRC validated by ZipFile.
                if len(raw)!=pin['bytes'] or hashlib.sha256(raw).hexdigest()!=pin['sha256']:
                    raise ValueError('Changed original Geofabrik member')
                path=cache/pin['cache_file'];path.parent.mkdir(parents=True,exist_ok=True)
                with path.open('xb') as output:
                    output.write(raw)
    for pin in missing:
        if pin.get('archive_member'):
            continue
        path=cache/pin['cache_file'];path.parent.mkdir(parents=True,exist_ok=True)
        stage=path.with_suffix(path.suffix+'.part')
        result=subprocess.run(['curl.exe','--fail','--location','--silent','--show-error',
            '--connect-timeout','15','--max-time','90','--max-filesize',str(pin['bytes']+1),
            '--output',str(stage),pin['url']],capture_output=True,text=True)
        if result.returncode:
            raise RuntimeError('Pinned northern Cyprus source fetch failed: '+result.stderr)
        raw=stage.read_bytes()
        if len(raw)!=pin['bytes'] or hashlib.sha256(raw).hexdigest()!=pin['sha256']:
            raise ValueError('Public northern Cyprus input changed from its pinned snapshot')
        stage.replace(path)


def prepare_sources(cache: Path=DEFAULT_CACHE):
    cache=Path(cache)
    _download_missing(cache)
    rows=_read_rows(cache);sources=[_source_record(rows)]
    manifest={'schema':1,'sources':sources,
              'qualified_identities':[{key:value for key,value in row.items() if key in (
                  'id','name','osm_id','osm_version','osm_timestamp','legal_schedule_number',
                  'legal_name','legal_settlement_count','settlement_name_audit')} for row in rows],
              'note':'Raw legal texts remain only in the ignored source cache. The runtime receives factual names/roles, source IDs, links and hashes.'}
    (ROOT/'data/atlas_north_cyprus_sources.json').write_text(
        json.dumps(manifest,ensure_ascii=False,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    return sources


def iter_boundaries(cache: Path,sources: list[dict]):
    rows=_read_rows(Path(cache))
    if sources!=[_source_record(rows)]:
        raise ValueError('Changed northern Cyprus identity, role, license or territorial scope')
    yield from rows


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache',type=Path,default=DEFAULT_CACHE)
    args=parser.parse_args();sources=prepare_sources(args.cache)
    print(json.dumps({'features':len(list(iter_boundaries(args.cache,sources))),
                      'settlement_qualification':sources[0]['settlement_qualification']},ensure_ascii=False))
