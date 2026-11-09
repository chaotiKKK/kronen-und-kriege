#!/usr/bin/env python3
"""Reproduzierbare Kartenassets für Kronen und Kriege.

Der Lauf ist absichtlich ein einziger Befehl:

    python tools/gen_map_assets.py

Er exportiert die 49 Provinzpolygone aus Data.gd, rastert daraus eine
Höhenkarte und Normalmap, lässt Blender das Shaded Relief und zwei Low-Poly-
Marker rendern und schreibt ein Manifest mit Hashes. Die Ausgaben unter
assets/map/generated/ werden zu Beginn vollständig entfernt; ein zweiter Lauf
erzeugt denselben Dateisatz neu.

Es werden keine CK3- oder Fremdassets verwendet.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, gaussian_filter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "map" / "generated"
WORK = ROOT / "build" / "map_asset_work"
W, H = 1200, 760
SS = 2
SW, SH = W * SS, H * SS

ALTITUDE = {
    "plains": 0.20,
    "farmland": 0.23,
    "forest": 0.32,
    "hills": 0.46,
    "mountains": 0.76,
    "marsh": 0.10,
    "coast": 0.13,
    "steppe": 0.18,
    "heath": 0.29,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", default=os.environ.get("BLENDER", ""),
                        help="Pfad zu blender.exe; sonst automatische Suche")
    parser.add_argument("--godot", default=os.environ.get("GODOT", str(ROOT / ".tools" / "godot.exe")))
    return parser.parse_args()


def find_blender(explicit: str) -> Path:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit))
    from_path = shutil.which("blender")
    if from_path:
        candidates.append(Path(from_path))
    bases = [
        Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Blender Foundation",
        Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Blender Foundation",
    ]
    for base in bases:
        if base.exists():
            candidates.extend(sorted(base.glob("Blender */blender.exe"), reverse=True))
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()
    raise SystemExit("Blender nicht gefunden. --blender <pfad> setzen.")


def run(cmd: list[str], *, env: dict | None = None, timeout: int = 900) -> str:
    print("+", " ".join(str(part) for part in cmd), flush=True)
    try:
        result = subprocess.run(
            [str(part) for part in cmd],
            cwd=str(ROOT),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        tail = (exc.stdout or "")[-4000:]
        raise SystemExit("Zeitüberschreitung nach %ss\n%s" % (timeout, tail))
    output = result.stdout or ""
    print(output.rstrip())
    if result.returncode != 0:
        raise SystemExit("Befehl fehlgeschlagen (%d): %s" % (result.returncode, cmd[0]))
    return output


def export_geometry(godot: Path) -> dict:
    WORK.mkdir(parents=True, exist_ok=True)
    target = WORK / "provinces.json"
    env = os.environ.copy()
    env["MAP_ASSET_GEOMETRY"] = str(target)
    env["APPDATA"] = str(ROOT / ".tools" / "appdata")
    output = run([godot, "--headless", "--path", str(ROOT), "--script",
                  "res://tools/export_map_geometry.gd"], env=env, timeout=180)
    if "MAP_GEOMETRY OK" not in output or not target.exists():
        raise SystemExit("Godot-Geometrieexport war nicht erfolgreich.")
    data = json.loads(target.read_text(encoding="utf-8"))
    if len(data.get("provinces", [])) != 49:
        raise SystemExit("Geometrieexport enthält %d statt 49 Provinzen." % len(data.get("provinces", [])))
    return data


def rasterize(provinces: list[dict]) -> tuple[np.ndarray, np.ndarray]:
    alt = Image.new("L", (SW, SH), 0)
    land = Image.new("L", (SW, SH), 0)
    alt_draw = ImageDraw.Draw(alt)
    land_draw = ImageDraw.Draw(land)
    for province in provinces:
        value = int(round(ALTITUDE.get(str(province["terrain"]), 0.2) * 255))
        for part in province.get("parts", []):
            poly = [(float(p[0]) * SS, float(p[1]) * SS) for p in part]
            if len(poly) < 3:
                continue
            alt_draw.polygon(poly, fill=value)
            land_draw.polygon(poly, fill=255)
    return np.asarray(alt, dtype=np.float32) / 255.0, np.asarray(land, dtype=np.uint8) > 128


def smooth_noise(rng: np.random.Generator, sigma: float) -> np.ndarray:
    field = rng.standard_normal((SH, SW)).astype(np.float32)
    field = gaussian_filter(field, sigma=sigma, mode="reflect")
    lo, hi = float(field.min()), float(field.max())
    return (field - lo) / max(hi - lo, 1e-6)


def build_height(provinces: list[dict]) -> tuple[np.ndarray, np.ndarray]:
    alt, land = rasterize(provinces)
    coast_dist = distance_transform_edt(land)
    inland = np.clip(coast_dist / (30.0 * SS), 0.0, 1.0).astype(np.float32)

    # Politische Flächen dürfen keine Kanten im Relief hinterlassen. Deshalb wird
    # das Gelände nur als breite Masse verwendet; die Bergrücken selbst kommen
    # aus gerichtetem Mehrskalenrauschen. Das erzeugt zusammenhängende Ketten
    # statt runder Plateaukerne.
    broad_alt = gaussian_filter(alt * land, sigma=75.0)
    mountain = np.clip((broad_alt - 0.265) / 0.225, 0.0, 1.0).astype(np.float32)
    hills = np.clip((broad_alt - 0.205) / 0.245, 0.0, 1.0).astype(np.float32)

    rng = np.random.default_rng(7319)
    broad = smooth_noise(rng, 80.0)
    middle = smooth_noise(rng, 24.0)
    fine = smooth_noise(rng, 7.0)
    ridge_a = 1.0 - np.abs(smooth_noise(rng, 44.0) * 2.0 - 1.0)
    ridge_b = 1.0 - np.abs(smooth_noise(rng, 14.0) * 2.0 - 1.0)
    ridge_c = 1.0 - np.abs(smooth_noise(rng, 5.0) * 2.0 - 1.0)
    ridge_a = (ridge_a ** 1.8).astype(np.float32)
    ridge_b = (ridge_b ** 2.3).astype(np.float32)
    ridge_c = (ridge_c ** 2.8).astype(np.float32)

    # Die breite Geländemasse bleibt niedrig; die Höhe kommt aus den Rücken.
    # So entstehen keine runden Plateaus, sondern ein zusammenhängendes,
    # geriffeltes Bergland mit Tälern.
    base = 0.070 + 0.085 * inland + broad_alt * 0.035
    height = base + ridge_a * 0.235 * mountain + ridge_b * 0.095 * mountain
    height += ridge_c * 0.024 * mountain
    height += ridge_a * 0.060 * hills
    height += (broad - 0.5) * 0.034
    height += (middle - 0.5) * 0.017 * (0.35 + inland)
    height += (fine - 0.5) * 0.008
    # Der Küstensaum fällt über rund 36 Kartenpixel auf Meereshöhe ab, damit
    # keine schwarze Klippenlinie um jede Landmasse entsteht.
    coastal = np.clip(coast_dist / (36.0 * SS), 0.0, 1.0).astype(np.float32)
    height *= (0.10 + 0.90 * coastal) * land
    height = gaussian_filter(height, sigma=1.5).astype(np.float32)
    height = np.clip(height, 0.035, 0.83) * land
    height[~land] = 0.0
    return height, land


def make_normal(height: np.ndarray, land: np.ndarray) -> Image.Image:
    gy, gx = np.gradient(height.astype(np.float32))
    strength = 78.0
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx /= length
    ny /= length
    nz /= length
    rgb = np.stack([
        (nx * 0.5 + 0.5) * 255.0,
        (ny * 0.5 + 0.5) * 255.0,
        (nz * 0.5 + 0.5) * 255.0,
    ], axis=-1)
    rgb[~land] = (128.0, 128.0, 255.0)
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def postprocess(work: Path) -> None:
    raw_relief = work / "relief_shaded_raw.png"
    if not raw_relief.exists():
        raise SystemExit("Blender hat kein Relief gerendert: %s" % raw_relief)
    relief = Image.open(raw_relief).convert("RGB").resize((SW, SH), Image.LANCZOS)
    # Das Relief ist absichtlich neutral: Es wird im Renderer multipliziert und
    # moduliert so die Provinzfarben, statt eine zweite Terrainpalette
    # einzuführen. Die Normalisierung nimmt nur die Blender-Luminanz und hält
    # den Kontrast unabhängig von der Beleuchtung reproduzierbar. Meer ist weiß
    # und bleibt bei der Multiplikation unverändert.
    rgb = np.asarray(relief, dtype=np.float32) / 255.0
    alpha = np.asarray(Image.open(work / "land_mask.png").convert("L"))
    is_land = alpha > 127
    lum = rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
    if is_land.any():
        lo, hi = np.percentile(lum[is_land], [1.0, 99.0])
        normalized = np.clip((lum - lo) / max(float(hi - lo), 1e-6), 0.0, 1.0)
        shade = 0.42 + 0.55 * (normalized ** 1.06)
        warm = np.stack([shade, shade * 0.985, shade * 0.955], axis=-1)
        rgb = np.where(is_land[..., None], warm, 1.0)
    Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8), "RGB").save(
        OUT / "relief_shaded.png", optimize=True)

    for name, size in (("marker_castle_raw.png", (256, 256)),
                       ("marker_banner_raw.png", (256, 256))):
        image = Image.open(work / name).convert("RGBA")
        if image.size != size:
            image = image.resize(size, Image.LANCZOS)
        image.save(OUT / name.replace("_raw", ""), optimize=True)


def write_outputs(provinces: list[dict], blender: Path, godot: Path) -> None:
    height_img = Image.open(work_height()).convert("L")
    normal_img = Image.open(OUT / "normal_map.png").convert("RGB")
    if height_img.size != (SW, SH) or normal_img.size != (SW, SH):
        raise SystemExit("Höhenkarte/Normalmap haben die falsche Größe.")
    if len(provinces) != 49:
        raise SystemExit("Provinzdaten unvollständig.")
    # Die Marker-GLB stammen aus Blender; nur kopieren, nie neu schreiben.
    for name in ("marker_castle.glb", "marker_banner.glb"):
        src = WORK / name
        if not src.exists() or src.stat().st_size < 4096:
            raise SystemExit("Blender-Marker fehlt oder ist zu klein: %s" % src)
        shutil.copy2(src, OUT / name)

    roles = {
        "heightmap.png": "16-bit-fähiges 8-bit-Höhenfeld, 2400x1520",
        "normal_map.png": "Tangent-Space-Normalmap aus dem Höhenfeld, 2400x1520",
        "relief_shaded.png": "Blender-Cycles-Shaded-Relief, 2400x1520 RGB, per Multiply im Renderer",
        "marker_castle.png": "Blender-Render der Burg-Halte, 256x256 RGBA",
        "marker_banner.png": "Blender-Render des Königreichsbanners, 256x256 RGBA",
        "marker_castle.glb": "Low-Poly-Burg-Mesh aus Blender 5.2, GLB",
        "marker_banner.glb": "Low-Poly-Banner-Mesh aus Blender 5.2, GLB",
    }
    entries = []
    for name, role in roles.items():
        path = OUT / name
        if not path.exists():
            raise SystemExit("Ausgabe fehlt: %s" % path)
        entry = {
            "path": "assets/map/generated/" + name,
            "role": role,
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
        if name.endswith(".png"):
            with Image.open(path) as image:
                entry["size"] = list(image.size)
                entry["mode"] = image.mode
        entries.append(entry)

    manifest = {
        "generator": "tools/gen_map_assets.py",
        "blender_generator": "tools/blender/gen_map_assets.py",
        "geometry_export": "tools/export_map_geometry.gd",
        "projection": {"size": [W, H], "raster": [SW, SH]},
        "source": [
            "data/europe_geometry.json",
            "scripts/Data.gd: provinces(), COUNTY_TERRAIN, 49 Grafschaften",
            "assets/map/generated/heightmap.png",
        ],
        "license": "Eigene prozedurale Projekt-Assets. Keine CK3-Dateien, keine Fremdassets.",
        "blender": blender.name + " (headless, Cycles CPU)",
        "godot": str(godot),
        "assets": entries,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "PROVENANCE.md").write_text(
        "# Herkunft und Lizenz der generierten Kartenassets\n\n"
        "Alle Dateien in diesem Ordner werden von `tools/gen_map_assets.py` und\n"
        "`tools/blender/gen_map_assets.py` aus den eigenen Projektdaten erzeugt.\n"
        "Quellen sind die 49 Provinzpolygone und Geländetypen aus `scripts/Data.gd`\n"
        "sowie die daraus gebaute Höhenkarte. Es wurden keine CK3-Dateien, keine\n"
        "Natural-Earth-Rohdaten und keine fremden Meshes oder Texturen übernommen.\n\n"
        "Die vorgelagerte Provinzgeometrie in `data/europe_geometry.json` wird durch\n"
        "`tools/make_europe_map.py` aus Natural-Earth-Länderumrissen (Public Domain)\n"
        "abgeleitet und mit eigenen Spielankern unterteilt. Diese Quellenkette gilt\n"
        "auch für das daraus abgeleitete prozedurale Relief. Der aktuelle Atlas nutzt\n"
        "einen separaten Natural-Earth-II-Untergrund; siehe `docs/atlas-sources.md`\n"
        "und `data/atlas_terrain_source.json` für die tatsächlichen Laufzeitquellen.\n\n"
        "Die Assets sind eigene prozedurale Werke des Projekts. Die Hash- und\n"
        "Größenliste steht in `manifest.json`; der Generator löscht diesen Ordner\n"
        "vor jedem Lauf vollständig und schreibt ihn neu.\n",
        encoding="utf-8",
    )
    print("MAPASSETS MANIFEST", len(entries), "Dateien")


def work_height() -> Path:
    return WORK / "heightmap.png"


def main() -> None:
    args = parse_args()
    blender = find_blender(args.blender)
    godot = Path(args.godot).resolve()
    if not godot.exists():
        raise SystemExit("Godot fehlt: %s" % godot)
    if OUT.exists():
        shutil.rmtree(OUT)
    if WORK.exists():
        shutil.rmtree(WORK)
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)

    print("MAPASSETS Blender:", blender)
    print("MAPASSETS Godot:", godot)
    data = export_geometry(godot)
    provinces = data["provinces"]
    height, land = build_height(provinces)
    height_img = Image.fromarray((np.clip(height, 0, 1) * 255).astype(np.uint8), "L")
    height_img.save(WORK / "heightmap.png", optimize=True)
    height_img.save(OUT / "heightmap.png", optimize=True)
    normal_img = make_normal(height, land)
    normal_img.save(OUT / "normal_map.png", optimize=True)
    landmark = Image.fromarray((land.astype(np.uint8) * 255), "L")
    landmark.save(WORK / "land_mask.png", optimize=True)

    run([str(blender), "--background", "--factory-startup", "--python",
         str(ROOT / "tools" / "blender" / "gen_map_assets.py"), "--",
         "--height", str(WORK / "heightmap.png"), "--work", str(WORK)], timeout=900)
    postprocess(WORK)
    write_outputs(provinces, blender, godot)

    print("MAPASSETS FILES")
    for path in sorted(OUT.iterdir()):
        if path.is_file():
            print("%12d  %s  %s" % (path.stat().st_size, sha256(path)[:16], path.name))
    print("MAPASSETS OK: Höhenkarte, Normalmap, Shaded Relief, 2 Marker-Sprites, 2 Marker-GLB")


if __name__ == "__main__":
    main()
