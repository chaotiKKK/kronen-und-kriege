"""Prepare a private Godot 4.5 Windows template without the manifest regression.

Reads branding from export_presets.cfg, edits an unpacked template COPY, then
validates resources and unchanged executable code before publishing the copy.
Use the result as custom_template/release with application/modify_resources=false.
Never run this against a game export containing an embedded PCK.
"""
from __future__ import annotations

import configparser
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TEMPLATE = ROOT / '.tools/appdata/Godot/export_templates/4.5.stable/windows_release_x86_64.exe'
DEFAULT_RCEDIT = ROOT / '.tools/rcedit-x64.exe'
DEFAULT_OUTPUT = ROOT / '.tools/windows-export-template/banger-queens-windows-release-x86_64.exe'
STRING_KEYS = {'company_name': 'CompanyName', 'product_name': 'ProductName',
               'file_description': 'FileDescription', 'copyright': 'LegalCopyright',
               'trademarks': 'LegalTrademarks'}


def load_settings(project: Path) -> dict:
    project = Path(project).resolve()
    config = configparser.ConfigParser(interpolation=None)
    config.read(project / 'export_presets.cfg', encoding='utf-8-sig')
    presets = [section for section in config.sections()
               if re.fullmatch(r'preset\.\d+', section)
               and json.loads(config[section].get('platform', '""')) == 'Windows Desktop']
    if len(presets) != 1:
        raise ValueError('Expected one Windows Desktop export preset')
    options = config[presets[0] + '.options']
    def value(key, default=''):
        return json.loads(options.get(key, json.dumps(default)))
    if value('binary_format/architecture') != 'x86_64':
        raise ValueError('This original template requires the x86_64 preset')
    versions = {name: value('application/' + name) for name in ('file_version', 'product_version')}
    for version in versions.values():
        if not re.fullmatch(r'\d+\.\d+\.\d+\.\d+', version) or any(int(x) > 65535 for x in version.split('.')):
            raise ValueError('Four Windows version components in range 0..65535 are required')
    icon = value('application/icon')
    if not icon.startswith('res://'):
        raise ValueError('The native ICO must be an explicit project resource')
    icon = (project / icon[6:]).resolve()
    if not icon.is_relative_to(project) or icon.suffix.lower() != '.ico':
        raise ValueError('A project-local existing ICO is required; no image conversion is performed')
    return {**versions, 'icon': icon,
            'strings': {target: value('application/' + key) for key, target in STRING_KEYS.items()}}


def inspect_pe(raw: bytes, *, require_unpacked=False) -> dict:
    """Read only PE headers/resources; no executable is loaded or run."""
    def unpack(fmt, offset):
        if offset < 0 or offset + struct.calcsize(fmt) > len(raw):
            raise ValueError('Truncated PE structure')
        return struct.unpack_from(fmt, raw, offset)
    if raw[:2] != b'MZ':
        raise ValueError('Not a PE executable')
    pe, = unpack('<I', 60)
    if raw[pe:pe+4] != b'PE\0\0':
        raise ValueError('Invalid PE signature')
    machine, count = unpack('<HH', pe+4)
    optional_size, = unpack('<H', pe+20)
    optional = pe+24
    magic, = unpack('<H', optional)
    if machine != 0x8664 or magic != 0x20b or optional_size < 136:
        raise ValueError('Expected a Windows x86_64 PE32+ template')
    sections = []
    for index in range(count):
        entry = optional+optional_size+40*index
        name = raw[entry:entry+8].rstrip(b'\0').decode('ascii')
        virtual_size, rva, raw_size, pointer = unpack('<IIII', entry+8)
        characteristics, = unpack('<I', entry+36)
        if raw_size and (pointer <= 0 or pointer+raw_size > len(raw)):
            raise ValueError('Truncated PE section: '+name)
        section = dict(name=name, virtual_size=virtual_size, rva=rva,
                       raw_size=raw_size, pointer=pointer, characteristics=characteristics)
        sections.append(section)
        if require_unpacked and name in ('pck', '.pck'):
            # Godot deliberately leaves VirtualSize=8 even for a large embedded pack.
            if raw_size > 512 or any(raw[pointer:pointer+raw_size]):
                raise ValueError('Refusing a template containing an embedded PCK')
    def file_offset(rva, size):
        candidates = [s for s in sections if s['rva'] <= rva < s['rva']+s['virtual_size']]
        if len(candidates) != 1:
            raise ValueError('Ambiguous/unmapped PE resource RVA')
        s = candidates[0]
        delta = rva-s['rva']
        if delta+size > s['raw_size']:
            raise ValueError('Resource extends outside its file-backed PE section')
        return s['pointer']+delta
    resource_rva, resource_size = unpack('<II', optional+128)
    resources = {}
    if resource_rva:
        base = file_offset(resource_rva, resource_size)
        def relative(offset, size):
            if offset < 0 or offset+size > resource_size:
                raise ValueError('Resource directory leaves its declared PE data')
            return base+offset
        def identifier(value):
            if not value & 0x80000000:
                return value
            pos = relative(value & 0x7fffffff, 2)
            length, = unpack('<H', pos)
            relative(value & 0x7fffffff, 2+2*length)
            return raw[pos+2:pos+2+2*length].decode('utf-16le')
        def directory(offset=0, path=()):
            if len(path) > 2:
                raise ValueError('Unexpected recursive PE resource directory')
            pos = relative(offset, 16)
            named, numbered = unpack('<HH', pos+12)
            relative(offset+16, 8*(named+numbered))
            for i in range(named+numbered):
                name, target = unpack('<II', pos+16+8*i)
                current = path+(identifier(name),)
                if target & 0x80000000:
                    directory(target & 0x7fffffff, current)
                else:
                    data, size, _, _ = unpack('<IIII', relative(target, 16))
                    if len(current) != 3 or current in resources:
                        raise ValueError('Invalid/duplicate PE resource identity')
                    start = file_offset(data, size)
                    resources[current] = raw[start:start+size]
        directory()
    code = {}
    for index, s in enumerate(sections):
        if s['characteristics'] & 0x20000000:
            code[str(index)+':'+s['name']] = {
                'rva':s['rva'], 'virtual_size':s['virtual_size'], 'raw_size':s['raw_size'],
                'sha256':hashlib.sha256(raw[s['pointer']:s['pointer']+s['raw_size']]).hexdigest()}
    return {'sections':sections, 'code_sections':code, 'resources':resources}


def ico_images(raw: bytes) -> list[tuple]:
    if len(raw) < 6:
        raise ValueError('Truncated ICO header')
    reserved, kind, count = struct.unpack_from('<HHH', raw)
    if reserved or kind != 1 or not count or len(raw) < 6+16*count:
        raise ValueError('Invalid ICO directory')
    images = []
    for index in range(count):
        width, height, colors, reserved, planes, bits, size, offset = struct.unpack_from('<BBBBHHII', raw, 6+16*index)
        if reserved or offset < 6+16*count or size <= 0 or offset+size > len(raw):
            raise ValueError('Truncated/invalid original ICO image')
        images.append((width, height, colors, reserved, planes, bits, raw[offset:offset+size]))
    return images


def validate_manifest(raw: bytes) -> None:
    root = ET.fromstring(raw)
    assembly = '{urn:schemas-microsoft-com:asm.v1}'
    matches = root.findall(assembly+'dependency/'+assembly+'dependentAssembly/'+assembly+'assemblyIdentity')
    expected = {'name':'Microsoft.Windows.Common-Controls', 'version':'6.0.0.0', 'type':'win32',
                'processorArchitecture':'*', 'publicKeyToken':'6595b64144ccf1df', 'language':'*'}
    path = root.find('.//{http://schemas.microsoft.com/SMI/2016/WindowsSettings}longPathAware')
    if not any(all(node.get(k) == v for k,v in expected.items()) for node in matches) or path is None or path.text != 'true':
        raise ValueError('Original Common-Controls-v6/long-path manifest is required')


def version_info(raw: bytes) -> dict:
    def block(start, limit):
        if start+6 > limit:
            raise ValueError('Truncated Windows version block')
        length, value_length, kind = struct.unpack_from('<HHH', raw, start)
        end = start+length
        if length < 6 or end > limit:
            raise ValueError('Invalid Windows version block length')
        pos = start+6
        while pos+2 <= end and raw[pos:pos+2] != b'\0\0':
            pos += 2
        if pos+2 > end:
            raise ValueError('Unterminated Windows version key')
        key = raw[start+6:pos].decode('utf-16le')
        pos = (pos+2+3) & ~3
        value_size = value_length*(2 if kind == 1 else 1)
        if pos+value_size > end:
            raise ValueError('Truncated Windows version value')
        value = raw[pos:pos+value_size]
        pos = (pos+value_size+3) & ~3
        children = []
        while pos+6 <= end:
            child = block(pos, end)
            children.append(child)
            pos = (pos+child['length']+3) & ~3
        return dict(length=length, key=key, kind=kind, value=value, children=children)
    root = block(0, len(raw))
    if root['key'] != 'VS_VERSION_INFO' or len(root['value']) != 52:
        raise ValueError('Missing fixed Windows version information')
    fixed = struct.unpack('<13I', root['value'])
    if fixed[0] != 0xfeef04bd:
        raise ValueError('Invalid Windows fixed version signature')
    def version(ms, ls):
        return '.'.join(str(x) for x in (ms>>16, ms&65535, ls>>16, ls&65535))
    tables = []
    for group in root['children']:
        if group['key'] == 'StringFileInfo':
            for table in group['children']:
                tables.append({s['key']:s['value'].decode('utf-16le').rstrip('\0') for s in table['children']})
    return dict(file_version=version(fixed[2],fixed[3]), product_version=version(fixed[4],fixed[5]), strings=tables)


def verify_prepared(original: bytes, candidate: bytes, settings: dict, icon: bytes) -> dict:
    before = inspect_pe(original, require_unpacked=True)
    after = inspect_pe(candidate, require_unpacked=True)
    if not before['code_sections'] or before['code_sections'] != after['code_sections']:
        raise ValueError('Template executable code changed')
    original_manifests = {key:value for key,value in before['resources'].items() if key[0] == 24}
    manifests = {key:value for key,value in after['resources'].items() if key[0] == 24}
    if not original_manifests or manifests != original_manifests:
        details = {str(k):{'bytes':len(v),'sha256':hashlib.sha256(v).hexdigest()} for k,v in manifests.items()}
        raise ValueError('Template original manifest bytes/identity changed: '+json.dumps(details))
    for manifest in manifests.values():
        validate_manifest(manifest)
    expected_strings = {**settings['strings'], 'FileVersion':settings['file_version'],
                        'ProductVersion':settings['product_version']}
    versions = [version_info(value) for key,value in after['resources'].items() if key[0] == 16]
    if not versions:
        raise ValueError('Missing prepared Windows version resource')
    for version in versions:
        if any(version[name] != settings[name] for name in ('file_version','product_version')) or not version['strings']:
            raise ValueError('Prepared fixed Windows versions differ from preset')
        if any(any(table.get(k) != v for k,v in expected_strings.items()) for table in version['strings']):
            raise ValueError('Prepared Windows branding strings differ from preset')
    expected_images = ico_images(icon)
    groups = []
    for key,value in after['resources'].items():
        if key[0] != 14:
            continue
        if len(value) < 6:
            raise ValueError('Truncated prepared group icon')
        reserved, kind, count = struct.unpack_from('<HHH', value)
        if reserved or kind != 1 or len(value) != 6+14*count:
            raise ValueError('Invalid prepared group icon')
        images = []
        for i in range(count):
            width,height,colors,reserved,planes,bits,size,identifier = struct.unpack_from('<BBBBHHIH',value,6+14*i)
            image = after['resources'].get((3,identifier,key[2]))
            if image is None or len(image) != size:
                raise ValueError('Prepared group icon has missing/incorrect image resource: '+str((key,identifier,size))+
                                 ' actual='+str([(k,len(v)) for k,v in after['resources'].items() if k[0] == 3])+
                                 ' groups='+str([(k,v.hex()[:100]) for k,v in after['resources'].items() if k[0] == 14]))
            images.append((width,height,colors,reserved,planes,bits,image))
        if images != expected_images:
            raise ValueError('Prepared ICO images differ from original source bytes')
        groups.append({'id':key[1], 'language':key[2], 'images':count})
    if not groups:
        raise ValueError('Missing prepared Windows icon')
    return {'code_sections':after['code_sections'], 'manifest_sha256':hashlib.sha256(next(iter(manifests.values()))).hexdigest(),
            'manifest_bytes':len(next(iter(manifests.values()))), 'manifest_resources':[list(k) for k in manifests],
            'version_info':versions, 'icon_groups':groups, 'icon_sha256':hashlib.sha256(icon).hexdigest(),
            'embedded_pck':False}


def icon_group_updates(original_resources: dict, prepared_resources: dict, icon: bytes) -> dict:
    """Preserve Godot group IDs and the ICO's full DWORD image sizes.

    Rcedit2 adds group0 and truncates sizes of uncompressed images >65535B.
    Image resources themselves remain exact; rebuild only their descriptors.
    """
    original = {key for key in original_resources if key[0] == 14}
    added = {key:value for key,value in prepared_resources.items() if key[0] == 14 and key not in original}
    if not added:
        return {}
    if not original or any(key[1] != 0 for key in added):
        raise ValueError('Unexpected Rcedit icon-group identities')
    changes = {}
    expected = ico_images(icon)
    for key in original:
        replacement = added.get((14,0,key[2]))
        if replacement is None or len(replacement) != 6+14*len(expected):
            raise ValueError('Missing Rcedit icon group for original language')
        group = struct.pack('<HHH',0,1,len(expected))
        for index,entry in enumerate(expected):
            identifier, = struct.unpack_from('<H',replacement,6+14*index+12)
            if prepared_resources.get((3,identifier,key[2])) != entry[-1]:
                raise ValueError('Rcedit changed original ICO image bytes')
            group += struct.pack('<BBBBHHIH',*entry[:-1],len(entry[-1]),identifier)
        changes[key] = group
    changes.update({key:None for key in added})
    return changes


def update_icon_groups(path: Path, changes: dict):
    if not changes:
        return
    kernel = ctypes.WinDLL('kernel32',use_last_error=True)
    kernel.BeginUpdateResourceW.argtypes = [ctypes.c_wchar_p,ctypes.c_bool]
    kernel.BeginUpdateResourceW.restype = ctypes.c_void_p
    kernel.UpdateResourceW.argtypes = [ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,
                                     ctypes.c_ushort,ctypes.c_void_p,ctypes.c_uint]
    kernel.UpdateResourceW.restype = ctypes.c_bool
    kernel.EndUpdateResourceW.argtypes = [ctypes.c_void_p,ctypes.c_bool]
    kernel.EndUpdateResourceW.restype = ctypes.c_bool
    handle = kernel.BeginUpdateResourceW(str(path),False)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        for (kind,identifier,language),payload in changes.items():
            name = ctypes.c_void_p(identifier) if isinstance(identifier,int) else ctypes.c_wchar_p(identifier)
            pointer = ctypes.cast(name,ctypes.c_void_p)
            data = ctypes.create_string_buffer(payload) if payload is not None else None
            if not kernel.UpdateResourceW(handle,ctypes.c_void_p(kind),pointer,language,data,len(payload) if payload is not None else 0):
                raise ctypes.WinError(ctypes.get_last_error())
        if not kernel.EndUpdateResourceW(handle,False):
            raise ctypes.WinError(ctypes.get_last_error())
        handle = None
    finally:
        if handle:
            kernel.EndUpdateResourceW(handle,True)


def prepare_template(project=ROOT, template=DEFAULT_TEMPLATE, rcedit=DEFAULT_RCEDIT, output=DEFAULT_OUTPUT):
    project, template, rcedit, output = (Path(p).resolve() for p in (project,template,rcedit,output))
    private_root = (project/'.tools/windows-export-template').resolve()
    if not output.is_relative_to(private_root) or output.suffix.lower() != '.exe' or output in (template,rcedit):
        raise ValueError('Output must be a separate private Windows template copy')
    original = template.read_bytes()
    info = inspect_pe(original, require_unpacked=True)
    manifests = [value for key,value in info['resources'].items() if key[0] == 24]
    if len(manifests) != 1:
        raise ValueError('Expected the original single Godot manifest')
    validate_manifest(manifests[0])
    settings = load_settings(project)
    icon = settings['icon'].read_bytes()
    ico_images(icon)
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.prepare-',dir=output.parent) as temporary:
        stage = Path(temporary)/'template.exe'
        shutil.copy2(template,stage)
        # Preserve the existing resource. Rcedit 2.0's --application-manifest
        # serializes its input with an extra XML padding comment; no rewrite is
        # necessary on this pristine, unpacked template.
        args = [str(rcedit), str(stage), '--set-icon',str(settings['icon']),
                '--set-file-version',settings['file_version'], '--set-product-version',settings['product_version']]
        for key,value in settings['strings'].items():
            args.extend(['--set-version-string',key,value])
        result = subprocess.run(args,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
        if result.returncode:
            raise RuntimeError('Rcedit template preparation failed: '+result.stderr+result.stdout)
        edited = inspect_pe(stage.read_bytes(),require_unpacked=True)
        update_icon_groups(stage,icon_group_updates(info['resources'],edited['resources'],icon))
        prepared = stage.read_bytes()
        receipt = verify_prepared(original,prepared,settings,icon)
        if template.read_bytes() != original:
            raise ValueError('Original export template changed during preparation')
        receipt.update(input=str(template),input_sha256=hashlib.sha256(original).hexdigest(),
                       output=str(output),output_sha256=hashlib.sha256(prepared).hexdigest(),
                       rcedit_sha256=hashlib.sha256(rcedit.read_bytes()).hexdigest(),
                       preset_sha256=hashlib.sha256((project/'export_presets.cfg').read_bytes()).hexdigest(),
                       export_options={'custom_template/release':str(output),'application/modify_resources':False})
        stage.replace(output)
    output.with_suffix('.receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,default=ROOT)
    parser.add_argument('--template',type=Path,default=DEFAULT_TEMPLATE)
    parser.add_argument('--rcedit',type=Path,default=DEFAULT_RCEDIT)
    parser.add_argument('--output',type=Path,default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()
    print(json.dumps(prepare_template(arguments.project,arguments.template,arguments.rcedit,arguments.output),ensure_ascii=False,indent=2))
