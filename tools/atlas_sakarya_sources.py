"""Isolated Sakarya producer KMZ reader; original 2024 geometry is never repaired.

The exact individual replacement list is evidence, not a country-wide override.
One unresolved spelling identity and any boundary disagreements remain visible
in the audit. Main-atlas integration is deliberately a separate operation.
"""
from __future__ import annotations

import gzip
import hashlib
from html.parser import HTMLParser
import io
import json
import math
from pathlib import Path
import re
import unicodedata
import xml.etree.ElementTree as ET
import zipfile

import shapely
from shapely.geometry import MultiPolygon, Polygon, mapping, shape

ROOT = Path(__file__).resolve().parents[1]
RAW = Path('audit/remaining8-second-pass-20261110/tr-lb-ma-cnm')
DIRECTORY = Path('sakarya-mahalle-20240515/v3')
SOURCE_ID = 'sakarya-original-mahalle-20240515'
DATASET_URL = 'https://veri.sakarya.bel.tr/dataset/92'
LICENSE_URL = 'https://veri.sakarya.bel.tr/license'
URL = 'https://veri.sakarya.bel.tr/dataset/67faf6a1-18d6-440c-89ed-7c5374edf70e/resource/eede1456-63d4-4fc9-805d-cfc435158995/download/mahalle-snrlar-kmz-verileri.kmz'
KMZ_SHA = 'd6befd154cda3e000c18378166a4f26d0208e7d0804099f686bca53cd8589a74'
KML_SHA = '1ab9401fd7a8472021cb35942b366f4e6f059ebfff9a2351b093a525dce5ac07'
BASELINE = Path('geofabrik-stage/turkey/normalized-TR-v4-r5-metropolitan-9fc82d8e3449.jsonl.gz')
BASELINE_SHA = '71dba0026f521a8440b555927d8faf163c78de189f8a0f0ebe5c4956b1fc68ad'
NS = {'k': 'http://www.opengis.net/kml/2.2'}
EXCLUDED_OSB = {'11634':'FERİZLİOSB', '11878':'SOĞUCAKOSB', '12216':'KABAKOZ OSB',
                '12843':'KARGALI HANBABAOSB', '12844':'SAKARYA I.ORGANİZE SANAYİ BÖLGESİ'}
# These are exact source-object / GF-object pairs, never fuzzy name rules.
ALIASES = {
    ('12233', 'geofabrik:TR:8:13763940'): {
        'source_name':'DAMLIK', 'target_name':'Esentepe Mahallesi', 'district':'Ferizli',
        'urls':['https://sakarya2lcik.adalet.gov.tr/kurum-mudurumuzun-mesaji'],
        'note':'Original Ministry of Justice page explicitly identifies Esentepe as former Damlık. No exact legal renaming date is inferred.'},
    ('13527', 'geofabrik:TR:8:13427021'): {
        'source_name':'ÇATALÖVEZ', 'target_name':'Çatalüvez Mahallesi', 'district':'Karasu',
        'urls':['https://www.karasu.bel.tr/muhtarliklarimiz', 'https://www.karasu.gov.tr/cataluvez'],
        'note':'Municipal source uses Çatalövez, district governor source uses Çatalüvez for the same unique Mahalle in Karasu. Original spellings retained.'},
    ('13662', 'geofabrik:TR:8:14156638'): {
        'source_name':'YENİ', 'target_name':'Yenimahalle Mahallesi', 'district':'Hendek',
        'urls':['https://www.hendek.bel.tr/haberler/yenimahalleye-semt-pazari-1'],
        'note':'The same municipal 2019 article explicitly uses Yeni Mahalle and Yenimahalle for the same neighbourhood.'},
}


def digest(data): return hashlib.sha256(data).hexdigest()


def write_immutable(path: Path, payload: bytes):
    path = Path(path)
    if path.exists():
        if path.read_bytes() != payload:
            raise ValueError('Immutable Sakarya artifact differs; create a new revision')
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False)+'\n').encode('utf8')


class _Cells(HTMLParser):
    def __init__(self):
        super().__init__(); self.cells = []; self.current = None

    def handle_starttag(self, tag, attrs):
        if tag == 'td': self.current = []

    def handle_data(self, data):
        if self.current is not None: self.current.append(data)

    def handle_endtag(self, tag):
        if tag == 'td' and self.current is not None:
            self.cells.append(' '.join(''.join(self.current).split())); self.current = None


def _ring(element):
    if element is None or not element.text:
        raise ValueError('Missing original KML ring')
    points = []
    for token in element.text.split():
        values = [float(v) for v in token.split(',')]
        if len(values) not in (2,3) or not all(math.isfinite(v) for v in values):
            raise ValueError('Non-finite original KML coordinate')
        if len(values) == 3 and values[2] != 0:
            raise ValueError('Unreviewed KML altitude')
        x,y = values[:2]
        if not -180 <= x <= 180 or not -90 <= y <= 90:
            raise ValueError('Non-geographic original KML coordinate')
        points.append((x,y))
    if len(points) < 4 or points[0] != points[-1]:
        raise ValueError('Original KML ring is not closed; no repair is permitted')
    return points


def parse_kml(payload):
    root = ET.fromstring(payload); records = []; seen = set()
    for pm in root.findall('.//k:Placemark', NS):
        identifier = pm.get('id')
        if not identifier or identifier in seen: raise ValueError('Duplicate/missing KML placemark identity')
        seen.add(identifier)
        cells = _Cells(); cells.feed(pm.findtext('k:description', '', NS))
        if len(cells.cells) % 2 != 1 and cells.cells: raise ValueError('Changed KML property table')
        properties = dict(zip(cells.cells[1::2], cells.cells[2::2]))
        polygons = []
        for p in pm.findall('.//k:Polygon', NS):
            outer = _ring(p.find('k:outerBoundaryIs/k:LinearRing/k:coordinates', NS))
            holes = [_ring(e) for e in p.findall('k:innerBoundaryIs/k:LinearRing/k:coordinates', NS)]
            polygons.append(Polygon(outer, holes))
        if not polygons: raise ValueError('Original KML placemark has no polygon')
        records.append({'placemark_id':identifier, 'name':pm.findtext('k:name', '', NS),
                        'original_properties':properties,
                        'geometry':polygons[0] if len(polygons)==1 else MultiPolygon(polygons)})
    return records


def read_pinned_kmz(payload):
    if len(payload) != 4560473 or digest(payload) != KMZ_SHA:
        raise ValueError('Changed pinned Sakarya KMZ')
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        if archive.namelist() != ['doc.kml']: raise ValueError('Changed pinned Sakarya members')
        member = archive.getinfo('doc.kml')
        if member.file_size != 12800420 or member.CRC != 0xf49de0dc:
            raise ValueError('Changed pinned Sakarya member size/CRC')
        data = archive.read(member)  # zipfile also verifies the original CRC.
    if digest(data) != KML_SHA: raise ValueError('Changed pinned Sakarya KML')
    return parse_kml(data)


def name_key(value):
    """Only Turkish case and explicit Mahalle suffixes, never ö/ü or rename guesses."""
    text = unicodedata.normalize('NFC', value.replace('I','ı').replace('İ','i')).casefold()
    text = re.sub(r'\b(?:mahallesi|mahalle|mah)\b', '', text)
    return ''.join(c for c in text if c.isalnum())


def qualify_record(record, parents):
    p = record['original_properties']; identifier = p.get('objectid','')
    if not identifier.isdecimal() or p.get('ad') != record['name'] or p.get('a_tarihi') != '15.05.2024':
        raise ValueError('Changed original Sakarya identity/date')
    if identifier in EXCLUDED_OSB:
        if record['name'] != EXCLUDED_OSB[identifier]: raise ValueError('Changed OSB identity')
        return None
    if identifier == '13252':
        if record['name'] != 'HASTAHANE' or p.get('ilce') != 'Akyazı':
            raise ValueError('Changed pending Hastahane identity')
        return None
    geometry = record['geometry']
    if geometry.is_empty or not geometry.is_valid or geometry.area <= 0: return None
    parent = parents.get(p.get('ilce'))
    if (not parent or parent.get('country') != 'TR' or parent.get('kind') != 'district'
            or parent.get('parent_id') != 'geofabrik:TR:4:223462' or parent.get('name') != p['ilce']):
        raise ValueError('Missing positively matched Sakarya district')
    return {'id':f'sakarya:mahalle:{identifier}', 'country':'TR', 'kind':'local_admin',
            'unit_type':'Mahalle', 'native_type':'Mahalle', 'name':record['name'],
            'name_known':True, 'original_name':record['name'], 'original_source_id':identifier,
            'official_national_code_known':False, 'original_properties':dict(p),
            'original_placemark_id':record['placemark_id'], 'geometry':geometry,
            'source':SOURCE_ID, 'parent_id':parent['id'], 'source_date':'2024-05-15',
            'parent_relationship':'Exact native district-name match to the existing Sakarya TR district',
            'native_role_evidence_urls':[DATASET_URL],
            'administrative_geometry_eligible':True}


def identity_binding(row, old):
    """Names/parents prove identity. IoU is separately measured, never a name matcher."""
    if (row.get('kind') != 'local_admin' or old.get('kind') != 'local_admin'
            or old.get('country') != 'TR' or row.get('parent_id') != old.get('parent_id')
            or not row['geometry'].is_valid or not old['geometry'].is_valid): return None
    method = 'same-native-name-and-district'; urls = [DATASET_URL]; note = ''
    if name_key(row['name']) != name_key(old['name']):
        alias = ALIASES.get((row['original_source_id'], old['id']))
        if (not alias or row['name'] != alias['source_name'] or old['name'] != alias['target_name']
                or row['original_properties']['ilce'] != alias['district']): return None
        method = 'explicit-primary-name-variant'; urls = alias['urls']; note = alias['note']
    intersection = row['geometry'].intersection(old['geometry']).area
    union = row['geometry'].union(old['geometry']).area
    return {'target_id':old['id'], 'replacement_id':row['id'], 'source_objectid':row['original_source_id'],
            'source_original_name':row['name'], 'target_original_name':old['name'],
            'district':row['original_properties']['ilce'], 'parent_id':row['parent_id'],
            'identity_method':method, 'evidence_urls':urls, 'identity_note':note,
            'geometry_intersection_over_union':intersection/union,
            'source_fraction_overlapping_target':intersection/row['geometry'].area,
            'target_fraction_overlapping_source':intersection/old['geometry'].area,
            'target_geometry_sha256':digest(old['geometry'].wkb),
            'source_geometry_sha256':digest(row['geometry'].wkb),
            'boundary_disagreement_requires_review':intersection/union < .5}


def conflict_quarantine(rows, previous, bindings, initial_retained, limit=70):
    """Bound an edition conflict by withholding whole source records, never geometry.

    A withheld new record's positively identified old counterpart becomes a
    fallback. It may expose the next conflict. This closure is deterministic;
    no fallback is removed and original geometry objects are left untouched.
    """
    if not 0 <= limit <= 70: raise ValueError('Sakarya conflict limit must be between0and70')
    old_by_id = {r['id']:r for r in previous}
    if not set(initial_retained) <= old_by_id.keys(): raise ValueError('Unknown retained fallback identity')
    replacement = {b['replacement_id']:b['target_id'] for b in bindings}
    if len(replacement) != len(bindings) or len(set(replacement.values())) != len(bindings):
        raise ValueError('Ambiguous source replacement mapping')
    if not set(replacement.values()) <= old_by_id.keys(): raise ValueError('Unknown replacement fallback identity')
    geometries = [r['geometry'] for r in rows]; tree = shapely.STRtree(geometries)
    retained = set(initial_retained); queue = sorted(retained); examined = set(); excluded = set(); steps = []
    while queue:
        old_id = queue.pop(0)
        if old_id in examined: continue
        examined.add(old_id); old = old_by_id[old_id]; g = old['geometry']
        if g.is_empty or not g.is_valid or g.area <= 0: raise ValueError('Invalid retained fallback geometry')
        for index in sorted(tree.query(g,predicate='intersects'), key=lambda i:rows[int(i)]['id']):
            row = rows[int(index)]
            if row['id'] in excluded: continue
            h = row['geometry']; intersection = g.intersection(h).area
            if intersection <= 1e-10: continue
            old_fraction = intersection/g.area; source_fraction = intersection/h.area
            if max(old_fraction,source_fraction) < .01: continue
            if len(excluded) >= limit:
                raise ValueError(f'Sakarya conflict quarantine limit{limit} would be exceeded; no output written')
            excluded.add(row['id']); target = replacement.get(row['id'])
            steps.append({'step':len(steps)+1,'trigger_retained_gf_id':old_id,
                          'trigger_original_name':old['name'],'excluded_source_id':row['id'],
                          'excluded_original_name':row['name'],'district':row['original_properties']['ilce'],
                          'intersection_degrees2':intersection,'fallback_fraction':old_fraction,
                          'new_original_fraction':source_fraction,'new_retained_gf_id':target,
                          'source_geometry_sha256':digest(h.wkb),'fallback_geometry_sha256':digest(g.wkb),
                          'reason':'Edition conflict ≥1% of either original polygon; whole new record withheld, no geometry changed'})
            if target and target not in retained:
                retained.add(target); queue.append(target); queue.sort()
    admitted = [r for r in rows if r['id'] not in excluded]
    active = [b for b in bindings if b['replacement_id'] not in excluded]
    remaining = []; conflict_count = 0
    for old_id in sorted(retained):
        g = old_by_id[old_id]['geometry']
        for row in admitted:
            h = row['geometry']
            if not g.intersects(h): continue
            intersection = g.intersection(h).area
            if intersection <= 1e-10: continue
            a,b = intersection/g.area,intersection/h.area
            if max(a,b) >= .01: conflict_count += 1
            remaining.append({'fallback_id':old_id,'source_id':row['id'],
                              'intersection_degrees2':intersection,'fallback_fraction':a,'new_original_fraction':b})
    if conflict_count: raise ValueError('Unresolved Sakarya fallback conflict after bounded closure')
    return admitted,active,{'limit':limit,'threshold_either_original_fraction':.01,
        'numerical_intersection_floor_degrees2':1e-10,'initial_retained_gf_ids':sorted(initial_retained),
        'retained_gf_ids':sorted(retained),'excluded_new_count':len(excluded),'steps':steps,
        'remaining_small_overlaps':remaining,'remaining_conflict_count':conflict_count,
        'no_geometry_repair_clipping_or_simplification':True}


def _verify(cache, source):
    path = cache/source['cache_file']
    if path.stat().st_size != source['bytes'] or digest(path.read_bytes()) != source['sha256']:
        raise ValueError('Changed immutable Sakarya normalized cache')
    audit = cache/source['qualification_audit_file']
    if not audit.is_file() or digest(audit.read_bytes()) != source['qualification_audit_sha256']:
        raise ValueError('Missing or changed immutable Sakarya qualification audit')


def prepare_sources(cache: Path) -> list[dict]:
    cache = Path(cache); directory = cache/DIRECTORY; receipt = directory/'sources.json'
    if receipt.exists():
        sources = json.loads(receipt.read_text(encoding='utf8'))['sources']
        for s in sources: _verify(cache, s)
        return sources
    raw = cache/RAW
    pinned = {'TR-Sakarya-dataset.body':'120fba7d6873458268cc2ea4a6666f5128382c3811e1f54374263556d6baca21',
              'TR-Sakarya-license.body':'adf280d7cb0deb30458dcb3d7cc17c811808c569a4c68960b8d83c3482007988',
              'TR-Esentepe-former-Damlik-primary.body':'097c481af2e8d9d48a2f4e4b5c8dd441c006c7fed3e913efdfbba61a8f6fec57'}
    for name, sha in pinned.items():
        if digest((raw/name).read_bytes()) != sha: raise ValueError('Changed Sakarya original terms/identity evidence')
    records = read_pinned_kmz((raw/'TR-Sakarya-kmz-bounded47.body').read_bytes())
    if len(records) != 677 or len({r['original_properties']['objectid'] for r in records}) != 677:
        raise ValueError('Changed Sakarya original inventory')
    if digest((cache/BASELINE).read_bytes()) != BASELINE_SHA: raise ValueError('Changed Sakarya comparison baseline')
    with gzip.open(cache/BASELINE, 'rt', encoding='utf8') as stream: baseline = [json.loads(line) for line in stream]
    parents = {r['name']:r for r in baseline if r.get('parent_id') == 'geofabrik:TR:4:223462' and r['kind']=='district'}
    if len(parents) != 16: raise ValueError('Changed Sakarya district inventory')
    old = [{**r, 'geometry':shape(r['geometry'])} for r in baseline
           if r.get('parent_id') in {p['id'] for p in parents.values()} and r['kind']=='local_admin']
    if len(old) != 198: raise ValueError('Changed Sakarya existing local inventory')
    admitted = []; exclusions = []; bindings = []
    for record in records:
        row = qualify_record(record, parents)
        if row is None:
            exclusions.append({**record, 'geometry':mapping(record['geometry']),
                'reason':'Explicit industrial OSB, not Mahalle' if record['original_properties']['objectid'] in EXCLUDED_OSB
                         else ('Unresolved exact identity to existing GF Hastane13999454; original retained, GF fallback remains'
                               if record['original_properties']['objectid']=='13252'
                               else 'Invalid unchanged original polygon; no repair performed'),
                'original_geometry_wkb_sha256':digest(record['geometry'].wkb)})
            continue
        hits = [b for previous in old if (b:=identity_binding(row, previous)) is not None]
        if len(hits) > 1: raise ValueError('Ambiguous Sakarya replacement identity')
        if hits:
            row['verified_replacement'] = hits[0]
            row['replaces_feature_ids'] = [hits[0]['target_id']]
            bindings.extend(hits)
        admitted.append(row)
    if len(admitted) != 669 or len(exclusions) != 8: raise ValueError('Changed Sakarya eligibility inventory')
    if len({b['target_id'] for b in bindings}) != len(bindings): raise ValueError('Repeated Sakarya replacement target')
    original_bindings = bindings[:]
    initial_retained = {r['id'] for r in old} - {b['target_id'] for b in bindings}
    before_quarantine = {r['id']:r for r in admitted}
    admitted, bindings, quarantine = conflict_quarantine(admitted, old, bindings, initial_retained)
    for step in quarantine['steps']:
        row = before_quarantine[step['excluded_source_id']]
        exclusions.append({**row,'geometry':mapping(row['geometry']),
                           'reason':'Whole original record withheld due to audited edition conflict with retained GF fallback',
                           'conflict_step':step, 'original_geometry_wkb_sha256':digest(row['geometry'].wkb)})
    if len(admitted) != 662 or len(bindings) != 189 or len(exclusions) != 15:
        raise ValueError('Changed bounded Sakarya edition-conflict result')
    unmatched = [{k:v for k,v in r.items() if k!='geometry'} for r in old if r['id'] not in {b['target_id'] for b in bindings}]
    # No union, buffer, clipping or simplification changes the original geometry.
    buffer = io.BytesIO()
    with gzip.GzipFile(fileobj=buffer, filename='', mode='wb', mtime=0) as stream:
        for row in sorted(admitted, key=lambda r:r['id']):
            stream.write((json.dumps({**row,'geometry':mapping(row['geometry'])},ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n').encode('utf8'))
    path = directory/'boundaries.jsonl.gz'; write_immutable(path, buffer.getvalue())
    audit = {'schema':1, 'country':'TR', 'source':SOURCE_ID, 'original_count':677,
             'ordinary_mahalle_count':672, 'valid_mahalle_count':670, 'admitted_mahalle_count':662, 'excluded_count':15,
             'excluded_unchanged_originals':exclusions, 'existing_gf_count':len(old),
             'verified_identity_bindings':bindings, 'original_positive_identity_bindings_before_conflict_quarantine':original_bindings,
             'retained_gf_records':unmatched, 'conflict_quarantine':quarantine,
             'geometry_conflicts':[b for b in bindings if b['boundary_disagreement_requires_review']],
             'baseline_file':BASELINE.as_posix(), 'baseline_sha256':BASELINE_SHA,
             'raw_kmz_sha256':KMZ_SHA, 'raw_kml_sha256':KML_SHA, 'raw_kml_crc32':'f49de0dc',
             'alias_policy':'Explicit exact-object pairs with primary evidence; overlap never invents aliases',
             'national_code_note':'Native objectid is a producer GIS object identity, not a documented national Mahalle code.'}
    auditpath = directory/'audit.json'; write_immutable(auditpath, json_bytes(audit))
    source = {'id':SOURCE_ID, 'country':'TR', 'scope_countries':['TR'], 'kind':'local_admin', 'unit_type':'Mahalle',
              'url':URL, 'dataset_url':DATASET_URL, 'date':'2024-05-15', 'metadata_updated':'2025-09-09',
              'source_unit_count':662, 'expected_unit_count':662, 'raw_source_unit_count':677,
              'cache_file':path.relative_to(cache).as_posix(), 'bytes':path.stat().st_size,
              'sha256':digest(path.read_bytes()), 'license':'Sakarya Açık Veri Lisansı (original terms snapshot)',
              'license_url':LICENSE_URL, 'license_original_sha256':pinned['TR-Sakarya-license.body'],
              'attribution':'Sakarya Büyükşehir Belediyesi, Coğrafi Bilgi Sistemleri Şube Müdürlüğü; Mahalle Sınırları, 15.05.2024',
              'replacement_scope':'feature', 'replaces_feature_ids':sorted(b['target_id'] for b in bindings),
              'feature_replacement_evidence':[
                  {'source_unit_id':b['replacement_id'], 'original_source_id':b['source_objectid'],
                   'replaces_feature_id':b['target_id'], 'identity_method':b['identity_method'],
                   'evidence_urls':b['evidence_urls'], 'identity_note':b['identity_note'],
                   'source_original_name':b['source_original_name'], 'target_original_name':b['target_original_name'],
                   'district':b['district'], 'parent_id':b['parent_id'],
                   'target_geometry_sha256':b['target_geometry_sha256'],
                   'source_geometry_sha256':b['source_geometry_sha256'],
                   'geometry_intersection_over_union':b['geometry_intersection_over_union'],
                   'source_geometry_date':'2024-05-15', 'target_geometry_snapshot':'2026-11-08T21:21:00Z',
                   'boundary_disagreement_requires_review':b['boundary_disagreement_requires_review']}
                  for b in sorted(bindings,key=lambda x:x['target_id'])],
              'geometry_conflict_feature_ids':sorted(b['replacement_id'] for b in bindings if b['boundary_disagreement_requires_review']),
              'qualification_audit_file':auditpath.relative_to(cache).as_posix(),
              'qualification_audit_sha256':digest(auditpath.read_bytes()), 'blocks_full_coverage_claim':True,
              'merge_review_required':True, 'unresolved_existing_feature_ids':[r['id'] for r in unmatched],
              'retained_fallback_feature_ids':quarantine['retained_gf_ids'],
              'coverage_note':'662 originale Mahalle-Flächen in Sakarya zugelassen. Von 677 Originalobjekten bleiben fünf Industriegebiete, zwei ungültige Mahalle-Polygone, Hastahane 13252 mit ungeklärter Schreibidentität und sieben konkret auditierte Editionskonflikte ausgeschlossen. Neun vorhandene GF-Flächen bleiben unveränderte Rückfallquellen. Kein vollständiger heutiger Behördenbestand behauptet.',
              'territorial_scope_note':'Nur Sakarya; 189 einzeln positiv identifizierte GF-Objekte können ersetzt werden. Originalkoordinaten vom 15.05.2024, Portalmetadaten vom 09.09.2025, GF-Vergleichsstand 08.11.2026. Fünf starke Geometrieabweichungen bleiben im Audit sichtbar. Die begrenzte Konfliktquarantäne verändert keine Grenze; verbleibende Alt/Neu-Überlappungen liegen jeweils unter 1 % beider Flächen. Namensbelege und aktuelle Lizenz machen die Originalgrenzen nicht vermessungsaktuell für 2026. Keine ganze Türkei- oder Metropolfläche wird ersetzt.'}
    write_immutable(receipt, json_bytes({'schema':1,'sources':[source]}))
    manifest = ROOT/'data/atlas_sakarya_sources.json'
    temporary = manifest.with_suffix('.json.tmp')
    temporary.write_bytes(json_bytes({'schema':1,'sources':[source]})); temporary.replace(manifest)
    return [source]


def iter_boundaries(cache: Path, sources: list[dict]):
    for source in sources:
        if source.get('id') != SOURCE_ID or source.get('kind') != 'local_admin' or source.get('country') != 'TR':
            raise ValueError('Unreviewed Sakarya source identity')
        _verify(Path(cache), source); seen = set()
        with gzip.open(Path(cache)/source['cache_file'], 'rt', encoding='utf8') as stream:
            for line in stream:
                row = json.loads(line); geometry = shape(row['geometry'])
                if (row['id'] in seen or row['kind'] != 'local_admin' or row['source'] != SOURCE_ID
                        or not geometry.is_valid or geometry.is_empty or row['original_source_id'] in EXCLUDED_OSB):
                    raise ValueError('Changed Sakarya normalized identity/eligibility')
                row['geometry'] = geometry; seen.add(row['id']); yield row
        if len(seen) != source['expected_unit_count']: raise ValueError('Changed Sakarya normalized inventory')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(); parser.add_argument('--cache', type=Path, default=ROOT/'.tools/atlas_sources')
    args = parser.parse_args(); sources = prepare_sources(args.cache)
    print(json.dumps({'sources':sources, 'validated_records':sum(1 for _ in iter_boundaries(args.cache,sources))},ensure_ascii=True,indent=2))
