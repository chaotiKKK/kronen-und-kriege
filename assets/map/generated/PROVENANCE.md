# Herkunft und Lizenz der generierten Kartenassets

Alle Dateien in diesem Ordner werden von `tools/gen_map_assets.py` und
`tools/blender/gen_map_assets.py` aus den eigenen Projektdaten erzeugt.
Quellen sind die 49 Provinzpolygone und Geländetypen aus `scripts/Data.gd`
sowie die daraus gebaute Höhenkarte. Es wurden keine CK3-Dateien, keine
Natural-Earth-Rohdaten und keine fremden Meshes oder Texturen übernommen.

Die Assets sind eigene prozedurale Werke des Projekts. Die Hash- und
Größenliste steht in `manifest.json`; der Generator löscht diesen Ordner
vor jedem Lauf vollständig und schreibt ihn neu.
