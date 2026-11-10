import copy
import unittest
import atlas_administration as atlas


class ExactFeatureReplacementTests(unittest.TestCase):
    def fixture(self):
        old = {'id': 'old:1', 'source': 'geofabrik-TR-admin8-local_admin',
               'country': 'TR', 'kind': 'local_admin', 'parent_id': 'district:1'}
        new = {'id': 'new:1', 'source': 'official:1', 'country': 'TR',
               'kind': 'local_admin', 'parent_id': 'district:1',
               'original_source_id': '42', 'replaces_feature_ids': ['old:1']}
        source = {'id': 'official:1', 'country': 'TR', 'kind': 'local_admin',
                  'replacement_scope': 'feature', 'replaces_feature_ids': ['old:1'],
                  'feature_replacement_evidence': [{'source_unit_id': 'new:1',
                      'original_source_id': '42', 'replaces_feature_id': 'old:1',
                      'parent_id': 'district:1', 'identity_method': 'exact-name-and-parent',
                      'evidence_urls': ['https://official.example/units']}]}
        fallback = {**old, 'id': 'old:2'}
        return [old, fallback, new], source

    def apply(self, features, sources):
        function = getattr(atlas, '_replace_exact_local_features', None)
        self.assertTrue(callable(function), 'Exact individual replacement contract missing')
        return function(features, sources)

    def test_replaces_only_exact_declared_target_and_keeps_fallback(self):
        features, source = self.fixture()
        removed = self.apply(features, [source])
        self.assertEqual(removed, {'old:1': 'new:1'})
        self.assertEqual([f['id'] for f in features], ['old:2', 'new:1'])
        self.assertEqual(features[1]['replaced_feature_ids'], ['old:1'])

    def test_requires_actual_admitted_new_feature(self):
        features, source = self.fixture()
        features.pop()
        with self.assertRaises(ValueError): self.apply(features, [source])
        self.assertEqual(len(features), 2)

    def test_rejects_cross_country_kind_parent_or_source(self):
        for field, value in [('country', 'AZ'), ('kind', 'municipality'),
                             ('parent_id', 'district:else'), ('source', 'unreviewed-source')]:
            with self.subTest(field=field):
                features, source = self.fixture()
                features[0][field] = value
                before = copy.deepcopy(features)
                with self.assertRaises(ValueError): self.apply(features, [source])
                self.assertEqual(features, before)

    def test_rejects_missing_evidence_mismatch_and_duplicate_target(self):
        for change in ['no-evidence', 'unknown-original', 'undeclared', 'duplicate']:
            with self.subTest(change=change):
                features, source = self.fixture()
                if change == 'no-evidence': source['feature_replacement_evidence'][0]['evidence_urls'] = []
                elif change == 'unknown-original': source['feature_replacement_evidence'][0]['original_source_id'] = 'wrong'
                elif change == 'undeclared': features[2]['replaces_feature_ids'].append('old:2')
                else: source['feature_replacement_evidence'].append(copy.deepcopy(source['feature_replacement_evidence'][0]))
                before = copy.deepcopy(features)
                with self.assertRaises(ValueError): self.apply(features, [source])
                self.assertEqual(features, before)

    def test_no_implicit_country_replacement_without_explicit_contract(self):
        features, source = self.fixture()
        source.pop('replacement_scope')
        with self.assertRaises(ValueError): self.apply(features, [source])

    def test_no_replacement_leaves_features_unchanged(self):
        features, _ = self.fixture()
        features[2].pop('replaces_feature_ids')
        before = copy.deepcopy(features)
        self.assertEqual(self.apply(features, []), {})
        self.assertEqual(features, before)


if __name__ == '__main__': unittest.main()
