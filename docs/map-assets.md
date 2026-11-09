# Kartenassets aus Blender

Die Weltkarte verwendet seit dieser Ausbaustufe eigene, aus den Projektdaten
erzeugte 3D-Relief-Assets. Es gibt keine CK3-Dateien und keine Fremdmeshes in
diesem Satz.

## Ein Befehl, ein vollständiger Satz

```bash
python tools/gen_map_assets.py
python tools/verify_map_assets.py --verbose
.tools/godot.exe --headless --path . --import
```

`gen_map_assets.py` löscht `assets/map/generated/` und
`build/map_asset_work/` vor jedem Lauf vollständig. Ein zweiter Lauf erzeugt
denselben Dateisatz.

Ablauf:

1. `tools/export_map_geometry.gd` exportiert die fertigen 49 Provinzpolygone,
   Geländetypen, Labels und Hauptstadtmarker aus `scripts/Data.gd` als JSON.
2. `tools/gen_map_assets.py` rastert daraus eine 2400×1520-Höhenkarte. Die
   Höhen stammen aus einer geglätteten Geländemasse, gerichteten
   Ridged-Noise-Bergrücken und einem weichen Küstensaum.
3. Die Normalmap wird per Sobel-Gradient aus demselben Höhenfeld berechnet.
4. `tools/blender/gen_map_assets.py` baut in Blender 5.2 headless ein
   Relief-Mesh (400×253 Gitter), beleuchtet es mit Cycles und rendert
   `relief_shaded.png`. Anschließend baut und rendert dasselbe Skript die
   Low-Poly-Burg und das Königreichsbanner und exportiert beide als GLB.
5. Das Relief wird auf neutrale Helligkeit normalisiert; Meer bleibt weiß.
   Dadurch kann der Renderer es per `blend_mul` über die Provinzfarben legen.
6. `manifest.json` und `PROVENANCE.md` dokumentieren Quellen, Rollen, Größen
   und SHA-256-Hashes. `tools/verify_map_assets.py` prüft sie.

## Dateien

| Datei | Format | Verwendung |
|---|---|---|
| `heightmap.png` | 2400×1520, L | Höhenquelle, reproduzierbar |
| `normal_map.png` | 2400×1520, RGB | Normalmap aus dem Höhenfeld |
| `relief_shaded.png` | 2400×1520, RGB | Blender-Shading, per Multiplikation im Renderer |
| `marker_castle.png` | 256×256, RGBA | Halte-Marker an allen neun Hauptstädten |
| `marker_banner.png` | 256×256, RGBA | Königreichsbanner; Reichssitze mit Goldring |
| `marker_castle.glb` | glTF 2.0 | Low-Poly-Burg-Mesh |
| `marker_banner.glb` | glTF 2.0 | Low-Poly-Banner-Mesh |

## Integration

`MapBase.gd` lädt `relief_shaded.png` als eigenes `TextureRect`-Kind und
verwendet den Shader `shaders/map_relief.gdshader` mit `render_mode
blend_mul`. Die Stärke ist im Politik-/Titel-/Kriegsmodus 0.48 und im
Gelände-/Entwicklungsmodus 0.64. Die Provinzfarben, Grenzen und
Auswahlzustände bleiben dadurch farblich erhalten; das Relief verändert nur
ihre Helligkeit. Der Shader läuft unter dem normalen 2D-Renderer, nicht als
teurer Screen-Space-Effekt.

`MapView.gd` lädt beide Marker-Sprites. `marker_specs()` wählt alle neun
Hauptstädte; pro Reich wird zusätzlich die entwicklungsstärkste Hauptstadt als
Reichssitz bestimmt (Gades, Latium, Hatti). Die Marker skalieren mit dem Zoom
und werden bei 1,28× gedeckelt. Die Markerflächen werden vor den
Provinzbeschriftungen in die Kollisionsliste eingetragen.

## Prüfung

`tests/MapAssetTest.tscn` prüft:

- alle sieben Dateien, PNG-Größen/-Modi, Alpha, Farbvielfalt und Kontrast,
- GLB-Magic und Mindestgröße,
- Manifestpfade und Herkunftsnachweis,
- dass `MapBase` wirklich `relief_shaded.png` und das ShaderMaterial verwendet,
- neun Halte-/Königreichsmarker und drei Reichssitze,
- Zoomskalierung und Deckelung.

`tests/MapPerfTest.tscn` prüft zusätzlich die geladene Relieftextur und die
neun Marker im echten Fenster; `ShotTest` erzeugt die Modusscreenshots unter
`build/verify/map-modes/`.

## Gestaltung gegenüber CK3

Näher am Original sind jetzt:

- echte Höhen-/Normaldaten statt nur gemalter Geländefarbe,
- weiches, multiplikatives Relief in allen Kartenmodi,
- begehbare 3D-Halte- und Bannerobjekte mit glaubwürdiger Perspektive,
- zoomabhängige Marker, die in der Übersicht lesbar und im 4×-Zoom gedeckelt
  bleiben.

Bewusst eigenständig bleiben die bronzezeitliche Projektion, die 49
Grafschaften, die neun Königreiche und die drei Reiche. Die Assets sind
stilisiert und aus den eigenen Daten erzeugt, nicht aus CK3 übernommen.
