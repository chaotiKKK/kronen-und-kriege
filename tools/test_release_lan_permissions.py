import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).parent / 'release_validation/atlas_release_validation.py'
spec = importlib.util.spec_from_file_location('release_validation_lan_contract', path)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class AndroidLanPermissionTests(unittest.TestCase):
    permissions = ['INTERNET', 'ACCESS_NETWORK_STATE', 'ACCESS_WIFI_STATE', 'CHANGE_WIFI_MULTICAST_STATE']

    def validate(self, names):
        function = getattr(release, 'require_lan_permissions', None)
        self.assertTrue(callable(function), 'Actual APK LAN permissions are not verified')
        return function('\n'.join("uses-permission: name='android.permission.%s'" % name for name in names))

    def test_all_actual_manifest_permissions_are_reported(self):
        self.assertEqual(self.validate(self.permissions), ['android.permission.' + p for p in self.permissions])

    def test_each_missing_permission_is_rejected(self):
        for omitted in self.permissions:
            with self.subTest(omitted=omitted):
                with self.assertRaises(ValueError):
                    self.validate([p for p in self.permissions if p != omitted])

    def test_similar_or_comment_only_permission_does_not_pass(self):
        function = getattr(release, 'require_lan_permissions', None)
        self.assertTrue(callable(function))
        with self.assertRaises(ValueError):
            function("comment: android.permission.INTERNET android.permission.ACCESS_WIFI_STATE")


if __name__ == '__main__': unittest.main()
