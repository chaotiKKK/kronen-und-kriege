"""Georeferenziert Natural Earth II als Offline-Untergrund des Spielatlas.

Dies ist eine deterministische GIS-Rasterverarbeitung: Die geografischen
Koordinaten bleiben mit den Vektoren deckungsgleich. Keine generierten Berge.
Natural Earth II 3.2.0, Public Domain; Quellenbeleg wird mitgeschrieben.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_URL = "https://naturalearth.s3.amazonaws.com/10m_raster/NE2_HR_LC_SR_W_DR.zip"
SOURCE = ROOT / ".tools/atlas_sources/NE2_HR_LC_SR_W_DR.zip"
DESTINATION = ROOT / "assets/map/atlas_terrain.webp"
BOUNDS = (-12, 33, 52, 72)


def pixel_bounds(size, bounds):
    width, height = size
    west, south, east, north = bounds
    if width <= 0 or height <= 0 or not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
        raise ValueError("Ungültige geografische Rastergrenzen")
    return (
        round((west + 180) / 360 * width),
        round((90 - north) / 180 * height),
        round((east + 180) / 360 * width),
        round((90 - south) / 180 * height),
    )


def main():
    from PIL import Image

    if not SOURCE.exists():
        SOURCE.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["curl.exe", "--fail", "--location", "--retry", "2", "--output", str(SOURCE), SOURCE_URL], check=True)
    source_sha = hashlib.file_digest(SOURCE.open("rb"), "sha256").hexdigest()
    with zipfile.ZipFile(SOURCE) as archive:
        member = next(name for name in archive.namelist() if name.lower().endswith(".tif"))
        # Nur der bekannte Rasterinhalt wird unter festem Zielnamen extrahiert.
        raster = SOURCE.with_suffix(".tif")
        expected_size = archive.getinfo(member).file_size
        if not raster.exists() or raster.stat().st_size != expected_size:
            with archive.open(member) as original, raster.open("wb") as target:
                shutil.copyfileobj(original, target)
    Image.MAX_IMAGE_PIXELS = 300_000_000
    with Image.open(raster) as image:
        original_size = image.size
        crop = pixel_bounds(image.size, BOUNDS)
        terrain = image.crop(crop).convert("RGB")
    # Das Pixel-Seitenverhältnis entspricht exakt dem vorhandenen Kartenraum.
    terrain = terrain.resize((4800, 3040), Image.Resampling.LANCZOS)
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    terrain.save(DESTINATION, "WEBP", quality=94, method=6)
    receipt = {
        "source": SOURCE_URL,
        "product": "Natural Earth II with Shaded Relief, Water, and Drainages",
        "version": "3.2.0",
        "license": "Public Domain",
        "license_url": "https://www.naturalearthdata.com/about/terms-of-use/",
        "source_sha256": source_sha,
        "source_size": list(original_size),
        "bounds": list(BOUNDS),
        "source_crop": list(crop),
        "output": "res://assets/map/atlas_terrain.webp",
        "output_size": [4800, 3040],
        "output_sha256": hashlib.sha256(DESTINATION.read_bytes()).hexdigest(),
        "changes": "Geografischer Ausschnitt Europa; an Kartenraum 1200x760 angepasst; WebP 94%.",
    }
    (ROOT / "data/atlas_terrain_source.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt, ensure_ascii=False))


if __name__ == "__main__":
    main()
