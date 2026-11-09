"""Prüft die prozeduralen Assets und den Schlüsselabgleich gegen den Spielcode.

Aufruf:
    python tools/verify_assets.py            # Exit 0 = alles in Ordnung
    python tools/verify_assets.py --verbose

Geprüft wird gegen assets/asset_manifest.json:
  * Datei existiert, Zielgröße stimmt, PNG ist RGBA mit echtem Alphakanal
  * Alpha-Deckung liegt im Korridor der Bildfamilie
  * Bild ist nicht leer: Bounding-Box, Farbvielfalt und Kontrast über Schwellen
  * jeder im Code gefundene Schlüssel hat ein Asset oder steht begründet offen
"""

import json
import os
import re
import sys

from PIL import Image, ImageStat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "asset_manifest.json")

MIN_COLORS = 24
MIN_STDDEV = 6.0
MIN_BBOX = 0.10


def coverage(alpha):
    hist = alpha.histogram()
    total = alpha.size[0] * alpha.size[1]
    return sum(hist[16:]) / float(total)


def check_image(path, size, cov_range):
    errors = []
    if not os.path.exists(path):
        return ["fehlt: %s" % path], None
    im = Image.open(path)
    if im.mode != "RGBA":
        errors.append("%s: Modus %s statt RGBA" % (path, im.mode))
        im = im.convert("RGBA")
    if list(im.size) != list(size):
        errors.append("%s: %dx%d statt %dx%d" % (path, im.size[0], im.size[1],
                                                 size[0], size[1]))
    alpha = im.getchannel("A")
    hist = alpha.histogram()
    if hist[0] == im.size[0] * im.size[1]:
        errors.append("%s: vollständig transparent" % path)
    cov = coverage(alpha)
    if not (cov_range[0] <= cov <= cov_range[1]):
        errors.append("%s: Deckung %.3f außerhalb %.2f–%.2f" %
                      (path, cov, cov_range[0], cov_range[1]))
    bbox = alpha.getbbox()
    if bbox is not None:
        area = (bbox[2] - bbox[0]) * (bbox[3] - bbox[1])
        frac = area / float(im.size[0] * im.size[1])
        if frac < MIN_BBOX:
            errors.append("%s: Inhalt nur %.2f der Fläche" % (path, frac))
    else:
        errors.append("%s: keine Bounding-Box" % path)
    rgb = im.convert("RGB")
    colors = rgb.getcolors(maxcolors=1 << 20)
    if colors is None or len(colors) < MIN_COLORS:
        errors.append("%s: nur %s Farben" % (path, "?" if colors is None else len(colors)))
    stat = ImageStat.Stat(rgb)
    spread = sum(stat.stddev) / 3.0
    if spread < MIN_STDDEV:
        errors.append("%s: Kontrast zu flach (stddev %.1f)" % (path, spread))
    return errors, {"coverage": cov, "colors": len(colors or []), "stddev": spread}


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        return fh.read()


def code_keys():
    """Sammelt die im Spielcode referenzierten Schlüssel."""
    data = read("scripts/Data.gd")
    game = read("scripts/Game.gd")
    keys = {}

    m = re.search(r"const TERRAIN_TYPES := \{(.*?)\n\}", data, re.S)
    terrain = re.findall(r'"([a-z_]+)":\s*\{"name"', m.group(1)) if m else []
    keys["terrain"] = terrain

    m = re.search(r"func building_cost\(key: String\) -> int:(.*?)\nfunc ", game, re.S)
    buildings = re.findall(r'if key == "([a-z_]+)"', m.group(1)) if m else []
    keys["building"] = buildings

    m = re.search(r"const LEGACY_TRACKS := \{(.*?)\n\}", game, re.S)
    keys["legacy"] = re.findall(r'"([a-z_]+)":\s*\{"name"', m.group(1)) if m else []

    m = re.search(r"const COUNCIL_OFFICES := \{(.*?)\n\}", game, re.S)
    keys["council"] = re.findall(r'"([a-z_]+)":\s*\{"name"', m.group(1)) if m else []

    m = re.search(r"const VASSAL_CONTRACTS := \[(.*?)\n\]", game, re.S)
    keys["contract"] = re.findall(r'"id":\s*"([0-9]+)"', m.group(1)) if m else []

    m = re.search(r"const RELIC_ORDER := \[(.*?)\]", game)
    keys["relic"] = re.findall(r'"([a-z_]+)"', m.group(1)) if m else []

    m = re.search(r"const FAITH_ORDER := \[(.*?)\]", game)
    keys["faith"] = re.findall(r'"([a-z_]+)"', m.group(1)) if m else []

    m = re.search(r"const FAITH_TOKEN_ORDER := \[(.*?)\]", game, re.S)
    if m:
        keys["faith"].extend(re.findall(r'"([a-z_0-9]+)"', m.group(1)))

    m = re.search(r"static func events\(\) -> Array:(.*?)\n\nstatic func", data, re.S)
    events = re.findall(r'"id": "([a-z_]+)"', m.group(1)) if m else []
    keys["event"] = events

    return keys


def main():
    verbose = "--verbose" in sys.argv
    errors = []
    if not os.path.exists(MANIFEST):
        print("FEHLER: Manifest fehlt: %s" % MANIFEST)
        return 1
    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)

    checked = 0
    for family, info in manifest["families"].items():
        for rel in info["files"]:
            path = os.path.join(ROOT, rel)
            errs, stats = check_image(path, info["size"], info["coverage"])
            errors.extend(errs)
            checked += 1
            if verbose and stats:
                print("  ok %-46s cov=%.3f farben=%4d stddev=%.1f" %
                      (rel, stats["coverage"], stats["colors"], stats["stddev"]))
            elif stats:
                print("  ok %s" % rel)

    for entry in manifest.get("existing", []):
        path = os.path.join(ROOT, entry["asset"])
        if not os.path.exists(path):
            errors.append("fehlt: %s (%s)" % (entry["asset"], entry["code"]))

    mapped = {e["code"]: e["asset"] for e in manifest["key_map"]}
    opened = {e["code"]: e["reason"] for e in manifest.get("open", [])}

    for name, asset in mapped.items():
        if not os.path.exists(os.path.join(ROOT, asset)):
            errors.append("key_map zeigt auf fehlende Datei: %s -> %s" % (name, asset))

    found = code_keys()
    total_keys = 0
    for family, names in found.items():
        for key in names:
            code = "%s.%s" % (family, key)
            total_keys += 1
            if code in mapped:
                continue
            if code in opened:
                if not opened[code].strip():
                    errors.append("%s: offen ohne Begründung" % code)
                continue
            errors.append("Code-Schlüssel ohne Asset und ohne Offen-Liste: %s" % code)

    for code in opened:
        family, _, key = code.partition(".")
        # Familien ohne Code-Gegenstück (z. B. unit.*) sind geplante Vorleistungen.
        if family in found and key not in found[family]:
            errors.append("Offen-Liste nennt unbekannten Code-Schlüssel: %s" % code)

    print("Geprüft: %d Bilddateien, %d Code-Schlüssel (%s)" %
          (checked, total_keys,
           ", ".join("%s=%d" % (k, len(v)) for k, v in found.items())))
    if errors:
        print("FEHLER (%d):" % len(errors))
        for err in errors:
            print("  - %s" % err)
        return 1
    print("ASSETCHECK OK: alle Bilder und Schlüssel stimmen.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
