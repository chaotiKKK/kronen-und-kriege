"""Official DLS territory joined to the post-reform CYSTAT2026 identities.

Twenty current municipalities use exact unions of their officially coded DLS
components. Municipal quarters and statistical community territories remain
local_admin; their existence does not establish an independently elected council.
Cyprus, the UN buffer and overlapping SBA civil areas retain separate masks.
The actual northern municipal system is outside this provider's admission.
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
import xml.etree.ElementTree as ET
import zipfile

from shapely.geometry import shape
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE = ROOT/'.tools/atlas_sources'
DIRECTORY = 'audit/cy-ir-ma-current-20261110'
SOURCE_ID = 'DLS-CY-reform2024-CYSTAT20260609'
SBA_SOURCE_ID = 'DLS-SBA-overlapping-local-areas-2024-CYSTAT20260609'
LICENSE_PAGE = 'https://www.data.gov.cy/en/dataset/187'
CLASSIFICATION_URL = 'https://www.cystat.gov.cy/el/Announcement?id=74185'
CYSTAT_REUSE = 'https://www.cystat.gov.cy/el/StaticPage?id=1490'
SBA_COMMUNITIES = 'https://www.sbaadministration.org/home/legislation/01_02_09_05_ORDINANCES/01_02_09_05_65_ORD_2024/20240628_ORD-13_G2093.pdf'
SBA_MUNICIPALITIES = 'https://www.sbaadministration.org/home/legislation/01_02_09_05_ORDINANCES/01_02_09_05_65_ORD_2024/20240628_ORD-14_G2093.pdf'
# Positive CYSTAT identities mapped to the official DLS municipality index.
# The other DLS15 objects are service complexes and Dekeleia, not municipalities.
MUNICIPALITIES = {
    '11010000':32, '11021012':2, '11030000':33, '11040000':34, '11050000':35,
    '31010000':47, '31020000':48, '41010000':43, '41020000':42, '41030000':49,
    '41040000':41, '41050000':40, '51010000':38, '51020000':39, '51030000':37,
    '51040000':36, '61016000':1, '61020000':46, '61030000':45, '61040000':44}
SBA_OVERLAPS = {'31033000':('Ammochostos','3000'), '31063202':('Lysi','3202')}
SBA_SCOPE_NOTICE = (
    'Nur die innerhalb des unveränderten ESB-Rahmens liegenden Original-DLS-Teile '
    'von Ammochostos und Lysi werden als gesetzlich anerkannte überlappende örtliche '
    'Verwaltungsgebiete dargestellt. Ordinance 14/2024, §§ 2, 6, 42, 43 und 155, '
    'belegt Rechtspersönlichkeit und zivile örtliche Aufgaben im Basisanteil. '
    'Nach §§ 160–161 gelten Ausnahmen für Crown-Eigentum und Militärliegenschaften; '
    'auf militärischen Grundstücken gilt die Verordnung nur im Umfang einer '
    'öffentlichen Anordnung des Administrators. Daraus folgt keine tatsächliche '
    'uneingeschränkte Machtausübung auf jedem Grundstück. Es entstehen keine neuen '
    'Gemeinden, keine CYN-Einträge und keine Zuständigkeiten außerhalb ESB.')
PINNED_INPUTS = [{'cache_file': 'audit/cy-ir-ma-current-20261110/CY-layer11-original.geojson',
  'url': 'https://eservices.dls.moi.gov.cy/arcgis/rest/services/National/AdminBoundaries_Indexes_GR/MapServer/11/query?where=1%3D1&outFields=%2A&returnGeometry=true&outSR=4326&f=geojson',
  'bytes': 22806472,
  'sha256': 'ec0cb841e862486ab6921732b7fca5e7df370863f2fe987e04659310d425d7fd'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CY-DLS-layer11-metadata.json',
  'url': 'https://eservices.dls.moi.gov.cy/arcgis/rest/services/National/AdminBoundaries_Indexes_GR/MapServer/11?f=pjson',
  'bytes': 4326,
  'sha256': '0a798820d832ee4addd676bd0046f80835417b98995617e92dd083f3b3a19465'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CY-layer15-attributes.json',
  'url': 'https://eservices.dls.moi.gov.cy/arcgis/rest/services/National/AdminBoundaries_Indexes_GR/MapServer/15/query?where=1%3D1&outFields=%2A&returnGeometry=false&f=json',
  'bytes': 15119,
  'sha256': '79284256fdec915f5396ccf34477d95ccb13a216d7f82405c7bdf6236575e90d'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CY-DLS-layer15-metadata.json',
  'url': 'https://eservices.dls.moi.gov.cy/arcgis/rest/services/National/AdminBoundaries_Indexes_GR/MapServer/15?f=pjson',
  'bytes': 5034,
  'sha256': 'bc5bef98697bb65c4e637612d2c6038a6b4dd93b2e020548cbc5c5d8250eaf9c'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CY-geocodes-20260609.xlsx',
  'url': 'https://library.cystat.gov.cy/NEW/Geocodes_with%20Toponyms-EN-090626.xlsx',
  'bytes': 153859,
  'sha256': 'cec2ff44b08ef84a6c78355a4a29d2ad472b33c3f0431ba53d6a0f5877c9e3b5'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CY-DLS-opendata-license.html',
  'url': 'https://www.data.gov.cy/en/dataset/187',
  'bytes': 67307,
  'sha256': 'aecac21fd58943d754139730dfb8731bb6dbbb32f67c098755ff46554acb8f46'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CY-CYSTAT-20260609-announcement.html',
  'url': 'https://www.cystat.gov.cy/el/Announcement?id=74185',
  'bytes': 54112,
  'sha256': '23589987794a81da7a46f66014a316d0e3a266a74e8390ede360abd4a12ea70b'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/SBA-overlapping-communities-2024.pdf',
  'url': 'https://www.sbaadministration.org/home/legislation/01_02_09_05_ORDINANCES/01_02_09_05_65_ORD_2024/20240628_ORD-13_G2093.pdf',
  'bytes': 1212832,
  'sha256': '8d43fde76b5e11b285f317a2a516f3170a8f73e48fd95832f70906ce7d60866f'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/SBA-overlapping-municipalities-2024.pdf',
  'url': 'https://www.sbaadministration.org/home/legislation/01_02_09_05_ORDINANCES/01_02_09_05_65_ORD_2024/20240628_ORD-14_G2093.pdf',
  'bytes': 1281234,
  'sha256': '0aca7c3928976359b3655bfa3d236235bbdef230e7b72f5133f73833968a1cdc'},
 {'cache_file': 'audit/cy-ir-ma-current-20261110/CY-CYSTAT-reuse-policy.html',
  'url': 'https://www.cystat.gov.cy/el/StaticPage?id=1490',
  'bytes': 55592,
  'sha256': '776b27375d8d82a2504e79367a9dd78e17c34fa863f164cb31ae62a674538f0b'}]


def read_geocodes(payload: bytes) -> list[dict]:
    """Read the named official 8-digit sheet, not the 10-digit quarter table."""
    main='{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
    rel='{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        workbook=ET.fromstring(archive.read('xl/workbook.xml'))
        sheets=[s for s in workbook.findall(main+'sheets/'+main+'sheet')
                if s.get('name')=='GEOCODES_8 digits_All Districts']
        if len(sheets)!=1:
            raise ValueError('Missing/ambiguous current CYSTAT8-digit classification sheet')
        relationships=ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))
        targets=[r.get('Target') for r in relationships if r.get('Id')==sheets[0].get(rel+'id')]
        if len(targets)!=1:
            raise ValueError('Missing CYSTAT worksheet relationship')
        target=targets[0].lstrip('/')
        if not target.startswith('xl/'):
            target='xl/'+target
        strings=[]
        if 'xl/sharedStrings.xml' in archive.namelist():
            strings=[''.join(t.text or '' for t in item.iter(main+'t'))
                     for item in ET.fromstring(archive.read('xl/sharedStrings.xml'))]
        document=ET.fromstring(archive.read(target))
        records=[]
        for row in document.findall(main+'sheetData/'+main+'row'):
            cells={}
            for cell in row.findall(main+'c'):
                value=cell.find(main+'v')
                if cell.get('t')=='inlineStr':
                    text=''.join(n.text or '' for n in cell.iter(main+'t'))
                elif value is not None:
                    text=strings[int(value.text)] if cell.get('t')=='s' else value.text
                else:continue
                cells[re.sub(r'\d','',cell.get('r',''))]=text
            code=cells.get('A','').strip()
            if not re.fullmatch(r'\d{8}',code):
                continue # table headings and explanatory footnotes
            role=cells.get('B','').strip()
            if role not in ('MUNICIPALITY','MUNICIPAL QUARTER','COMMUNITY'):
                raise ValueError('Unexpected current CYSTAT territorial role')
            records.append({'code':code,'role':role,'name':cells.get('C','').strip(),
                            'previous_code':cells.get('D','').strip(),'territorial_note':cells.get('E','').strip()})
    if len({r['code'] for r in records})!=len(records):
        raise ValueError('Duplicate current CYSTAT geographical identity')
    return records


def components_for(municipality: dict, records: list[dict], originals: dict) -> list[dict]:
    previous=municipality['previous_code']
    components=[municipality] if re.fullmatch(r'\d{4}',previous) else [r for r in records
                if r['role']=='MUNICIPAL QUARTER' and r['code'][:4]==municipality['code'][:4]]
    if not components:
        raise ValueError('Current municipality has no official original components')
    missing=[r['previous_code'] for r in components if r['previous_code'] not in originals]
    if missing:
        raise ValueError('Missing original DLS municipality components: '+','.join(missing))
    return [{'previous_code':r['previous_code'],'geometry':originals[r['previous_code']]['geometry']}
            for r in components]


def qualify_unit(record: dict, geometry):
    code = record['code']
    if not re.fullmatch(r'\d{8}',code) or not record.get('name'):
        raise ValueError('Invalid current CYSTAT territorial identity')
    role = record['role']
    if role not in ('COMMUNITY','MUNICIPAL QUARTER'):
        raise ValueError('This original territorial component is not an independent current municipality')
    if geometry.is_empty or not geometry.is_valid or geometry.geom_type not in ('Polygon','MultiPolygon'):
        raise ValueError('Invalid original DLS territorial polygon; no repair is authorized')
    row = {'id':'dls:CY:local:'+code, 'country':'CY','name':record['name'],
           'name_known':True,'original_name':record['name'],'kind':'local_admin','geometry':geometry,
           'parent_id':'country:CY','source':SOURCE_ID,'geographical_code':code,
           'previous_geographical_code':record['previous_code'],'source_role':role,
           'unit_type':'Δημοτικό διαμέρισμα / Municipal quarter' if role=='MUNICIPAL QUARTER' else 'Κοινότητα / Territorial community',
           'territorial_note':record.get('territorial_note',''),
           'role_evidence_url':CLASSIFICATION_URL,'source_date':'2024-07-01',
           'classification_date':'2026-06-09','geometry_modified_by_importer':False,
           'independent_council_status':'Not inferred from a statistical geographical code'}
    if role == 'MUNICIPAL QUARTER':
        parents = [key for key in MUNICIPALITIES if key[:4]==code[:4]]
        if len(parents)!=1:
            raise ValueError('Municipal quarter lacks its verified current parent municipality')
        row['parent_id'] = 'dls:CY:municipality:'+parents[0]
        row['source_parent_id'] = row['parent_id']
    return row


def assemble_municipality(record: dict, parts: list[dict], index: dict):
    code=record['code']
    if (code not in MUNICIPALITIES or record['role']!='MUNICIPALITY'
            or index.get('OBJECTID')!=MUNICIPALITIES[code]
            or not index.get('NAME_ENG','').startswith('Dimos ')
            or not index.get('NAME_GR','').startswith('Δήμος ')):
        raise ValueError('No positive current municipal identity in the official DLS/CYSTAT crosswalk')
    if not parts or len({p['previous_code'] for p in parts})!=len(parts):
        raise ValueError('Missing/duplicate original municipality component')
    if any(p['geometry'].is_empty or not p['geometry'].is_valid for p in parts):
        raise ValueError('Invalid original municipality component; no automatic repair')
    geometry=unary_union([p['geometry'] for p in parts])
    if geometry.is_empty or not geometry.is_valid:
        raise ValueError('Original component union does not form a valid municipality')
    return {'id':'dls:CY:municipality:'+code,'country':'CY','name':record['name'],
            'name_known':True,'original_name':record['name'],'source_names':{'el':index['NAME_GR'],'en':record['name']},
            'kind':'municipality','geometry':geometry,'parent_id':'country:CY','source':SOURCE_ID,
            'geographical_code':code,'unit_type':'Δήμος / Municipality','source_role':'MUNICIPALITY',
            'source_dls_index':index,'territorial_note':record.get('territorial_note',''),
            'source_part_ids':['dls:CY:old:'+p['previous_code'] for p in parts],
            'source_part_official_codes':[p['previous_code'] for p in parts],
            'role_evidence_url':CLASSIFICATION_URL,'reform_effective_date':'2024-07-01',
            'classification_date':'2026-06-09','geometry_modified_by_importer':len(parts)>1,
            'geometry_derivation':'Union of original DLS components according to official CYSTAT2026 membership codes; no gap filling'}


def qualify_sba_overlap(record: dict, original: dict):
    """Keep the positively identified original; only the merger clips to ESB."""
    expected=SBA_OVERLAPS.get(record.get('code'))
    properties=original['properties']
    original_code=str(properties['DIST_CODE'])+str(properties['VIL_CODE']).zfill(3)
    if (expected is None or record.get('role')!='MUNICIPALITY'
            or (record.get('name'),record.get('previous_code'))!=expected
            or original_code!=expected[1]):
        raise ValueError('No exact positive DLS/CYSTAT identity for the statutory ESB overlap')
    geometry=original['geometry']
    if geometry.is_empty or not geometry.is_valid or geometry.geom_type not in ('Polygon','MultiPolygon'):
        raise ValueError('Invalid original DLS overlap; no repair or guessed geometry')
    return {'id':'dls:ESB:overlap:'+record['code'],'country':'ESB',
            'source_country':'CY','original_source_country':'CY',
            'name':record['name'],'name_known':True,'original_name':record['name'],
            'source_original_name':properties.get('VIL_NM_G'),
            'kind':'local_admin','geometry':geometry,'parent_id':'country:ESB',
            'source':SBA_SOURCE_ID,'source_unit_id':'dls:CY:municipality:'+record['code'],
            'geographical_code':record['code'],'previous_geographical_code':record['previous_code'],
            'source_role':'MUNICIPALITY','source_dls_properties':properties,
            'source_part_ids':['dls:CY:old:'+record['previous_code']],
            'unit_type':'Überlappendes ziviles Kommunalgebiet (SBA)',
            'source_unit_type':'Δήμος / Municipality',
            'territorial_note':record.get('territorial_note',''),
            'territorial_part':True,'geometry_modified_by_importer':False,
            'geometry_derivation':'Original DLS polygon retained unchanged; explicit ESB-only territorial clipping is performed by the atlas merger',
            'classification_date':'2026-06-09','role_evidence_url':SBA_MUNICIPALITIES,
            'role_legal_sections':[2,6,42,43,155], 'role_limiting_sections':[160,161],
            'territorial_scope_note':SBA_SCOPE_NOTICE,
            'country_assignment_method':'statutory_ESB_scope_requires_explicit_clip',
            'actual_unrestricted_exercise_of_powers_verified':False}


def verified_file(cache: Path, receipt: dict) -> Path:
    root=Path(cache).resolve();path=(root/receipt['cache_file']).resolve()
    if not path.is_relative_to(root):
        raise ValueError('Cyprus source path leaves its declared cache')
    raw=path.read_bytes()
    if len(raw)!=receipt['bytes'] or hashlib.sha256(raw).hexdigest()!=receipt['sha256']:
        raise ValueError('Changed original Cyprus source bytes/hash: '+path.name)
    return path


def _read_rows(cache: Path):
    files={Path(p['cache_file']).name:verified_file(cache,p) for p in PINNED_INPUTS}
    records=read_geocodes(files['CY-geocodes-20260609.xlsx'].read_bytes())
    if Counter(r['role'] for r in records)!={'MUNICIPALITY':29,'MUNICIPAL QUARTER':91,'COMMUNITY':511}:
        raise ValueError('The original CYSTAT2026 role inventory changed')
    document=json.loads(files['CY-layer11-original.geojson'].read_text(encoding='utf-8'))
    if document.get('type')!='FeatureCollection' or document.get('exceededTransferLimit') or len(document.get('features',[]))!=613:
        raise ValueError('The original DLS community/component geometry is incomplete')
    originals={}
    for feature in document['features']:
        p=feature['properties'];code=str(p['DIST_CODE'])+str(p['VIL_CODE']).zfill(3)
        if not re.fullmatch(r'\d{4}',code) or code in originals:
            raise ValueError('Invalid/duplicate original DLS geographical code')
        geometry=shape(feature['geometry'])
        if geometry.is_empty or not geometry.is_valid or geometry.geom_type not in ('Polygon','MultiPolygon'):
            raise ValueError('Invalid original DLS area; no automatic geometry repair')
        originals[code]={'geometry':geometry,'properties':p}
    previous=[r['previous_code'] for r in records if re.fullmatch(r'\d{4}',r['previous_code'])]
    if len(previous)!=613 or set(previous)!=set(originals):
        raise ValueError('DLS components do not match the official current/previous CYSTAT crosswalk')
    inventory=json.loads(files['CY-layer15-attributes.json'].read_text(encoding='utf-8'))
    index={f['attributes']['OBJECTID']:f['attributes'] for f in inventory['features']}
    if (len(index)!=50 or inventory.get('exceededTransferLimit')
            or {p['OBJECTID'] for p in index.values() if p.get('NAME_ENG','').startswith('Dimos ')}!=set(MUNICIPALITIES.values())):
        raise ValueError('Official DLS municipality/service-complex index changed')
    rows=[]
    for record in records:
        if record['code'] in MUNICIPALITIES:
            parts=components_for(record,records,originals)
            rows.append(assemble_municipality(record,parts,index[MUNICIPALITIES[record['code']]]))
        elif record['role'] in ('COMMUNITY','MUNICIPAL QUARTER'):
            original=originals[record['previous_code']]
            row=qualify_unit(record,original['geometry'])
            row.update(source_original_name=original['properties']['VIL_NM_G'],
                       source_dls_properties=original['properties'],
                       source_part_ids=['dls:CY:old:'+record['previous_code']])
            rows.append(row)
        # The other nine Republic municipalities are territorial claims in the
        # north, not the currently effective eighteen-municipality CYN system.
    if Counter(r['kind'] for r in rows)!={'municipality':20,'local_admin':602}:
        raise ValueError('Unexpected qualified Cyprus role counts')
    return rows,records


def _source_record(rows):
    canonical=json.dumps(PINNED_INPUTS,sort_keys=True,separators=(',',':')).encode('utf-8')
    return {'id':SOURCE_ID,'country':'CY','country_iso3':'CYP',
        'scope_countries':['CY','CNM','ESB','WSB'],'kind':'municipality',
        'replacement_scope':'country','merge_priority':4,
        'url':LICENSE_PAGE,'metadata_url':CLASSIFICATION_URL,
        'date':'2024-07-01 reform; CYSTAT2026-06-09; DLS retrieval2026-11-10',
        'license':'CC BY4.0 (DLS geometry); CYSTAT attribution/reuse policy (classification)',
        'license_url':'https://creativecommons.org/licenses/by/4.0/',
        'license_evidence_url':LICENSE_PAGE,
        'attribution':'© Republic of Cyprus, Department of Lands and Surveys, CC BY4.0; © Republic of Cyprus, Statistical Service, geographical codes2026. Für den Atlas wurden kommunale Originalflächen vereinigt und Klassifikationen zugeordnet. CYSTAT übernimmt keine Verantwortung für diese Bearbeitung oder ihre Folgen; keine amtliche Unterstützung wird behauptet.',
        'license_layers':[
            {'scope':'DLS geometry and native labels','license':'CC BY4.0','url':LICENSE_PAGE},
            {'scope':'CYSTAT2026 geographical codes and names','license':'CYSTAT free commercial/non-commercial reuse with attribution; modification notice and liability disclaimer','url':CYSTAT_REUSE}],
        'unit_type':'Δήμος; Δημοτικό διαμέρισμα; Κοινότητα (territorial community)',
        'files':PINNED_INPUTS,'bytes':sum(r['bytes'] for r in PINNED_INPUTS),
        'sha256':hashlib.sha256(canonical).hexdigest(),
        'hash_scope':'SHA256 of the canonical ordered original input receipts; every original file is separately pinned',
        'source_feature_count':613,'source_unit_count':len(rows),'normalized_unit_count':len(rows),
        'role_counts':dict(Counter(r['kind'] for r in rows)),
        'municipal_authorities':20,'municipal_quarters':91,'territorial_communities':511,
        'excluded_claimed_northern_municipalities':9,
        'blocks_full_coverage_claim':False,
        'blocks_full_coverage_claim_countries':['CNM'],
        'territorial_review_caveats':{'CNM':'Die Quelle belegt territoriale Teile der Republik Zypern, aber keine kommunalen UN-Körperschaften oder tatsächlich flächendeckend ausgeübte Gemeindebefugnisse im UN-Puffer. Diese gebietsbezogene Rollenprüfung bleibt offen.'},
        'territorial_scope_note':'Die ursprünglichen DLS-Ortsgebiete und nach der Reform vereinigten Gemeindeflächen werden nur an den unabhängigen Länderrahmen CY, CNM, ESB und WSB geteilt. Die SBA-Verordnungen 13/2024 und 14/2024 belegen überlappende zivile Gemeinde- und Community-Aufgaben innerhalb der Basen; keine gesamte Basis und kein UN-Puffer wird dadurch zur Gemeinde. Die eigene nördliche Kommunalverwaltung CYN wird von dieser Quelle nicht importiert. Die zusätzlichen ESB-Teile von Lysi und Ammochostos gehören ausschließlich zur getrennten, ausdrücklich auf ESB begrenzten Zusatzquelle mit ihren Crown- und Militärausnahmen.',
        'coverage_note':'Nach den zwei gesondert gesetzlich qualifizierten ESB-Ergänzungen ergibt der Originaldatenvergleich gegen den unveränderten unabhängigen Länderrahmen für ESB rund 95,60 % örtliche Flächenabdeckung; rund 5,61 km² Restfläche bleiben offen. Die Werte bezeichnen weder eine vollständige amtliche Grenzvermessung noch überall tatsächlich ausgeübte Gemeindebefugnisse. Rundungen der Atlasdarstellung können geringfügig abweichen. Für CNM bleibt die gesonderte territoriale Rollenprüfung bestehen.',
        'role_evidence_urls':[CLASSIFICATION_URL,SBA_COMMUNITIES,SBA_MUNICIPALITIES],
        'unit_semantics':{'render_role':'20 municipalities plus distinct local_admin territorial units',
            'geometry':'Exact original DLS component polygons, united only for the official current municipal membership codes',
            'classification_date':'2026-06-09','reform_effective_date':'2024-07-01',
            'community_council_caveat':'511 statistical community territories do not establish511 independently elected councils. The ministry reports286 councils in government-controlled areas and137 in the north; no per-territory council identity is inferred.',
            'coverage_status':'CY und die belegten überlappenden örtlichen SBA-Rollen sind qualifiziert. Einschließlich der getrennten ESB-Zusatzquelle liegt der Originaldatenvergleich dort bei rund 95,60 %; rund 5,61 km² geometrische Restfläche bleiben offen. Die territoriale Abdeckung in CNM ist getrennt von der weiterhin offenen Befugnisfrage zu betrachten; keine kommunale UN-Körperschaft wird daraus abgeleitet.'}}


def _read_sba_rows(cache: Path, records: list[dict]):
    document=json.loads(verified_file(cache,PINNED_INPUTS[0]).read_text(encoding='utf-8'))
    originals={str(f['properties']['DIST_CODE'])+str(f['properties']['VIL_CODE']).zfill(3):
               {'geometry':shape(f['geometry']),'properties':f['properties']}
               for f in document['features']}
    identities=[record for record in records if record['code'] in SBA_OVERLAPS]
    if {r['code'] for r in identities}!=set(SBA_OVERLAPS) or len(identities)!=2:
        raise ValueError('The two statutory ESB identities are missing or duplicated')
    return [qualify_sba_overlap(record,originals[record['previous_code']]) for record in identities]


def _sba_source_record(rows):
    # Exact original receipts and attribution, but a separate additive scope.
    common=_source_record([])
    shared=('url','metadata_url','date','license','license_url','license_evidence_url',
            'attribution','license_layers','files','bytes','sha256','hash_scope')
    return {**{key:common[key] for key in shared},
        'id':SBA_SOURCE_ID,'country':'ESB','country_iso3':'ESB',
        'scope_countries':['ESB'],'kind':'local_admin','replacement_scope':'feature',
        'merge_priority':4,'clip_to_scope':True,
        'scope_clip_reference_source':'natural-earth-countries',
        'scope_clip_basis':'Exact original DLS polygons intersected only with the unchanged Natural Earth ESB territorial frame; no territory is imported outside ESB',
        'scope_clip_evidence_url':SBA_MUNICIPALITIES,
        'unit_type':'Gesetzlich anerkanntes überlappendes örtliches Verwaltungsgebiet (SBA)',
        'source_feature_count':613,'qualified_original_feature_count':2,
        'source_unit_count':len(rows),'normalized_unit_count':len(rows),
        'role_counts':dict(Counter(r['kind'] for r in rows)),
        'municipal_authorities_created':0,'blocks_full_coverage_claim':False,
        'territorial_scope_note':SBA_SCOPE_NOTICE,
        'coverage_note':'Diese additive Quelle qualifiziert ausschließlich zwei vorhandene territoriale ESB-Teile. Sie bescheinigt keine vollständige Flächenabdeckung oder uneingeschränkte tatsächliche Gemeindemacht; die übrige geometrische Restlücke bleibt gemessen.',
        'role_evidence_urls':[CLASSIFICATION_URL,SBA_MUNICIPALITIES],
        'role_legal_sections':[2,6,42,43,155], 'role_limiting_sections':[160,161],
        'legal_reference':{'ordinance':'Overlapping Municipalities Ordinance 14/2024',
            'published':'2024-06-28','positive_sections':[2,6,42,43,155],
            'positive_pdf_pages':[6,7,8,9,10,32],'limiting_sections':[160,161],
            'limiting_pdf_pages':[33,34],
            'section_number_note':'The actual Council section is155; the table of contents calls it156.'},
        'evidence':[{'country':'ESB','title':'SBA Ordinance 14/2024: überlappende örtliche Aufgaben und Crown-/Militärausnahmen','url':SBA_MUNICIPALITIES}],
        'unit_semantics':{'reference_note':'Positiver gesetzlicher territorialer Rollennachweis; keine neue Gemeinde und kein Beleg tatsächlich uneingeschränkter Kompetenzausübung auf Militärliegenschaften.'}}


def prepare_sources(cache: Path=DEFAULT_CACHE):
    cache=Path(cache)
    for receipt in PINNED_INPUTS:
        path=(cache/receipt['cache_file']).resolve()
        if not path.is_relative_to(cache.resolve()):
            raise ValueError('Cyprus source cache path escapes root')
        if not path.exists():
            path.parent.mkdir(parents=True,exist_ok=True)
            stage=path.with_suffix(path.suffix+'.part')
            result=subprocess.run(['curl.exe','--fail','--location','--silent','--show-error',
                '--connect-timeout','15','--max-time','90','--max-filesize',str(receipt['bytes']+1),
                '--output',str(stage),receipt['url']],capture_output=True,text=True)
            if result.returncode:
                raise RuntimeError('Pinned Cyprus source fetch failed: '+result.stderr)
            payload=stage.read_bytes()
            if len(payload)!=receipt['bytes'] or hashlib.sha256(payload).hexdigest()!=receipt['sha256']:
                raise ValueError('Public Cyprus source changed from the pinned snapshot')
            stage.replace(path)
        verified_file(cache,receipt)
    rows,records=_read_rows(cache)
    overlap_rows=_read_sba_rows(cache,records)
    sources=[_source_record(rows),_sba_source_record(overlap_rows)]
    manifest={'schema':1,'sources':sources,'official_role_identities':records,
              'note':'Raw legal documents stay only in the ignored build cache; runtime metadata contains factual identities, links and hashes.'}
    (ROOT/'data/atlas_cyprus_sources.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return sources


def iter_boundaries(cache: Path,sources: list[dict]):
    rows,records=_read_rows(Path(cache))
    overlap_rows=_read_sba_rows(Path(cache),records)
    if sources!=[_source_record(rows),_sba_source_record(overlap_rows)]:
        raise ValueError('Changed Cyprus source identity, roles, licensing or territorial scope')
    yield from rows
    yield from overlap_rows


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache',type=Path,default=DEFAULT_CACHE)
    args=parser.parse_args()
    selected=prepare_sources(args.cache)
    rows=list(iter_boundaries(args.cache,selected))
    print(json.dumps({'features':len(rows),'roles':dict(Counter(r['kind'] for r in rows)),
                      'municipalities':20,'municipal_quarters':91,'territorial_communities':511,
                      'SBA_overlapping_local_areas':2}))
