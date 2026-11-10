"""Bounded audit of BO6964 legal coordinates and original OSM physical courses.

The public factual source is sufficient for offline reproduction. Original PDF
and XML stay private; no personal OSM metadata is copied. Reconstruction follows
each printed decision separately. It never creates a residual municipality or
silently replaces a required natural course by a straight chord. Current
candidates are audit-only because the two texts disagree on a shared road
segment and some physical-course endpoint offsets remain unresolved.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import sys

from shapely.geometry import LineString, Point, Polygon
from shapely.ops import polygonize, substring, transform, unary_union
from shapely.validation import explain_validity

ROOT=Path(__file__).resolve().parents[1]
DEFAULT_SOURCE=ROOT/'data/atlas_morocco_legal_source.json'
EXPECTED_CANONICAL_SHA256='82131c99af243ce1e854a03a7fa46b06ad0c69a0be47629f04be71a738aa3e86'
MAX_UNRESOLVED_JOIN_METRES=10.0


def validate_source(document: dict) -> None:
    canonical=json.dumps(document,ensure_ascii=False,sort_keys=True,
                         separators=(',',':'),allow_nan=False).encode('utf-8')
    if hashlib.sha256(canonical).hexdigest()!=EXPECTED_CANONICAL_SHA256:
        raise ValueError('Changed reviewed Moroccan legal/physical source facts')
    if document.get('schema')!=1 or document.get('administrative_geometry_eligible') is not False:
        raise ValueError('The present Moroccan reconstruction is audit-only')
    if [x['code'] for x in document['municipalities']]!=['042810503','042810511']:
        raise ValueError('Unexpected legal municipal identities')


def load_source(path: Path=DEFAULT_SOURCE) -> dict:
    document=json.loads(Path(path).read_text(encoding='utf-8'))
    validate_source(document)
    return document


@lru_cache(maxsize=1)
def _transformer():
    try:
        import pyproj
    except ModuleNotFoundError:
        isolated=ROOT/'.tools/atlas_python'
        if not (isolated/'pyproj').is_dir():
            raise RuntimeError('Install pyproj in the build Python environment; no network download is performed')
        sys.path.insert(0,str(isolated))
        import pyproj
    pyproj.network.set_network_enabled(False)
    pipeline=load_source()['coordinate_reference']['pipeline']
    return pyproj.Transformer.from_pipeline(pipeline)


def to_wgs84(x, y, z=None):
    return _transformer().transform(x,y)


def _to_native(x, y, z=None):
    return _transformer().transform(x,y,direction='INVERSE')


def connected_chain(ways: list[dict], nodes: dict) -> dict:
    """Order complete ways by identical endpoint IDs; no nearest-edge joining."""
    if not ways or len({x['id'] for x in ways})!=len(ways):
        raise ValueError('Missing or duplicate physical-course ways')
    adjacency=defaultdict(list)
    for index,way in enumerate(ways):
        ids=way.get('node_ids',[])
        if len(ids)<2 or ids[0]==ids[-1] or any(n not in nodes for n in ids):
            raise ValueError('Incomplete or closed original way in an open physical course')
        adjacency[ids[0]].append(index);adjacency[ids[-1]].append(index)
    ends=[node for node,edges in adjacency.items() if len(edges)==1]
    if len(ends)!=2 or any(len(edges)>2 for edges in adjacency.values()):
        raise ValueError('Disconnected, branched or cyclic physical course; no inferred join')
    current=min(ends);ordered=[];used=set();ordered_ways=[]
    while len(used)<len(ways):
        choices=[i for i in adjacency[current] if i not in used]
        if len(choices)!=1:
            raise ValueError('Physical course is not one complete node-connected chain')
        index=choices[0];way=ways[index];ids=list(way['node_ids'])
        if ids[0]!=current:
            ids.reverse()
        ordered.extend(ids if not ordered else ids[1:])
        used.add(index);ordered_ways.append(way['id']);current=ids[-1]
    coordinates=[list(nodes[n]) for n in ordered]
    line=LineString(coordinates)
    if line.is_empty or not line.is_simple:
        raise ValueError('Original physical chain self-intersects; no automatic repair')
    return {'node_ids':ordered,'way_ids':ordered_ways,'coordinates':coordinates}


def trace_course(line: LineString, start, end) -> dict:
    """Cut the original metric line and disclose both unsnapped connectors."""
    a,b=Point(start),Point(end)
    first,last=line.project(a),line.project(b)
    if math.isclose(first,last,abs_tol=1e-8):
        raise ValueError('The physical course does not distinguish the legal endpoints')
    cut=substring(line,first,last)
    if cut.geom_type!='LineString' or cut.length<=0:
        raise ValueError('Required physical course is incomplete')
    original=list(cut.coords);coordinates=[tuple(start)]
    for point in original+[tuple(end)]:
        if point!=coordinates[-1]:
            coordinates.append(point)
    start_gap=a.distance(Point(original[0]));end_gap=b.distance(Point(original[-1]))
    return {'coordinates':coordinates,'start_gap_m':start_gap,'end_gap_m':end_gap,
            'physical_course_length_m':cut.length,
            'start_position_m':first,'end_position_m':last,
            'start_at_source_chain_end':min(first,line.length-first)<1e-7,
            'end_at_source_chain_end':min(last,line.length-last)<1e-7,
            'maximum_curve_to_printed_chord_m':cut.hausdorff_distance(LineString([start,end])),
            'derivation':'Original physical chain clipped at nearest metric positions. Interior source vertices are retained. Explicit straight connectors to printed legal points are audit hypotheses; original OSM nodes were not moved.'}


def _segments(municipality):
    points=municipality['points']
    if [x['point'] for x in points]!=list(range(1,len(points)+1)):
        raise ValueError('Incomplete, reordered or repeated legal point sequence')
    courses={}
    for entry in municipality.get('course_segments',[]):
        key=(entry['from'],entry['to'])
        if key in courses:
            raise ValueError('Duplicate legal physical-course exception')
        courses[key]=entry['course']
    used=set()
    for i,point in enumerate(points):
        following=points[(i+1)%len(points)];key=(point['point'],following['point'])
        if key in courses:used.add(key)
        yield key,(point['x'],point['y']),(following['x'],following['y']),courses.get(key,'straight')
    if used!=set(courses):
        raise ValueError('A legal course exception does not follow the printed point order')


def shared_course_disagreements(municipalities: list[dict]) -> list[dict]:
    shared=defaultdict(list)
    for municipality in municipalities:
        for indices,a,b,course in _segments(municipality):
            shared[tuple(sorted((a,b)))].append({'code':municipality['code'],
                'points':list(indices),'course':course})
    return [{'legal_endpoints':list(endpoints),'municipalities':rows,
             'courses':[row['course'] for row in rows],
             'consequence':'Identical printed endpoints have different course instructions. No exception is silently transferred between decisions.'}
            for endpoints,rows in shared.items() if len(rows)>1 and len({r['course'] for r in rows})>1]


def reconstruct_unit(municipality: dict, courses: dict) -> dict:
    ring=[];segments=[]
    for indices,a,b,course in _segments(municipality):
        if course=='straight':
            part={'coordinates':[a,b],'start_gap_m':0.0,'end_gap_m':0.0,
                  'derivation':'Ordinary printed Lambert polygonal segment'}
        else:
            if course not in courses:
                raise ValueError('Missing required physical course: '+course)
            part=trace_course(courses[course],a,b)
        ring.extend(part['coordinates'] if not ring else part['coordinates'][1:])
        segments.append({'from':indices[0],'to':indices[1],'course':course,**part})
    if len(ring)<4 or ring[0]!=ring[-1]:
        raise ValueError('The legal reconstruction did not close; no synthetic closing edge')
    geometry=Polygon(ring)
    validity=explain_validity(geometry)
    return {'code':municipality['code'],'name':municipality['name'],
            'decision':municipality['decision'],'geometry_native':geometry,
            'geometry_validity':validity,'segments':segments,
            'area_km2':geometry.area/1e6 if geometry.is_valid and not geometry.is_empty else None,
            'administrative_geometry_eligible':False}


def reconstruct_source(document: dict) -> dict:
    validate_source(document)
    nodes={row['id']:[row['lon'],row['lat']] for row in document['osm_nodes']}
    ways={row['id']:row for row in document['osm_ways']}
    courses={};chains={}
    for name,spec in document['courses'].items():
        chain=connected_chain([ways[rid] for rid in spec['way_ids']],nodes)
        chains[name]={'way_ids':chain['way_ids'],'original_node_count':len(chain['node_ids']),
                      'connected_by_original_node_ids':True}
        courses[name]=transform(_to_native,LineString(chain['coordinates']))
    candidates={row['code']:reconstruct_unit(row,courses) for row in document['municipalities']}
    conflicts=shared_course_disagreements(document['municipalities'])
    for conflict in conflicts:
        paths=[]
        for member in conflict['municipalities']:
            segment=next(s for s in candidates[member['code']]['segments']
                         if [s['from'],s['to']]==member['points'])
            paths.append(LineString(segment['coordinates']))
        faces=list(polygonize(unary_union(paths)))
        conflict['curve_chord_disagreement_area_m2']=sum(face.area for face in faces)
        conflict['diagnostic_face_count']=len(faces)
        conflict['maximum_course_separation_m']=max(
            a.hausdorff_distance(b) for a in paths for b in paths)
        conflict['measurement_note']='Local linework faces quantify the disagreement only; they are not assigned to a municipality or used to repair either candidate.'
    physical=[{'municipality':row['code'],**{k:v for k,v in s.items() if k!='coordinates'}}
              for row in candidates.values() for s in row['segments'] if s['course']!='straight']
    maximum=max(max(s['start_gap_m'],s['end_gap_m']) for s in physical)
    unresolved=[s for s in physical if max(s['start_gap_m'],s['end_gap_m'])>MAX_UNRESOLVED_JOIN_METRES]
    # Eligibility is deliberately not inferred from a polygon being valid or
    # having a high coverage percentage. The current facts retain open issues.
    eligible=(document.get('administrative_geometry_eligible') is True
              and document.get('field_verification_complete') is True
              and not conflicts and not unresolved
              and all(c['geometry_native'].is_valid for c in candidates.values()))
    first,second=list(candidates.values())
    overlap=(first['geometry_native'].intersection(second['geometry_native']).area
             if first['geometry_native'].is_valid and second['geometry_native'].is_valid else None)
    for candidate in candidates.values():
        candidate['geometry']=(transform(to_wgs84,candidate['geometry_native'])
                               if candidate['geometry_native'].is_valid else None)
        candidate['administrative_geometry_eligible']=eligible
    audit={'status':'Qualified identities and full physical chains; unresolved legal-course/endpoint audit',
           'administrative_geometry_eligible':eligible,
           'crs_inferred_not_printed':True,'transform_accuracy_m':7.0,
           'physical_chains':chains,'physical_segments':physical,
           'maximum_physical_endpoint_gap_m':maximum,
           'unresolved_endpoint_threshold_m':MAX_UNRESOLVED_JOIN_METRES,
           'threshold_meaning':'A conservative audit gate, not an official legal tolerance or permission to snap source geometry',
           'segments_above_threshold':len(unresolved),
           'shared_course_disagreements':conflicts,
           'candidate_areas_km2':{code:row['area_km2'] for code,row in candidates.items()},
           'candidate_overlap_area_m2':overlap,
           'overlap_measurement_status':'Measured from valid candidates' if overlap is not None else 'Unresolved: invalid candidate prevents a trustworthy whole-polygon overlap assertion; local course disagreement is measured separately',
           'candidate_geometry_valid':all(r['geometry_native'].is_valid for r in candidates.values()),
           'candidate_validity':{code:r['geometry_validity'] for code,r in candidates.items()},
           'open_issues':document['open_issues'],
           'no_original_source_nodes_moved':True,'no_remainder_polygon_used':True,
           'runtime_admission':'Blocked: candidate construction and legal/physical observations are not a completed administrative boundary provider.'}
    return {'candidates':candidates,'audit':audit,'administrative_geometry_eligible':eligible}


def iter_eligible_boundaries(document: dict):
    result=reconstruct_source(document)
    if not result['administrative_geometry_eligible']:
        return
    yield from result['candidates'].values()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=DEFAULT_SOURCE)
    args=parser.parse_args()
    print(json.dumps(reconstruct_source(load_source(args.source))['audit'],ensure_ascii=False,indent=2,allow_nan=False))
