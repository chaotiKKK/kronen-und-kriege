#!/usr/bin/env python3
"""Prüft die Kartenassets aus assets/map/generated/ gegen ihr Manifest."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "map" / "generated"
MANIFEST = OUT / "manifest.json"
EXPECTED = {
    "heightmap.png": ((2400, 1520), "L"),
    "normal_map.png": ((2400, 1520), "RGB"),
    "relief_shaded.png": ((2400, 1520), "RGB"),
    "marker_castle.png": ((256, 256), "RGBA"),
    "marker_banner.png": ((256, 256), "RGBA"),
}


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main() -> int:
    verbose = "--verbose" in sys.argv
    errors: list[str] = []
    if not MANIFEST.exists():
        print("FEHLER: Manifest fehlt:", MANIFEST)
        return 1
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = {Path(item["path"]).name: item for item in manifest.get("assets", [])}
    for name, (size, mode) in EXPECTED.items():
        path = OUT / name
        if not path.exists():
            errors.append("fehlt: " + name)
            continue
        with Image.open(path) as image:
            if image.size != size:
                errors.append("%s: %s statt %s" % (name, image.size, size))
            if mode == "RGBA":
                if image.mode != "RGBA":
                    errors.append("%s: Modus %s statt RGBA" % (name, image.mode))
                else:
                    alpha = image.getchannel("A")
                    if alpha.getbbox() is None:
                        errors.append(name + ": vollständig transparent")
            elif image.mode != mode:
                errors.append("%s: Modus %s statt %s" % (name, image.mode, mode))
        if verbose:
            print("OK %-24s %s %s" % (name, size, mode))
    for name in ("marker_castle.glb", "marker_banner.glb"):
        path = OUT / name
        if not path.exists() or path.stat().st_size < 4096:
            errors.append("GLB fehlt oder ist zu klein: " + name)
            continue
        if path.read_bytes()[:4] != b"glTF":
            errors.append("GLB-Magic fehlt: " + name)
    for name, entry in entries.items():
        path = OUT / name
        if not path.exists():
            errors.append("Manifest-Datei fehlt: " + name)
            continue
        if path.stat().st_size != int(entry["bytes"]):
            errors.append("Manifest-Größe falsch: " + name)
        if digest(path) != entry["sha256"]:
            errors.append("Manifest-Hash falsch: " + name)
    if len(entries) != 7:
        errors.append("Manifest listet %d statt 7 Assets" % len(entries))
    if errors:
        for error in errors:
            print("FEHLER:", error)
        return 1
    print("MAPASSETS VERIFY OK: %d Assets, Hashes, PNG-Modi und GLB-Magic." % len(entries))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
