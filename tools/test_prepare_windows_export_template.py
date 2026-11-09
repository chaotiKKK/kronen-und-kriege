"""Checks for a prepared Windows template before Godot embeds the game PCK."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

SPEC = importlib.util.find_spec('prepare_windows_export_template')
if SPEC:
    import prepare_windows_export_template as subject
else:
    subject = None


class WindowsTemplateTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(subject, 'Windows template preparer has not been implemented')

    def test_reads_windows_preset_values_without_changing_the_preset(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = root / 'export_presets.cfg'
            config.write_text('[preset.0]\nplatform="Android"\n[preset.0.options]\n'
                'application/product_name="Wrong"\n[preset.1]\nplatform="Windows Desktop"\n'
                '[preset.1.options]\nbinary_format/architecture="x86_64"\n'
                'application/icon="res://icon.ico"\napplication/file_version="1.6.0.0"\n'
                'application/product_version="1.6.0.0"\napplication/company_name="Banger Queens"\n'
                'application/product_name="Banger Queens"\n'
                'application/file_description="Grand Strategy: 2000 v. Chr. bis 2200 n. Chr."\n', encoding='utf-8')
            before = config.read_bytes()
            settings = subject.load_settings(root)
            self.assertEqual(settings['file_version'], '1.6.0.0')
            self.assertEqual(settings['strings']['ProductName'], 'Banger Queens')
            self.assertEqual(settings['icon'], root / 'icon.ico')
            self.assertEqual(config.read_bytes(), before)

    def test_embedded_pck_is_rejected_using_raw_size_despite_virtual_size_eight(self):
        raw = bytearray(2048)
        raw[:2] = b'MZ'
        struct.pack_into('<I', raw, 60, 128)
        raw[128:132] = b'PE\0\0'
        struct.pack_into('<HH', raw, 132, 0x8664, 1)
        struct.pack_into('<H', raw, 148, 240)
        struct.pack_into('<H', raw, 152, 0x20b)
        section = 392
        raw[section:section+8] = b'pck\0\0\0\0\0'
        struct.pack_into('<IIII', raw, section+8, 8, 4096, 1024, 512)
        raw[512:516] = b'GDPC'
        with self.assertRaisesRegex(ValueError, 'PCK'):
            subject.inspect_pe(bytes(raw), require_unpacked=True)

    def test_ico_retains_exact_original_compressed_image_bytes(self):
        raw = struct.pack('<HHH', 0, 1, 1)
        raw += struct.pack('<BBBBHHII', 32, 32, 0, 0, 1, 32, 8, 22) + b'PNGbytes'
        self.assertEqual(subject.ico_images(raw), [(32, 32, 0, 0, 1, 32, b'PNGbytes')])
        with self.assertRaises(ValueError):
            subject.ico_images(raw[:-1])

    def test_native_controls_manifest_also_requires_original_long_path_setting(self):
        manifest = b'<assembly xmlns="urn:schemas-microsoft-com:asm.v1"><dependency><dependentAssembly>'
        manifest += b'<assemblyIdentity name="Microsoft.Windows.Common-Controls" version="6.0.0.0" '
        manifest += b'type="win32" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*"/>'
        manifest += b'</dependentAssembly></dependency></assembly>'
        with self.assertRaises(ValueError):
            subject.validate_manifest(manifest)

    def test_candidate_with_modified_executable_code_is_rejected(self):
        raw = bytearray(1024)
        raw[:2] = b'MZ'
        struct.pack_into('<I', raw, 60, 128)
        raw[128:132] = b'PE\0\0'
        struct.pack_into('<HH', raw, 132, 0x8664, 1)
        struct.pack_into('<H', raw, 148, 240)
        struct.pack_into('<H', raw, 152, 0x20b)
        raw[392:400] = b'.text\0\0\0'
        struct.pack_into('<IIII', raw, 400, 8, 4096, 512, 512)
        struct.pack_into('<I', raw, 428, 0x60000020)
        original = bytes(raw)
        raw[512] = 0xcc
        with self.assertRaisesRegex(ValueError, 'code'):
            subject.verify_prepared(original, bytes(raw), {}, b'')

    def test_fixed_versions_are_checked_as_numbers(self):
        key = 'VS_VERSION_INFO'.encode('utf-16le') + b'\0\0'
        head = struct.pack('<HHH', 92, 52, 0) + key
        head += b'\0' * ((-len(head)) % 4)
        fixed = struct.pack('<13I', 0xfeef04bd, 0x10000, 0x10006, 0, 0x10006, 0,
                            0x3f, 0, 4, 1, 0, 0, 0)
        versions = subject.version_info(head + fixed)
        self.assertEqual(versions['file_version'], '1.6.0.0')
        self.assertEqual(versions['product_version'], '1.6.0.0')

    def test_rcedit_numeric_icon_group_is_transferred_to_original_named_identity(self):
        group = struct.pack('<HHH',0,1,1)+struct.pack('<BBBBHHIH',32,32,0,0,1,32,8,1)
        original = {(14,'GODOT_ICON',1033):b'old group'}
        prepared = {(14,'GODOT_ICON',1033):b'old group', (14,0,1033):group, (3,1,1033):b'PNGbytes'}
        icon = struct.pack('<HHH',0,1,1)+struct.pack('<BBBBHHII',32,32,0,0,1,32,8,22)+b'PNGbytes'
        plan = subject.icon_group_updates(original,prepared,icon)
        self.assertEqual(plan, {(14,'GODOT_ICON',1033):group, (14,0,1033):None})

    def test_large_ico_images_keep_full_dword_size_in_named_group(self):
        image = b'x'*65576
        group = struct.pack('<HHH',0,1,1)+struct.pack('<BBBBHHIH',128,128,0,0,1,32,40,1)
        icon = struct.pack('<HHH',0,1,1)+struct.pack('<BBBBHHII',128,128,0,0,1,32,len(image),22)+image
        plan = subject.icon_group_updates({(14,'GODOT_ICON',1033):b'old'},
            {(14,0,1033):group,(3,1,1033):image},icon)
        self.assertEqual(struct.unpack_from('<I',plan[(14,'GODOT_ICON',1033)],14)[0],65576)


if __name__ == '__main__':
    unittest.main(verbosity=2)
