"""Legal-point reconstruction must preserve physical evidence and uncertainty."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

from shapely.geometry import LineString, Point

if importlib.util.find_spec('atlas_morocco_legal_boundaries'):
    import atlas_morocco_legal_boundaries as source
else:
    source=None


class MoroccoLegalBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(source,'The bounded legal-reconstruction helper is missing')

    def test_original_way_chain_joins_only_identical_nodes_and_preserves_bends(self):
        ways=[{'id':10,'node_ids':[1,2,3]}, {'id':11,'node_ids':[5,4,3]}]
        nodes={1:[0,0],2:[1,1],3:[2,0],4:[3,-1],5:[4,0]}
        chain=source.connected_chain(ways,nodes)
        self.assertEqual(chain['node_ids'],[1,2,3,4,5])
        self.assertEqual(chain['coordinates'],[[0,0],[1,1],[2,0],[3,-1],[4,0]])

    def test_nearby_disconnected_ways_are_not_silently_snapped(self):
        ways=[{'id':10,'node_ids':[1,2]}, {'id':11,'node_ids':[3,4]}]
        nodes={1:[0,0],2:[1,0],3:[1.000001,0],4:[2,0]}
        with self.assertRaises(ValueError):source.connected_chain(ways,nodes)

    def test_branched_course_requires_explicit_evidence_instead_of_a_shortest_guess(self):
        ways=[{'id':10,'node_ids':[1,2]},{'id':11,'node_ids':[2,3]},{'id':12,'node_ids':[2,4]}]
        with self.assertRaises(ValueError):
            source.connected_chain(ways,{1:[0,0],2:[1,0],3:[2,1],4:[2,-1]})

    def test_course_keeps_the_curve_and_reports_unsnapped_legal_connectors(self):
        original=LineString([(0,0),(5,2),(10,0)])
        course=source.trace_course(original,[1,-1],[9,-1])
        self.assertIn((5,2),course['coordinates'])
        self.assertEqual(course['coordinates'][0],(1,-1))
        self.assertEqual(course['coordinates'][-1],(9,-1))
        self.assertGreater(course['start_gap_m'],1)
        self.assertGreater(course['end_gap_m'],1)
        self.assertEqual(list(original.coords),[(0,0),(5,2),(10,0)])

    def test_missing_required_physical_course_never_becomes_a_straight_segment(self):
        municipality={'code':'test','name':'Test','decision':'test',
            'points':[{'point':1,'x':0,'y':0},{'point':2,'x':10,'y':0},{'point':3,'x':0,'y':10}],
            'course_segments':[{'from':1,'to':2,'course':'missing'}]}
        with self.assertRaises(ValueError):source.reconstruct_unit(municipality,{})

    def test_physical_curve_is_not_implicitly_transferred_to_other_legal_text(self):
        first={'code':'A','points':[{'point':1,'x':0,'y':0},{'point':2,'x':10,'y':0},{'point':3,'x':0,'y':10}],
               'course_segments':[{'from':1,'to':2,'course':'road'}]}
        second={'code':'B','points':[{'point':1,'x':10,'y':0},{'point':2,'x':0,'y':0},{'point':3,'x':10,'y':-10}],
                'course_segments':[]}
        conflicts=source.shared_course_disagreements([first,second])
        self.assertEqual(len(conflicts),1)
        self.assertEqual(set(conflicts[0]['courses']),{'road','straight'})

    def test_invalid_audit_polygon_stays_invalid_and_cannot_become_a_runtime_boundary(self):
        municipality={'code':'test','name':'Test','decision':'test',
            'points':[{'point':1,'x':0,'y':0},{'point':2,'x':10,'y':10},
                      {'point':3,'x':10,'y':0},{'point':4,'x':0,'y':10}],
            'course_segments':[]}
        candidate=source.reconstruct_unit(municipality,{})
        self.assertFalse(candidate['geometry_native'].is_valid)
        self.assertIn('Self-intersection',candidate['geometry_validity'])
        self.assertFalse(candidate['administrative_geometry_eligible'])

    def test_large_endpoint_offsets_and_legal_course_conflict_block_runtime_admission(self):
        result=source.reconstruct_source(source.load_source())
        self.assertEqual(set(result['candidates']),{'042810503','042810511'})
        self.assertFalse(result['administrative_geometry_eligible'])
        self.assertTrue(result['audit']['shared_course_disagreements'])
        self.assertGreater(result['audit']['maximum_physical_endpoint_gap_m'],60)
        self.assertFalse(result['audit']['candidate_geometry_valid'])
        for validity in result['audit']['candidate_validity'].values():
            self.assertIn('Self-intersection',validity)
        self.assertIsNone(result['audit']['candidate_overlap_area_m2'])
        conflict=result['audit']['shared_course_disagreements'][0]
        self.assertGreater(conflict['maximum_course_separation_m'],170)
        self.assertGreater(conflict['curve_chord_disagreement_area_m2'],190000)
        self.assertEqual(list(source.iter_eligible_boundaries(source.load_source())),[])

    def test_public_source_preserves_all_legal_points_and_original_natural_segments(self):
        doc=source.load_source()
        self.assertEqual([len(row['points']) for row in doc['municipalities']],[25,19])
        sidi=doc['municipalities'][1]
        self.assertEqual([(x['from'],x['to']) for x in sidi['course_segments']],[(2,3),(12,13),(14,15),(19,1)])
        self.assertEqual((sidi['points'][0]['x'],sidi['points'][0]['y']),(401145,439653))
        for node in doc['osm_nodes']:
            self.assertEqual(set(node),{'id','version','timestamp','lon','lat'})
        for way in doc['osm_ways']:
            self.assertEqual(set(way),{'id','version','timestamp','node_ids','tags'})
        self.assertFalse(doc['coordinate_reference']['printed_epsg_code'])

    def test_original_evidence_coordinate_tampering_is_rejected(self):
        doc=source.load_source();changed=copy.deepcopy(doc)
        changed['osm_nodes'][0]['lon']+=.001
        with self.assertRaises(ValueError):source.validate_source(changed)

    def test_crs_pipeline_reproduces_the_independently_checked_northern_lambert_point(self):
        lon,lat=source.to_wgs84(401145,439653)
        self.assertAlmostEqual(lon,-6.475596369730704,places=8)
        self.assertAlmostEqual(lat,34.5521871519685,places=8)


if __name__=='__main__':
    unittest.main(verbosity=2)
